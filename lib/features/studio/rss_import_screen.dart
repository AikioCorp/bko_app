import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

class RssImportScreen extends ConsumerStatefulWidget {
  final String? initialPodcastId;
  const RssImportScreen({super.key, this.initialPodcastId});

  @override
  ConsumerState<RssImportScreen> createState() => _RssImportScreenState();
}

class _RssImportScreenState extends ConsumerState<RssImportScreen> {
  final _urlController = TextEditingController();
  int _step =
      1; // 1: URL input & podcast select, 2: Preview & mapping, 3: Confirm & sync
  bool _analyzing = false;
  bool _importing = false;
  String? _errorMessage;

  List<dynamic> _podcasts = [];
  String? _selectedPodcastId;
  bool _loadingPodcasts = true;

  Map<String, dynamic>? _previewData;
  bool _autoSync = true;

  @override
  void initState() {
    super.initState();
    _loadCreatorPodcasts();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadCreatorPodcasts() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      if (mounted) setState(() => _loadingPodcasts = false);
      return;
    }
    try {
      final res = await BkoApi.get('/creator/podcasts', token: auth.token);
      final list = (res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] : [])) as List;
      if (mounted) {
        setState(() {
          _podcasts = list;
          if (_podcasts.isNotEmpty) {
            _selectedPodcastId =
                _podcasts.any((p) => '${p['id']}' == widget.initialPodcastId)
                    ? widget.initialPodcastId
                    : '${_podcasts.first['id']}';
          }
          _loadingPodcasts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPodcasts = false;
          _errorMessage = 'Impossible de charger vos émissions. Réessayez.';
        });
      }
    }
  }

  Future<void> _analyzeRssFeed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _errorMessage =
          'Veuillez saisir une adresse HTTP(S) de flux RSS valide.');
      return;
    }

    if (_selectedPodcastId == null) {
      setState(() => _errorMessage =
          'Veuillez sélectionner une émission pour y lier ce flux RSS.');
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() {
      _analyzing = true;
      _errorMessage = null;
    });

    try {
      final res = await BkoApi.post(
        '/creator/podcasts/$_selectedPodcastId/rss/preview',
        {'feedUrl': url},
        token: auth.token,
      );

      if (!mounted) return;
      setState(() {
        _previewData = res is Map ? Map<String, dynamic>.from(res) : null;
        _analyzing = false;
        if (_previewData != null) {
          _step = 2;
        } else {
          _errorMessage = 'Impossible d\'analyser ce flux RSS.';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = 'Erreur lors de l\'analyse du flux RSS.';
      });
    }
  }

  Future<void> _confirmImport() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated ||
        auth.token == null ||
        _selectedPodcastId == null) {
      return;
    }

    setState(() {
      _importing = true;
      _errorMessage = null;
    });

    try {
      await BkoApi.post(
        '/creator/podcasts/$_selectedPodcastId/rss/connect',
        {
          'feedUrl': _urlController.text.trim(),
          'autoSync': _autoSync,
        },
        token: auth.token,
      );

      if (!mounted) return;
      setState(() {
        _importing = false;
        _step = 3;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _errorMessage = 'Échec de la connexion du flux RSS.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        backgroundColor: bgSurf,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Importation RSS',
          style: BkoTheme.fontLato(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
      ),
      body: _loadingPodcasts
          ? const Center(
              child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_podcasts.isEmpty)
                    TextButton(
                        onPressed: () async {
                          await context.push('/studio/podcasts/new');
                          if (mounted) _loadCreatorPodcasts();
                        },
                        child: const Text(
                            'Créer d’abord une émission pour accueillir le flux RSS')),
                  // Step Indicator
                  Row(
                    children: [
                      _stepDot(1, 'Flux RSS'),
                      _stepLine(),
                      _stepDot(2, 'Aperçu'),
                      _stepLine(),
                      _stepDot(3, 'Statut'),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Step 1: Podcast selection & URL Input
                  if (_step == 1) ...[
                    if (_podcasts.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: bgElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderSub),
                        ),
                        child: Column(
                          children: [
                            const Icon(IconsaxPlusLinear.radio,
                                size: 48, color: BkoTheme.goldAccent),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune émission trouvée',
                              style: BkoTheme.fontLato(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPri),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Vous devez d\'abord créer une émission dans votre studio avant de pouvoir y associer un flux RSS.',
                              textAlign: TextAlign.center,
                              style: BkoTheme.fontLato(
                                  fontSize: 13, color: textSec, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            BkoBounceable(
                              onTap: () {
                                BkoHaptics.light();
                                context.push('/studio/podcasts/new');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: BkoTheme.goldAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'CRÉER UNE ÉMISSION',
                                  style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: BkoTheme.darkBgObsidian,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'ÉMISSION DE DESTINATION',
                        style: BkoTheme.fontLato(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: textSec,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPodcastId,
                        dropdownColor: bgElevated,
                        style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: bgElevated,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: borderSub),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: BkoTheme.goldAccent),
                          ),
                        ),
                        items: _podcasts.map<DropdownMenuItem<String>>((p) {
                          return DropdownMenuItem<String>(
                            value: '${p['id']}',
                            child: Text(p['name'] ?? 'Émission',
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedPodcastId = val),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'ADRESSE DU FLUX RSS',
                        style: BkoTheme.fontLato(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: textSec,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _urlController,
                        style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'https://anchor.fm/s/12345/podcast/rss',
                          hintStyle: BkoTheme.fontLato(
                              fontSize: 13,
                              color: BkoTheme.getTextMuted(context)),
                          filled: true,
                          fillColor: bgElevated,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: borderSub),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: BkoTheme.goldAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Compatible avec Anchor, Spotify for Podcasters, Acast, Buzzsprout, Libsyn, Apple Podcasts et tout flux RSS 2.0 standard.',
                        style: BkoTheme.fontLato(
                            fontSize: 11.5, color: textSec, height: 1.4),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: BkoTheme.fontLato(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (_analyzing)
                        const Center(
                          child: CircularProgressIndicator.adaptive(
                            valueColor:
                                AlwaysStoppedAnimation(BkoTheme.goldAccent),
                          ),
                        )
                      else
                        BkoBounceable(
                          onTap: () {
                            BkoHaptics.light();
                            _analyzeRssFeed();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: BkoTheme.goldAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  IconsaxPlusLinear.search_normal_1,
                                  size: 18,
                                  color: BkoTheme.darkBgObsidian,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ANALYSER LE FLUX RSS',
                                  style: BkoTheme.fontLato(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: BkoTheme.darkBgObsidian,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],

                  // Step 2: Preview & Mapping
                  if (_step == 2 && _previewData != null) ...[
                    Text(
                      'APERÇU DU FLUX DÉTECTÉ',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderSub),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_previewData!['title'] ?? 'Émission RSS'}',
                            style: BkoTheme.fontLato(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textPri),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_previewData!['description'] ?? 'Aucune description'}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: BkoTheme.fontLato(
                                fontSize: 12.5, color: textSec, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(IconsaxPlusLinear.radio,
                                  size: 16, color: BkoTheme.goldAccent),
                              const SizedBox(width: 6),
                              Text(
                                '${_previewData!['itemCount'] ?? _previewData!['episodesCount'] ?? 0} épisodes détectés',
                                style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: textPri),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _autoSync,
                      activeThumbColor: BkoTheme.goldAccent,
                      title: Text(
                        'Synchronisation automatique',
                        style: BkoTheme.fontLato(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: textPri),
                      ),
                      subtitle: Text(
                        'Importer automatiquement les nouveaux épisodes publiés sur le flux RSS.',
                        style:
                            BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                      ),
                      onChanged: (val) => setState(() => _autoSync = val),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (_importing)
                      const Center(
                        child: CircularProgressIndicator.adaptive(
                          valueColor:
                              AlwaysStoppedAnimation(BkoTheme.goldAccent),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: BkoBounceable(
                              onTap: () {
                                BkoHaptics.light();
                                setState(() => _step = 1);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: bgElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderSub),
                                ),
                                child: Text(
                                  'MODIFIER',
                                  style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: textPri,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: BkoBounceable(
                              onTap: () {
                                BkoHaptics.light();
                                _confirmImport();
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: BkoTheme.goldAccent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'CONNECTER ET IMPORTER',
                                  style: BkoTheme.fontLato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: BkoTheme.darkBgObsidian,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],

                  // Step 3: Success Confirmation
                  if (_step == 3) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: bgElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderSub),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    BkoTheme.goldAccent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                IconsaxPlusLinear.tick_circle,
                                size: 56,
                                color: BkoTheme.goldAccent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Flux RSS Connecté !',
                              style: BkoTheme.fontLato(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textPri),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'L\'émission et ses épisodes sont en cours de synchronisation avec Bamako Podcast.',
                              textAlign: TextAlign.center,
                              style: BkoTheme.fontLato(
                                  fontSize: 13, color: textSec, height: 1.4),
                            ),
                            const SizedBox(height: 28),
                            BkoBounceable(
                              onTap: () {
                                BkoHaptics.light();
                                context.go('/studio');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                decoration: BoxDecoration(
                                  color: BkoTheme.goldAccent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'REVENIR AU STUDIO',
                                  style: BkoTheme.fontLato(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: BkoTheme.darkBgObsidian,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stepDot(int stepNum, String label) {
    final active = _step >= stepNum;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? BkoTheme.goldAccent
                : BkoTheme.getBgSurfaceElevated(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? BkoTheme.goldAccent
                  : BkoTheme.getBorderSubtle(context),
            ),
          ),
          child: Text(
            '$stepNum',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: active
                  ? BkoTheme.darkBgObsidian
                  : BkoTheme.getTextSecondary(context),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 10,
            color: active
                ? BkoTheme.goldAccent
                : BkoTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _stepLine() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: BkoTheme.getBorderSubtle(context),
      ),
    );
  }
}

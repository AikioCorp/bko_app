import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_header_actions.dart';
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
  final _podcastNameController = TextEditingController();
  final _podcastDescController = TextEditingController();
  String _targetMode = 'new';
  String? _createdPodcastId;

  int _step = 1; // 1: URL & podcast, 2: Preview & mapping, 3: Confirm & sync
  bool _analyzing = false;
  bool _importing = false;
  String? _errorMessage;

  List<dynamic> _podcasts = [];
  String? _selectedPodcastId;
  bool _loadingPodcasts = true;

  Map<String, dynamic>? _previewData;
  bool _autoSync = true;

  // État de la connexion RSS existante
  Map<String, dynamic>? _existingFeed;
  bool _loadingFeed = false;
  bool _syncingNow = false;
  bool _pausingFeed = false;
  bool _disconnectingFeed = false;
  bool _showReconfigure = false;

  @override
  void initState() {
    super.initState();
    _loadCreatorPodcasts();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _podcastNameController.dispose();
    _podcastDescController.dispose();
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
        String? chosenId;
        if (list.isNotEmpty) {
          chosenId = list.any((p) => '${p['id']}' == widget.initialPodcastId)
              ? widget.initialPodcastId
              : '${list.first['id']}';
        }
        setState(() {
          _podcasts = list;
          _selectedPodcastId = chosenId;
          _loadingPodcasts = false;
        });
        if (chosenId != null) {
          _loadExistingRssFeed(chosenId);
        }
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

  Future<void> _loadExistingRssFeed(String podcastId) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _loadingFeed = true);
    try {
      final res = await BkoApi.get('/creator/podcasts/$podcastId/rss', token: auth.token);
      if (!mounted) return;
      setState(() {
        _existingFeed = res is Map ? Map<String, dynamic>.from(res) : null;
        _loadingFeed = false;
        if (_existingFeed != null) {
          _showReconfigure = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _existingFeed = null;
        _loadingFeed = false;
      });
    }
  }

  Future<void> _syncNow() async {
    final auth = ref.read(authProvider);
    if (_selectedPodcastId == null || auth.token == null) return;
    setState(() => _syncingNow = true);
    try {
      await BkoApi.post('/creator/podcasts/$_selectedPodcastId/rss/sync', {}, token: auth.token);
      if (mounted) {
        BkoHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande de synchronisation lancée avec succès.')),
        );
        await _loadExistingRssFeed(_selectedPodcastId!);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec du lancement de la synchronisation.')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingNow = false);
    }
  }

  Future<void> _togglePauseFeed() async {
    final auth = ref.read(authProvider);
    if (_selectedPodcastId == null || auth.token == null) return;
    setState(() => _pausingFeed = true);
    try {
      final res = await BkoApi.post('/creator/podcasts/$_selectedPodcastId/rss/pause', {}, token: auth.token);
      if (mounted) {
        BkoHaptics.light();
        final msg = res is Map && res['message'] != null ? res['message'].toString() : 'Statut mis à jour.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        await _loadExistingRssFeed(_selectedPodcastId!);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de modifier le statut de synchronisation.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pausingFeed = false);
    }
  }

  Future<void> _disconnectFeed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurfaceElevated(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: BkoTheme.getBorderSubtle(context)),
        ),
        title: Text(
          'Déconnecter le flux RSS ?',
          style: BkoTheme.fontPoppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        content: Text(
          'Déconnecter le flux conserve tous les épisodes déjà importés sur Bamako Podcast, mais arrêtera définitivement leur mise à jour automatique. Voulez-vous continuer ?',
          style: BkoTheme.fontLato(
            fontSize: 13,
            color: BkoTheme.getTextSecondary(context),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: BkoTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = ref.read(authProvider);
    if (_selectedPodcastId == null || auth.token == null) return;

    setState(() => _disconnectingFeed = true);
    try {
      await BkoApi.delete('/creator/podcasts/$_selectedPodcastId/rss', token: auth.token);
      if (mounted) {
        BkoHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flux RSS déconnecté. Vos épisodes existants sont conservés.')),
        );
        setState(() {
          _existingFeed = null;
          _showReconfigure = false;
          _step = 1;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la déconnexion du flux.')),
        );
      }
    } finally {
      if (mounted) setState(() => _disconnectingFeed = false);
    }
  }

  Future<void> _analyzeRssFeed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _errorMessage = 'Veuillez saisir une adresse HTTP(S) de flux RSS valide.');
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
        _selectedPodcastId != null
            ? '/creator/podcasts/$_selectedPodcastId/rss/preview'
            : '/creator/rss/preview',
        {'feedUrl': url},
        token: auth.token,
      );

      if (!mounted) return;
      final data = res is Map ? Map<String, dynamic>.from(res) : null;
      setState(() {
        _previewData = data;
        _analyzing = false;
        if (_previewData != null) {
          _podcastNameController.text = _previewData!['title']?.toString() ?? '';
          _podcastDescController.text = _previewData!['description']?.toString() ?? '';
          if (_selectedPodcastId == null || _podcasts.isEmpty) {
            _targetMode = 'new';
          }
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
    if (!auth.isAuthenticated || auth.token == null) {
      return;
    }

    setState(() {
      _importing = true;
      _errorMessage = null;
    });

    try {
      String? podcastIdToUse = _targetMode == 'existing' ? _selectedPodcastId : _createdPodcastId;

      if (_targetMode == 'new' && podcastIdToUse == null) {
        final title = _podcastNameController.text.trim();
        if (title.isEmpty) {
          setState(() {
            _importing = false;
            _errorMessage = 'Veuillez renseigner un titre pour l\'émission.';
          });
          return;
        }

        final createRes = await BkoApi.post(
          '/creator/podcasts',
          {
            'name': title,
            'description': _podcastDescController.text.trim(),
            'cover': _previewData?['image']?.toString() ?? '',
            'countryId': 'ML',
            'primaryLanguageCode': 'fr',
            'status': 'DRAFT',
          },
          token: auth.token,
        );

        final createMap = createRes is Map ? Map<String, dynamic>.from(createRes) : <String, dynamic>{};
        podcastIdToUse = '${createMap['id'] ?? createMap['data']?['id']}';
        _createdPodcastId = podcastIdToUse;
        _selectedPodcastId = podcastIdToUse;
      }

      if (podcastIdToUse == null) {
        setState(() {
          _importing = false;
          _errorMessage = 'Veuillez sélectionner une émission de destination.';
        });
        return;
      }

      await BkoApi.post(
        '/creator/podcasts/$podcastIdToUse/rss/connect',
        {
          'feedUrl': _urlController.text.trim(),
          'autoSync': _autoSync,
          'importSettings': {
            'keepManualEdits': true,
          },
          'sourceAuthor': _previewData?['author'],
        },
        token: auth.token,
      );

      if (!mounted) return;
      setState(() {
        _importing = false;
        _step = 3;
      });
      await _loadExistingRssFeed(podcastIdToUse);
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

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'Jamais';
    try {
      final dt = DateTime.parse(dateVal.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return 'il y a ${diff.inMinutes} min';
      }
      if (diff.inHours < 24) {
        return 'il y a ${diff.inHours} h';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateVal.toString();
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
          'Gestion du Flux RSS',
          style: BkoTheme.fontLato(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPri,
          ),
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
                  // Sélecteur d'émission
                  if (_podcasts.isNotEmpty) ...[
                    Text(
                      'ÉMISSION DU STUDIO',
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderSub),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: BkoTheme.goldAccent),
                        ),
                      ),
                      items: _podcasts.map<DropdownMenuItem<String>>((p) {
                        return DropdownMenuItem<String>(
                          value: '${p['id']}',
                          child: Text(p['name'] ?? 'Émission', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPodcastId = val;
                            _showReconfigure = false;
                            _step = 1;
                            _previewData = null;
                            _errorMessage = null;
                          });
                          _loadExistingRssFeed(val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_loadingFeed)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(
                          valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
                        ),
                      ),
                    )
                  else if (_existingFeed != null && !_showReconfigure) ...[
                    // TABLEAU DE BORD DU FLUX RSS CONNECTÉ
                    _buildConnectedDashboard(bgElevated, borderSub, textPri, textSec),
                  ] else ...[
                    // PARCOURS D'IMPORTATION / CONNEXION D'UN FLUX
                    _buildImportWizard(bgElevated, borderSub, textPri, textSec),
                  ],
                ],
              ),
            ),
    );
  }

  /// Dashboard du flux RSS connecté avec statut réel, synchro, pause/reprise et historique
  Widget _buildConnectedDashboard(Color bgElevated, Color borderSub, Color textPri, Color textSec) {
    final feed = _existingFeed!;
    final feedUrl = feed['url']?.toString() ?? '';
    final syncStatus = feed['syncStatus']?.toString() ?? 'IDLE';
    final syncEnabled = feed['syncEnabled'] != false;
    final lastSync = feed['lastSuccessfulSyncAt'] ?? feed['lastSyncAt'];
    final importedCount = feed['_count']?['importedEpisodes'] ??
        (feed['importedEpisodes'] is List ? (feed['importedEpisodes'] as List).length : 0);
    final syncRuns = (feed['syncRuns'] is List ? feed['syncRuns'] as List : []);

    Color statusBadgeColor = const Color(0xFF10B981);
    String statusLabel = 'FLUX ACTIF';

    if (syncStatus == 'RUNNING') {
      statusBadgeColor = BkoTheme.goldAccent;
      statusLabel = 'SYNCHRONISATION EN COURS';
    } else if (!syncEnabled) {
      statusBadgeColor = const Color(0xFFF59E0B);
      statusLabel = 'SYNCHRONISATION EN PAUSE';
    } else if (feed['errorMessage'] != null) {
      statusBadgeColor = Colors.redAccent.shade400;
      statusLabel = 'ERREUR DE SYNCHRONISATION';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carte d'état principale
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bgElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSub),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(IconsaxPlusLinear.radio, color: BkoTheme.goldAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'FLUX RSS CONNECTÉ',
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: textPri,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBadgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusBadgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusLabel,
                      style: BkoTheme.fontPoppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: statusBadgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // URL du flux avec bouton copier
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderSub),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        feedUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          color: textPri,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(IconsaxPlusLinear.copy, size: 16),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      color: textSec,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: feedUrl));
                        BkoHaptics.light();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lien du flux RSS copié !')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Métriques
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dernière synchro', style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(lastSync),
                          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w700, color: textPri),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Épisodes importés', style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                        const SizedBox(height: 2),
                        Text(
                          '$importedCount épisode(s)',
                          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w700, color: BkoTheme.goldAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Boutons d'action
        Row(
          children: [
            Expanded(
              child: BkoBounceable(
                onTap: _syncingNow ? () {} : _syncNow,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BkoTheme.goldAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _syncingNow
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          'SYNCHRONISER',
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: BkoTheme.darkBgObsidian,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BkoBounceable(
                onTap: _pausingFeed ? () {} : _togglePauseFeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderSub),
                  ),
                  child: _pausingFeed
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: BkoTheme.goldAccent),
                        )
                      : Text(
                          syncEnabled ? 'SUSPENDRE' : 'REPRENDRE',
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: syncEnabled ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Bouton de déconnexion
        SizedBox(
          width: double.infinity,
          child: BkoBounceable(
            onTap: _disconnectingFeed ? () {} : _disconnectFeed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.redAccent.shade700.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.shade700.withValues(alpha: 0.3)),
              ),
              child: _disconnectingFeed
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                    )
                  : Text(
                      'DÉCONNECTER LE FLUX RSS',
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent.shade200,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Règle de découplage
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderSub),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(IconsaxPlusLinear.info_circle, color: BkoTheme.goldAccent, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Règle de découplage : Déconnecter le flux conserve l\'ensemble des épisodes déjà importés sur Bamako Podcast. Seule la scrutation automatique des futures sorties est interrompue.',
                  style: BkoTheme.fontLato(fontSize: 11.5, color: textSec, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Historique des synchronisations
        if (syncRuns.isNotEmpty) ...[
          Text(
            'HISTORIQUE RÉCENT DES SYNCHROS',
            style: BkoTheme.fontLato(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: textSec,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderSub),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: syncRuns.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: borderSub),
              itemBuilder: (ctx, idx) {
                final run = syncRuns[idx];
                final isSuccess = run['status'] == 'SUCCESS';
                final isFailed = run['status'] == 'FAILED';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isSuccess
                            ? IconsaxPlusLinear.tick_circle
                            : isFailed
                                ? IconsaxPlusLinear.close_circle
                                : IconsaxPlusLinear.refresh_circle,
                        size: 16,
                        color: isSuccess
                            ? const Color(0xFF10B981)
                            : isFailed
                                ? Colors.redAccent
                                : BkoTheme.goldAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              run['trigger'] == 'MANUAL' ? 'Synchronisation manuelle' : 'Synchronisation automatique',
                              style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w700, color: textPri),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${run['episodesAdded'] ?? 0} ajouté(s) • ${run['episodesUpdated'] ?? 0} mis à jour',
                              style: BkoTheme.fontLato(fontSize: 11, color: textSec),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDate(run['startedAt']),
                        style: BkoTheme.fontLato(fontSize: 10.5, color: textSec),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Option pour reconfigurer
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() => _showReconfigure = true);
            },
            icon: const Icon(IconsaxPlusLinear.edit_2, size: 14, color: BkoTheme.goldAccent),
            label: Text(
              'Remplacer par un autre flux RSS',
              style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w700, color: BkoTheme.goldAccent),
            ),
          ),
        ),
      ],
    );
  }

  /// Wizard en 3 étapes pour configurer et connecter un nouveau flux RSS
  Widget _buildImportWizard(Color bgElevated, Color borderSub, Color textPri, Color textSec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_existingFeed != null) ...[
          TextButton.icon(
            onPressed: () => setState(() => _showReconfigure = false),
            icon: const Icon(IconsaxPlusLinear.arrow_left_2, size: 14, color: BkoTheme.goldAccent),
            label: Text(
              'Retour au flux actuel',
              style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w700, color: BkoTheme.goldAccent),
            ),
          ),
          const SizedBox(height: 10),
        ],

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
                hintStyle: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextMuted(context)),
                filled: true,
                fillColor: bgElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderSub),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: BkoTheme.goldAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Compatible avec Spotify for Podcasters, Acast, Buzzsprout, Libsyn, Apple Podcasts et tout flux RSS 2.0 standard.',
              style: BkoTheme.fontLato(fontSize: 11.5, color: textSec, height: 1.4),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
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
                  valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
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
                  style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w800, color: textPri),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_previewData!['description'] ?? 'Aucune description'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: BkoTheme.fontLato(fontSize: 12.5, color: textSec, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(IconsaxPlusLinear.radio, size: 16, color: BkoTheme.goldAccent),
                    const SizedBox(width: 6),
                    Text(
                      '${_previewData!['episodeCount'] ?? _previewData!['itemCount'] ?? _previewData!['episodesCount'] ?? 0} épisodes détectés',
                      style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: textPri),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_podcasts.isNotEmpty) ...[
            Text(
              'DESTINATION DE L’ÉMISSION',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: textSec,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: BkoBounceable(
                    onTap: () => setState(() => _targetMode = 'new'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _targetMode == 'new'
                            ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                            : bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _targetMode == 'new'
                              ? BkoTheme.goldAccent
                              : borderSub,
                        ),
                      ),
                      child: Text(
                        'Créer une émission',
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _targetMode == 'new'
                              ? BkoTheme.goldAccent
                              : textPri,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BkoBounceable(
                    onTap: () => setState(() => _targetMode = 'existing'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _targetMode == 'existing'
                            ? BkoTheme.goldAccent.withValues(alpha: 0.15)
                            : bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _targetMode == 'existing'
                              ? BkoTheme.goldAccent
                              : borderSub,
                        ),
                      ),
                      child: Text(
                        'Associer existante',
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _targetMode == 'existing'
                              ? BkoTheme.goldAccent
                              : textPri,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (_targetMode == 'new' || _podcasts.isEmpty) ...[
            Text(
              'TITRE DE L’ÉMISSION',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: textSec,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _podcastNameController,
              style: BkoTheme.fontLato(fontSize: 13.5, color: textPri),
              decoration: InputDecoration(
                filled: true,
                fillColor: bgElevated,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderSub),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: BkoTheme.goldAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'DESCRIPTION',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: textSec,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _podcastDescController,
              maxLines: 2,
              style: BkoTheme.fontLato(fontSize: 13, color: textPri),
              decoration: InputDecoration(
                filled: true,
                fillColor: bgElevated,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderSub),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: BkoTheme.goldAccent),
                ),
              ),
            ),
          ] else ...[
            Text(
              'ÉMISSION DU STUDIO',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: textSec,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedPodcastId,
              dropdownColor: bgElevated,
              style: BkoTheme.fontLato(fontSize: 13.5, color: textPri),
              decoration: InputDecoration(
                filled: true,
                fillColor: bgElevated,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderSub),
                ),
              ),
              items: _podcasts.map<DropdownMenuItem<String>>((p) {
                return DropdownMenuItem<String>(
                  value: '${p['id']}',
                  child: Text(p['name'] ?? 'Émission',
                      overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPodcastId = val);
              },
            ),
          ],
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoSync,
            activeThumbColor: BkoTheme.goldAccent,
            title: Text(
              'Synchronisation automatique',
              style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w800, color: textPri),
            ),
            subtitle: Text(
              'Importer automatiquement les futurs épisodes publiés sur le flux RSS.',
              style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
            ),
            onChanged: (val) => setState(() => _autoSync = val),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
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
                valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    onTap: _importing
                        ? null
                        : () {
                            BkoHaptics.light();
                            _confirmImport();
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _importing
                            ? BkoTheme.goldAccent.withValues(alpha: 0.5)
                            : BkoTheme.goldAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    BkoTheme.darkBgObsidian),
                              ),
                            )
                          : Text(
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
                      color: BkoTheme.goldAccent.withValues(alpha: 0.15),
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
                    style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w800, color: textPri),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'L\'émission et ses épisodes sont en cours de synchronisation avec Bamako Podcast.',
                    textAlign: TextAlign.center,
                    style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  BkoBounceable(
                    onTap: () {
                      BkoHaptics.light();
                      setState(() {
                        _showReconfigure = false;
                        _step = 1;
                      });
                      if (_selectedPodcastId != null) {
                        _loadExistingRssFeed(_selectedPodcastId!);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'VOIR LE SUIVI DU FLUX',
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
            color: active ? BkoTheme.goldAccent : BkoTheme.getBgSurfaceElevated(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? BkoTheme.goldAccent : BkoTheme.getBorderSubtle(context),
            ),
          ),
          child: Text(
            '$stepNum',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: active ? BkoTheme.darkBgObsidian : BkoTheme.getTextSecondary(context),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 10,
            color: active ? BkoTheme.goldAccent : BkoTheme.getTextSecondary(context),
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

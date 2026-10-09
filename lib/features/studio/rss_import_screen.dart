import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';

class RssImportScreen extends ConsumerStatefulWidget {
  const RssImportScreen({super.key});

  @override
  ConsumerState<RssImportScreen> createState() => _RssImportScreenState();
}

class _RssImportScreenState extends ConsumerState<RssImportScreen> {
  final _urlController = TextEditingController();
  int _step = 1; // 1: URL input, 2: Preview & mapping, 3: Confirm & sync
  bool _analyzing = false;
  bool _importing = false;
  String? _errorMessage;

  Map<String, dynamic>? _previewData;
  bool _autoSync = true;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
        '/creator/podcasts/import-rss/preview',
        {'rssUrl': url},
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
        _errorMessage = 'Erreur d\'analyse du flux RSS.';
      });
    }
  }

  Future<void> _confirmImport() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null || _previewData == null) return;

    setState(() {
      _importing = true;
      _errorMessage = null;
    });

    try {
      await BkoApi.post(
        '/creator/podcasts/import-rss',
        {
          'rssUrl': _urlController.text.trim(),
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
        _errorMessage = 'Échec de la synchronisation RSS.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        backgroundColor: bgSurf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Importation RSS', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // Step 1: URL Input
            if (_step == 1) ...[
              Text('ADRESSE DU FLUX RSS', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlController,
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: InputDecoration(
                  hintText: 'https://anchor.fm/s/12345/podcast/rss',
                  hintStyle: BkoTheme.fontLato(fontSize: 13, color: Colors.grey),
                  filled: true,
                  fillColor: BkoTheme.getBgSurfaceElevated(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderSub)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Compatible avec Anchor, Spotify for Podcasters, Acast, Buzzsprout, Libsyn, Apple Podcasts et tout flux RSS 2.0 standard.',
                style: BkoTheme.fontLato(fontSize: 11.5, color: textSec, height: 1.4),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                  child: Text(_errorMessage!, style: BkoTheme.fontLato(fontSize: 12, color: Colors.red.shade300)),
                ),
              ],

              const SizedBox(height: 32),

              if (_analyzing)
                const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _analyzeRssFeed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BkoTheme.goldAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 20, color: Colors.black),
                    label: Text('ANALYSER LE FLUX RSS', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
                  ),
                ),
            ],

            // Step 2: Preview & Mapping
            if (_step == 2 && _previewData != null) ...[
              Text('APERÇU DE L\'ÉMISSION DÉTECTÉE', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurfaceElevated(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderSub),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_previewData!['title'] ?? 'Émission RSS'}', style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w900, color: textPri)),
                    const SizedBox(height: 4),
                    Text('${_previewData!['description'] ?? 'Pas de description'}', maxLines: 3, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 12.5, color: textSec)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.podcasts_rounded, size: 16, color: BkoTheme.goldAccent),
                        const SizedBox(width: 6),
                        Text('${(_previewData!['episodes'] as List?)?.length ?? 0} Épisode(s) détectés', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w700, color: BkoTheme.goldAccent)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Options
              SwitchListTile(
                value: _autoSync,
                activeTrackColor: BkoTheme.goldAccent.withValues(alpha: 0.5),
                activeThumbColor: BkoTheme.goldAccent,
                contentPadding: EdgeInsets.zero,
                title: Text('Synchronisation automatique', style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w800, color: textPri)),
                subtitle: Text('Importer automatiquement les futurs épisodes publiés sur ce flux RSS.', style: BkoTheme.fontLato(fontSize: 11.5, color: textSec)),
                onChanged: (val) => setState(() => _autoSync = val),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                  child: Text(_errorMessage!, style: BkoTheme.fontLato(fontSize: 12, color: Colors.red.shade300)),
                ),
              ],

              const SizedBox(height: 28),

              if (_importing)
                const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step = 1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: borderSub),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('RETOURNER', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w800, color: textPri)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirmImport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BkoTheme.goldAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('CONFIRMER L\'IMPORT', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
                      ),
                    ),
                  ],
                ),
            ],

            // Step 3: Success & Status
            if (_step == 3) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: BkoTheme.goldAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle_rounded, size: 64, color: BkoTheme.goldAccent),
                      ),
                      const SizedBox(height: 20),
                      Text('Flux RSS Connecté !', style: BkoTheme.fontLato(fontSize: 22, fontWeight: FontWeight.w900, color: textPri)),
                      const SizedBox(height: 8),
                      Text(
                        'L\'émission et ses épisodes sont en cours de synchronisation avec le catalogue Bko Podcast.',
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => context.go('/studio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BkoTheme.goldAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('REVENIR AU STUDIO', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
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
            color: active ? BkoTheme.goldAccent : BkoTheme.getBgSurfaceElevated(context),
            shape: BoxShape.circle,
            border: Border.all(color: active ? BkoTheme.goldAccent : BkoTheme.getBorderSubtle(context)),
          ),
          child: Text(
            '$stepNum',
            style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, color: active ? Colors.black : BkoTheme.getTextSecondary(context)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: BkoTheme.fontLato(fontSize: 10, color: active ? BkoTheme.goldAccent : BkoTheme.getTextSecondary(context))),
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

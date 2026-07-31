import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';
import '../shell/shell_providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tab = 0; // 0 = enregistrés, 1 = historique, 2 = playlists
  bool _loading = false;
  List<dynamic> _saved = [];
  List<dynamic> _history = [];
  List<dynamic> _playlists = [];
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce && ref.read(authProvider).isAuthenticated) {
      _loadedOnce = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _loading = true);

    if (_tab == 0) {
      final data = await BkoApi.get('/me/saved', token: token);
      if (mounted) setState(() => _saved = (data as List?) ?? []);
    } else if (_tab == 1) {
      final data = await BkoApi.get('/me/history', token: token);
      if (mounted) setState(() => _history = (data as List?) ?? []);
    } else {
      final data = await BkoApi.get('/me/playlists', token: token);
      if (mounted) setState(() => _playlists = (data as List?) ?? []);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _selectTab(int i) {
    setState(() => _tab = i);
    _fetch();
  }

  void _play(Map ep) {
    final podcast = ep['podcast'] as Map?;
    final d = ep['durationSeconds'];
    final label = d is int ? '${(d / 60).round()} min' : '';

    final sources = (ep['mediaSources'] as List<dynamic>?) ?? [];
    String? audioUrl = ep['primaryAudioSource']?['externalUrl'] ??
        BkoApi.extractAudioUrl(Map<String, dynamic>.from(ep));
    String? videoUrl = ep['primaryVideoSource']?['embedUrl'] ??
        ep['primaryVideoSource']?['externalUrl'];

    if (videoUrl == null) {
      for (var s in sources) {
        if (s['type'] == 'VIDEO') {
          videoUrl = s['embedUrl'] ?? s['externalUrl'];
          break;
        }
      }
    }

    final cover = '${ep['cover'] ?? podcast?['cover'] ?? ''}';
    final bool hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;

    ref.read(activeEpisodeProvider.notifier).playEpisode(
          title: '${ep['title'] ?? ''}',
          showName: '${podcast?['name'] ?? ''}',
          duration: label,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: hasAudio,
          hasVideo: hasVideo,
          episodeId: '${ep['id'] ?? ''}',
          podcastSlug: '${podcast?['slug'] ?? ''}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    if (!auth.isAuthenticated) {
      return _LoginPrompt(textPri: textPri, textSec: textSec);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Ma bibliothèque',
                  style: BkoTheme.fontLato(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textPri)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _tabButton('Enregistrés', 0, surface, border, textSec),
                  const SizedBox(width: 8),
                  _tabButton('Historique', 1, surface, border, textSec),
                  const SizedBox(width: 8),
                  _tabButton('Playlists', 2, surface, border, textSec),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: BkoTheme.goldAccent))
                  : _buildTabContent(surface, border, textPri, textSec),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
      Color surface, Color border, Color textPri, Color textSec) {
    if (_tab == 2) {
      if (_playlists.isEmpty) return _empty('Aucune playlist.', textSec);
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: _playlists.map((pl) {
          final map = pl as Map;
          final count = (map['_count']?['items'] ?? 0).toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border)),
            child: Row(
              children: [
                const Icon(Icons.queue_music, color: BkoTheme.goldAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${map['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPri)),
                ),
                Text('$count épisodes',
                    style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
              ],
            ),
          );
        }).toList(),
      );
    }

    final list = _tab == 0 ? _saved : _history;
    if (list.isEmpty) {
      return _empty(
          _tab == 0
              ? 'Aucun épisode enregistré.'
              : 'Aucun historique d\'écoute.',
          textSec);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: list.map((raw) {
        // Historique : l'épisode est imbriqué sous `episode`. Enregistrés : l'objet EST l'épisode.
        final ep = (_tab == 1 && (raw as Map)['episode'] is Map)
            ? Map<String, dynamic>.from((raw)['episode'])
            : Map<String, dynamic>.from(raw as Map);
        return _episodeTile(ep, surface, border, textPri, textSec);
      }).toList(),
    );
  }

  Widget _tabButton(
      String label, int index, Color surface, Color border, Color textSec) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? BkoTheme.goldAccent : surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? BkoTheme.goldAccent : border),
          ),
          child: Text(label,
              style: BkoTheme.fontLato(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.black : textSec)),
        ),
      ),
    );
  }

  Widget _episodeTile(
      Map ep, Color bg, Color border, Color textPri, Color textSec) {
    final podcast = ep['podcast'] as Map?;
    final url = '${ep['cover'] ?? podcast?['cover'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: url.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: url,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallback(),
                    placeholder: (_, __) => _fallback(),
                  )
                : _fallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ep['title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPri)),
                const SizedBox(height: 2),
                Text('${podcast?['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill,
                color: BkoTheme.goldAccent, size: 34),
            onPressed: () => _play(ep),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
        width: 48,
        height: 48,
        color: BkoTheme.goldAccent.withValues(alpha: 0.12),
        child: const Icon(Icons.podcasts, color: BkoTheme.goldAccent),
      );

  Widget _empty(String text, Color color) => Center(
      child: Text(text, style: BkoTheme.fontLato(fontSize: 13, color: color)));
}

class _LoginPrompt extends StatelessWidget {
  final Color textPri;
  final Color textSec;
  const _LoginPrompt({required this.textPri, required this.textSec});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.library_music_outlined, size: 64, color: textSec),
                const SizedBox(height: 16),
                Text('Votre bibliothèque',
                    style: BkoTheme.fontLato(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPri)),
                const SizedBox(height: 6),
                Text(
                    'Connectez-vous pour retrouver vos épisodes enregistrés, votre historique et vos playlists.',
                    textAlign: TextAlign.center,
                    style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BkoTheme.goldAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('SE CONNECTER',
                      style: BkoTheme.fontLato(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

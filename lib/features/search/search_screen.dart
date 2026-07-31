import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../shell/shell_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  bool _searched = false;
  List<dynamic> _podcasts = [];
  List<dynamic> _episodes = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(value));
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _podcasts = [];
        _episodes = [];
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    final data = await BkoApi.get('/search?q=${Uri.encodeQueryComponent(q)}');
    if (!mounted) return;
    setState(() {
      if (data is Map) {
        _podcasts = (data['podcasts'] as List?) ?? [];
        _episodes = (data['episodes'] as List?) ?? [];
      } else {
        _podcasts = [];
        _episodes = [];
      }
      _loading = false;
      _searched = true;
    });
  }

  void _playEpisode(Map episode) {
    final podcast = episode['podcast'] as Map?;
    final durationSec = episode['durationSeconds'];
    final durLabel =
        durationSec is int ? '${(durationSec / 60).round()} min' : '';

    final sources = (episode['mediaSources'] as List<dynamic>?) ?? [];
    String? audioUrl = episode['primaryAudioSource']?['externalUrl'] ??
        BkoApi.extractAudioUrl(Map<String, dynamic>.from(episode));
    String? videoUrl = episode['primaryVideoSource']?['embedUrl'] ??
        episode['primaryVideoSource']?['externalUrl'];

    if (videoUrl == null) {
      for (var s in sources) {
        if (s['type'] == 'VIDEO') {
          videoUrl = s['embedUrl'] ?? s['externalUrl'];
          break;
        }
      }
    }

    final cover = '${episode['cover'] ?? podcast?['cover'] ?? ''}';
    final bool hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;

    ref.read(activeEpisodeProvider.notifier).playEpisode(
          title: '${episode['title'] ?? ''}',
          showName: '${podcast?['name'] ?? ''}',
          duration: durLabel,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: hasAudio,
          hasVideo: hasVideo,
          episodeId: '${episode['id'] ?? ''}',
          podcastSlug: '${podcast?['slug'] ?? ''}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Recherche',
                  style: BkoTheme.fontLato(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textPri)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                onSubmitted: _run,
                autofocus: false,
                style: BkoTheme.fontLato(fontSize: 14, color: textPri),
                decoration: InputDecoration(
                  hintText: 'Podcast, épisode, créateur…',
                  hintStyle: BkoTheme.fontLato(fontSize: 14, color: textSec),
                  prefixIcon: Icon(Icons.search, color: textSec),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: textSec),
                          onPressed: () {
                            _controller.clear();
                            _run('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: BkoTheme.goldAccent),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: BkoTheme.goldAccent))
                  : !_searched
                      ? Center(
                          child: Text(
                              'Tapez au moins 2 caractères pour rechercher.',
                              style: BkoTheme.fontLato(
                                  fontSize: 13, color: textSec)))
                      : (_podcasts.isEmpty && _episodes.isEmpty)
                          ? Center(
                              child: Text('Aucun résultat.',
                                  style: BkoTheme.fontLato(
                                      fontSize: 13, color: textSec)))
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 120),
                              children: [
                                if (_podcasts.isNotEmpty) ...[
                                  _sectionTitle('Podcasts', textPri),
                                  const SizedBox(height: 8),
                                  ..._podcasts.map((p) => _podcastTile(p as Map,
                                      surface, border, textPri, textSec)),
                                  const SizedBox(height: 20),
                                ],
                                if (_episodes.isNotEmpty) ...[
                                  _sectionTitle('Épisodes', textPri),
                                  const SizedBox(height: 8),
                                  ..._episodes.map((e) => _episodeTile(e as Map,
                                      surface, border, textPri, textSec)),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, Color color) => Text(label,
      style: BkoTheme.fontLato(
          fontSize: 16, fontWeight: FontWeight.w800, color: color));

  Widget _podcastTile(
      Map p, Color bg, Color border, Color textPri, Color textSec) {
    return GestureDetector(
      onTap: () {
        final slug = p['slug'];
        if (slug is String && slug.isNotEmpty) context.go('/podcasts/$slug');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border)),
        child: Row(
          children: [
            _cover('${p['cover'] ?? ''}', 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPri)),
                  const SizedBox(height: 2),
                  Text('${p['shortDescription'] ?? p['description'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textSec),
          ],
        ),
      ),
    );
  }

  Widget _episodeTile(
      Map e, Color bg, Color border, Color textPri, Color textSec) {
    final podcast = e['podcast'] as Map?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Row(
        children: [
          _cover('${e['cover'] ?? podcast?['cover'] ?? ''}', 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e['title'] ?? ''}',
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
            onPressed: () => _playEpisode(e),
          ),
        ],
      ),
    );
  }

  Widget _cover(String url, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url.startsWith('http')
          ? CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _coverFallback(size),
              placeholder: (_, __) => _coverFallback(size),
            )
          : _coverFallback(size),
    );
  }

  Widget _coverFallback(double size) => Container(
        width: size,
        height: size,
        color: BkoTheme.goldAccent.withValues(alpha: 0.12),
        child: const Icon(Icons.podcasts, color: BkoTheme.goldAccent),
      );
}

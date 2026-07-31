import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/network/bko_api.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';
import '../../core/theme/bko_theme.dart';
import '../player/youtube_player_widget.dart';
import '../shell/shell_providers.dart';

class EpisodeDetailsScreen extends ConsumerStatefulWidget {
  final String podcastSlug;
  final String episodeSlug;

  const EpisodeDetailsScreen({
    super.key,
    required this.podcastSlug,
    required this.episodeSlug,
  });

  @override
  ConsumerState<EpisodeDetailsScreen> createState() =>
      _EpisodeDetailsScreenState();
}

class _EpisodeDetailsScreenState extends ConsumerState<EpisodeDetailsScreen> {
  Map<String, dynamic>? _episode;
  Map<String, dynamic>? _podcast;
  bool _isLoading = true;

  // ignore: unused_field
  final List<Map<String, String>> _sampleChapters = const [
    {'time': '00:00', 'title': 'Introduction & Bienvenue'},
    {'time': '04:30', 'title': 'Parcours et origines du projet'},
    {'time': '12:20', 'title': 'Les clés du développement en Afrique'},
    {'time': '28:15', 'title': 'Conseils pratiques et conclusion'},
  ];
  List<Map<String, String>> _chapters = [];

  @override
  void initState() {
    super.initState();
    _fetchEpisodeDetails();
  }

  Future<void> _fetchEpisodeDetails() => _loadEpisodeFromApi();

  // ignore: unused_element
  Future<void> _fetchEpisodeDetailsLegacy() async {
    final candidateHosts = [
      '127.0.0.1',
      '192.168.1.2',
      'localhost',
      '10.0.2.2'
    ];

    for (final host in candidateHosts) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 2);

        // Fetch podcast details
        final podReq = await client.getUrl(
          Uri.parse(
              'http://$host:8080/api/v1/podcasts/${Uri.encodeComponent(widget.podcastSlug)}'),
        );
        final podRes = await podReq.close();
        if (podRes.statusCode == 200) {
          final body = await podRes.transform(utf8.decoder).join();
          final json = jsonDecode(body);
          if (json['success'] == true && json['data'] != null) {
            final pData = json['data'];
            final eps = (pData['episodes'] as List<dynamic>?) ?? [];
            final matchEp = eps.firstWhere(
              (e) =>
                  e['slug'] == widget.episodeSlug ||
                  e['id'] == widget.episodeSlug,
              orElse: () => eps.isNotEmpty ? eps.first : null,
            );

            if (mounted) {
              setState(() {
                _podcast = pData;
                _episode = matchEp;
                _isLoading = false;
              });
              return;
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEpisodeFromApi() async {
    try {
      final data = await BkoApi.get(
        '/podcasts/${Uri.encodeComponent(widget.podcastSlug)}/episodes/${Uri.encodeComponent(widget.episodeSlug)}',
      );
      if (data is! Map) throw const ApiException('Episode introuvable.');
      final episode = Map<String, dynamic>.from(data);
      final podcast = episode['podcast'] is Map
          ? Map<String, dynamic>.from(episode['podcast'] as Map)
          : null;
      List<Map<String, String>> chapters = [];
      final episodeId = episode['id'];
      if (episodeId is String && episodeId.isNotEmpty) {
        try {
          final chapterData = await BkoApi.get('/episodes/$episodeId/chapters');
          if (chapterData is List) {
            chapters = chapterData.whereType<Map>().map((chapter) {
              final value = Map<String, dynamic>.from(chapter);
              return {
                'time': _formatChapterTime(value['startTimeMs']),
                'title': '${value['title'] ?? ''}',
              };
            }).toList();
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _podcast = podcast;
        _episode = episode;
        _chapters = chapters;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatChapterTime(dynamic milliseconds) {
    final seconds = ((milliseconds as num?)?.toInt() ?? 0) ~/ 1000;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _startPlayback(String mode) async {
    final episode = _episode;
    if (episode == null) return;
    final audioUrl = BkoApi.extractAudioUrl(episode);
    final videoUrl = BkoApi.extractVideoUrl(episode);
    final durationSeconds = episode['durationSeconds'] as num? ?? 0;
    final started = await ref.read(activeEpisodeProvider.notifier).playEpisode(
          title: '${episode['title'] ?? ''}',
          showName: '${_podcast?['name'] ?? ''}',
          duration: durationSeconds > 0
              ? '${(durationSeconds / 60).round()} min'
              : '',
          coverUrl: '${episode['cover'] ?? _podcast?['cover'] ?? ''}',
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null,
          hasVideo: videoUrl != null,
          initialMode: mode,
          episodeId: '${episode['id'] ?? ''}',
          podcastSlug: '${_podcast?['slug'] ?? widget.podcastSlug}',
        );
    if (!mounted) return;
    final message = started
        ? 'Lecture lancÃ©e.'
        : ref.read(activeEpisodeProvider).errorMessage ??
            'MÃ©dia indisponible.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ignore: unused_element
  void _startPlaybackLegacy(String mode) {
    if (_episode == null) return;

    final title = _episode!['title'] ?? 'Épisode';
    final showName = _podcast?['name'] ?? 'Podcast';
    final durationSeconds = _episode!['durationSeconds'] ?? 2400;
    final minutes = (durationSeconds / 60).round();
    final durationStr = '$minutes min';
    final cover = _episode!['cover'] ?? _podcast?['cover'] ?? '';

    final sources = (_episode!['mediaSources'] as List<dynamic>?) ?? [];
    String? audioUrl = _episode!['primaryAudioSource']?['externalUrl'];
    String? videoUrl = _episode!['primaryVideoSource']?['embedUrl'] ??
        _episode!['primaryVideoSource']?['externalUrl'];

    if (audioUrl == null) {
      for (var s in sources) {
        if (s['type'] == 'AUDIO' && s['externalUrl'] != null) {
          audioUrl = s['externalUrl'];
          break;
        }
      }
    }

    if (videoUrl == null) {
      for (var s in sources) {
        if (s['type'] == 'VIDEO') {
          videoUrl = s['embedUrl'] ?? s['externalUrl'];
          break;
        }
      }
    }

    final bool hasAudio = _episode!['audioAvailable'] ??
        (audioUrl != null && audioUrl.isNotEmpty);
    final bool hasVideo = _episode!['videoAvailable'] ??
        ((videoUrl != null && videoUrl.isNotEmpty) || cover.contains('/vi/'));

    ref.read(activeEpisodeProvider.notifier).playEpisode(
          title: title,
          showName: showName,
          duration: durationStr,
          coverUrl: cover,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: hasAudio,
          hasVideo: hasVideo,
          initialMode: mode,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('▶ Lecture ($mode) : $title',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 2),
        backgroundColor: BkoTheme.goldAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _seekToTimestamp(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      final pos = Duration(minutes: minutes, seconds: seconds);

      ref.read(activeEpisodeProvider.notifier).seek(pos);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱ Saut au chapitre $time',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
          duration: const Duration(seconds: 1),
          backgroundColor: BkoTheme.goldAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareEpisode() async {
    final episodeSlug = _episode?['slug'] ?? widget.episodeSlug;
    final podcastSlug = _podcast?['slug'] ?? widget.podcastSlug;
    // ignore: deprecated_member_use
    await Share.share(
      'https://bamakopodcast.com/podcasts/$podcastSlug/episodes/$episodeSlug',
    );
  }

  Future<void> _saveEpisode() async {
    final episodeId = _episode?['id'];
    final auth = ref.read(authProvider);
    if (episodeId is! String || episodeId.isEmpty) return;
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'enregistrer cet episode');
      return;
    }
    try {
      await BkoApi.post('/episodes/$episodeId/save', {}, token: auth.token);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistrement impossible.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: BkoTheme.getBgObsidian(context),
        appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
        body: const Center(
            child: CircularProgressIndicator(color: BkoTheme.goldAccent)),
      );
    }

    final title = _episode?['title'] ?? 'Détail Épisode';
    final description = _episode?['description'] ??
        'Aucune description disponible pour cet épisode.';
    final cover = _episode?['cover'] ?? _podcast?['cover'] ?? '';
    final podcastName = _podcast?['name'] ?? 'Podcast';
    final durationSec = _episode?['durationSeconds'] ?? 2400;
    final minutes = (durationSec / 60).round();
    final durationLabel = '$minutes min';

    final sources = (_episode?['mediaSources'] as List<dynamic>?) ?? [];
    String? videoUrl = _episode?['primaryVideoSource']?['embedUrl'] ??
        _episode?['primaryVideoSource']?['externalUrl'];
    if (videoUrl == null) {
      for (var s in sources) {
        if (s['type'] == 'VIDEO') {
          videoUrl = s['embedUrl'] ?? s['externalUrl'];
          break;
        }
      }
    }
    final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final bool hasAudio = BkoApi.extractAudioUrl(_episode ?? const {}) != null;

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              _shareEpisode();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Lien de l\'épisode copié dans le presse-papier !')),
              );
            },
          ),
          IconButton(
            icon:
                const Icon(Icons.bookmark_border_rounded, color: Colors.white),
            onPressed: () {
              _saveEpisode();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Épisode enregistré dans votre bibliothèque !')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Media Header Player/Cover
            hasVideo
                ? BkoYoutubePlayerWidget(
                    coverUrl: cover,
                    videoUrl: videoUrl,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF1E2638),
                          child: const Icon(Icons.graphic_eq_rounded,
                              color: BkoTheme.goldAccent, size: 64),
                        ),
                      ),
                    ),
                  ),

            const SizedBox(height: 20),

            // 2. Podcast Title & Link
            GestureDetector(
              onTap: () {
                final slug = _podcast?['slug'] ?? widget.podcastSlug;
                context.push('/podcasts/$slug');
              },
              child: Row(
                children: [
                  const Icon(Icons.podcasts_rounded,
                      color: BkoTheme.goldAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    podcastName,
                    style: BkoTheme.fontLato(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: BkoTheme.goldAccent, size: 18),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 3. Episode Title
            Text(
              title,
              style: BkoTheme.fontLato(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textPri,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // 4. Meta Info (Duration, Date)
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: textSec),
                const SizedBox(width: 4),
                Text(durationLabel,
                    style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_rounded, size: 13, color: textSec),
                const SizedBox(width: 4),
                Text('Récemment publié',
                    style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
              ],
            ),

            const SizedBox(height: 20),

            // 5. Main Action Buttons (ÉCOUTER / REGARDER)
            Row(
              children: [
                if (hasAudio)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startPlayback('AUDIO'),
                      icon: const Icon(Icons.headphones_rounded,
                          color: Colors.black, size: 18),
                      label: Text('ÉCOUTER',
                          style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BkoTheme.goldAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                if (hasAudio && hasVideo) const SizedBox(width: 12),
                if (hasVideo)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _startPlayback('VIDEO'),
                      icon: const Icon(Icons.videocam_rounded,
                          color: BkoTheme.goldAccent, size: 18),
                      label: Text('REGARDER',
                          style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: textPri)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BkoTheme.goldAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // 6. Description Section
            Text(
              'À propos de cet épisode',
              style: BkoTheme.fontLato(
                  fontSize: 15, fontWeight: FontWeight.w900, color: textPri),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: BkoTheme.fontLato(
                  fontSize: 13.5, color: textSec, height: 1.5),
            ),

            const SizedBox(height: 28),

            // 7. Chapitres Section
            Text(
              'Chapitres de l\'épisode',
              style: BkoTheme.fontLato(
                  fontSize: 15, fontWeight: FontWeight.w900, color: textPri),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: bgSurf,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderSub),
              ),
              child: Column(
                children: _chapters.map((ch) {
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        ch['time']!,
                        style: BkoTheme.fontLato(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: BkoTheme.goldAccent),
                      ),
                    ),
                    title: Text(
                      ch['title']!,
                      style: BkoTheme.fontLato(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textPri),
                    ),
                    trailing: const Icon(Icons.play_circle_fill_rounded,
                        color: BkoTheme.goldAccent, size: 24),
                    onTap: () => _seekToTimestamp(ch['time']!),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

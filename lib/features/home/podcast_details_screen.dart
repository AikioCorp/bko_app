
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../shell/shell_providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';
import '../player/full_audio_player_sheet.dart';
import 'widgets/episode_list_item.dart';

class PodcastDetailsScreen extends ConsumerStatefulWidget {
  final String slug;
  const PodcastDetailsScreen({super.key, required this.slug});

  @override
  ConsumerState<PodcastDetailsScreen> createState() =>
      _PodcastDetailsScreenState();
}

class _PodcastDetailsScreenState extends ConsumerState<PodcastDetailsScreen> {
  Map<String, dynamic>? _podcast;
  List<dynamic> _episodes = [];
  List<dynamic> _similarPodcasts = [];
  String? _categoryName;
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _fetchPodcastDetails();
  }

  Future<void> _fetchPodcastDetails() => _loadPodcastFromApi();

  Future<void> _loadPodcastFromApi() async {
    try {
      final token = ref.read(authProvider).token;
      final data = await BkoApi.get(
        '/podcasts/${Uri.encodeComponent(widget.slug)}',
        token: token,
      );
      if (!mounted) return;
      final podcast = data is Map ? Map<String, dynamic>.from(data) : null;
      final viewer = podcast?['viewer'] is Map ? podcast!['viewer'] as Map : null;

      final categories = podcast?['categories'] as List? ?? [];
      final firstCategory = categories.isNotEmpty && categories.first['category'] != null
          ? categories.first['category'] as Map
          : null;
      final categorySlug = firstCategory?['slug'] as String?;
      final categoryName = firstCategory?['name'] as String?;

      setState(() {
        _podcast = podcast;
        _categoryName = categoryName;
        _isFollowing = viewer?['isFollowing'] == true;
        _episodes = podcast?['episodes'] is List
            ? List<dynamic>.from(podcast!['episodes'] as List)
            : [];
        _isLoading = false;
      });

      _loadSimilarPodcasts(categorySlug: categorySlug);
    } catch (_) {
      if (!mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSimilarPodcasts({String? categorySlug}) async {
    try {
      dynamic res;
      if (categorySlug != null && categorySlug.isNotEmpty) {
        res = await BkoApi.get('/podcasts?categorySlug=${Uri.encodeComponent(categorySlug)}&limit=8');
      }

      List<dynamic> list = [];
      if (res is Map && res['data'] is List) {
        list = res['data'] as List;
      } else if (res is List) {
        list = res;
      }

      // If category returned empty or none specified, load trending/general podcasts
      if (list.isEmpty) {
        final fallback = await BkoApi.get('/podcasts?limit=8');
        if (fallback is Map && fallback['data'] is List) {
          list = fallback['data'] as List;
        } else if (fallback is List) {
          list = fallback;
        }
      }

      final currentId = '${_podcast?['id'] ?? ''}';
      final filtered = list.where((p) {
        if (p is! Map) return false;
        final pId = '${p['id'] ?? ''}';
        final pSlug = '${p['slug'] ?? ''}';
        return pId != currentId && pSlug != widget.slug;
      }).toList();

      if (mounted) {
        setState(() {
          _similarPodcasts = filtered;
        });
      }
    } catch (_) {}
  }



  Future<void> _playEpisode(Map<String, dynamic> ep) async {
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);
    final durationSeconds = ep['durationSeconds'] as num? ?? 0;
    final episodeId = '${ep['id'] ?? ''}';

    final active = ref.read(activeEpisodeProvider);
    final isAlreadyPlayingThis = active.hasActiveEpisode &&
        active.episodeId == episodeId &&
        active.isPlaying;

    await ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: '${ep['title'] ?? ''}',
          showName: '${_podcast?['name'] ?? ''}',
          duration: durationSeconds > 0
              ? '${(durationSeconds / 60).round()} min'
              : '',
          coverUrl: '${ep['cover'] ?? _podcast?['cover'] ?? ''}',
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null,
          hasVideo: videoUrl != null,
          episodeId: episodeId,
          podcastSlug: '${_podcast?['slug'] ?? widget.slug}',
          episodeSlug: '${ep['slug'] ?? ''}',
        );

    if (!isAlreadyPlayingThis && mounted) {
      FullAudioPlayerSheet.show(context);
    }
  }

  Future<void> _toggleFollow() async {
    final podcastId = _podcast?['id'];
    final auth = ref.read(authProvider);
    if (podcastId is! String || podcastId.isEmpty) return;
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'suivre ce podcast');
      return;
    }
    try {
      if (_isFollowing) {
        await BkoApi.delete('/podcasts/$podcastId/follow', token: auth.token);
      } else {
        await BkoApi.post('/podcasts/$podcastId/follow', {}, token: auth.token);
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible pour le moment.')),
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
        backgroundColor: bgSurf,
        body: const Center(
          child: CircularProgressIndicator(color: BkoTheme.goldAccent),
        ),
      );
    }

    final name = _podcast?['name'] ?? widget.slug.toUpperCase();
    final description = _podcast?['description'] ??
        'Découvrez ce podcast d\'exception sur Bamako Podcast.';
    final coverUrl = _podcast?['cover'] ?? '';
    final countryFlag = _podcast?['country']?['flagEmoji'] ?? '🇲🇱';
    final countryName = _podcast?['country']?['name'] ?? 'Mali';

    final firstEpisodeId =
        _episodes.isNotEmpty ? '${_episodes.first['id'] ?? ''}' : '';
    final isFirstPlaying = firstEpisodeId.isNotEmpty &&
        ref.watch(
          activeEpisodeProvider.select(
            (s) => s.hasActiveEpisode && s.episodeId == firstEpisodeId && s.isPlaying,
          ),
        );

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        backgroundColor: bgSurf,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          name,
          style: BkoTheme.fontLato(
              fontSize: 16, fontWeight: FontWeight.w900, color: textPri),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: textPri, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            handleShellScrollNotification(notification, ref),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Artwork & Bio
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurfaceElevated(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderSub),
                      ),
                      child: coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(
                                Icons.graphic_eq_rounded,
                                color: BkoTheme.goldAccent,
                                size: 64,
                              ),
                            )
                          : const Icon(
                              Icons.graphic_eq_rounded,
                              color: BkoTheme.goldAccent,
                              size: 64,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: BkoTheme.fontLato(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(countryFlag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        countryName,
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: textSec)),
                      const SizedBox(width: 8),
                      Text(
                        '${_episodes.length} Épisodes',
                        style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BkoTheme.goldAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                        isFirstPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 24),
                    label: Text(
                      isFirstPlaying ? 'PAUSE' : 'ÉCOUTER',
                      style: BkoTheme.fontLato(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    onPressed: () {
                      if (_episodes.isNotEmpty) {
                        _playEpisode(_episodes.first);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    side: BorderSide(color: borderSub),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    _isFollowing ? Icons.check_rounded : Icons.add_rounded,
                    color: textPri,
                    size: 18,
                  ),
                  label: Text(
                    _isFollowing ? 'SUIVI' : 'SUIVRE',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textPri,
                    ),
                  ),
                  onPressed: _toggleFollow,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bio / Description
            Text(
              'À PROPOS',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: textSec,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: BkoTheme.fontLato(
                fontSize: 13.5,
                color: textPri,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            // Episodes List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ÉPISODES (${_episodes.length})',
                  style: BkoTheme.fontLato(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: BkoTheme.goldAccent,
                  ),
                ),
                Icon(Icons.sort_rounded, color: textSec, size: 20),
              ],
            ),

            const SizedBox(height: 14),

            // Episodes Items
            if (_episodes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Aucun épisode disponible pour le moment.',
                  style: BkoTheme.fontLato(fontSize: 13, color: textSec),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _episodes.length,
                itemBuilder: (context, index) {
                  final ep = Map<String, dynamic>.from(_episodes[index]);
                  ep['podcast'] ??= _podcast;
                  return EpisodeListItem(
                    episode: ep,
                    showPodcastName: false,
                  );
                },
              ),

            // Similar / Recommended Podcasts Section
            if (_similarPodcasts.isNotEmpty) ...[
              const SizedBox(height: 36),
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: BkoTheme.goldAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _categoryName != null
                        ? 'DANS LA MÊME THÉMATIQUE ($_categoryName)'
                        : 'VOUS POURRIEZ AUSSI AIMER',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 185,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _similarPodcasts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item =
                        Map<String, dynamic>.from(_similarPodcasts[index]);
                    final simSlug = '${item['slug'] ?? ''}';
                    final simName = '${item['name'] ?? ''}';
                    final simCover = '${item['cover'] ?? ''}';
                    final epCount = item['_count']?['episodes'] ?? 0;

                    return GestureDetector(
                      onTap: () {
                        if (simSlug.isNotEmpty) {
                          context.push('/podcasts/$simSlug');
                        }
                      },
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderSub),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 114,
                                height: 114,
                                color: const Color(0xFF1E1E24),
                                child: simCover.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: simCover,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.podcasts_rounded,
                                          color: BkoTheme.goldAccent,
                                          size: 32,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.podcasts_rounded,
                                        color: BkoTheme.goldAccent,
                                        size: 32,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              simName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$epCount épisodes',
                              maxLines: 1,
                              style: BkoTheme.fontLato(
                                fontSize: 11,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 180),
          ],
        ),
      ),
    ),
  );
  }
}

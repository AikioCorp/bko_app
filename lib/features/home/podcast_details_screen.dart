
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../shell/shell_providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';

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
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _fetchPodcastDetails();
  }

  String _normalizeSlug(String str) {
    return str
        .toLowerCase()
        .replaceAll("'", "")
        .replaceAll("’", "")
        .replaceAll("é", "e")
        .replaceAll("è", "e")
        .replaceAll("ê", "e")
        .replaceAll("à", "a")
        .replaceAll("â", "a")
        .replaceAll("ù", "u")
        .replaceAll("ô", "o")
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _fetchPodcastDetails() => _loadPodcastFromApi();



  Future<void> _loadPodcastFromApi() async {
    try {
      final data = await BkoApi.get(
        '/podcasts/${Uri.encodeComponent(widget.slug)}',
      );
      if (!mounted) return;
      final podcast = data is Map ? Map<String, dynamic>.from(data) : null;
      setState(() {
        _podcast = podcast;
        _episodes = podcast?['episodes'] is List
            ? List<dynamic>.from(podcast!['episodes'] as List)
            : [];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<void> _playEpisode(Map<String, dynamic> ep) async {
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);
    final durationSeconds = ep['durationSeconds'] as num? ?? 0;
    final started = await ref.read(activeEpisodeProvider.notifier).playEpisode(
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
          episodeId: '${ep['id'] ?? ''}',
          podcastSlug: '${_podcast?['slug'] ?? widget.slug}',
        );
    if (!mounted || started) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(activeEpisodeProvider).errorMessage ??
              'MÃ©dia indisponible.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      body: SingleChildScrollView(
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
                    icon: const Icon(Icons.play_arrow_rounded,
                        color: Colors.black, size: 24),
                    label: Text(
                      'ÉCOUTER',
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
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _episodes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ep = _episodes[index];
                  final epTitle = ep['title'] ?? 'Épisode ${index + 1}';
                  final epDesc = ep['description'] ?? '';
                  final epCover = ep['cover'] ?? coverUrl;
                  final durationSec = ep['durationSeconds'] ?? 2400;
                  final min = (durationSec / 60).round();

                  final epSlug = (ep['slug'] as String? ?? '').isNotEmpty
                      ? ep['slug']
                      : _normalizeSlug(epTitle);

                  return GestureDetector(
                    onTap: () {
                      context.push('/podcasts/${widget.slug}/episodes/$epSlug');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurfaceElevated(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderSub),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: epCover,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                width: 52,
                                height: 52,
                                color: bgSurf,
                                child: const Icon(Icons.graphic_eq_rounded,
                                    color: BkoTheme.goldAccent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  epTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: BkoTheme.fontLato(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textPri,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  epDesc.isNotEmpty ? epDesc : '$min min',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: BkoTheme.fontLato(
                                      fontSize: 11.5, color: textSec),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _playEpisode(ep),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: BkoTheme.goldAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 180),
          ],
        ),
      ),
    );
  }
}

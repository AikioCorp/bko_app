import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/bko_api.dart';
import '../../../core/theme/bko_theme.dart';
import '../../downloads/download_manager.dart';
import '../../player/widgets/bko_play_button.dart';
import '../../shell/shell_providers.dart';
import 'episode_actions_sheet.dart';

class EpisodeListItem extends ConsumerWidget {
  final Map<String, dynamic> episode;
  final VoidCallback? onPlay;
  final bool showPodcastName;
  final String? recommendationReason;

  const EpisodeListItem({
    super.key,
    required this.episode,
    this.onPlay,
    this.showPodcastName = true,
    this.recommendationReason,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeId = '${episode['id'] ?? ''}';
    final isCurrentEpisode = ref.watch(
      activeEpisodeProvider.select(
        (s) => s.hasActiveEpisode && s.episodeId == episodeId && episodeId.isNotEmpty,
      ),
    );
    final isPlaying = isCurrentEpisode &&
        ref.watch(activeEpisodeProvider.select((s) => s.isPlaying));
    final downloads = ref.watch(downloadProvider);

    final podcast = episode['podcast'] is Map ? episode['podcast'] as Map : null;
    final podcastName = '${podcast?['name'] ?? ''}';
    final podcastSlug = '${podcast?['slug'] ?? ''}';
    final episodeSlug = '${episode['slug'] ?? ''}';
    final title = '${episode['title'] ?? 'Épisode'}';
    final coverUrl = '${episode['cover'] ?? podcast?['cover'] ?? ''}';

    final durationSec = episode['durationSeconds'] as num? ?? 0;
    final durationLabel =
        durationSec > 0 ? '${(durationSec / 60).round()} min' : '';
    final audioUrl = BkoApi.extractAudioUrl(episode);
    final videoUrl = BkoApi.extractVideoUrl(episode);

    final downloadTask = downloads.cast<DownloadTask?>().firstWhere(
          (t) => t?.episodeId == episodeId,
          orElse: () => null,
        );
    final isDownloaded = downloadTask?.status == DownloadStatus.completed;
    final isDownloading = downloadTask?.status == DownloadStatus.downloading;

    // History progress
    double historyProgress = 0.0;
    if (isCurrentEpisode) {
      historyProgress = ref.watch(activeEpisodeProvider.select((s) => s.progress));
    } else if (episode['viewer'] is Map && episode['viewer']['progress'] is Map) {
      final pos = episode['viewer']['progress']['positionSeconds'] as num? ?? 0;
      if (durationSec > 0) {
        historyProgress = (pos / durationSec).clamp(0.0, 1.0);
      }
    }

    const bgSurface = Color(0xFF141416);
    const border = Color(0xFF262626);
    const textPri = Colors.white;
    const textSec = Colors.white70;

    return Semantics(
      label: '$title par $podcastName, durée $durationLabel',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentEpisode
                ? BkoTheme.goldAccent.withValues(alpha: 0.5)
                : border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (podcastSlug.isNotEmpty && episodeSlug.isNotEmpty) {
                context.push('/podcasts/$podcastSlug/episodes/$episodeSlug');
              } else if (onPlay != null) {
                onPlay!();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Artwork with Play Overlay
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: coverUrl.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: coverUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _fallbackCover(),
                                  )
                                : _fallbackCover(),
                          ),
                          // Play/Pause icon button
                          onPlay != null
                              ? GestureDetector(
                                  onTap: onPlay,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isPlaying
                                          ? BkoTheme.goldAccent
                                          : Colors.black.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: isPlaying ? Colors.black : Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : BkoPlayButton(
                                  episodeId: episodeId,
                                  title: title,
                                  showName: podcastName,
                                  duration: durationLabel,
                                  coverUrl: coverUrl,
                                  audioUrl: downloadTask?.localPath ?? audioUrl,
                                  videoUrl: videoUrl,
                                  hasAudio: audioUrl != null,
                                  hasVideo: videoUrl != null,
                                  podcastSlug: podcastSlug,
                                  episodeSlug: episodeSlug,
                                  size: 32,
                                  iconSize: 18,
                                ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // 2. Title & Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recommendationReason != null && recommendationReason!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F1F1F),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF2A2A2A)),
                                  ),
                                  child: Text(
                                    recommendationReason!,
                                    style: BkoTheme.fontLato(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: BkoTheme.goldAccent,
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isCurrentEpisode
                                    ? BkoTheme.goldAccent
                                    : textPri,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (showPodcastName && podcastName.isNotEmpty) ...[
                              Text(
                                podcastName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BkoTheme.fontLato(
                                  fontSize: 11.5,
                                  color: textSec,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Row(
                              children: [
                                if (durationLabel.isNotEmpty) ...[
                                  Text(
                                    durationLabel,
                                    style: BkoTheme.fontLato(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Offline Download Badge
                                if (isDownloaded)
                                  const Row(
                                    children: [
                                      Icon(Icons.download_done_rounded,
                                          size: 13,
                                          color: BkoTheme.goldAccent),
                                      SizedBox(width: 3),
                                      Text(
                                        'Hors ligne',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: BkoTheme.goldAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (isDownloading)
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value: downloadTask?.progress,
                                          color: BkoTheme.goldAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${((downloadTask?.progress ?? 0) * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 3. Action Sheet (3-dot menu) Button
                      Semantics(
                        button: true,
                        label: 'Options pour $title',
                        child: IconButton(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: Colors.white70, size: 20),
                          splashRadius: 24,
                          onPressed: () {
                            EpisodeActionsSheet.show(context, episode);
                          },
                        ),
                      ),
                    ],
                  ),

                  // History progress bar
                  if (historyProgress > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: historyProgress,
                        minHeight: 2.5,
                        backgroundColor: Colors.white10,
                        color: BkoTheme.goldAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _fallbackCover() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF1E1E24),
        child: const Icon(Icons.podcasts_rounded,
            color: BkoTheme.goldAccent, size: 24),
      );
}

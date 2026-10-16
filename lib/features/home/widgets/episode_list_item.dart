import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/network/bko_api.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../downloads/download_manager.dart';
import '../../player/full_audio_player_sheet.dart';
import '../../shell/shell_providers.dart';
import 'episode_actions_sheet.dart';

/// Carte d'épisode minimaliste, épurée et conforme aux règles mobile-designer :
/// - Aucune ombre, bordure subtile de 1 px.
/// - Icônes Iconsax uniquement (Play, Pause, More, Microphone).
/// - Zéro couleur en dur : tous les rôles proviennent de BkoTheme.
/// - Déballage transparent des enveloppes de recommandation.
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
    // Déballage sécurisé : supporte à la fois les objets épisodes directs
    // et les enveloppes de recommandation du backend ({ episode: {...}, reason: '...' })
    final ep = (episode['episode'] is Map)
        ? Map<String, dynamic>.from(episode['episode'] as Map)
        : episode;
    final reason = recommendationReason ?? (episode['reason']?.toString());

    final episodeId = '${ep['id'] ?? ''}';
    final isCurrentEpisode = ref.watch(
      activeEpisodeProvider.select(
        (s) => s.hasActiveEpisode && s.episodeId == episodeId && episodeId.isNotEmpty,
      ),
    );
    final isPlaying = isCurrentEpisode &&
        ref.watch(activeEpisodeProvider.select((s) => s.isPlaying));
    final downloads = ref.watch(downloadProvider);

    final podcast = ep['podcast'] is Map ? ep['podcast'] as Map : null;
    final podcastName = '${podcast?['name'] ?? ''}';
    final podcastSlug = '${podcast?['slug'] ?? ''}';
    final episodeSlug = '${ep['slug'] ?? ''}';
    final title = '${ep['title'] ?? 'Épisode'}';
    final coverUrl = BkoApi.extractCoverUrl(ep) ?? '${ep['cover'] ?? podcast?['cover'] ?? ''}';

    final durationSec = ep['durationSeconds'] as num? ?? 0;
    final durationLabel =
        durationSec > 0 ? '${(durationSec / 60).round()} min' : '';
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);

    final downloadTask = downloads.cast<DownloadTask?>().firstWhere(
          (t) => t?.episodeId == episodeId,
          orElse: () => null,
        );
    final isDownloaded = downloadTask?.status == DownloadStatus.completed;
    final isDownloading = downloadTask?.status == DownloadStatus.downloading;

    // Progression d'écoute
    double historyProgress = 0.0;
    if (isCurrentEpisode) {
      historyProgress = ref.watch(activeEpisodeProvider.select((s) => s.progress));
    } else if (ep['viewer'] is Map && ep['viewer']['progress'] is Map) {
      final pos = ep['viewer']['progress']['positionSeconds'] as num? ?? 0;
      if (durationSec > 0) {
        historyProgress = (pos / durationSec).clamp(0.0, 1.0);
      }
    }

    final bgSurface = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final textMuted = BkoTheme.getTextMuted(context);
    const goldAccent = BkoTheme.goldAccent;

    void handlePlayEpisode() {
      BkoHaptics.light();
      if (onPlay != null) {
        onPlay!();
        return;
      }

      final active = ref.read(activeEpisodeProvider);
      final isAlreadyPlayingThis = active.hasActiveEpisode &&
          active.episodeId == episodeId &&
          active.isPlaying;

      ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
            title: title,
            showName: podcastName,
            duration: durationLabel,
            coverUrl: coverUrl,
            audioUrl: downloadTask?.localPath ?? audioUrl,
            videoUrl: videoUrl,
            hasAudio: audioUrl != null || downloadTask?.localPath != null,
            hasVideo: videoUrl != null,
            episodeId: episodeId,
            podcastSlug: podcastSlug,
            episodeSlug: episodeSlug,
          );

      if (!isAlreadyPlayingThis) {
        FullAudioPlayerSheet.show(context);
      }
    }

    return Semantics(
      label: '$title par $podcastName, durée $durationLabel',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentEpisode ? goldAccent.withValues(alpha: 0.5) : border,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (podcastSlug.isNotEmpty && episodeSlug.isNotEmpty) {
                context.push('/podcasts/$podcastSlug/episodes/$episodeSlug');
              } else {
                handlePlayEpisode();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Pochette carrée nette
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: coverUrl.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _fallbackCover(context),
                                )
                              : _fallbackCover(context),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. Titre, émission & métadonnées
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (reason != null && reason.trim().isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: bgElevated,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: border),
                                ),
                                child: Text(
                                  reason.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: BkoTheme.fontLato(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: goldAccent,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: BkoTheme.fontLato(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isCurrentEpisode ? goldAccent : textPri,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (showPodcastName && podcastName.isNotEmpty) ...[
                                  Flexible(
                                    child: Text(
                                      podcastName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: textSec,
                                      ),
                                    ),
                                  ),
                                  if (durationLabel.isNotEmpty) ...[
                                    Text(' • ', style: BkoTheme.fontLato(fontSize: 10, color: textMuted)),
                                  ],
                                ],
                                if (durationLabel.isNotEmpty) ...[
                                  Text(
                                    durationLabel,
                                    style: BkoTheme.fontLato(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                                if (isDownloaded) ...[
                                  const SizedBox(width: 6),
                                  const Icon(IconsaxPlusLinear.tick_circle, size: 12, color: goldAccent),
                                ] else if (isDownloading) ...[
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      value: downloadTask?.progress,
                                      color: goldAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. Bouton Play / Pause compact & minimaliste
                      BkoBounceable(
                        onTap: handlePlayEpisode,
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPlaying ? goldAccent : bgElevated,
                            border: Border.all(
                              color: isPlaying ? goldAccent : border,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            isPlaying ? IconsaxPlusBold.pause : IconsaxPlusBold.play,
                            color: isPlaying ? BkoTheme.onBrand : goldAccent,
                            size: 14,
                          ),
                        ),
                      ),

                      // 4. Bouton menu options discret
                      BkoBounceable(
                        onTap: () {
                          BkoHaptics.light();
                          EpisodeActionsSheet.show(context, ep);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Icon(
                            IconsaxPlusLinear.more,
                            size: 18,
                            color: textSec,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 5. Barre de progression d'écoute discrète
                  if (historyProgress > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: historyProgress,
                        minHeight: 2,
                        backgroundColor: bgElevated,
                        color: goldAccent,
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

  Widget _fallbackCover(BuildContext context) => Container(
        width: 50,
        height: 50,
        color: BkoTheme.getBgSurfaceElevated(context),
        child: Center(
          child: Icon(
            IconsaxPlusLinear.microphone_2,
            color: BkoTheme.getAccent(context),
            size: 20,
          ),
        ),
      );
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/bko_theme.dart';
import '../shell/shell_providers.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEpisode = ref.watch(activeEpisodeProvider);
    final queue = activeEpisode.queue;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final textMut = BkoTheme.getTextMuted(context);
    final handleColor = isDark ? Colors.white24 : Colors.black12;
    final goldContrast = isDark ? BkoTheme.goldAccent : const Color(0xFFB45309);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: border),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(IconsaxPlusLinear.music_playlist,
                        color: goldContrast, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'File d’attente',
                      style: BkoTheme.fontLato(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (queue.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref
                              .read(activeEpisodeProvider.notifier)
                              .clearQueue();
                        },
                        child: Text(
                          'Vider la file',
                          style: BkoTheme.fontLato(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent.shade100,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(IconsaxPlusLinear.close_circle,
                          color: textSec, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: border),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // 1. Current Track
                if (activeEpisode.hasActiveEpisode) ...[
                  Text(
                    'EN COURS DE LECTURE',
                    style: BkoTheme.fontLato(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: goldContrast,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: BkoTheme.goldAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: activeEpisode.coverUrl.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: activeEpisode.coverUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _fallbackCover(context, bgElevated),
                                )
                              : _fallbackCover(context, bgElevated),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeEpisode.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BkoTheme.fontLato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textPri,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeEpisode.showName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BkoTheme.fontLato(
                                  fontSize: 12,
                                  color: textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          IconsaxPlusLinear.music_filter,
                          color: goldContrast,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // 2. Upcoming Queue Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'À SUIVRE (${queue.length})',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: textSec,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (queue.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: bgElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Icon(IconsaxPlusLinear.music_playlist,
                            size: 38, color: textMut),
                        const SizedBox(height: 8),
                        Text(
                          'Aucun épisode en attente',
                          style: BkoTheme.fontLato(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Utilisez « Lire ensuite » ou « Ajouter à la file » sur un épisode pour le programmer.',
                          textAlign: TextAlign.center,
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            color: textSec,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: queue.length,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(activeEpisodeProvider.notifier)
                          .reorderQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = queue[index];

                      return Container(
                        key: ValueKey('queue_item_${item.episodeId}_$index'),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: bgElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            // Drag handle
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.drag_handle_rounded,
                                    color: textMut, size: 20),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Artwork
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.coverUrl.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: item.coverUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _fallbackCover(context, bgElevated, size: 40),
                                    )
                                  : _fallbackCover(context, bgElevated, size: 40),
                            ),
                            const SizedBox(width: 12),

                            // Details (tap to play)
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  ref
                                      .read(activeEpisodeProvider.notifier)
                                      .removeFromQueue(index);
                                  ref
                                      .read(activeEpisodeProvider.notifier)
                                      .playEpisode(
                                        title: item.title,
                                        showName: item.showName,
                                        duration: item.duration,
                                        coverUrl: item.coverUrl,
                                        audioUrl: item.audioUrl,
                                        videoUrl: item.videoUrl,
                                        hasAudio: item.hasAudio,
                                        hasVideo: item.hasVideo,
                                        episodeId: item.episodeId,
                                        podcastSlug: item.podcastSlug,
                                        episodeSlug: item.episodeSlug,
                                      );
                                },
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPri,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.showName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 11.5,
                                        color: textSec,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Delete button
                            IconButton(
                              icon: Icon(IconsaxPlusLinear.close_circle,
                                  color: textMut, size: 18),
                              onPressed: () {
                                ref
                                    .read(activeEpisodeProvider.notifier)
                                    .removeFromQueue(index);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover(BuildContext context, Color bgColor, {double size = 48}) => Container(
        width: size,
        height: size,
        color: bgColor,
        child: Icon(IconsaxPlusLinear.music,
            color: BkoTheme.getAccent(context), size: 20),
      );
}

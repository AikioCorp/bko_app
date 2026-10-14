import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../player/full_audio_player_sheet.dart';
import '../player/widgets/bko_play_button.dart';
import '../shell/shell_providers.dart';
import 'download_manager.dart';
import 'widgets/download_limit_modal.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadProvider);
    final notifier = ref.read(downloadProvider.notifier);

    final completedTasks = tasks.where((t) => t.status == DownloadStatus.completed).toList();
    final inProgressTasks = tasks
        .where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.pending)
        .toList();
    final errorTasks = tasks
        .where((t) => t.status == DownloadStatus.error || t.status == DownloadStatus.unsupported)
        .toList();

    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Téléchargements',
          style: BkoTheme.fontPoppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPri,
          ),
        ),
        actions: [
          const AppHeaderActions(),
          IconButton(
            icon: Icon(IconsaxPlusLinear.refresh_2, color: textPri, size: 20),
            tooltip: 'Synchroniser avec le compte',
            onPressed: () async {
              BkoHaptics.light();
              await notifier.syncRemoteQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Synchronisation des téléchargements effectuée.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(IconsaxPlusLinear.setting_4, color: BkoTheme.goldAccent, size: 20),
            tooltip: 'Téléchargements intelligents',
            onPressed: () => _openSmartSettingsSheet(context, ref, notifier),
          ),
          if (completedTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    '${completedTasks.length} épisode${completedTasks.length > 1 ? "s" : ""}',
                    style: BkoTheme.fontPoppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: BkoTheme.goldAccent,
        backgroundColor: surface,
        onRefresh: () => notifier.syncRemoteQueue(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // Smart Downloads Status Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: notifier.smartSettings.smartDownloadsEnabled
                      ? BkoTheme.goldAccent.withValues(alpha: 0.35)
                      : border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(IconsaxPlusLinear.magicpen, color: BkoTheme.goldAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Smart Downloads',
                              style: BkoTheme.fontPoppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: notifier.smartSettings.smartDownloadsEnabled
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : textSec.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notifier.smartSettings.smartDownloadsEnabled ? 'ACTIF' : 'INACTIF',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: notifier.smartSettings.smartDownloadsEnabled
                                      ? Colors.greenAccent
                                      : textSec,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stockage utilisé : ${notifier.formattedTotalStorage}',
                          style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openSmartSettingsSheet(context, ref, notifier),
                    style: TextButton.styleFrom(
                      foregroundColor: BkoTheme.goldAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    child: const Text('Gérer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Information Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(IconsaxPlusLinear.document_download, color: BkoTheme.goldAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Écoute hors connexion',
                          style: BkoTheme.fontPoppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Les épisodes audio enregistrés localement restent disponibles sans réseau internet. Touchez un épisode pour ouvrir le lecteur ou touchez l’émission pour voir sa fiche.',
                          style: BkoTheme.fontLato(
                            fontSize: 11.5,
                            color: textSec,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // In Progress Section
            if (inProgressTasks.isNotEmpty) ...[
              Text(
                'En cours de téléchargement (${inProgressTasks.length})',
                style: BkoTheme.fontPoppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 10),
              for (final task in inProgressTasks)
                _buildInProgressCard(context, task, notifier, surface, border, textPri, textSec),
              const SizedBox(height: 24),
            ],

            // Error / Unsupported Section
            if (errorTasks.isNotEmpty) ...[
              Text(
                'Alertes & erreurs (${errorTasks.length})',
                style: BkoTheme.fontPoppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 10),
              for (final task in errorTasks)
                _buildErrorCard(context, task, notifier, surface, border, textPri, textSec),
              const SizedBox(height: 24),
            ],

            // Available Offline Section
            Text(
              'Disponibles hors connexion (${completedTasks.length})',
              style: BkoTheme.fontPoppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPri,
              ),
            ),
            const SizedBox(height: 10),

            if (completedTasks.isEmpty && inProgressTasks.isEmpty && errorTasks.isEmpty) ...[
              _buildEmptyState(context, surface, border, textPri, textSec),
            ] else if (completedTasks.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Center(
                  child: Text(
                    'Aucun épisode terminé pour le moment.',
                    style: BkoTheme.fontLato(fontSize: 13, color: textSec),
                  ),
                ),
              ),
            ] else ...[
              for (final task in completedTasks)
                _buildCompletedCard(context, ref, task, notifier, surface, border, textPri, textSec),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color surface,
    Color border,
    Color textPri,
    Color textSec,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BkoTheme.goldAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              IconsaxPlusLinear.document_download,
              size: 40,
              color: BkoTheme.goldAccent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aucun épisode téléchargé',
            style: BkoTheme.fontPoppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Téléchargez vos épisodes favoris depuis leur fiche pour les écouter partout, même sans connexion ou en déplacement.',
            textAlign: TextAlign.center,
            style: BkoTheme.fontLato(
              fontSize: 13,
              color: textSec,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          BkoBounceable(
            onTap: () {
              BkoHaptics.select();
              context.go('/explore');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: BkoTheme.getPrimaryButtonBg(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    IconsaxPlusLinear.discover,
                    size: 18,
                    color: BkoTheme.getPrimaryButtonText(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Découvrir des émissions',
                    style: BkoTheme.fontPoppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BkoTheme.getPrimaryButtonText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressCard(
    BuildContext context,
    DownloadTask task,
    DownloadNotifier notifier,
    Color surface,
    Color border,
    Color textPri,
    Color textSec,
  ) {
    final pct = (task.progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildCover(task.coverUrl, surface, border),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BkoTheme.fontPoppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textPri,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.podcastName,
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
              IconButton(
                icon: Icon(IconsaxPlusLinear.close_circle, size: 20, color: textSec),
                tooltip: 'Annuler',
                onPressed: () {
                  BkoHaptics.light();
                  notifier.cancelDownload(task.episodeId);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progress > 0 ? task.progress : null,
              backgroundColor: border,
              valueColor: const AlwaysStoppedAnimation(BkoTheme.goldAccent),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Téléchargement en cours...',
                style: BkoTheme.fontLato(fontSize: 11, color: textSec),
              ),
              Text(
                '$pct%',
                style: BkoTheme.fontPoppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BkoTheme.goldAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    DownloadTask task,
    DownloadNotifier notifier,
    Color surface,
    Color border,
    Color textPri,
    Color textSec,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCover(task.coverUrl, surface, border),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BkoTheme.fontPoppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  task.errorMessage ?? 'Erreur lors du téléchargement',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BkoTheme.fontLato(
                    fontSize: 11.5,
                    color: Colors.red.shade300,
                  ),
                ),
              ],
            ),
          ),
          if (task.status == DownloadStatus.error)
            IconButton(
              icon: const Icon(IconsaxPlusLinear.refresh, size: 20, color: BkoTheme.goldAccent),
              tooltip: 'Réessayer',
              onPressed: () async {
                BkoHaptics.light();
                try {
                  await notifier.retryDownload(task.episodeId);
                } on DownloadLimitException {
                  if (context.mounted) {
                    DownloadLimitModal.show(context);
                  }
                }
              },
            ),
          IconButton(
            icon: Icon(IconsaxPlusLinear.trash, size: 20, color: textSec),
            tooltip: 'Supprimer',
            onPressed: () {
              BkoHaptics.light();
              notifier.deleteDownload(task.episodeId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(
    BuildContext context,
    WidgetRef ref,
    DownloadTask task,
    DownloadNotifier notifier,
    Color surface,
    Color border,
    Color textPri,
    Color textSec,
  ) {
    final active = ref.watch(activeEpisodeProvider);
    final isCurrent = active.hasActiveEpisode && active.episodeId == task.episodeId;

    void openFullPlayerOrPlay() {
      BkoHaptics.select();
      if (isCurrent) {
        FullAudioPlayerSheet.show(context);
      } else {
        ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
              episodeId: task.episodeId,
              title: task.title,
              showName: task.podcastName,
              duration: task.formattedSize,
              coverUrl: task.coverUrl,
              audioUrl: task.localPath,
              hasAudio: true,
              podcastSlug: task.podcastSlug,
              episodeSlug: task.episodeSlug,
            );
        FullAudioPlayerSheet.show(context);
      }
    }

    void openPodcastPage() {
      if (task.podcastSlug.isNotEmpty) {
        BkoHaptics.light();
        context.push('/podcasts/${task.podcastSlug}');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? BkoTheme.goldAccent.withValues(alpha: 0.5) : border,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: openFullPlayerOrPlay,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Artwork cliquable avec indicateur si en cours de lecture
                Stack(
                  children: [
                    _buildCover(task.coverUrl, surface, border),
                    if (isCurrent)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BkoTheme.goldAccent, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Informations texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre de l'épisode
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BkoTheme.fontPoppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? BkoTheme.goldAccent : textPri,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Lien vers le podcast + taille du fichier
                      Row(
                        children: [
                          Flexible(
                            child: task.podcastSlug.isNotEmpty
                                ? GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: openPodcastPage,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          IconsaxPlusLinear.microphone_2,
                                          size: 11,
                                          color: BkoTheme.goldAccent.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            task.podcastName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: BkoTheme.fontLato(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: textSec,
                                              decoration: TextDecoration.underline,
                                              decorationColor: textSec.withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                    task.podcastName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: BkoTheme.fontLato(
                                      fontSize: 11.5,
                                      color: textSec,
                                    ),
                                  ),
                          ),
                          if (task.formattedSize.isNotEmpty) ...[
                            Text(
                              ' • ',
                              style: BkoTheme.fontLato(fontSize: 11, color: textSec),
                            ),
                            Text(
                              task.formattedSize,
                              style: BkoTheme.fontLato(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textSec,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Bouton Lecture / Pause
                BkoPlayButton(
                  episodeId: task.episodeId,
                  title: task.title,
                  showName: task.podcastName,
                  duration: task.formattedSize,
                  coverUrl: task.coverUrl,
                  audioUrl: task.localPath,
                  hasAudio: true,
                  podcastSlug: task.podcastSlug,
                  episodeSlug: task.episodeSlug,
                  size: 34,
                  iconSize: 20,
                  backgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.15),
                  activeBackgroundColor: BkoTheme.goldAccent,
                  iconColor: BkoTheme.goldAccent,
                  activeIconColor: Colors.black,
                ),

                // Bouton Menu d'actions (Grand lecteur, Podcast, Supprimer)
                IconButton(
                  icon: Icon(IconsaxPlusLinear.more, size: 20, color: textSec),
                  tooltip: 'Options de l\'épisode',
                  onPressed: () {
                    BkoHaptics.light();
                    _showTaskOptionsSheet(context, ref, task);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskOptionsSheet(BuildContext context, WidgetRef ref, DownloadTask task) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final textPri = BkoTheme.getTextPrimary(ctx);
        final textSec = BkoTheme.getTextSecondary(ctx);
        final surfaceElevated = BkoTheme.getBgSurfaceElevated(ctx);
        final border = BkoTheme.getBorderSubtle(ctx);

        return Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).padding.bottom + 20),
          decoration: BoxDecoration(
            color: surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSec.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  _buildCover(task.coverUrl, surfaceElevated, border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BkoTheme.fontPoppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.podcastName,
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
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: border, height: 1),
              const SizedBox(height: 8),

              // Option 1: Grand lecteur
              _buildSheetActionTile(
                ctx,
                icon: IconsaxPlusBold.play,
                iconColor: BkoTheme.goldAccent,
                title: 'Ouvrir le grand lecteur',
                subtitle: 'Contrôles complets, vitesse et chapitres',
                onTap: () {
                  Navigator.pop(ctx);
                  final active = ref.read(activeEpisodeProvider);
                  if (active.hasActiveEpisode && active.episodeId == task.episodeId) {
                    FullAudioPlayerSheet.show(context);
                  } else {
                    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
                          episodeId: task.episodeId,
                          title: task.title,
                          showName: task.podcastName,
                          duration: task.formattedSize,
                          coverUrl: task.coverUrl,
                          audioUrl: task.localPath,
                          hasAudio: true,
                          podcastSlug: task.podcastSlug,
                          episodeSlug: task.episodeSlug,
                        );
                    FullAudioPlayerSheet.show(context);
                  }
                },
              ),

              // Option 2: Fiche du podcast
              if (task.podcastSlug.isNotEmpty)
                _buildSheetActionTile(
                  ctx,
                  icon: IconsaxPlusLinear.microphone_2,
                  title: 'Voir la page du podcast',
                  subtitle: 'Tous les épisodes et informations de l’émission',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/podcasts/${task.podcastSlug}');
                  },
                ),

              // Option 3: Fiche de l'épisode
              if (task.podcastSlug.isNotEmpty && task.episodeSlug.isNotEmpty)
                _buildSheetActionTile(
                  ctx,
                  icon: IconsaxPlusLinear.document_text_1,
                  title: 'Détails de l’épisode',
                  subtitle: 'Notes d’émission et chapitres',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/podcasts/${task.podcastSlug}/episodes/${task.episodeSlug}');
                  },
                ),

              // Option 4: Supprimer
              _buildSheetActionTile(
                ctx,
                icon: IconsaxPlusLinear.trash,
                iconColor: Colors.redAccent,
                title: 'Supprimer de mon appareil',
                subtitle: 'Libère ${task.formattedSize.isNotEmpty ? task.formattedSize : "l'espace"} de stockage local',
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAndDelete(context, ref, task);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetActionTile(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    return InkWell(
      onTap: () {
        BkoHaptics.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? BkoTheme.goldAccent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, size: 20, color: iconColor ?? textPri),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BkoTheme.fontPoppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPri,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: BkoTheme.fontLato(
                      fontSize: 11.5,
                      color: textSec,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_right_3,
              size: 16,
              color: textSec.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref, DownloadTask task) async {
    final active = ref.read(activeEpisodeProvider);
    final isPlayingThis = active.hasActiveEpisode && active.episodeId == task.episodeId;
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);

    if (isPlayingThis) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
          title: Text(
            'Épisode en cours d’écoute',
            style: BkoTheme.fontPoppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
          content: Text(
            'Cet épisode est actuellement en cours de lecture. La suppression va arrêter la lecture et retirer le fichier de votre appareil.',
            style: BkoTheme.fontLato(
              fontSize: 13.5,
              color: textSec,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: BkoTheme.fontLato(color: textSec)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Arrêter et supprimer',
                style: BkoTheme.fontLato(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(activeEpisodeProvider.notifier).stop();
        await ref.read(downloadProvider.notifier).deleteDownload(task.episodeId);
      }
    } else {
      await ref.read(downloadProvider.notifier).deleteDownload(task.episodeId);
    }
  }

  Widget _buildCover(String url, Color surface, Color border) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  IconsaxPlusLinear.microphone_2,
                  color: BkoTheme.goldAccent,
                  size: 22,
                ),
              )
            : const Icon(
                IconsaxPlusLinear.microphone_2,
                color: BkoTheme.goldAccent,
                size: 22,
              ),
      ),
    );
  }

  void _openSmartSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    DownloadNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final settings = notifier.smartSettings;
            final textPri = BkoTheme.getTextPrimary(ctx);
            final textSec = BkoTheme.getTextSecondary(ctx);
            final surface = BkoTheme.getBgSurfaceElevated(ctx);
            final border = BkoTheme.getBorderSubtle(ctx);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: textSec.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(IconsaxPlusLinear.magicpen, color: BkoTheme.goldAccent, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Smart Downloads',
                        style: BkoTheme.fontPoppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gestion automatisée du stockage inspirée de Netflix et Apple Podcasts.',
                    style: BkoTheme.fontLato(fontSize: 12.5, color: textSec),
                  ),
                  const SizedBox(height: 18),

                  // 1. Activer Smart Downloads
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: BkoTheme.goldAccent,
                    title: Text(
                      'Activer les téléchargements intelligents',
                      style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPri),
                    ),
                    subtitle: Text(
                      'Automatise le téléchargement et la suppression pour optimiser votre espace.',
                      style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                    ),
                    value: settings.smartDownloadsEnabled,
                    onChanged: (val) async {
                      await notifier.updateSmartSettings(smartDownloadsEnabled: val);
                      setSheetState(() {});
                    },
                  ),
                  Divider(color: border, height: 1),

                  // 2. Télécharger l'épisode suivant
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: BkoTheme.goldAccent,
                    title: Text(
                      'Télécharger l\'épisode suivant',
                      style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPri),
                    ),
                    subtitle: Text(
                      'Télécharge automatiquement le prochain épisode dès que vous finissez une écoute.',
                      style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                    ),
                    value: settings.autoDownloadNext,
                    onChanged: settings.smartDownloadsEnabled
                        ? (val) async {
                            await notifier.updateSmartSettings(autoDownloadNext: val);
                            setSheetState(() {});
                          }
                        : null,
                  ),
                  Divider(color: border, height: 1),

                  // 3. Supprimer après écoute
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: BkoTheme.goldAccent,
                    title: Text(
                      'Supprimer après écoute complète',
                      style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPri),
                    ),
                    subtitle: Text(
                      'Libère instantanément le stockage de votre téléphone une fois l\'épisode terminé.',
                      style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                    ),
                    value: settings.autoDeleteCompleted,
                    onChanged: settings.smartDownloadsEnabled
                        ? (val) async {
                            await notifier.updateSmartSettings(autoDeleteCompleted: val);
                            setSheetState(() {});
                          }
                        : null,
                  ),
                  Divider(color: border, height: 1),

                  // 4. Télécharger uniquement en Wi-Fi
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: BkoTheme.goldAccent,
                    title: Text(
                      'Télécharger uniquement en Wi-Fi',
                      style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPri),
                    ),
                    subtitle: Text(
                      'Préserve vos données mobiles lors des téléchargements.',
                      style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                    ),
                    value: settings.wifiOnly,
                    onChanged: (val) async {
                      await notifier.updateSmartSettings(wifiOnly: val);
                      setSheetState(() {});
                    },
                  ),

                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BkoTheme.getBgSurface(ctx),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Espace utilisé :', style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                        Text(
                          notifier.formattedTotalStorage,
                          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.bold, color: BkoTheme.goldAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/bko_theme.dart';
import '../player/widgets/bko_play_button.dart';
import '../shell/shell_providers.dart';
import 'download_manager.dart';

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          tooltip: 'Retour',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Téléchargements',
          style: BkoTheme.fontPoppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPri,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            tooltip: 'Synchroniser avec le compte',
            onPressed: () async {
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
            icon: const Icon(Icons.tune_rounded, color: BkoTheme.goldAccent, size: 20),
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
                    color: const Color(0xFF1E1E1E),
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
        backgroundColor: const Color(0xFF1E1E1E),
        onRefresh: () => notifier.syncRemoteQueue(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // Smart Downloads Status Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: notifier.smartSettings.smartDownloadsEnabled
                      ? BkoTheme.goldAccent.withValues(alpha: 0.35)
                      : const Color(0xFF262626),
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
                    child: const Icon(Icons.auto_awesome, color: BkoTheme.goldAccent, size: 20),
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
                                    : Colors.grey.withValues(alpha: 0.2),
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
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.offline_bolt_rounded, color: BkoTheme.goldAccent, size: 20),
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
                          'Les épisodes audio enregistrés localement restent disponibles sans réseau internet. Les contenus vidéo externes ne peuvent pas être téléchargés.',
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
            _buildEmptyState(context, textPri, textSec),
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

  Widget _buildEmptyState(BuildContext context, Color textPri, Color textSec) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_for_offline_outlined,
              size: 44,
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
          ElevatedButton.icon(
            onPressed: () => context.go('/explore'),
            icon: const Icon(Icons.explore_rounded, size: 18),
            label: Text(
              'Découvrir des émissions',
              style: BkoTheme.fontPoppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: BkoTheme.goldAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 0,
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
              _buildCover(task.coverUrl),
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
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                tooltip: 'Annuler',
                onPressed: () => notifier.cancelDownload(task.episodeId),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progress > 0 ? task.progress : null,
              backgroundColor: const Color(0xFF262626),
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
          _buildCover(task.coverUrl),
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
              icon: const Icon(Icons.refresh_rounded, size: 20, color: BkoTheme.goldAccent),
              tooltip: 'Réessayer',
              onPressed: () async {
                try {
                  await notifier.retryDownload(task.episodeId);
                } on DownloadLimitException {
                  if (context.mounted) {
                    DownloadLimitDialog.show(context);
                  }
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
            tooltip: 'Supprimer',
            onPressed: () => notifier.deleteDownload(task.episodeId),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _buildCover(task.coverUrl),
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
                Text.rich(
                  TextSpan(
                    text: task.podcastName,
                    style: BkoTheme.fontLato(
                      fontSize: 11.5,
                      color: textSec,
                    ),
                    children: [
                      if (task.formattedSize.isNotEmpty) ...[
                        TextSpan(
                          text: ' • ',
                          style: BkoTheme.fontLato(fontSize: 11, color: textSec),
                        ),
                        TextSpan(
                          text: task.formattedSize,
                          style: BkoTheme.fontLato(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textSec,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
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
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
            tooltip: 'Supprimer la copie locale',
            onPressed: () => _confirmAndDelete(context, ref, task),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref, DownloadTask task) async {
    final active = ref.read(activeEpisodeProvider);
    final isPlayingThis = active.hasActiveEpisode && active.episodeId == task.episodeId;

    if (isPlayingThis) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16161A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Épisode en cours d’écoute',
            style: BkoTheme.fontLato(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Cet épisode est actuellement en cours de lecture. La suppression va arrêter la lecture et retirer le fichier de votre appareil.',
            style: BkoTheme.fontLato(
              fontSize: 13.5,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: BkoTheme.fontLato(color: Colors.white60)),
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

  Widget _buildCover(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: const Color(0xFF1E1E1E),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.mic_rounded,
                  color: BkoTheme.goldAccent,
                  size: 22,
                ),
              )
            : const Icon(
                Icons.mic_rounded,
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
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final settings = notifier.smartSettings;
            final textPri = BkoTheme.getTextPrimary(ctx);
            final textSec = BkoTheme.getTextSecondary(ctx);
            const surface = Color(0xFF16161A);
            const border = Color(0xFF262626);

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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: BkoTheme.goldAccent, size: 22),
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
                  const Divider(color: Color(0xFF262626)),

                  // 2. Télécharger l\'épisode suivant
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
                  const Divider(color: Color(0xFF262626)),

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
                  const Divider(color: Color(0xFF262626)),

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
                      color: const Color(0xFF111113),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/bko_api.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_download_toast.dart';
import '../../../core/widgets/bko_toast.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_modal.dart';
import '../../downloads/download_manager.dart';
import '../../library/library_screen.dart';
import '../../library/likes_provider.dart';
import '../../library/widgets/playlist_picker_sheet.dart';
import '../../shell/shell_providers.dart';

class EpisodeActionsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> episode;
  final VoidCallback? onSavedStateChanged;

  const EpisodeActionsSheet({
    super.key,
    required this.episode,
    this.onSavedStateChanged,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> episode, {
    VoidCallback? onSavedStateChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpisodeActionsSheet(
        episode: episode,
        onSavedStateChanged: onSavedStateChanged,
      ),
    );
  }

  @override
  ConsumerState<EpisodeActionsSheet> createState() =>
      _EpisodeActionsSheetState();
}

class _EpisodeActionsSheetState extends ConsumerState<EpisodeActionsSheet> {
  bool _isSaving = false;
  bool? _isSaved;

  @override
  void initState() {
    super.initState();
    final viewer = widget.episode['viewer'];
    if (viewer is Map && viewer['isSaved'] != null) {
      _isSaved = viewer['isSaved'] == true;
    }
  }

  QueueItem _buildQueueItem() {
    final ep = widget.episode;
    final podcast = ep['podcast'] is Map ? ep['podcast'] as Map : null;
    final durationSec = ep['durationSeconds'] as num? ?? 0;
    final durationLabel =
        durationSec > 0 ? '${(durationSec / 60).round()} min' : '';
    final audioUrl = BkoApi.extractAudioUrl(ep);
    final videoUrl = BkoApi.extractVideoUrl(ep);

    return QueueItem(
      episodeId: '${ep['id'] ?? ''}',
      title: '${ep['title'] ?? 'Épisode'}',
      showName: '${podcast?['name'] ?? ''}',
      duration: durationLabel,
      coverUrl: BkoApi.extractCoverUrl(ep) ?? '${ep['cover'] ?? podcast?['cover'] ?? ''}',
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      hasAudio: audioUrl != null && audioUrl.isNotEmpty,
      hasVideo: videoUrl != null && videoUrl.isNotEmpty,
      podcastSlug: '${podcast?['slug'] ?? ''}',
      episodeSlug: '${ep['slug'] ?? ''}',
    );
  }

  Future<void> _handlePlayNext() async {
    final item = _buildQueueItem();
    ref.read(activeEpisodeProvider.notifier).playNext(item);
    Navigator.pop(context);
    BkoToast.showSuccess(
      context,
      title: 'Lecture suivante',
      message: '« ${item.title} » sera lu ensuite',
    );
  }

  Future<void> _handleAddToQueue() async {
    final item = _buildQueueItem();
    ref.read(activeEpisodeProvider.notifier).addToQueue(item);
    Navigator.pop(context);
    BkoToast.showSuccess(
      context,
      title: 'File d’attente',
      message: '« ${item.title} » ajouté à la file',
    );
  }

  Future<void> _handleToggleSave() async {
    final episodeId = '${widget.episode['id'] ?? ''}';
    final auth = ref.read(authProvider);

    if (episodeId.isEmpty) return;
    if (!auth.isAuthenticated || auth.token == null) {
      Navigator.pop(context);
      AuthRequiredModal.show(context,
          actionTitle: 'enregistrer cet épisode dans votre bibliothèque');
      return;
    }

    setState(() => _isSaving = true);
    final currentSaved = _isSaved ?? false;

    try {
      if (currentSaved) {
        await BkoApi.delete('/episodes/$episodeId/save', token: auth.token);
      } else {
        await BkoApi.post('/episodes/$episodeId/save', {}, token: auth.token);
      }

      setState(() {
        _isSaved = !currentSaved;
        _isSaving = false;
      });
      ref.read(libraryUpdateSignalProvider.notifier).state++;
      widget.onSavedStateChanged?.call();

      if (!mounted) return;
      final ep = widget.episode;
      final podcast = ep['podcast'] is Map ? ep['podcast'] as Map : null;
      BkoToast.showLibrary(
        context,
        title: '${ep['title'] ?? 'Épisode'}',
        podcastName: podcast?['name'],
        isSaved: !currentSaved,
      );
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        BkoToast.showError(
          context,
          title: 'Action impossible',
          message: 'Impossible de modifier l’enregistrement.',
        );
      }
    }
  }

  Future<void> _handleShare() async {
    final ep = widget.episode;
    final podcast = ep['podcast'] is Map ? ep['podcast'] as Map : null;
    final podcastSlug = '${podcast?['slug'] ?? ''}';
    final episodeSlug = '${ep['slug'] ?? ''}';

    Navigator.pop(context);
    // ignore: deprecated_member_use
    await Share.share(
      'https://bamakopodcast.com/podcasts/$podcastSlug/episodes/$episodeSlug',
    );
  }

  void _handleGoToPodcast() {
    final ep = widget.episode;
    final podcast = ep['podcast'] is Map ? ep['podcast'] as Map : null;
    final podcastSlug = '${podcast?['slug'] ?? ''}';
    Navigator.pop(context);
    if (podcastSlug.isNotEmpty) {
      context.push('/podcasts/$podcastSlug');
    }
  }

  void _handleOpenPlaylists() {
    Navigator.pop(context);
    PlaylistPickerSheet.show(context, widget.episode);
  }

  Future<void> _handleNotInterested() async {
    final episodeId = '${widget.episode['id'] ?? ''}';
    final auth = ref.read(authProvider);
    Navigator.pop(context);

    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'personnaliser vos recommandations');
      return;
    }

    try {
      await BkoApi.post(
        '/recommendations/feedback',
        {'targetType': 'EPISODE', 'targetId': episodeId, 'action': 'NOT_INTERESTED'},
        token: auth.token,
      );
      if (!mounted) return;
      BkoToast.showInfo(
        context,
        title: 'Recommandation masquée',
        message: 'Nous ajustons vos suggestions.',
        actionLabel: 'Annuler',
        onAction: () async {
          try {
            await BkoApi.delete(
              '/recommendations/feedback',
              token: auth.token,
            );
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  Future<void> _handleHidePodcast() async {
    final ep = widget.episode;
    final podcast = ep['podcast'] is Map ? ep['podcast'] as Map : null;
    final podcastId = '${podcast?['id'] ?? ep['podcastId'] ?? ''}';
    final podcastName = '${podcast?['name'] ?? 'cette émission'}';
    final auth = ref.read(authProvider);
    Navigator.pop(context);

    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'masquer cette émission');
      return;
    }

    if (podcastId.isEmpty) return;

    try {
      await BkoApi.post(
        '/recommendations/feedback',
        {'targetType': 'PODCAST', 'targetId': podcastId, 'action': 'HIDE_PODCAST'},
        token: auth.token,
      );
      if (!mounted) return;
      BkoToast.showInfo(
        context,
        title: 'Émission masquée',
        message: '« $podcastName » a été masquée de vos suggestions.',
        actionLabel: 'Annuler',
        onAction: () async {
          try {
            await BkoApi.delete(
              '/recommendations/feedback',
              token: auth.token,
            );
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final podcast = ep['podcast'] is Map ? ep['podcast'] as Map : null;
    final title = '${ep['title'] ?? 'Épisode'}';
    final rawPodcastName = '${podcast?['name'] ?? ''}'.trim();
    final podcastName = (rawPodcastName.isNotEmpty && rawPodcastName.toLowerCase() != 'bamako podcast')
        ? rawPodcastName
        : '';
    final coverUrl = BkoApi.extractCoverUrl(ep) ?? '${ep['cover'] ?? podcast?['cover'] ?? ''}';
    final episodeId = '${ep['id'] ?? ''}';

    final downloads = ref.watch(downloadProvider);
    final downloadTask =
        downloads.cast<DownloadTask?>().firstWhere(
              (t) => t?.episodeId == episodeId,
              orElse: () => null,
            );
    final isDownloaded =
        downloadTask?.status == DownloadStatus.completed;
    final isDownloading =
        downloadTask?.status == DownloadStatus.downloading;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final handleColor = isDark ? Colors.white24 : Colors.black12;
    final goldContrast = isDark ? BkoTheme.goldAccent : const Color(0xFFB45309);

    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Artwork & Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: coverUrl.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _fallbackCover(bgElevated),
                        )
                      : _fallbackCover(bgElevated),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BkoTheme.fontLato(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPri,
                        ),
                      ),
                      if (podcastName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          podcastName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BkoTheme.fontLato(
                            fontSize: 12.5,
                            color: textSec,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: border),
          const SizedBox(height: 8),

          // Action Items
          _buildActionTile(
            icon: IconsaxPlusLinear.play_add,
            iconColor: textPri,
            title: 'Lire ensuite',
            subtitle: 'Placer juste après le contenu en cours',
            textPri: textPri,
            textSec: textSec,
            onTap: _handlePlayNext,
          ),
          _buildActionTile(
            icon: IconsaxPlusLinear.music_playlist,
            iconColor: textPri,
            title: 'Ajouter à la file d’attente',
            subtitle: 'Placer à la fin de la session de lecture',
            textPri: textPri,
            textSec: textSec,
            onTap: _handleAddToQueue,
          ),
          _buildActionTile(
            icon: IconsaxPlusLinear.folder_add,
            iconColor: textPri,
            title: 'Ajouter à une playlist',
            subtitle: 'Organiser dans vos collections personnelles',
            textPri: textPri,
            textSec: textSec,
            onTap: _handleOpenPlaylists,
          ),

          // Like / Favorite Action
          _buildActionTile(
            icon: (ref.watch(likedEpisodesProvider).contains(episodeId) || widget.episode['viewer']?['isLiked'] == true)
                ? IconsaxPlusBold.heart
                : IconsaxPlusLinear.heart,
            iconColor: (ref.watch(likedEpisodesProvider).contains(episodeId) || widget.episode['viewer']?['isLiked'] == true)
                ? Colors.redAccent
                : textPri,
            title: (ref.watch(likedEpisodesProvider).contains(episodeId) || widget.episode['viewer']?['isLiked'] == true)
                ? 'Ne plus aimer'
                : 'Aimer cet épisode',
            subtitle: (ref.watch(likedEpisodesProvider).contains(episodeId) || widget.episode['viewer']?['isLiked'] == true)
                ? 'Retirer de vos épisodes aimés'
                : 'Enrichir vos recommandations personnalisées',
            textPri: textPri,
            textSec: textSec,
            onTap: () async {
              Navigator.pop(context);
              await ref.read(likedEpisodesProvider.notifier).toggleLike(context, episodeId);
            },
          ),

          // Offline Download Action (uniquement pour les épisodes disposant d'une source audio téléchargeable, jamais pour une vidéo YouTube seule)
          if (BkoApi.extractAudioUrl(ep) != null) ...[
            if (isDownloaded)
              _buildActionTile(
                icon: IconsaxPlusLinear.trash,
                iconColor: Colors.redAccent,
                title: 'Supprimer le téléchargement',
                subtitle: 'Libérer de l’espace sur votre téléphone',
                textPri: textPri,
                textSec: textSec,
                onTap: () {
                  ref
                      .read(downloadProvider.notifier)
                      .deleteTask(episodeId);
                  Navigator.pop(context);
                  BkoToast.showInfo(
                    context,
                    title: 'Téléchargement supprimé',
                    message: '${widget.episode['title'] ?? ''}',
                    icon: IconsaxPlusBold.document_download,
                  );
                },
              )
            else if (isDownloading)
              _buildActionTile(
                icon: IconsaxPlusLinear.arrow_circle_down,
                iconColor: goldContrast,
                title: 'Téléchargement en cours...',
                subtitle: '${((downloadTask?.progress ?? 0) * 100).toInt()}%',
                textPri: textPri,
                textSec: textSec,
                onTap: () {
                  ref
                      .read(downloadProvider.notifier)
                      .cancelDownload(episodeId);
                  Navigator.pop(context);
                },
              )
            else
              _buildActionTile(
                icon: IconsaxPlusLinear.arrow_circle_down,
                iconColor: textPri,
                title: 'Télécharger l’épisode',
                subtitle: 'Disponible pour l’écoute hors connexion',
                textPri: textPri,
                textSec: textSec,
                onTap: () {
                  Navigator.pop(context);
                  try {
                    ref
                        .read(downloadProvider.notifier)
                        .startDownload(widget.episode);
                    BkoDownloadToast.show(
                      context,
                      title: title,
                      podcastName: podcastName,
                    );
                  } on DownloadLimitException {
                    DownloadLimitDialog.show(context);
                  }
                },
              ),
          ],

          // Save / Bookmark Action
          _buildActionTile(
            icon: _isSaved == true
                ? IconsaxPlusBold.archive_add
                : IconsaxPlusLinear.archive_add,
            iconColor: _isSaved == true ? goldContrast : textPri,
            title: _isSaved == true
                ? 'Retirer des enregistrés'
                : 'Enregistrer dans la bibliothèque',
            subtitle: 'Retrouvez cet épisode dans vos Enregistrés',
            isLoading: _isSaving,
            textPri: textPri,
            textSec: textSec,
            onTap: _handleToggleSave,
          ),

          _buildActionTile(
            icon: IconsaxPlusLinear.share,
            iconColor: textPri,
            title: 'Partager l’épisode',
            subtitle: 'Envoyer à un ami ou sur les réseaux',
            textPri: textPri,
            textSec: textSec,
            onTap: _handleShare,
          ),

          _buildActionTile(
            icon: IconsaxPlusLinear.radio,
            iconColor: textPri,
            title: 'Accéder à l’émission',
            subtitle: 'Voir tous les épisodes de $podcastName',
            textPri: textPri,
            textSec: textSec,
            onTap: _handleGoToPodcast,
          ),

          Divider(color: border, height: 16),

          _buildActionTile(
            icon: IconsaxPlusLinear.dislike,
            iconColor: textSec,
            title: 'Pas intéressé',
            subtitle: 'Moins de recommandations de ce type',
            textPri: textPri,
            textSec: textSec,
            onTap: _handleNotInterested,
          ),

          _buildActionTile(
            icon: IconsaxPlusLinear.eye_slash,
            iconColor: textSec,
            title: 'Masquer cette émission',
            subtitle: 'Ne plus recommander $podcastName',
            textPri: textPri,
            textSec: textSec,
            onTap: _handleHidePodcast,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textPri,
    required Color textSec,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        splashColor: BkoTheme.goldAccent.withValues(alpha: 0.1),
        highlightColor: textPri.withValues(alpha: 0.05),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BkoTheme.goldAccent,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: BkoTheme.fontLato(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackCover([Color? bgColor]) => Container(
        width: 52,
        height: 52,
        color: bgColor ?? const Color(0xFF1F1F24),
        child: const Icon(IconsaxPlusLinear.music,
            color: BkoTheme.goldAccent, size: 24),
      );
}

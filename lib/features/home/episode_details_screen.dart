import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_download_toast.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/skeleton_loaders.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';
import '../downloads/download_manager.dart';
import '../library/library_screen.dart';
import '../library/widgets/playlist_picker_sheet.dart';
import '../player/widgets/bko_play_button.dart';
import '../player/youtube_player_widget.dart';
import '../shell/shell_providers.dart';
import 'widgets/episode_actions_sheet.dart';
import 'widgets/episode_comments_sheet.dart';

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

  bool _isLiked = false;
  int _likesCount = 0;
  bool _isSaved = false;
  int _commentsCount = 0;
  bool _isTogglingLike = false;
  bool _isTogglingSave = false;

  List<Map<String, String>> _chapters = [];

  @override
  void initState() {
    super.initState();
    _fetchEpisodeDetails();
  }

  Future<void> _fetchEpisodeDetails() => _loadEpisodeFromApi();

  Future<void> _loadEpisodeFromApi() async {
    try {
      final token = ref.read(authProvider).token;
      final data = await BkoApi.get(
        '/podcasts/${Uri.encodeComponent(widget.podcastSlug)}/episodes/${Uri.encodeComponent(widget.episodeSlug)}',
        token: token,
      );
      if (data is! Map) throw const ApiException('Épisode introuvable.');
      final episode = Map<String, dynamic>.from(data);
      final podcast = episode['podcast'] is Map
          ? Map<String, dynamic>.from(episode['podcast'] as Map)
          : null;

      final viewer = episode['viewer'] is Map ? episode['viewer'] as Map : null;
      final countObj =
          episode['_count'] is Map ? episode['_count'] as Map : null;

      final isLiked = viewer?['isLiked'] == true;
      final isSaved = viewer?['isSaved'] == true;
      final likesCount = (countObj?['EpisodeLike'] as num?)?.toInt() ?? 0;
      final commentsCount = (countObj?['Comment'] as num?)?.toInt() ?? 0;

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
        _isLiked = isLiked;
        _isSaved = isSaved;
        _likesCount = likesCount;
        _commentsCount = commentsCount;
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
    final episodeId = '${episode['id'] ?? ''}';

    final downloads = ref.read(downloadProvider);
    final downloadTask = downloads.cast<DownloadTask?>().firstWhere(
          (t) => t?.episodeId == episodeId,
          orElse: () => null,
        );
    final localAudio = downloadTask?.status == DownloadStatus.completed
        ? downloadTask?.localPath
        : null;

    await ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          title: '${episode['title'] ?? ''}',
          showName: '${_podcast?['name'] ?? ''}',
          duration: durationSeconds > 0
              ? '${(durationSeconds / 60).round()} min'
              : '',
          coverUrl: '${episode['cover'] ?? _podcast?['cover'] ?? ''}',
          audioUrl: localAudio ?? audioUrl,
          videoUrl: videoUrl,
          hasAudio: audioUrl != null || localAudio != null,
          hasVideo: videoUrl != null,
          initialMode: mode,
          episodeId: episodeId,
          podcastSlug: '${_podcast?['slug'] ?? widget.podcastSlug}',
          episodeSlug: '${episode['slug'] ?? widget.episodeSlug}',
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

  Future<void> _toggleLike() async {
    final episodeId = _episode?['id'];
    final auth = ref.read(authProvider);
    if (episodeId is! String || episodeId.isEmpty) return;
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'aimer cet épisode');
      return;
    }
    if (_isTogglingLike) return;
    setState(() => _isTogglingLike = true);

    final wasLiked = _isLiked;
    final prevCount = _likesCount;

    // Optimistic update
    setState(() {
      _isLiked = !wasLiked;
      _likesCount =
          wasLiked ? (_likesCount - 1).clamp(0, 999999) : _likesCount + 1;
    });

    try {
      if (wasLiked) {
        await BkoApi.delete('/episodes/$episodeId/likes', token: auth.token);
      } else {
        await BkoApi.post('/episodes/$episodeId/likes', {}, token: auth.token);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount = prevCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d’enregistrer votre réaction.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  Future<void> _toggleSave() async {
    final episodeId = _episode?['id'];
    final auth = ref.read(authProvider);
    if (episodeId is! String || episodeId.isEmpty) return;
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'enregistrer cet épisode');
      return;
    }
    if (_isTogglingSave) return;
    setState(() => _isTogglingSave = true);

    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);

    try {
      if (wasSaved) {
        await BkoApi.delete('/episodes/$episodeId/save', token: auth.token);
      } else {
        await BkoApi.post('/episodes/$episodeId/save', {}, token: auth.token);
      }
      if (mounted) {
        ref.read(libraryUpdateSignalProvider.notifier).state++;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!wasSaved
                ? 'Épisode enregistré dans votre bibliothèque'
                : 'Épisode retiré de votre bibliothèque'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaved = wasSaved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingSave = false);
    }
  }

  void _openComments() {
    final episodeId = _episode?['id'];
    final title = _episode?['title'] ?? 'Épisode';
    if (episodeId == null) return;
    EpisodeCommentsSheet.show(
      context,
      episodeId: '$episodeId',
      episodeTitle: title,
      onCommentCountChanged: (newCount) {
        if (mounted) setState(() => _commentsCount = newCount);
      },
    );
  }

  void _openMoreActions() {
    if (_episode == null) return;
    EpisodeActionsSheet.show(
      context,
      _episode!,
      onSavedStateChanged: () {
        _loadEpisodeFromApi();
      },
    );
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
        appBar: AppBar(
        actions: const [AppHeaderActions()],
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: AppBackButton(
            color: Colors.white,
            fallbackLocation: '/podcasts/${widget.podcastSlug}',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: BkoSkeletonBox(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              BkoSkeletonBox(
                width: double.infinity,
                height: 24,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 10),
              BkoSkeletonBox(
                width: 160,
                height: 14,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BkoSkeletonBox(
                      height: 50,
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const BkoSkeletonBox(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              BkoSkeletonBox(
                width: double.infinity,
                height: 80,
                borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
        ),
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
    final episodeId = '${_episode?['id'] ?? ''}';

    final downloads = ref.watch(downloadProvider);
    final downloadTask = downloads.cast<DownloadTask?>().firstWhere(
          (t) => t?.episodeId == episodeId,
          orElse: () => null,
        );
    final isDownloaded = downloadTask?.status == DownloadStatus.completed;
    final isDownloading = downloadTask?.status == DownloadStatus.downloading;

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
        leading: AppBackButton(
          color: Colors.white,
          fallbackLocation: '/podcasts/${widget.podcastSlug}',
        ),
        actions: [
          const AppHeaderActions(),
          IconButton(
            icon: Icon(
              _isLiked ? IconsaxPlusBold.heart : IconsaxPlusLinear.heart,
              color: _isLiked ? Colors.redAccent : Colors.white,
              size: 22,
            ),
            tooltip: _isLiked ? 'Ne plus aimer' : 'Aimer cet épisode',
            onPressed: () {
              BkoHaptics.light();
              _toggleLike();
            },
          ),
          IconButton(
            icon: Icon(
              _isSaved ? IconsaxPlusBold.archive_add : IconsaxPlusLinear.archive_add,
              color: _isSaved ? BkoTheme.goldAccent : Colors.white,
              size: 22,
            ),
            onPressed: () {
              BkoHaptics.light();
              _toggleSave();
            },
          ),
          IconButton(
            icon: const Icon(IconsaxPlusLinear.share, color: Colors.white, size: 22),
            onPressed: () {
              BkoHaptics.select();
              _shareEpisode();
            },
          ),
          IconButton(
            icon: const Icon(IconsaxPlusLinear.more, color: Colors.white, size: 22),
            onPressed: () {
              BkoHaptics.select();
              _openMoreActions();
            },
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            handleShellScrollNotification(notification, ref),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Media Header Player/Cover
            hasVideo
                ? BkoYoutubePlayerWidget(
                    coverUrl: cover,
                    videoUrl: videoUrl,
                    onPlaybackError: () {
                      final active = ref.read(activeEpisodeProvider);
                      if (active.episodeId == _episode?['id']) {
                        ref.read(activeEpisodeProvider.notifier).pauseVideo();
                      }
                    },
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

            const SizedBox(height: 18),

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

            // 4. Meta Info (Duration, Date, Offline state)
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: textSec),
                const SizedBox(width: 4),
                Text(durationLabel,
                    style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                const SizedBox(width: 14),
                Icon(Icons.calendar_today_rounded, size: 13, color: textSec),
                const SizedBox(width: 4),
                Text('Récemment publié',
                    style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                if (isDownloaded) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.download_done_rounded,
                      size: 14, color: BkoTheme.goldAccent),
                  const SizedBox(width: 4),
                  Text(
                    'Hors ligne',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 18),

            // 5. Main Play Buttons (ÉCOUTER / REGARDER)
            Row(
              children: [
                if (hasAudio)
                  Expanded(
                    child: BkoPlayButton.pill(
                      episodeId: episodeId,
                      title: title,
                      showName: podcastName,
                      duration: durationLabel,
                      coverUrl: cover,
                      audioUrl: downloadTask?.localPath ?? BkoApi.extractAudioUrl(_episode ?? const {}),
                      videoUrl: videoUrl,
                      hasAudio: hasAudio,
                      hasVideo: hasVideo,
                      initialMode: 'AUDIO',
                      podcastSlug: _podcast?['slug'] ?? widget.podcastSlug,
                      episodeSlug: _episode?['slug'] ?? widget.episodeSlug,
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

            const SizedBox(height: 14),

            // 6. Secondary Action Row (Télécharger, Enregistrer, Playlist, Plus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSub),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Télécharger
                  _buildActionButton(
                    icon: isDownloaded
                        ? Icons.download_done_rounded
                        : isDownloading
                            ? Icons.downloading_rounded
                            : Icons.download_rounded,
                    iconColor: isDownloaded
                        ? BkoTheme.goldAccent
                        : isDownloading
                            ? BkoTheme.goldAccent
                            : textPri,
                    label: isDownloaded
                        ? 'Téléchargé'
                        : isDownloading
                            ? '${((downloadTask?.progress ?? 0) * 100).toInt()}%'
                            : 'Télécharger',
                    onTap: () {
                      if (_episode == null) return;
                      if (isDownloaded) {
                        ref
                            .read(downloadProvider.notifier)
                            .deleteTask(episodeId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Téléchargement retiré.'),
                              behavior: SnackBarBehavior.floating),
                        );
                      } else {
                        try {
                          ref
                              .read(downloadProvider.notifier)
                              .startDownload(_episode!);
                          BkoDownloadToast.show(
                            context,
                            title: _episode?['title'] ?? 'Épisode',
                            podcastName: _episode?['podcast']?['name'],
                          );
                        } on DownloadLimitException {
                          DownloadLimitDialog.show(context);
                        }
                      }
                    },
                  ),

                  // Enregistrer / Favoris
                  _buildActionButton(
                    icon: _isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    iconColor: _isSaved ? BkoTheme.goldAccent : textPri,
                    label: _isSaved ? 'Enregistré' : 'Enregistrer',
                    onTap: _toggleSave,
                  ),

                  // Ajouter à une playlist
                  _buildActionButton(
                    icon: Icons.playlist_add_rounded,
                    iconColor: textPri,
                    label: 'Playlist',
                    onTap: () {
                      if (_episode != null) {
                        PlaylistPickerSheet.show(context, _episode!);
                      }
                    },
                  ),

                  // Plus (...)
                  _buildActionButton(
                    icon: Icons.more_horiz_rounded,
                    iconColor: textPri,
                    label: 'Plus',
                    onTap: _openMoreActions,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 7. Community Row: Aimer (Likes Count), Commenter (Comments Count), Partager
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSub),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Aimer with count
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(
                          _isLiked
                              ? IconsaxPlusBold.heart
                              : IconsaxPlusLinear.heart,
                          color: _isLiked ? Colors.redAccent : Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_likesCount',
                          style: BkoTheme.fontLato(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: _isLiked ? Colors.redAccent : textPri,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Commenter with count
                  GestureDetector(
                    onTap: _openComments,
                    child: Row(
                      children: [
                        const Icon(
                          IconsaxPlusLinear.messages_2,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_commentsCount',
                          style: BkoTheme.fontLato(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'avis',
                          style: BkoTheme.fontLato(
                            fontSize: 12,
                            color: textSec,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Partager
                  GestureDetector(
                    onTap: _shareEpisode,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.share_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Partager',
                          style: BkoTheme.fontLato(
                            fontSize: 13,
                            color: textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 8. Description Section
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

            const SizedBox(height: 24),

            // 9. Discussion / Commentaires Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commentaires & discussion',
                  style: BkoTheme.fontLato(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: textPri),
                ),
                TextButton.icon(
                  onPressed: _openComments,
                  icon: const Icon(Icons.edit_note_rounded,
                      color: BkoTheme.goldAccent, size: 18),
                  label: Text(
                    'Écrire',
                    style: BkoTheme.fontLato(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: BkoTheme.goldAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openComments,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgSurf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderSub),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        color: BkoTheme.goldAccent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _commentsCount > 0
                            ? 'Voir les $_commentsCount commentaires ou donner votre avis...'
                            : 'Aucun commentaire. Soyez le premier à commenter !',
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          color: textSec,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white54, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 10. Chapitres Section
            if (_chapters.isNotEmpty) ...[
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
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    BkoTheme.goldAccent.withValues(alpha: 0.3)),
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
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 48),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: BkoBounceable(
        scaleFactor: 0.92,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

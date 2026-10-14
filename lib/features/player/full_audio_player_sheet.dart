import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../../core/widgets/skeleton_loaders.dart';
import '../home/widgets/episode_actions_sheet.dart';
import '../home/widgets/episode_comments_sheet.dart';
import '../library/likes_provider.dart';
import '../shell/shell_providers.dart';
import 'queue_sheet.dart';
import 'youtube_player_widget.dart';

class FullAudioPlayerSheet extends ConsumerStatefulWidget {
  const FullAudioPlayerSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(isFullPlayerOpenProvider.notifier).state = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
      useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FullAudioPlayerSheet(),
      );
    } finally {
      container.read(isFullPlayerOpenProvider.notifier).state = false;
    }
    final active = container.read(activeEpisodeProvider);
    if (active.mode == 'VIDEO' && active.isPlaying) {
      container.read(activeEpisodeProvider.notifier).pauseVideo();
    }
  }

  @override
  ConsumerState<FullAudioPlayerSheet> createState() =>
      _FullAudioPlayerSheetState();
}

class _FullAudioPlayerSheetState extends ConsumerState<FullAudioPlayerSheet> {
  int _selectedTab = 0; // 0 = À suivre, 1 = Chapitres
  List<Map<String, String>> _chapters = [];
  bool _loadingChapters = false;
  String? _lastLoadedEpisodeId;
  double? _dragValue;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadChaptersIfAvailable();
  }

  @override
  void dispose() {
    _dragValue = null;
    _isDragging = false;
    super.dispose();
  }

  Future<void> _loadChaptersIfAvailable() async {
    if (!mounted) return;
    final active = ref.read(activeEpisodeProvider);
    if (!active.hasActiveEpisode || active.episodeId.isEmpty) return;
    if (_lastLoadedEpisodeId == active.episodeId) return;

    _lastLoadedEpisodeId = active.episodeId;
    setState(() => _loadingChapters = true);

    try {
      final res = await BkoApi.get('/episodes/${active.episodeId}/chapters');
      if (res is List) {
        final loaded = res.whereType<Map>().map((c) {
          final m = Map<String, dynamic>.from(c);
          return {
            'time': _formatChapterTime(m['startTimeMs']),
            'title': '${m['title'] ?? ''}',
          };
        }).toList();
        if (mounted) {
          setState(() {
            _chapters = loaded;
            _loadingChapters = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingChapters = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChapters = false);
    }
  }

  String _formatChapterTime(dynamic ms) {
    final seconds = ((ms as num?)?.toInt() ?? 0) ~/ 1000;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _seekToTimestamp(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      if (_isDragging) {
        setState(() {
          _isDragging = false;
          _dragValue = null;
        });
      }
      ref
          .read(activeEpisodeProvider.notifier)
          .seek(Duration(minutes: minutes, seconds: seconds));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSpeedPicker(double currentSpeed) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Vitesse de lecture',
              style: BkoTheme.fontLato(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF262626)),
            ...speeds.map((s) {
              final isSelected = (s - currentSpeed).abs() < 0.05;
              return ListTile(
                title: Text(
                  '${s}x ${s == 1.0 ? '(Normal)' : ''}',
                  style: BkoTheme.fontLato(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? BkoTheme.goldAccent : Colors.white,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: BkoTheme.goldAccent)
                    : null,
                onTap: () {
                  ref
                      .read(activeEpisodeProvider.notifier)
                      .setPlaybackSpeed(s);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerPicker() {
    final timers = [
      {'label': 'Désactivé', 'duration': null},
      {'label': '15 minutes', 'duration': const Duration(minutes: 15)},
      {'label': '30 minutes', 'duration': const Duration(minutes: 30)},
      {'label': '45 minutes', 'duration': const Duration(minutes: 45)},
      {'label': '1 heure', 'duration': const Duration(hours: 1)},
      {
        'label': 'Fin de l’épisode',
        'duration': ref.read(activeEpisodeProvider).totalDuration -
            ref.read(activeEpisodeProvider).currentPosition
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Minuteur de mise en veille',
              style: BkoTheme.fontLato(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF262626)),
            ...timers.map((t) {
              final label = t['label'] as String;
              final dur = t['duration'] as Duration?;
              return ListTile(
                leading: const Icon(Icons.bedtime_outlined,
                    color: BkoTheme.goldAccent, size: 20),
                title: Text(
                  label,
                  style: BkoTheme.fontLato(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  ref
                      .read(activeEpisodeProvider.notifier)
                      .setSleepTimer(dur);
                  Navigator.pop(ctx);
                  if (dur != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Minuteur activé : $label'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeEpisodeProvider);

    ref.listen<String>(
      activeEpisodeProvider.select((s) => s.episodeId),
      (prev, next) {
        if (next.isNotEmpty && next != _lastLoadedEpisodeId) {
          if (_isDragging) {
            setState(() {
              _isDragging = false;
              _dragValue = null;
            });
          }
          _loadChaptersIfAvailable();
        }
      },
    );

    if (!active.hasActiveEpisode) {
      return const SizedBox.shrink();
    }

    const bgObsidian = Color(0xFF0B0B0B);
    const borderSub = Color(0xFF262626);
    const textPri = Colors.white;
    const textSec = Colors.white70;

    final totalDuration = active.totalDuration;
    final effectivePos = _isDragging &&
            _dragValue != null &&
            totalDuration.inMilliseconds > 0
        ? Duration(
            milliseconds:
                (_dragValue! * totalDuration.inMilliseconds).round(),
          )
        : active.currentPosition;

    final elapsedStr = _formatDuration(effectivePos);
    final remainingStr = totalDuration > effectivePos
        ? '-${_formatDuration(totalDuration - effectivePos)}'
        : _formatDuration(totalDuration);

    final double sliderValue = _isDragging && _dragValue != null
        ? _dragValue!.clamp(0.0, 1.0)
        : active.progress.clamp(0.0, 1.0);

    final episodeMap = {
      'id': active.episodeId,
      'title': active.title,
      'podcast': {'name': active.showName, 'slug': active.podcastSlug},
      'podcastSlug': active.podcastSlug,
      'slug': active.episodeSlug,
      'cover': active.coverUrl,
      'audioUrl': active.audioUrl,
      'videoUrl': active.videoUrl,
    };

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: bgObsidian,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Top Bar: Down chevron, Header title, 3 dots
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(IconsaxPlusLinear.arrow_down_1,
                      color: Colors.white, size: 24),
                  onPressed: () {
                    BkoHaptics.select();
                    Navigator.pop(context);
                  },
                ),
                Text(
                  active.mode == 'VIDEO'
                      ? 'EN COURS DE VISIONNAGE'
                      : 'EN COURS D’ÉCOUTE',
                  style: BkoTheme.fontLato(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: BkoTheme.goldAccent,
                  ),
                ),
                IconButton(
                  icon: const Icon(IconsaxPlusLinear.more,
                      color: Colors.white, size: 22),
                  onPressed: () {
                    BkoHaptics.select();
                    EpisodeActionsSheet.show(context, episodeMap);
                  },
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                24, 8, 24, MediaQuery.viewPaddingOf(context).bottom + 24,
              ),
              child: Column(
                children: [
                  // Audio / Video Switcher (if both available)
                  if (active.hasAudio && active.hasVideo) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderSub),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => ref
                                .read(activeEpisodeProvider.notifier)
                                .setMode('AUDIO'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: active.mode == 'AUDIO'
                                    ? BkoTheme.goldAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.headphones_rounded,
                                    size: 14,
                                    color: active.mode == 'AUDIO'
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ÉCOUTER',
                                    style: BkoTheme.fontLato(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: active.mode == 'AUDIO'
                                          ? Colors.black
                                          : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => ref
                                .read(activeEpisodeProvider.notifier)
                                .setMode('VIDEO'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: active.mode == 'VIDEO'
                                    ? BkoTheme.goldAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.videocam_rounded,
                                    size: 14,
                                    color: active.mode == 'VIDEO'
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'REGARDER',
                                    style: BkoTheme.fontLato(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: active.mode == 'VIDEO'
                                          ? Colors.black
                                          : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Media Container (YouTube Video or Artwork)
                  if (active.mode == 'VIDEO')
                    BkoYoutubePlayerWidget(
                      coverUrl: active.coverUrl,
                      videoUrl: active.videoUrl,
                      autoPlay: active.isPlaying,
                      startPosition: active.currentPosition,
                      onPlaybackError: () => ref
                          .read(activeEpisodeProvider.notifier)
                          .pauseVideo(),
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.width * 0.76,
                        maxWidth: MediaQuery.of(context).size.width * 0.76,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: borderSub),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: active.coverUrl.isNotEmpty &&
                                  active.coverUrl.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: active.coverUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _fallbackCover(),
                                )
                              : _fallbackCover(),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Title & Podcast Link
                  Text(
                    active.title.isNotEmpty ? active.title : 'Épisode',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      final slug = active.podcastSlug.isNotEmpty
                          ? active.podcastSlug
                          : active.showName
                              .toLowerCase()
                              .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      context.push('/podcasts/$slug');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          active.showName.isNotEmpty
                              ? active.showName
                              : 'Bamako Podcast',
                          style: BkoTheme.fontLato(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: BkoTheme.goldAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: BkoTheme.goldAccent, size: 18),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Scrubber Slider
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3.5,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: _isDragging ? 8 : 6,
                        elevation: 0,
                        pressedElevation: 0,
                      ),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: BkoTheme.goldAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: BkoTheme.goldAccent,
                      overlayColor: const Color(0x33FFBF00),
                    ),
                    child: Slider(
                      value: sliderValue,
                      onChangeStart: (val) {
                        BkoHaptics.light();
                        setState(() {
                          _isDragging = true;
                          _dragValue = val;
                        });
                      },
                      onChanged: (val) {
                        setState(() {
                          _dragValue = val;
                        });
                      },
                      onChangeEnd: (val) {
                        final total = active.totalDuration;
                        if (total.inMilliseconds > 0) {
                          final newPos = Duration(
                            milliseconds:
                                (val * total.inMilliseconds).round(),
                          );
                          ref
                              .read(activeEpisodeProvider.notifier)
                              .seek(newPos);
                        }
                        setState(() {
                          _isDragging = false;
                          _dragValue = null;
                        });
                        BkoHaptics.select();
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(elapsedStr,
                            style: BkoTheme.fontLato(
                                fontSize: 11.5, color: textSec)),
                        Text(remainingStr,
                            style: BkoTheme.fontLato(
                                fontSize: 11.5, color: textSec)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Primary Playback Controls (-15s, Play/Pause, +30s)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      BkoBounceable(
                        scaleFactor: 0.88,
                        onTap: () {
                          ref
                              .read(activeEpisodeProvider.notifier)
                              .seekRelative(-15);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: const Icon(IconsaxPlusLinear.backward_15_seconds,
                              color: Colors.white, size: 30),
                        ),
                      ),
                      BkoBounceable(
                        onTap: () {
                          if (active.isBuffering) return;
                          ref
                              .read(activeEpisodeProvider.notifier)
                              .togglePlayPause();
                        },
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            color: BkoTheme.goldAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: active.isBuffering
                                ? const EqualizerLoader(
                                    size: 26,
                                    color: Colors.black,
                                    isPlaying: true,
                                  )
                                : Icon(
                                    active.isPlaying
                                        ? IconsaxPlusBold.pause
                                        : IconsaxPlusBold.play,
                                    color: Colors.black,
                                    size: 34,
                                  ),
                          ),
                        ),
                      ),
                      BkoBounceable(
                        scaleFactor: 0.88,
                        onTap: () {
                          ref
                              .read(activeEpisodeProvider.notifier)
                              .seekRelative(30);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: const Icon(IconsaxPlusLinear.forward_15_seconds,
                              color: Colors.white, size: 30),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Secondary Toolbar: Speed, Sleep Timer, Queue, Comments
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderSub),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 1. Playback Speed Button
                        TextButton(
                          onPressed: () =>
                              _showSpeedPicker(active.playbackSpeed),
                          child: Text(
                            '${active.playbackSpeed}x',
                            style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: active.playbackSpeed != 1.0
                                  ? BkoTheme.goldAccent
                                  : Colors.white,
                            ),
                          ),
                        ),

                        // 2. Sleep Timer Button
                        IconButton(
                          icon: Icon(
                            IconsaxPlusLinear.timer_1,
                            color: active.sleepTimerEndsAt != null
                                ? BkoTheme.goldAccent
                                : Colors.white70,
                            size: 20,
                          ),
                          onPressed: () {
                            BkoHaptics.select();
                            _showSleepTimerPicker();
                          },
                        ),

                        // 3. Like (Heart) Button
                        IconButton(
                          icon: Icon(
                            ref.watch(likedEpisodesProvider).contains(active.episodeId)
                                ? IconsaxPlusBold.heart
                                : IconsaxPlusLinear.heart,
                            color: ref.watch(likedEpisodesProvider).contains(active.episodeId)
                                ? Colors.redAccent
                                : Colors.white70,
                            size: 21,
                          ),
                          tooltip: ref.watch(likedEpisodesProvider).contains(active.episodeId)
                              ? 'Ne plus aimer'
                              : 'Aimer cet épisode',
                          onPressed: () {
                            if (active.episodeId.isNotEmpty) {
                              ref
                                  .read(likedEpisodesProvider.notifier)
                                  .toggleLike(context, active.episodeId);
                            }
                          },
                        ),

                        // 4. Queue Button
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            IconButton(
                              icon: const Icon(IconsaxPlusLinear.music_playlist,
                                  color: Colors.white70, size: 22),
                              onPressed: () {
                                BkoHaptics.select();
                                QueueSheet.show(context);
                              },
                            ),
                            if (active.queue.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 6, right: 6),
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: BkoTheme.goldAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${active.queue.length}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // 4. Comments Button
                        IconButton(
                          icon: const Icon(IconsaxPlusLinear.messages_2,
                              color: Colors.white70, size: 20),
                          onPressed: () {
                            BkoHaptics.select();
                            EpisodeCommentsSheet.show(
                              context,
                              episodeId: active.episodeId,
                              episodeTitle: active.title,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Tabs: "À suivre" / "Chapitres"
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildTabButton('À suivre (${active.queue.length})', 0),
                      _buildTabButton('Chapitres (${_chapters.length})', 1),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_selectedTab == 0) ...[
                    // Queue Quick Preview
                    if (active.queue.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141418),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderSub),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.playlist_play_rounded,
                                color: Colors.white38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Votre file est vide.\nAjoutez des épisodes avec « Lire ensuite » pour continuer l’écoute.',
                                style: BkoTheme.fontLato(
                                    fontSize: 12, color: textSec),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: active.queue.take(3).map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16161A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderSub),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.coverUrl.startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: item.coverUrl,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              _fallbackCover(size: 36),
                                        )
                                      : _fallbackCover(size: 36),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: BkoTheme.fontLato(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textPri,
                                        ),
                                      ),
                                      Text(
                                        item.showName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: BkoTheme.fontLato(
                                            fontSize: 11, color: textSec),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.play_arrow_rounded,
                                    color: BkoTheme.goldAccent, size: 20),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ] else ...[
                    // Chapters List
                    if (_loadingChapters)
                      Column(
                        children: List.generate(
                          3,
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                BkoSkeletonBox(
                                  width: 48,
                                  height: 24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: BkoSkeletonBox(
                                    height: 16,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (_chapters.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141418),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderSub),
                        ),
                        child: Text(
                          'Aucun chapitre disponible pour cet épisode.',
                          style:
                              BkoTheme.fontLato(fontSize: 12, color: textSec),
                        ),
                      )
                    else
                      Column(
                        children: _chapters.map((ch) {
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      BkoTheme.goldAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ch['time']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: BkoTheme.goldAccent,
                                  ),
                                ),
                              ),
                              title: Text(
                                ch['title']!,
                                style: BkoTheme.fontLato(
                                    fontSize: 13, color: textPri),
                              ),
                              trailing: const Icon(Icons.play_circle_fill_rounded,
                                  color: BkoTheme.goldAccent, size: 20),
                              onTap: () => _seekToTimestamp(ch['time']!),
                            ),
                          );
                        }).toList(),
                      ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF222228) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? BkoTheme.goldAccent : const Color(0xFF262626),
          ),
        ),
        child: Text(
          label,
          style: BkoTheme.fontLato(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _fallbackCover({double size = 48}) => Container(
        width: size,
        height: size,
        color: const Color(0xFF1E1E24),
        child: const Icon(Icons.podcasts_rounded,
            color: BkoTheme.goldAccent, size: 24),
      );
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';
import '../player/youtube_player_widget.dart';
import 'shell_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  DateTime? _lastHistorySync;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/library')) return 2;
    if (location.startsWith('/favorites')) return 2;
    if (location.startsWith('/search')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  Future<void> _syncHistory(ActiveEpisodeState episode) async {
    if (!episode.hasActiveEpisode ||
        episode.episodeId.isEmpty ||
        episode.currentPosition.inSeconds < 5) {
      return;
    }
    final now = DateTime.now();
    if (_lastHistorySync != null &&
        now.difference(_lastHistorySync!) < const Duration(seconds: 20)) {
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) return;
    _lastHistorySync = now;
    try {
      await BkoApi.post(
          '/me/history',
          {
            'episodeId': episode.episodeId,
            'positionSeconds': episode.currentPosition.inSeconds,
            'durationSeconds': episode.totalDuration.inSeconds,
          },
          token: token);
    } catch (_) {
      _lastHistorySync = null;
    }
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/explore');
        break;
      case 2:
        context.go('/library');
        break;
      case 3:
        context.go('/search');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final activeEpisode = ref.watch(activeEpisodeProvider);
    ref.listen<ActiveEpisodeState>(activeEpisodeProvider, (_, next) {
      _syncHistory(next);
    });
    final isNavVisible = ref.watch(shellNavVisibilityProvider);

    // Apple Motion Curve: Fast out, continuous spring easing
    const appleEase = Cubic(0.2, 0.9, 0.2, 1.0);
    const animDuration = Duration(milliseconds: 320);

    final bool hasLecture = activeEpisode.hasActiveEpisode;
    final bool isMorphed3Pills = hasLecture && !isNavVisible;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark ? const Color(0xED161B22) : const Color(0xF2FFFFFF);
    final glassBorder =
        isDark ? const Color(0x33E6B009) : const Color(0x20000000);

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: AnimatedContainer(
        duration: animDuration,
        curve: appleEase,
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          bottomPadding > 0 ? bottomPadding + 6 : 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -----------------------------------------------------------------
            // 1. MINI-PLAYER CAPSULE (TOP OR CENTERED)
            // -----------------------------------------------------------------
            AnimatedCrossFade(
              duration: animDuration,
              firstCurve: appleEase,
              secondCurve: appleEase,
              crossFadeState: hasLecture
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: isMorphed3Pills
                    ? _buildCompactMorphed3PillBar(context, activeEpisode)
                    : _buildFullMiniPlayerCapsule(context, activeEpisode),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // -----------------------------------------------------------------
            // 2. BOTTOM NAVIGATION CAPSULE (SLIDES DOWN & SCALES IN MORPH MODE)
            // -----------------------------------------------------------------
            AnimatedCrossFade(
              duration: animDuration,
              firstCurve: appleEase,
              secondCurve: appleEase,
              crossFadeState: isMorphed3Pills
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildAppleFullBottomNav(
                  context, selectedIndex, glassBg, glassBorder),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullPlayerModal(
      BuildContext context, ActiveEpisodeState activeEpisode) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (modalContext) {
        return Consumer(
          builder: (context, ref, child) {
            final activeState = ref.watch(activeEpisodeProvider);
            final position = activeState.currentPosition;
            final minutes =
                position.inMinutes.remainder(60).toString().padLeft(2, '0');
            final seconds =
                position.inSeconds.remainder(60).toString().padLeft(2, '0');
            final timeStr = '$minutes:$seconds';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(modalContext),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70, size: 28),
                      ),
                      Text(
                        activeState.mode == 'VIDEO'
                            ? 'EN COURS DE VISIONNAGE'
                            : 'EN COURS D\'ÉCOUTE',
                        style: BkoTheme.fontLato(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                      const Icon(Icons.more_horiz_rounded,
                          color: Colors.white70, size: 24),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Mode Toggle Pill (ÉCOUTER / REGARDER)
                  if (activeState.hasVideo)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2638),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (activeState.hasAudio)
                            GestureDetector(
                              onTap: () => ref
                                  .read(activeEpisodeProvider.notifier)
                                  .setMode('AUDIO'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: activeState.mode == 'AUDIO'
                                      ? BkoTheme.goldAccent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.headphones_rounded,
                                      size: 14,
                                      color: activeState.mode == 'AUDIO'
                                          ? Colors.black
                                          : Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ÉCOUTER',
                                      style: BkoTheme.fontLato(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: activeState.mode == 'AUDIO'
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
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: activeState.mode == 'VIDEO'
                                    ? BkoTheme.goldAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.videocam_rounded,
                                    size: 14,
                                    color: activeState.mode == 'VIDEO'
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'REGARDER',
                                    style: BkoTheme.fontLato(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: activeState.mode == 'VIDEO'
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
                  if (activeState.mode == 'VIDEO')
                    BkoYoutubePlayerWidget(
                      coverUrl: activeState.coverUrl,
                      videoUrl: activeState.videoUrl,
                      autoPlay: activeState.isPlaying,
                      startPosition: activeState.currentPosition,
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: activeState.coverUrl.isNotEmpty
                            ? Image.network(
                                activeState.coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: const Color(0xFF1E2638),
                                  child: const Icon(Icons.graphic_eq_rounded,
                                      color: BkoTheme.goldAccent, size: 64),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF1E2638),
                                child: const Icon(Icons.graphic_eq_rounded,
                                    color: BkoTheme.goldAccent, size: 64),
                              ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    activeState.title.isNotEmpty
                        ? activeState.title
                        : 'Épisode',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BkoTheme.fontLato(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(modalContext);
                      final slug = activeState.showName
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      context.push('/podcasts/$slug');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          activeState.showName.isNotEmpty
                              ? activeState.showName
                              : 'Voir la chaîne du podcast',
                          style: BkoTheme.fontLato(
                            fontSize: 13,
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
                  const SizedBox(height: 24),
                  SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: BkoTheme.goldAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: BkoTheme.goldAccent,
                    ),
                    child: Slider(
                      value: activeState.progress.clamp(0.0, 1.0),
                      onChanged: (val) {
                        final total = activeState.totalDuration;
                        if (total.inMilliseconds > 0) {
                          final newPos = Duration(
                              milliseconds:
                                  (val * total.inMilliseconds).round());
                          ref.read(activeEpisodeProvider.notifier).seek(newPos);
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(timeStr,
                            style: BkoTheme.fontLato(
                                fontSize: 11, color: Colors.white54)),
                        Text(activeState.duration,
                            style: BkoTheme.fontLato(
                                fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded,
                            color: Colors.white, size: 30),
                        onPressed: () {
                          final current = activeState.currentPosition;
                          final newPos = current - const Duration(seconds: 10);
                          ref.read(activeEpisodeProvider.notifier).seek(
                              newPos < Duration.zero ? Duration.zero : newPos);
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(activeEpisodeProvider.notifier)
                              .togglePlayPause();
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: BkoTheme.goldAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activeState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 36,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded,
                            color: Colors.white, size: 30),
                        onPressed: () {
                          final current = activeState.currentPosition;
                          final newPos = current + const Duration(seconds: 10);
                          ref.read(activeEpisodeProvider.notifier).seek(newPos);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MORPHED 3-PILL BAR (Scroll Down Mode during Active Lecture)
  // ---------------------------------------------------------------------------
  Widget _buildCompactMorphed3PillBar(
    BuildContext context,
    ActiveEpisodeState activeEpisode,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark ? const Color(0xE6161B22) : const Color(0xECFFFFFF);
    final glassBorder =
        isDark ? const Color(0x33E6B009) : const Color(0x250F172A);

    return Row(
      key: const ValueKey('Morphed3PillBar'),
      children: [
        // 1. LEFT CIRCLE PILL: HOME 🏠
        _buildCircleActionPill(
          context,
          icon: Icons.home_rounded,
          onTap: () {
            ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
            context.go('/');
          },
        ),

        const SizedBox(width: 8),

        // 2. CENTER CAPSULE: COMPACT MINI PLAYER
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: glassBg,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: glassBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _openFullPlayerModal(context, activeEpisode),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  activeEpisode.coverUrl.isNotEmpty
                                      ? activeEpisode.coverUrl
                                      : '',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 36,
                                    height: 36,
                                    color:
                                        BkoTheme.getBgSurfaceElevated(context),
                                    child: const Icon(Icons.graphic_eq_rounded,
                                        color: BkoTheme.goldAccent, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      activeEpisode.title.isNotEmpty
                                          ? activeEpisode.title
                                          : "Management humain...",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: BkoTheme.getTextPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      activeEpisode.showName.isNotEmpty
                                          ? activeEpisode.showName
                                          : "14 janvier",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            BkoTheme.getTextSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Solid Play Triangle Button ▶
                      _AppleSpringPlayButton(
                        isPlaying: activeEpisode.isPlaying,
                        onTap: () {
                          ref
                              .read(activeEpisodeProvider.notifier)
                              .togglePlayPause();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // 3. RIGHT CIRCLE PILL: SEARCH 🔍
        _buildCircleActionPill(
          context,
          icon: Icons.search_rounded,
          onTap: () {
            ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
            context.go('/explore');
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FULL MINI PLAYER CAPSULE (Top Capsule when Nav Bar is Visible)
  // ---------------------------------------------------------------------------
  Widget _buildFullMiniPlayerCapsule(
    BuildContext context,
    ActiveEpisodeState activeEpisode,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark ? const Color(0xE6161B22) : const Color(0xECFFFFFF);
    final glassBorder =
        isDark ? const Color(0x33E6B009) : const Color(0x250F172A);

    return Container(
      key: const ValueKey('FullMiniPlayerCapsule'),
      height: 56,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: glassBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openFullPlayerModal(context, activeEpisode),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(
                            activeEpisode.coverUrl.isNotEmpty
                                ? activeEpisode.coverUrl
                                : '',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 40,
                              height: 40,
                              color: BkoTheme.getBgSurfaceElevated(context),
                              child: const Icon(Icons.graphic_eq_rounded,
                                  color: BkoTheme.goldAccent, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                activeEpisode.title.isNotEmpty
                                    ? activeEpisode.title
                                    : "Management humain : concilier exigence...",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BkoTheme.fontLato(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: BkoTheme.getTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                activeEpisode.showName.isNotEmpty
                                    ? "${activeEpisode.showName} • ${activeEpisode.duration}"
                                    : "14 janvier",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BkoTheme.fontLato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: BkoTheme.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Play/Pause Button ▶
                _AppleSpringPlayButton(
                  isPlaying: activeEpisode.isPlaying,
                  onTap: () {
                    ref.read(activeEpisodeProvider.notifier).togglePlayPause();
                  },
                ),

                const SizedBox(width: 4),

                // Skip 30s Icon (30)
                _AppleTactileIconButton(
                  icon: Icons.forward_30_rounded,
                  color: BkoTheme.getTextPrimary(context),
                  size: 22,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FULL BOTTOM NAVIGATION CAPSULE (Apple Podcasts Style)
  // ---------------------------------------------------------------------------
  Widget _buildAppleFullBottomNav(
    BuildContext context,
    int selectedIndex,
    Color glassBg,
    Color glassBorder,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      {'icon': Icons.home_rounded, 'label': 'Accueil'},
      {'icon': Icons.grid_view_rounded, 'label': 'Nouveautés'},
      {'icon': Icons.podcasts_rounded, 'label': 'Bibliothèque'},
      {'icon': Icons.search_rounded, 'label': 'Recherche'},
      {'icon': Icons.person_outline_rounded, 'label': 'Profil'},
    ];
    items[1] = {'icon': Icons.explore_rounded, 'label': 'Explorer'};

    return Container(
      key: const ValueKey('AppleFullBottomNav'),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: glassBorder, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = selectedIndex == index;
                final item = items[index];

                return _ApplePodcastsNavItem(
                  isSelected: isSelected,
                  icon: item['icon'] as IconData,
                  label: item['label'] as String,
                  onTap: () => _onItemTapped(index, context),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // Helper: Circular Action Pill (Home 🏠 / Search 🔍)
  Widget _buildCircleActionPill(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark ? const Color(0xE6161B22) : const Color(0xECFFFFFF);
    final glassBorder =
        isDark ? const Color(0x33E6B009) : const Color(0x250F172A);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(26),
              child: Container(
                decoration: BoxDecoration(
                  color: glassBg,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: glassBorder, width: 1.2),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: BkoTheme.getActiveNavItemColor(context),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// APPLE PODCASTS NAVIGATION ITEM WITH HIGHLIGHT BUBBLE
// -----------------------------------------------------------------------------

class _ApplePodcastsNavItem extends StatefulWidget {
  final bool isSelected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ApplePodcastsNavItem({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ApplePodcastsNavItem> createState() => _ApplePodcastsNavItemState();
}

class _ApplePodcastsNavItemState extends State<_ApplePodcastsNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = BkoTheme.getActiveNavItemColor(context);
    final inactiveColor = BkoTheme.getTextSecondary(context);

    final bubbleBg = widget.isSelected
        ? (isDark ? const Color(0x33E6B009) : const Color(0x1F0F172A))
        : Colors.transparent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuad,
        scale: _isPressed ? 0.92 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: const Cubic(0.16, 1.0, 0.3, 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 22,
                color: widget.isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: BkoTheme.fontLato(
                  fontSize: 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: widget.isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// APPLE TACTILE SPRING BUTTONS
// -----------------------------------------------------------------------------

class _AppleSpringPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _AppleSpringPlayButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_AppleSpringPlayButton> createState() => _AppleSpringPlayButtonState();
}

class _AppleSpringPlayButtonState extends State<_AppleSpringPlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final playBtnBg = BkoTheme.getTextPrimary(context);
    final playBtnIconColor = BkoTheme.getBgObsidian(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuad,
        scale: _isPressed ? 0.90 : 1.0,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: playBtnBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: playBtnIconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _AppleTactileIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  const _AppleTactileIconButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onPressed,
  });

  @override
  State<_AppleTactileIconButton> createState() =>
      _AppleTactileIconButtonState();
}

class _AppleTactileIconButtonState extends State<_AppleTactileIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        scale: _isPressed ? 0.85 : 1.0,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(
              widget.icon,
              color: widget.color,
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}

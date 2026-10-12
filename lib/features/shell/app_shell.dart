import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';
import '../player/full_audio_player_sheet.dart';
import 'bko_mini_player.dart';
import 'shell_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell? navigationShell;
  final Widget? child;
  const AppShell({super.key, this.navigationShell, this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  DateTime? _lastHistorySync;

  int _calculateSelectedIndex(BuildContext context) {
    if (widget.navigationShell != null) {
      return widget.navigationShell!.currentIndex;
    }
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/explore') || location.startsWith('/search')) return 1;
    if (location.startsWith('/library') || location.startsWith('/favorites')) return 2;
    if (location.startsWith('/profile')) return 3;
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
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(
        index,
        initialLocation: index == widget.navigationShell!.currentIndex,
      );
      return;
    }
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
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final hasLecture = ref.watch(activeEpisodeProvider.select((s) => s.hasActiveEpisode));
    ref.listen<ActiveEpisodeState>(activeEpisodeProvider, (prev, next) {
      _syncHistory(next);
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF991B1B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
    final isNavVisible = ref.watch(shellNavVisibilityProvider);

    // Apple Motion Curve: Fast out, continuous spring easing
    const appleEase = Cubic(0.2, 0.9, 0.2, 1.0);
    const animDuration = Duration(milliseconds: 320);

    final bool isMorphed3Pills = hasLecture && !isNavVisible;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark ? const Color(0xED161B22) : const Color(0xF2FFFFFF);
    final glassBorder =
        isDark ? const Color(0x33E6B009) : const Color(0x20000000);

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell ?? widget.child,
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
                    ? _buildCompactMorphed3PillBar(context)
                    : const BkoMiniPlayer(),
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

  void _openFullPlayerModal(BuildContext context) {
    FullAudioPlayerSheet.show(context);
  }

  // ---------------------------------------------------------------------------
  // MORPHED 3-PILL BAR (Scroll Down Mode during Active Lecture)
  // ---------------------------------------------------------------------------
  Widget _buildCompactMorphed3PillBar(BuildContext context) {
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
          icon: IconsaxPlusLinear.home_2,
          onTap: () {
            BkoHaptics.select();
            ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
            context.go('/');
          },
        ),

        const SizedBox(width: 8),

        // 2. CENTER CAPSULE: COMPACT MINI PLAYER
        Expanded(
          child: Container(
            height: 52,
            decoration: const BoxDecoration(),
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
                  child: Consumer(
                    builder: (context, ref, _) {
                      final title = ref.watch(activeEpisodeProvider.select((s) => s.title));
                      final showName = ref.watch(activeEpisodeProvider.select((s) => s.showName));
                      final coverUrl = ref.watch(activeEpisodeProvider.select((s) => s.coverUrl));
                      final isPlaying = ref.watch(activeEpisodeProvider.select((s) => s.isPlaying));

                      return Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openFullPlayerModal(context),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      coverUrl.isNotEmpty ? coverUrl : '',
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        width: 36,
                                        height: 36,
                                        color: BkoTheme.getBgSurfaceElevated(context),
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
                                          title.isNotEmpty ? title : "Bamako Podcast",
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
                                          showName.isNotEmpty ? showName : "En cours",
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
                          const SizedBox(width: 6),

                          // Solid Play Triangle Button ▶
                          _AppleSpringPlayButton(
                            isPlaying: isPlaying,
                            onTap: () {
                              ref
                                  .read(activeEpisodeProvider.notifier)
                                  .togglePlayPause();
                            },
                          ),
                        ],
                      );
                    },
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
          icon: IconsaxPlusLinear.search_normal_1,
          onTap: () {
            BkoHaptics.select();
            ref.read(shellNavVisibilityProvider.notifier).setVisible(true);
            context.go('/explore');
          },
        ),
      ],
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
    final items = [
      {
        'linearIcon': IconsaxPlusLinear.home_2,
        'boldIcon': IconsaxPlusBold.home_2,
        'label': 'Accueil',
      },
      {
        'linearIcon': IconsaxPlusLinear.discover,
        'boldIcon': IconsaxPlusBold.discover,
        'label': 'Explorer',
      },
      {
        'linearIcon': IconsaxPlusLinear.folder_2,
        'boldIcon': IconsaxPlusBold.folder_2,
        'label': 'Bibliothèque',
      },
      {
        'linearIcon': IconsaxPlusLinear.profile_circle,
        'boldIcon': IconsaxPlusBold.profile_circle,
        'label': 'Profil',
      },
    ];

    return Container(
      key: const ValueKey('AppleFullBottomNav'),
      decoration: const BoxDecoration(),
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

                return Flexible(
                  child: _ApplePodcastsNavItem(
                    isSelected: isSelected,
                    linearIcon: item['linearIcon'] as IconData,
                    boldIcon: item['boldIcon'] as IconData,
                    label: item['label'] as String,
                    onTap: () {
                      BkoHaptics.select();
                      _onItemTapped(index, context);
                    },
                  ),
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
      decoration: const BoxDecoration(),
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
  final IconData linearIcon;
  final IconData boldIcon;
  final String label;
  final VoidCallback onTap;

  const _ApplePodcastsNavItem({
    required this.isSelected,
    required this.linearIcon,
    required this.boldIcon,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSelected ? widget.boldIcon : widget.linearIcon,
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
      onTap: () {
        BkoHaptics.light();
        widget.onTap();
      },
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
            widget.isPlaying
                ? IconsaxPlusBold.pause
                : IconsaxPlusBold.play,
            color: playBtnIconColor,
            size: 18,
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

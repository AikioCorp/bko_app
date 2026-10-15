import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/equalizer_loader.dart';
import '../player/full_audio_player_sheet.dart';
import 'shell_providers.dart';

/// Persistent Mini-Player capsule styled with Apple fluid ergonomics.
/// Reflects the single source of truth from [activeEpisodeProvider].
class BkoMiniPlayer extends ConsumerWidget {
  final bool compact;

  const BkoMiniPlayer({
    super.key,
    this.compact = false,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFullPlayerOpen = ref.watch(isFullPlayerOpenProvider);
    if (isFullPlayerOpen) return const SizedBox.shrink();

    final active = ref.watch(activeEpisodeProvider);
    if (!active.hasActiveEpisode) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark ? const Color(0xE6161B22) : const Color(0xF2FFFFFF);
    final glassBorder = isDark ? const Color(0x33E6B009) : const Color(0x250F172A);

    final elapsedStr = _formatDuration(active.currentPosition);
    final totalStr = active.totalDuration > Duration.zero
        ? _formatDuration(active.totalDuration)
        : (active.duration.isNotEmpty ? active.duration : '--:--');

    return Semantics(
      label: 'Lecteur en cours : ${active.title}',
      child: Container(
        height: 64,
        decoration: const BoxDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: glassBg,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: glassBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      // 1. Tappable Episode Artwork & Metadata -> Opens Full Player
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => FullAudioPlayerSheet.show(context),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(
                                  active.coverUrl.isNotEmpty ? active.coverUrl : '',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 44,
                                    height: 44,
                                    color: BkoTheme.getBgSurfaceElevated(context),
                                    child: const Icon(
                                      IconsaxPlusLinear.music,
                                      color: BkoTheme.goldAccent,
                                      size: 20,
                                    ),
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
                                      active.title.isNotEmpty
                                          ? active.title
                                          : 'Bamako Podcast',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: BkoTheme.getTextPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            active.showName.isNotEmpty
                                                ? active.showName
                                                : 'Bamako Podcast',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: BkoTheme.fontLato(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: BkoTheme.getTextSecondary(context),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0x33FFBF00) : const Color(0x1ADB8900),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$elapsedStr / $totalStr',
                                            style: BkoTheme.fontLato(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? BkoTheme.goldAccent : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 2. Play / Pause Spring Button with buffering support
                      _SpringMiniPlayButton(
                        isPlaying: active.isPlaying,
                        isLoading: active.isBuffering,
                        onTap: () {
                          ref.read(activeEpisodeProvider.notifier).togglePlayPause();
                        },
                      ),

                      if (!compact) ...[
                        const SizedBox(width: 4),
                        // 3. Skip +30s Button
                        _SpringIconButton(
                          icon: IconsaxPlusLinear.forward_15_seconds,
                          color: BkoTheme.getTextPrimary(context),
                          size: 22,
                          tooltip: 'Avancer de 30 secondes',
                          onPressed: () {
                            BkoHaptics.select();
                            ref.read(activeEpisodeProvider.notifier).seekRelative(30);
                          },
                        ),
                      ],

                      const SizedBox(width: 2),
                      // 4. Close / Dismiss Mini-Player
                      _SpringIconButton(
                        icon: IconsaxPlusLinear.close_circle,
                        color: BkoTheme.getTextSecondary(context),
                        size: 20,
                        tooltip: 'Fermer le lecteur',
                        onPressed: () {
                          BkoHaptics.light();
                          ref.read(activeEpisodeProvider.notifier).stop();
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 3.5,
                      color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: active.progress.clamp(0.0, 1.0),
                        child: Container(
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpringMiniPlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  const _SpringMiniPlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_SpringMiniPlayButton> createState() => _SpringMiniPlayButtonState();
}

class _SpringMiniPlayButtonState extends State<_SpringMiniPlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final playBtnBg = BkoTheme.getTextPrimary(context);
    final playBtnIconColor = BkoTheme.getBgObsidian(context);

    return Semantics(
      button: true,
      label: widget.isPlaying ? 'Pause' : 'Lecture',
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          BkoHaptics.tapDown();
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 90),
          curve: const Cubic(0.2, 0.9, 0.2, 1.0),
          scale: _isPressed ? 0.90 : 1.0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: playBtnBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: widget.isLoading
                  ? EqualizerLoader(
                      size: 16,
                      color: playBtnIconColor,
                      isPlaying: true,
                    )
                  : Icon(
                      widget.isPlaying
                          ? IconsaxPlusBold.pause
                          : IconsaxPlusBold.play,
                      color: playBtnIconColor,
                      size: 18,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpringIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String tooltip;
  final VoidCallback onPressed;

  const _SpringIconButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_SpringIconButton> createState() => _SpringIconButtonState();
}

class _SpringIconButtonState extends State<_SpringIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          BkoHaptics.tapDown();
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 90),
          curve: const Cubic(0.2, 0.9, 0.2, 1.0),
          scale: _isPressed ? 0.85 : 1.0,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            alignment: Alignment.center,
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

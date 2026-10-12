import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../../core/widgets/equalizer_loader.dart';
import '../../shell/shell_providers.dart';
import '../full_audio_player_sheet.dart';

enum BkoPlayButtonStyle {
  circle,
  pill,
}

/// Unified, reactive Play/Pause button for episodes.
/// Automatically observes [activeEpisodeProvider] and coordinates with [BkoAudioHandler].
/// - Displays [Pause] icon when the target episode is playing.
/// - Displays [Play] icon when paused or inactive.
/// - Displays a [CircularProgressIndicator] when loading / buffering.
/// - Tapping while playing pauses immediately without reloading media.
/// - Tapping while paused resumes playback at the exact second.
class BkoPlayButton extends ConsumerWidget {
  final String episodeId;
  final String title;
  final String showName;
  final String duration;
  final String coverUrl;
  final String? audioUrl;
  final String? videoUrl;
  final bool? hasAudio;
  final bool? hasVideo;
  final String? podcastSlug;
  final String? episodeSlug;
  final String? initialMode;

  final BkoPlayButtonStyle style;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? activeBackgroundColor;
  final Color? iconColor;
  final Color? activeIconColor;

  const BkoPlayButton({
    super.key,
    required this.episodeId,
    required this.title,
    required this.showName,
    this.duration = '',
    this.coverUrl = '',
    this.audioUrl,
    this.videoUrl,
    this.hasAudio,
    this.hasVideo,
    this.podcastSlug,
    this.episodeSlug,
    this.initialMode,
    this.style = BkoPlayButtonStyle.circle,
    this.size = 36,
    this.iconSize = 20,
    this.backgroundColor,
    this.activeBackgroundColor,
    this.iconColor,
    this.activeIconColor,
  });

  const BkoPlayButton.pill({
    super.key,
    required this.episodeId,
    required this.title,
    required this.showName,
    this.duration = '',
    this.coverUrl = '',
    this.audioUrl,
    this.videoUrl,
    this.hasAudio,
    this.hasVideo,
    this.podcastSlug,
    this.episodeSlug,
    this.initialMode,
    this.size = 48,
    this.iconSize = 20,
    this.backgroundColor,
    this.activeBackgroundColor,
    this.iconColor,
    this.activeIconColor,
  }) : style = BkoPlayButtonStyle.pill;

  void _onTap(BuildContext context, WidgetRef ref) {
    BkoHaptics.light();
    final active = ref.read(activeEpisodeProvider);
    final isAlreadyPlayingThis = active.hasActiveEpisode &&
        active.episodeId == episodeId &&
        active.isPlaying;

    ref.read(activeEpisodeProvider.notifier).handlePlayOrPause(
          episodeId: episodeId,
          title: title,
          showName: showName,
          duration: duration,
          coverUrl: coverUrl,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          hasAudio: hasAudio,
          hasVideo: hasVideo,
          initialMode: initialMode,
          podcastSlug: podcastSlug,
          episodeSlug: episodeSlug,
        );

    if (style == BkoPlayButtonStyle.pill && !isAlreadyPlayingThis && context.mounted) {
      FullAudioPlayerSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(
      activeEpisodeProvider.select(
        (s) => s.hasActiveEpisode && s.episodeId == episodeId && episodeId.isNotEmpty,
      ),
    );
    final isPlaying = isCurrent &&
        ref.watch(activeEpisodeProvider.select((s) => s.isPlaying));
    final isLoading = isCurrent &&
        ref.watch(activeEpisodeProvider.select((s) => s.isBuffering));

    final String semanticsLabel = isPlaying
        ? 'Mettre en pause $title'
        : (isCurrent ? 'Reprendre la lecture de $title' : 'Lire $title');

    if (style == BkoPlayButtonStyle.pill) {
      return _buildPill(context, ref, isCurrent, isPlaying, isLoading, semanticsLabel);
    }

    return _buildCircle(context, ref, isCurrent, isPlaying, isLoading, semanticsLabel);
  }

  Widget _buildCircle(
    BuildContext context,
    WidgetRef ref,
    bool isCurrent,
    bool isPlaying,
    bool isLoading,
    String semanticsLabel,
  ) {
    final defaultBg = backgroundColor ?? Colors.black.withValues(alpha: 0.65);
    final activeBg = activeBackgroundColor ?? BkoTheme.goldAccent;
    final defaultFg = iconColor ?? Colors.white;
    final activeFg = activeIconColor ?? Colors.black;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: BkoBounceable(
        onTap: () => _onTap(context, ref),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: (isPlaying || (isCurrent && isLoading)) ? activeBg : defaultBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isLoading
                  ? EqualizerLoader(
                      size: iconSize * 0.85,
                      color: isPlaying ? activeFg : BkoTheme.goldAccent,
                    )
                  : Icon(
                      isPlaying ? IconsaxPlusBold.pause : IconsaxPlusBold.play,
                      color: isPlaying ? activeFg : defaultFg,
                      size: iconSize,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(
    BuildContext context,
    WidgetRef ref,
    bool isCurrent,
    bool isPlaying,
    bool isLoading,
    String semanticsLabel,
  ) {
    String labelText;
    IconData iconData;

    if (isLoading) {
      labelText = 'CHARGEMENT...';
      iconData = IconsaxPlusLinear.music_filter;
    } else if (isPlaying) {
      labelText = 'PAUSE';
      iconData = IconsaxPlusBold.pause;
    } else if (isCurrent) {
      labelText = 'REPRENDRE';
      iconData = IconsaxPlusBold.play;
    } else {
      labelText = 'ÉCOUTER';
      iconData = IconsaxPlusLinear.headphone;
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: BkoBounceable(
        onTap: () => _onTap(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: BkoTheme.goldAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const EqualizerLoader(size: 16, color: Colors.black)
              else
                Icon(iconData, color: Colors.black, size: 18),
              const SizedBox(width: 8),
              Text(
                labelText,
                style: BkoTheme.fontLato(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

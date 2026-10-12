import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/bko_theme.dart';
import 'bko_mini_player.dart';
import 'shell_providers.dart';

/// Wraps subpages (/downloads, /notifications, /podcasts/:slug, /playlists/:id, /studio, etc.)
/// with a persistent mini-player capsule anchored above safe area when audio is active.
class SubpageAudioShell extends ConsumerWidget {
  final Widget child;

  const SubpageAudioShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveEpisode =
        ref.watch(activeEpisodeProvider.select((s) => s.hasActiveEpisode));
    final isNavVisible = ref.watch(shellNavVisibilityProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    const appleEase = Cubic(0.2, 0.9, 0.2, 1.0);
    const animDuration = Duration(milliseconds: 300);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      body: child,
      bottomNavigationBar: hasActiveEpisode
          ? AnimatedSlide(
              duration: animDuration,
              curve: appleEase,
              offset: isNavVisible ? Offset.zero : const Offset(0, 1.3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: isNavVisible ? 1.0 : 0.0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    bottomPadding > 0 ? bottomPadding + 6 : 14,
                  ),
                  child: const BkoMiniPlayer(),
                ),
              ),
            )
          : null,
    );
  }
}

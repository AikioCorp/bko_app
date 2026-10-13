import 'package:flutter/material.dart';
import '../theme/bko_theme.dart';
import 'equalizer_loader.dart';

/// Reusable pulse animation controller for solid skeletons.
class BkoSkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Border? border;
  final Widget? child;

  const BkoSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.border,
    this.child,
  });

  @override
  State<BkoSkeletonBox> createState() => _BkoSkeletonBoxState();
}

class _BkoSkeletonBoxState extends State<BkoSkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.35,
      end: 0.80,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.baseColor ?? BkoTheme.getBgSurfaceElevated(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    final border = widget.border ?? Border.all(color: BkoTheme.getBorderSubtle(context));

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: radius,
              border: border,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Skeleton for horizontal podcast card carousel.
class BkoPodcastCardSkeleton extends StatelessWidget {
  final double size;

  const BkoPodcastCardSkeleton({
    super.key,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BkoSkeletonBox(
            width: size,
            height: size,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 10),
          BkoSkeletonBox(
            width: size * 0.85,
            height: 14,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 6),
          BkoSkeletonBox(
            width: size * 0.55,
            height: 12,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for vertical episode list row.
class BkoEpisodeRowSkeleton extends StatelessWidget {
  const BkoEpisodeRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSub),
      ),
      child: Row(
        children: [
          const BkoSkeletonBox(
            width: 54,
            height: 54,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BkoSkeletonBox(
                  width: double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                const BkoSkeletonBox(
                  width: 120,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const BkoSkeletonBox(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ],
      ),
    );
  }
}

/// Rich audio/podcast home screen skeleton loader.
class BkoHomeSkeleton extends StatelessWidget {
  const BkoHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final borderSub = BkoTheme.getBorderSubtle(context);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // 1. Horizontal Category Chips Skeleton
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => BkoSkeletonBox(
                width: i == 0 ? 64 : (70.0 + (i * 12)),
                height: 36,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Hero Banner Card Skeleton with Equalizer Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                BkoSkeletonBox(
                  width: double.infinity,
                  height: 195,
                  borderRadius: BorderRadius.circular(20),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BkoSkeletonBox(
                        width: 140,
                        height: 12,
                        borderRadius: BorderRadius.circular(6),
                        baseColor: BkoTheme.goldAccent.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 8),
                      BkoSkeletonBox(
                        width: 220,
                        height: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: BkoTheme.getBgObsidian(context).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderSub),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const EqualizerLoader(bars: 3, size: 14, color: BkoTheme.goldAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Chargement...',
                          style: BkoTheme.fontLato(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: BkoTheme.goldAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3. Section Title Skeleton (Émissions à la une)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BkoSkeletonBox(
                  width: 160,
                  height: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
                BkoSkeletonBox(
                  width: 60,
                  height: 14,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Horizontal Podcast Cards Carousel Skeleton
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => const BkoPodcastCardSkeleton(size: 130),
            ),
          ),
          const SizedBox(height: 24),

          // 5. Section Title Skeleton (Derniers épisodes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BkoSkeletonBox(
              width: 140,
              height: 18,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 14),

          // 6. Vertical Episode Rows List Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: BkoEpisodeRowSkeleton(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for single notification card.
class BkoNotificationCardSkeleton extends StatelessWidget {
  const BkoNotificationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSub),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BkoSkeletonBox(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BkoSkeletonBox(
                  width: double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 8),
                BkoSkeletonBox(
                  width: 180,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 8),
                BkoSkeletonBox(
                  width: 80,
                  height: 10,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton list for notifications screen.
class BkoNotificationListSkeleton extends StatelessWidget {
  final int count;
  const BkoNotificationListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: count,
      itemBuilder: (_, __) => const BkoNotificationCardSkeleton(),
    );
  }
}

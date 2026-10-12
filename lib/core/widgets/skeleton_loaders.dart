import 'package:flutter/material.dart';

/// Reusable pulse animation controller for solid skeletons.
class BkoSkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Border? border;

  const BkoSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.border,
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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.35,
      end: 0.75,
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
    final color = widget.baseColor ?? const Color(0xFF16161A);
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

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
              border: widget.border ?? Border.all(color: const Color(0xFF262626)),
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
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

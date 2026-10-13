import 'package:flutter/material.dart';
import 'bko_haptics.dart';

/// Interactive wrapper providing a physical spring tap feedback (scale 0.96)
/// and subtle haptic response without jarring animations.
class BkoBounceable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHaptics;
  final double scaleFactor;
  final HitTestBehavior behavior;

  const BkoBounceable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enableHaptics = true,
    this.scaleFactor = 0.96,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BkoBounceable> createState() => _BkoBounceableState();
}

class _BkoBounceableState extends State<BkoBounceable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      // Apple Fluid Interfaces spring curve: instantaneous reaction, critically damped recovery
      curve: const Cubic(0.2, 0.9, 0.2, 1.0),
      reverseCurve: const Cubic(0.2, 0.9, 0.2, 1.0),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
      // Crucial for iOS Taptic Engine: feedback must couple into compressed fingertip on pointer-down
      if (widget.enableHaptics) {
        BkoHaptics.tapDown();
      }
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptics) {
                BkoHaptics.select();
              }
              widget.onLongPress!();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

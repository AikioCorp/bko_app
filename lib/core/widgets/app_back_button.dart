import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'bko_bounceable.dart';
import 'bko_haptics.dart';

/// Standardized back button following mobile-designer rule #10:
/// Always uses IconsaxPlusLinear.arrow_left_1 with a comfortable 48x48 touch target,
/// GoRouter-aware popping, and light haptic feedback.
class AppBackButton extends StatelessWidget {
  final Color? color;
  final VoidCallback? onPressed;
  final double size;
  final String? fallbackLocation;

  const AppBackButton({
    super.key,
    this.color,
    this.onPressed,
    this.size = 22,
    this.fallbackLocation,
  });

  void _handlePop(BuildContext context) {
    BkoHaptics.select();
    if (onPressed != null) {
      onPressed!();
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (fallbackLocation != null && fallbackLocation!.isNotEmpty) {
      context.go(fallbackLocation!);
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Semantics(
      button: true,
      label: 'Retour',
      child: BkoBounceable(
        onTap: () => _handlePop(context),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Icon(
            IconsaxPlusLinear.arrow_left_1,
            size: size,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}

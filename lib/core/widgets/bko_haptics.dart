import 'package:flutter/services.dart';

/// Anti-burst haptic feedback service adhering to mobile-designer guidelines.
/// Ensures maximum discretion, energy efficiency, and prevents stacking vibrations.
class BkoHaptics {
  static bool enabled = true;
  static DateTime? _lastVibration;
  static const int _debounceMs = 120;

  static bool _canVibrate() {
    if (!enabled) return false;
    final now = DateTime.now();
    if (_lastVibration != null &&
        now.difference(_lastVibration!).inMilliseconds < _debounceMs) {
      return false;
    }
    _lastVibration = now;
    return true;
  }

  /// Very subtle tick for tab/segment/selection change.
  static void select() {
    if (_canVibrate()) {
      HapticFeedback.selectionClick();
    }
  }

  /// Alias for select()
  static void selection() => select();

  /// Light impact for toggle, like, play/pause, button press.
  static void light() {
    if (_canVibrate()) {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium impact for successful completion (checkout, download finished).
  static void success() {
    if (_canVibrate()) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy impact for blocking error or destructive confirmation.
  static void error() {
    if (_canVibrate()) {
      HapticFeedback.heavyImpact();
    }
  }
}

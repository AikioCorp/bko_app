import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Anti-burst haptic feedback service adhering to mobile-designer & Apple Fluid Interfaces guidelines.
/// Calibrated specifically for iOS Taptic Engine and Android haptic actuators:
/// - Provides instant physical tapDown feedback on pointer-down (while finger compresses the glass)
/// - Delivers crisp, perceptible iOS selection & impact pulses
/// - Anti-burst filter prevents sensory saturation while remaining responsive to quick taps
class BkoHaptics {
  static bool enabled = true;
  static DateTime? _lastVibration;
  static const int _debounceMs = 70;

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

  /// Instant tactile response on pointer-down (physical contact with glass).
  /// Uses light impact so the mechanical click couples directly into the compressed fingertip.
  static void tapDown() {
    if (_canVibrate()) {
      HapticFeedback.lightImpact();
    }
  }

  /// Discrete tick for tab, segment, or selection changes.
  /// On iOS, uses light impact because selectionClick outside picker wheels is often imperceptible.
  /// On Android, uses standard selection click.
  static void select() {
    if (_canVibrate()) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
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

  /// Warning impact for quota limits, destructive prompts, or guest restrictions.
  static void warning() {
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

import 'package:flutter/foundation.dart';

/// Interface for a shake detector.
///
/// Users must provide an implementation of this interface (e.g., using `sensors_plus`)
/// if they wish to use the [EnvTrigger.shake] trigger.
abstract interface class EnvShakeDetector {
  /// Starts listening for shake events.
  void start(double threshold, VoidCallback onShake);

  /// Stops listening for shake events.
  void stop();
}

/// Sealed class defining the gesture triggers to open the debug panel.
sealed class EnvTrigger {
  const EnvTrigger();

  /// Trigger by tapping multiple times (default: 7 taps).
  const factory EnvTrigger.tap({int count}) = TapTrigger;

  /// Trigger by swiping from the edge of the screen.
  const factory EnvTrigger.edgeSwipe({double edgeWidth}) = EdgeSwipeTrigger;

  /// Trigger by shaking the device.
  ///
  /// Requires a user-provided [detector] implementation.
  const factory EnvTrigger.shake({
    required EnvShakeDetector detector,
    double threshold,
  }) = ShakeTrigger;
}

/// Trigger by tapping multiple times.
class TapTrigger extends EnvTrigger {
  /// The number of taps required to trigger.
  final int count;

  const TapTrigger({this.count = 7});
}

/// Trigger by swiping from the edge of the screen.
class EdgeSwipeTrigger extends EnvTrigger {
  /// The width of the edge area that detects swipes.
  final double edgeWidth;

  const EdgeSwipeTrigger({this.edgeWidth = 20});
}

/// Trigger by shaking the device.
class ShakeTrigger extends EnvTrigger {
  /// The detector implementation.
  final EnvShakeDetector detector;

  /// The G-force threshold required to trigger.
  final double threshold;

  const ShakeTrigger({
    required this.detector,
    this.threshold = 15.0,
  });
}

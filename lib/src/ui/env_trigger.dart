import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Defines the gesture that opens the [EnvifiedOverlay] debug panel.
///
/// Use one of the factory constructors to select a trigger type:
///
/// ```dart
/// EnvifiedOverlay(
///   trigger: const EnvTrigger.tap(count: 7),    // default — 7 rapid taps
///   // trigger: const EnvTrigger.shake(),         // device shake
///   // trigger: const EnvTrigger.edgeSwipe(),     // right-edge swipe
///   ...
/// )
/// ```
sealed class EnvTrigger {
  const EnvTrigger();

  /// Open the panel by tapping any child widget [count] times rapidly
  /// (within an 800 ms window).
  ///
  /// Defaults to 7 taps, which is unlikely to trigger accidentally.
  const factory EnvTrigger.tap({int? count}) = _TapTrigger;

  /// Open the panel by shaking the device.
  ///
  /// Listens to the accelerometer via `sensors_plus`. A shake is detected
  /// when the total acceleration magnitude exceeds [threshold] m/s².
  /// A 2-second debounce prevents repeated triggers.
  ///
  /// Requires `sensors_plus` to be configured in `pubspec.yaml`.
  const factory EnvTrigger.shake({double? threshold}) = _ShakeTrigger;

  /// Open the panel by swiping inward from the right screen edge.
  ///
  /// A transparent strip of width [edgeWidth] (default 20 px) is placed along
  /// the right edge. A right-to-left horizontal drag starting inside that strip
  /// opens the panel.
  const factory EnvTrigger.edgeSwipe({double? edgeWidth}) = _EdgeSwipeTrigger;

  /// Wraps [child] in a gesture-detecting widget that calls [onOpen] when the
  /// configured trigger fires.
  ///
  /// [isActive] should be true when the trigger is actively listening (e.g.
  /// when the panel is closed).
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  });
}

// ── Tap trigger ───────────────────────────────────────────────────────────────

final class _TapTrigger extends EnvTrigger {
  final int count;
  const _TapTrigger({int? count})
      : count = count ?? 7,
        super();

  @override
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  }) {
    return _TapTriggerWidget(
      count: count,
      onOpen: onOpen,
      isActive: isActive,
      child: child,
    );
  }
}

class _TapTriggerWidget extends StatefulWidget {
  final int count;
  final VoidCallback onOpen;
  final bool isActive;
  final Widget child;

  const _TapTriggerWidget({
    required this.count,
    required this.onOpen,
    required this.isActive,
    required this.child,
  });

  @override
  State<_TapTriggerWidget> createState() => _TapTriggerWidgetState();
}

class _TapTriggerWidgetState extends State<_TapTriggerWidget> {
  int _tapCount = 0;
  Timer? _resetTimer;

  void _onTap() {
    if (!widget.isActive) return;

    _tapCount++;
    _resetTimer?.cancel();
    if (_tapCount >= widget.count) {
      _tapCount = 0;
      widget.onOpen();
    } else {
      _resetTimer = Timer(const Duration(milliseconds: 800), () {
        _tapCount = 0;
      });
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _onTap,
      child: widget.child,
    );
  }
}

// ── Shake trigger ─────────────────────────────────────────────────────────────

final class _ShakeTrigger extends EnvTrigger {
  final double threshold;
  const _ShakeTrigger({double? threshold})
      : threshold = threshold ?? 15.0,
        super();

  @override
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  }) {
    return _ShakeTriggerWidget(
      threshold: threshold,
      onOpen: onOpen,
      isActive: isActive,
      child: child,
    );
  }
}

class _ShakeTriggerWidget extends StatefulWidget {
  final double threshold;
  final VoidCallback onOpen;
  final bool isActive;
  final Widget child;

  const _ShakeTriggerWidget({
    required this.threshold,
    required this.onOpen,
    required this.isActive,
    required this.child,
  });

  @override
  State<_ShakeTriggerWidget> createState() => _ShakeTriggerWidgetState();
}

class _ShakeTriggerWidgetState extends State<_ShakeTriggerWidget> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastTrigger;

  @override
  void initState() {
    super.initState();
    _subscription = accelerometerEventStream().listen(_onAccelerometer);
  }

  void _onAccelerometer(AccelerometerEvent event) {
    final double magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (!widget.isActive) return;

    if (magnitude > widget.threshold) {
      final DateTime now = DateTime.now();
      if (_lastTrigger == null ||
          now.difference(_lastTrigger!) > const Duration(seconds: 2)) {
        _lastTrigger = now;
        widget.onOpen();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Edge-swipe trigger ────────────────────────────────────────────────────────

final class _EdgeSwipeTrigger extends EnvTrigger {
  final double edgeWidth;
  const _EdgeSwipeTrigger({double? edgeWidth})
      : edgeWidth = edgeWidth ?? 20.0,
        super();

  @override
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  }) {
    return _EdgeSwipeTriggerWidget(
      edgeWidth: edgeWidth,
      onOpen: onOpen,
      isActive: isActive,
      child: child,
    );
  }
}

class _EdgeSwipeTriggerWidget extends StatefulWidget {
  final double edgeWidth;
  final VoidCallback onOpen;
  final bool isActive;
  final Widget child;

  const _EdgeSwipeTriggerWidget({
    required this.edgeWidth,
    required this.onOpen,
    required this.isActive,
    required this.child,
  });

  @override
  State<_EdgeSwipeTriggerWidget> createState() =>
      _EdgeSwipeTriggerWidgetState();
}

class _EdgeSwipeTriggerWidgetState extends State<_EdgeSwipeTriggerWidget> {
  Offset? _pointerDownPosition;
  bool _startedInEdge = false;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isActive) {
      _startedInEdge = false;
      return;
    }
    _pointerDownPosition = event.localPosition;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    _startedInEdge = event.localPosition.dx >= screenWidth - widget.edgeWidth;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_startedInEdge || _pointerDownPosition == null) return;
    final double dx = event.localPosition.dx - _pointerDownPosition!.dx;
    // Swipe inward = from right edge towards left = negative dx.
    if (dx < -40) {
      _startedInEdge = false; // Prevent repeated triggers.
      widget.onOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      child: widget.child,
    );
  }
}

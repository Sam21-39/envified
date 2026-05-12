import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Interface for custom trigger detectors (e.g. shake, volume buttons).
abstract class EnvTriggerDetector {
  /// Start listening for the trigger.
  void start(double threshold, VoidCallback onTrigger);

  /// Stop listening for the trigger.
  void stop();
}

/// Defines the gesture that opens the [EnvifiedOverlay] debug panel.
sealed class EnvTrigger {
  const EnvTrigger();

  /// Open the panel by tapping any child widget [count] times rapidly.
  const factory EnvTrigger.tap({int? count}) = _TapTrigger;

  /// Open the panel by shaking the device.
  ///
  /// If [detector] is null, a default implementation using `sensors_plus` is used.
  const factory EnvTrigger.shake({
    double? threshold,
    EnvTriggerDetector? detector,
  }) = _ShakeTrigger;

  /// Open the panel by swiping inward from the right screen edge.
  const factory EnvTrigger.edgeSwipe({double? edgeWidth}) = _EdgeSwipeTrigger;

  /// Wraps [child] in a gesture-detecting widget.
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  });
}

// ── Tap trigger ───────────────────────────────────────────────────────────────

final class _TapTrigger extends EnvTrigger {
  final int count;
  const _TapTrigger({int? count}) : count = count ?? 7;

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
  final EnvTriggerDetector? detector;

  const _ShakeTrigger({double? threshold, this.detector})
      : threshold = threshold ?? 15.0;

  @override
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  }) {
    return _ShakeTriggerWidget(
      threshold: threshold,
      detector: detector ?? const _DefaultShakeDetector(),
      onOpen: onOpen,
      isActive: isActive,
      child: child,
    );
  }
}

class _ShakeTriggerWidget extends StatefulWidget {
  final double threshold;
  final EnvTriggerDetector detector;
  final VoidCallback onOpen;
  final bool isActive;
  final Widget child;

  const _ShakeTriggerWidget({
    required this.threshold,
    required this.detector,
    required this.onOpen,
    required this.isActive,
    required this.child,
  });

  @override
  State<_ShakeTriggerWidget> createState() => _ShakeTriggerWidgetState();
}

class _ShakeTriggerWidgetState extends State<_ShakeTriggerWidget> {
  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void didUpdateWidget(_ShakeTriggerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startListening();
      } else {
        widget.detector.stop();
      }
    }
  }

  void _startListening() {
    if (widget.isActive) {
      widget.detector.start(widget.threshold, widget.onOpen);
    }
  }

  @override
  void dispose() {
    widget.detector.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DefaultShakeDetector implements EnvTriggerDetector {
  static StreamSubscription<AccelerometerEvent>? _subscription;
  static DateTime? _lastTrigger;

  const _DefaultShakeDetector();

  @override
  void start(double threshold, VoidCallback onTrigger) {
    _subscription?.cancel();
    _subscription = accelerometerEventStream().listen((event) {
      final double magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (magnitude > threshold) {
        final DateTime now = DateTime.now();
        if (_lastTrigger == null ||
            now.difference(_lastTrigger!) > const Duration(seconds: 2)) {
          _lastTrigger = now;
          onTrigger();
        }
      }
    });
  }

  @override
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}

// ── Edge-swipe trigger ────────────────────────────────────────────────────────

final class _EdgeSwipeTrigger extends EnvTrigger {
  final double edgeWidth;
  const _EdgeSwipeTrigger({double? edgeWidth}) : edgeWidth = edgeWidth ?? 20.0;

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
    if (dx < -40) {
      _startedInEdge = false;
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

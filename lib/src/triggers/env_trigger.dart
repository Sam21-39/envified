import 'dart:async';
import 'package:flutter/material.dart';

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

  /// Trigger by long-pressing the status badge or the overlay area.
  const factory EnvTrigger.longPress({Duration duration}) = LongPressTrigger;

  /// Trigger by double-tapping.
  const factory EnvTrigger.doubleTap() = DoubleTapTrigger;

  /// Wraps [child] in a gesture-detecting widget.
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  });
}

/// Trigger by tapping multiple times.
class TapTrigger extends EnvTrigger {
  /// The number of taps required to trigger.
  final int count;

  const TapTrigger({this.count = 7});

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

/// Trigger by swiping from the edge of the screen.
class EdgeSwipeTrigger extends EnvTrigger {
  /// The width of the edge area that detects swipes.
  final double edgeWidth;

  const EdgeSwipeTrigger({this.edgeWidth = 20});

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

class ShakeTrigger extends EnvTrigger {
  /// The detector implementation.
  final EnvShakeDetector detector;

  /// The G-force threshold required to trigger.
  final double threshold;

  const ShakeTrigger({
    required this.detector,
    this.threshold = 15.0,
  });

  @override
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  }) {
    return _ShakeTriggerWidget(
      detector: detector,
      threshold: threshold,
      onOpen: onOpen,
      isActive: isActive,
      child: child,
    );
  }
}

/// Trigger by long-pressing.
class LongPressTrigger extends EnvTrigger {
  final Duration duration;

  const LongPressTrigger({this.duration = const Duration(milliseconds: 1500)});

  @override
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: isActive ? onOpen : null,
      child: child,
    );
  }
}

/// Trigger by double-tapping.
class DoubleTapTrigger extends EnvTrigger {
  const DoubleTapTrigger();

  @override
  Widget build({
    required Widget child,
    required VoidCallback onOpen,
    bool isActive = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: isActive ? onOpen : null,
      child: child,
    );
  }
}

// ── Internal Trigger Widgets ──────────────────────────────────────────────────

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

class _ShakeTriggerWidget extends StatefulWidget {
  final EnvShakeDetector detector;
  final double threshold;
  final VoidCallback onOpen;
  final bool isActive;
  final Widget child;

  const _ShakeTriggerWidget({
    required this.detector,
    required this.threshold,
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
    if (widget.isActive) {
      widget.detector.start(widget.threshold, widget.onOpen);
    }
  }

  @override
  void didUpdateWidget(_ShakeTriggerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        widget.detector.start(widget.threshold, widget.onOpen);
      } else {
        widget.detector.stop();
      }
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

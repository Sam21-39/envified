import 'package:flutter/material.dart';

import '../env_config_service.dart';
import '../env_gate.dart';
import 'env_debug_panel.dart';
import 'env_trigger.dart';

/// A transparent wrapper widget that optionally injects a floating debug button
/// into the app's [Overlay], allowing [EnvDebugPanel] to be opened at any time.
///
/// The recommended placement is inside the `builder` of your [MaterialApp] so
/// the overlay persists across all routes:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => EnvifiedOverlay(
///     service: EnvConfigService.instance,
///     enabled: kDebugMode,
///     gate: EnvGate(pin: '1234'),
///     trigger: const EnvTrigger.tap(count: 7),
///     child: child ?? const SizedBox.shrink(),
///   ),
///   home: const MyApp(),
/// )
/// ```
///
/// ## Gate (access control)
///
/// When [gate] is non-null, the user must authenticate before the panel opens.
/// Supported methods:
/// - PIN dialog: `EnvGate(pin: '1234')`
/// - Biometric: `EnvGate(biometric: true)`
/// - Either: `EnvGate(pin: '1234', biometric: true)`
///
/// If authentication fails, a `'Authentication failed'` SnackBar is shown.
///
/// ## Trigger (gesture)
///
/// [trigger] controls how the panel is opened. Defaults to 7 rapid taps.
/// Other options: `EnvTrigger.shake()`, `EnvTrigger.edgeSwipe()`.
///
/// ## Auto-lock
///
/// The panel automatically closes (and re-requires authentication) whenever
/// the app is hidden or paused ([AppLifecycleState.hidden] /
/// [AppLifecycleState.paused]).
///
/// When [enabled] is `false` the widget is a transparent pass-through with
/// no runtime overhead.
///
/// @see EnvDebugPanel
/// @see EnvConfigService
/// @see EnvGate
/// @see EnvTrigger
class EnvifiedOverlay extends StatefulWidget {
  /// The [EnvConfigService] instance passed through to [EnvDebugPanel].
  final EnvConfigService service;

  /// The widget tree to render beneath the overlay.
  final Widget child;

  /// When `false`, this widget is a transparent pass-through with no runtime
  /// cost. Pass `kDebugMode` here to automatically disable in production builds.
  final bool enabled;

  /// Optional callback forwarded to [EnvDebugPanel.onApply].
  final VoidCallback? onApply;

  /// Optional access gate that must be passed before the panel is revealed.
  ///
  /// See [EnvGate] for available authentication strategies.
  final EnvGate? gate;

  /// The gesture that opens the debug panel.
  ///
  /// Defaults to 7 rapid taps anywhere on the child widget tree.
  final EnvTrigger trigger;

  /// Creates an [EnvifiedOverlay].
  const EnvifiedOverlay({
    super.key,
    required this.service,
    required this.child,
    this.enabled = true,
    this.onApply,
    this.gate,
    this.trigger = const EnvTrigger.tap(count: 7),
  });

  @override
  State<EnvifiedOverlay> createState() => _EnvifiedOverlayState();
}

class _EnvifiedOverlayState extends State<EnvifiedOverlay> {
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(
      builder: (context) => _OverlayContent(
        service: widget.service,
        appChild: widget.child,
        onApply: widget.onApply,
        gate: widget.gate,
        trigger: widget.trigger,
      ),
    );
  }

  @override
  void didUpdateWidget(EnvifiedOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the MaterialApp rebuilds and provides a new child, re-render.
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    // A dedicated Overlay is critical when used in MaterialApp.builder,
    // because the builder context is above the Navigator's Overlay.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        initialEntries: [_entry],
      ),
    );
  }
}

class _OverlayContent extends StatefulWidget {
  final EnvConfigService service;
  final Widget appChild;
  final VoidCallback? onApply;
  final EnvGate? gate;
  final EnvTrigger trigger;

  const _OverlayContent({
    required this.service,
    required this.appChild,
    this.onApply,
    this.gate,
    required this.trigger,
  });

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  bool _isOpen = false;
  bool _isAuthenticated = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onHide: _closePanel,
      onPause: _closePanel,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _closePanel() {
    if (mounted) {
      setState(() {
        _isOpen = false;
        _isAuthenticated = false; // Re-authenticate on next open.
      });
    }
  }

  Future<void> _requestOpen() async {
    if (_isOpen) {
      _closePanel();
      return;
    }

    final EnvGate? gate = widget.gate;
    if (gate != null && !_isAuthenticated) {
      if (!mounted) return;
      final bool passed = await gate.authenticate(context);
      if (!passed) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Authentication failed'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      _isAuthenticated = true;
    }

    if (mounted) setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.trigger.build(
      onOpen: _requestOpen,
      child: Stack(
        children: [
          widget.appChild,
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closePanel,
                child: Container(color: Colors.black54),
              ),
            ),
          if (_isOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: 80, // Above the FAB
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Theme.of(context).canvasColor,
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.maybeOf(context)?.size.height ?? 800 * 0.7,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: EnvDebugPanel(
                        service: widget.service,
                        onApply: widget.onApply,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 24,
            right: 16,
            child: _EnvFab(
              service: widget.service,
              isOpen: _isOpen,
              onTap: _requestOpen,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvFab extends StatelessWidget {
  final EnvConfigService service;
  final bool isOpen;
  final VoidCallback onTap;

  const _EnvFab({
    required this.service,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: service.current,
      builder: (context, config, _) {
        final bool locked = service.isProdLocked;

        return FloatingActionButton(
          heroTag: 'envified_fab',
          mini: true,
          backgroundColor:
              locked ? Colors.red.shade700 : Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
          tooltip: isOpen ? 'Close Panel' : 'envified — Environment Panel',
          onPressed: onTap,
          child: isOpen
              ? const Icon(Icons.close, size: 18)
              : locked
                  ? const Icon(Icons.lock, size: 18)
                  : const Text('🌿', style: TextStyle(fontSize: 18)),
        );
      },
    );
  }
}

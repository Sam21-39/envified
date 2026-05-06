import 'package:flutter/material.dart';

import '../env_config_service.dart';
import 'env_debug_panel.dart';

/// A transparent wrapper widget that optionally injects a floating debug button
/// into the app's [Overlay], allowing [EnvDebugPanel] to be opened at any time.
///
/// A transparent wrapper widget that injects a floating debug button
/// into the app, allowing [EnvDebugPanel] to be opened at any time.
///
/// ## Usage
///
/// The recommended way to use [EnvifiedOverlay] is inside the `builder`
/// of your [MaterialApp] so it persists across all routes:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => EnvifiedOverlay(
///     service: EnvConfigService.instance,
///     enabled: kDebugMode,
///     child: child ?? const SizedBox.shrink(),
///   ),
///   home: const MyApp(),
/// )
/// ```
///
/// When [enabled] is `false` the widget renders [child] with **zero overhead**.
///
/// When [enabled] is `true` a small 🌿 floating button appears in the
/// bottom-right corner of the screen. Tapping it opens the [EnvDebugPanel].
///
/// @see EnvDebugPanel
/// @see EnvConfigService
class EnvifiedOverlay extends StatefulWidget {
  /// The [EnvConfigService] instance passed through to [EnvDebugPanel].
  final EnvConfigService service;

  /// The widget tree to render beneath the overlay (usually the Navigator from MaterialApp.builder).
  final Widget child;

  /// When `false`, this widget is a transparent pass-through with no runtime
  /// cost. Pass `kDebugMode` here to automatically disable in production builds.
  final bool enabled;

  /// Optional callback forwarded to [EnvDebugPanel.onApply].
  final VoidCallback? onApply;

  /// Creates an [EnvifiedOverlay].
  const EnvifiedOverlay({
    super.key,
    required this.service,
    required this.child,
    this.enabled = true,
    this.onApply,
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
      ),
    );
  }

  @override
  void didUpdateWidget(EnvifiedOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the MaterialApp rebuilds and provides a new child to the builder,
    // we must mark the overlay entry for rebuild to pass down the new child.
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    // We provide a dedicated Overlay. This is critical when used in
    // MaterialApp.builder because the builder context is ABOVE the Navigator
    // and its Overlay. Without this, Tooltips and TextFields in the debug
    // panel will throw "No Overlay widget found".
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

  const _OverlayContent({
    required this.service,
    required this.appChild,
    this.onApply,
  });

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  bool _isOpen = false;

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.appChild,
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
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
            onTap: _toggle,
          ),
        ),
      ],
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

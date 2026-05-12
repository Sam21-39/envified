import 'package:envified/envified.dart';
import 'package:flutter/material.dart';

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

  /// Callback to restart the application.
  final VoidCallback? onRestart;

  /// Optional access gate that must be passed before the panel is revealed.
  ///
  /// See [EnvGate] for available authentication strategies.
  final EnvGate? gate;

  /// The gesture that opens the debug panel.
  ///
  /// Defaults to 7 rapid taps anywhere on the child widget tree.
  final EnvTrigger trigger;

  /// Whether to show the floating 🌿 button in the bottom-right corner.
  ///
  /// Defaults to `true`. Set to `false` to use the [trigger] as the exclusive
  /// way to open the panel (stealth mode).
  final bool showFab;

  /// Whether to display the .env key-value section in the debug panel.
  ///
  /// Defaults to `false` for privacy.
  final bool showEnvKeys;

  /// Whether to display the current-environment label badge.
  ///
  /// Defaults to `true`.
  final bool isShowEnvLabel;

  const EnvifiedOverlay({
    super.key,
    required this.service,
    required this.child,
    this.enabled = true,
    this.onRestart,
    this.gate,
    this.trigger = const EnvTrigger.tap(count: 7),
    this.showFab = true,
    this.showEnvKeys = false,
    this.isShowEnvLabel = true,
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
        onRestart: widget.onRestart,
        gate: widget.gate,
        trigger: widget.trigger,
        showFab: widget.showFab,
        showEnvKeys: widget.showEnvKeys,
        isShowEnvLabel: widget.isShowEnvLabel,
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
  final VoidCallback? onRestart;
  final EnvGate? gate;
  final EnvTrigger trigger;
  final bool showFab;
  final bool showEnvKeys;
  final bool isShowEnvLabel;

  const _OverlayContent({
    required this.service,
    required this.appChild,
    this.onRestart,
    this.gate,
    required this.trigger,
    required this.showFab,
    required this.showEnvKeys,
    required this.isShowEnvLabel,
  });

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent>
    with WidgetsBindingObserver {
  bool _isOpen = false;
  bool _isAuthenticated = false;
  OverlayEntry? _gateEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _closePanel();
    }
  }

  void _closePanel() {
    _hideGate();
    if (mounted) {
      setState(() {
        _isOpen = false;
        _isAuthenticated = false;
      });
    }
  }

  void _hideGate() {
    _gateEntry?.remove();
    _gateEntry = null;
  }

  void _requestOpen() {
    if (_isOpen) {
      _closePanel();
      return;
    }

    final EnvGate? gate = widget.gate;
    if (gate != null && !_isAuthenticated) {
      _showGate();
      return;
    }

    if (mounted) setState(() => _isOpen = true);
  }

  void _showGate() {
    _hideGate(); // Ensure only one exists

    final gate = widget.gate;
    if (gate == null) return;

    final pinController = TextEditingController();
    String? pinError;

    _gateEntry = OverlayEntry(
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setGateState) {
            void verifyPin() {
              if (gate.verify(pinController.text)) {
                _hideGate();
                if (mounted) {
                  setState(() {
                    _isAuthenticated = true;
                    _isOpen = true;
                  });
                }
              } else {
                setGateState(() {
                  pinError = 'Invalid PIN';
                  pinController.clear();
                });
              }
            }

            return Stack(
              children: [
                // Dark Scrim
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closePanel,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                // Centered Dialog
                Scaffold(
                  backgroundColor: Colors.transparent,
                  resizeToAvoidBottomInset: true,
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Material(
                            elevation: 24,
                            borderRadius: BorderRadius.circular(16),
                            color: Theme.of(context).cardColor,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Enter PIN',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: pinController,
                                    obscureText: true,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      letterSpacing: 8,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '••••',
                                      errorText: pinError,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => verifyPin(),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: _closePanel,
                                        child: const Text('CANCEL'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: verifyPin,
                                        child: const Text('VERIFY'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_gateEntry!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideGate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.trigger.build(
      onOpen: _requestOpen,
      isActive: !_isOpen && _gateEntry == null,
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
              child: SafeArea(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Theme.of(context).canvasColor,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            120, // 80 (bottom) + 40 (top margin)
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: EnvDebugPanel(
                          service: widget.service,
                          onRestart: widget.onRestart,
                          showEnvKeys: widget.showEnvKeys,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.isShowEnvLabel) EnvStatusBadge(service: widget.service),
          if (widget.showFab)
            Positioned(
              bottom: 24,
              right: 16,
              child: _EnvFab(
                service: widget.service,
                isOpen: _isOpen || _gateEntry != null,
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

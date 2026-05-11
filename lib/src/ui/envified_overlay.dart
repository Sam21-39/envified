import 'package:envified/envified.dart';
import 'package:flutter/material.dart';

/// A transparent wrapper widget that injects the environment debug panel
/// into the app's [Overlay].
///
/// The recommended placement is inside the `builder` of your [MaterialApp]:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => EnvifiedOverlay(
///     enabled: kDebugMode,
///     gate: EnvGate(pin: '1234'),
///     trigger: const EnvTrigger.tap(count: 7),
///     child: child ?? const SizedBox.shrink(),
///   ),
/// )
/// ```
class EnvifiedOverlay extends StatefulWidget {
  /// The widget tree to render beneath the overlay.
  final Widget child;

  /// When `false`, this widget is a transparent pass-through.
  final bool enabled;

  /// Optional access gate that must be passed before the panel is revealed.
  final EnvGate? gate;

  /// The gesture that opens the debug panel.
  final EnvTrigger trigger;

  /// Whether to show the floating 🌿 button.
  final bool showFab;

  /// Whether to display the .env key-value section in the debug panel.
  ///
  /// Defaults to `false` for privacy.
  final bool showEnvKeys;

  /// Whether to display the current-environment label badge.
  ///
  /// Defaults to `true`.
  final bool isShowEnvLabel;

  /// Callback to restart the application.
  final VoidCallback? onRestart;

  const EnvifiedOverlay({
    required this.child,
    super.key,
    this.enabled = true,
    this.gate,
    this.trigger = const EnvTrigger.tap(),
    this.showFab = true,
    this.showEnvKeys = false,
    this.isShowEnvLabel = true,
    this.onRestart,
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
        appChild: widget.child,
        gate: widget.gate,
        trigger: widget.trigger,
        showFab: widget.showFab,
        showEnvKeys: widget.showEnvKeys,
        isShowEnvLabel: widget.isShowEnvLabel,
        onRestart: widget.onRestart,
      ),
    );
  }

  @override
  void didUpdateWidget(EnvifiedOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        initialEntries: [_entry],
      ),
    );
  }
}

class _OverlayContent extends StatefulWidget {
  final Widget appChild;
  final EnvGate? gate;
  final EnvTrigger trigger;
  final bool showFab;
  final bool showEnvKeys;
  final bool isShowEnvLabel;
  final VoidCallback? onRestart;

  const _OverlayContent({
    required this.appChild,
    required this.trigger,
    required this.showFab,
    required this.showEnvKeys,
    required this.isShowEnvLabel,
    this.gate,
    this.onRestart,
  });

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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

    final gate = widget.gate;
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
                      color: Colors.black.withOpacity(0.88),
                    ),
                  ),
                ),
                // Centered Dialog
                Scaffold(
                  backgroundColor: Colors.transparent,
                  resizeToAvoidBottomInset: true,
                  body: Center(
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
              bottom: 80,
              child: SafeArea(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor,
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: EnvDebugPanel(
                          onRestart: widget.onRestart,
                          showEnvKeys: widget.showEnvKeys,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.isShowEnvLabel) const EnvStatusBadge(),
          if (widget.showFab)
            Positioned(
              bottom: 24,
              right: 16,
              child: _EnvFab(
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
  final bool isOpen;
  final VoidCallback onTap;

  const _EnvFab({
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: EnvConfigService.instance.restartNeeded,
      builder: (context, restartNeeded, _) {
        return FloatingActionButton(
          heroTag: 'envified_fab',
          mini: true,
          backgroundColor:
              restartNeeded ? Colors.orange.shade700 : Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
          onPressed: onTap,
          child: isOpen
              ? const Icon(Icons.close, size: 18)
              : const Text('🌿', style: TextStyle(fontSize: 18)),
        );
      },
    );
  }
}

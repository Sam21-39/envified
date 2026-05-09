import 'package:flutter/material.dart';
import '../gate/env_gate.dart';
import '../service/env_config_service.dart';
import '../triggers/env_trigger.dart';
import 'env_debug_panel.dart';

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

  const EnvifiedOverlay({
    required this.child,
    super.key,
    this.enabled = true,
    this.gate,
    this.trigger = const EnvTrigger.tap(),
    this.showFab = true,
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

  const _OverlayContent({
    required this.appChild,
    required this.trigger,
    required this.showFab,
    this.gate,
  });

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  bool _isOpen = false;
  bool _isAuthenticated = false;

  void _closePanel() {
    if (mounted) {
      setState(() {
        _isOpen = false;
        _isAuthenticated = false;
      });
    }
  }

  Future<void> _requestOpen() async {
    if (_isOpen) {
      _closePanel();
      return;
    }

    final gate = widget.gate;
    if (gate != null && !_isAuthenticated) {
      final bool passed = await _showPinDialog(context, gate);
      if (!passed) return;
      _isAuthenticated = true;
    }

    if (mounted) setState(() => _isOpen = true);
  }

  Future<bool> _showPinDialog(BuildContext context, EnvGate gate) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (gate.verify(controller.text)) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid PIN')),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.trigger.build(
      onOpen: _requestOpen,
      isActive: !_isOpen,
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
                            color: Colors.black // ignore: deprecated_member_use
.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: const SingleChildScrollView(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: EnvDebugPanel(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.showFab)
            Positioned(
              bottom: 24,
              right: 16,
              child: _EnvFab(
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

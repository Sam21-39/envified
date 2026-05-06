import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../env_model.dart';
import '../env_config_service.dart';
import 'env_debug_panel.dart';

/// A highly customizable, draggable floating overlay that wraps your app
/// and provides quick access to the [EnvDebugPanel].
///
/// Best used within the `builder` property of `MaterialApp`.
class EnvifiedOverlay extends StatefulWidget {
  final Widget child;
  final EnvConfigService service;

  /// Whether to show the overlay.
  /// Defaults to true UNLESS the current environment is [Env.prod].
  final bool? enabled;

  /// Optional Navigator key to use for showing the modal bottom sheet.
  /// If you wrap `MaterialApp.builder` with this overlay, you MUST provide this key.
  final GlobalKey<NavigatorState>? navigatorKey;

  const EnvifiedOverlay({
    super.key,
    required this.child,
    required this.service,
    this.enabled,
    this.navigatorKey,
  });

  @override
  State<EnvifiedOverlay> createState() => _EnvifiedOverlayState();
}

class _EnvifiedOverlayState extends State<EnvifiedOverlay> {
  Offset _offset = const Offset(20, kToolbarHeight + 40);

  @override
  void dispose() {
    super.dispose();
  }

  void _showPanel() {
    final navContext = widget.navigatorKey?.currentContext ?? context;
    showModalBottomSheet(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EnvDebugPanel(
          service: widget.service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: widget.service.current,
      builder: (context, config, child) {
        final bool shouldShow = widget.enabled ?? (config.env != Env.prod);

        return Stack(
          textDirection: TextDirection.ltr,
          children: [
            widget.child,
            if (shouldShow)
              Builder(builder: (context) {
                // Ensure the overlay stays within screen bounds dynamically
                final size = MediaQuery.sizeOf(context);
                final dx = _offset.dx.clamp(
                    0.0, (size.width - 56.0).clamp(0.0, double.infinity));
                final dy = _offset.dy.clamp(
                    0.0, (size.height - 56.0).clamp(0.0, double.infinity));

                return Positioned(
                  left: dx,
                  top: dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _offset += details.delta;
                      });
                    },
                    onTap: _showPanel,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      shape: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black87,
                          border: Border.all(color: Colors.white24, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/bug-ant.svg',
                          package: 'envified',
                          colorFilter: const ColorFilter.mode(
                              Colors.greenAccent, BlendMode.srcIn),
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

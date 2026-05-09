import 'package:flutter/material.dart';
import '../models/env.dart';
import '../models/env_config.dart';
import '../service/env_config_service.dart';

/// A persistent, lightweight environment indicator badge.
class EnvStatusBadge extends StatelessWidget {
  /// Where within the screen to anchor the badge.
  final Alignment alignment;

  /// Margin applied to the badge.
  final EdgeInsets margin;

  const EnvStatusBadge({
    super.key,
    this.alignment = Alignment.topRight,
    this.margin = const EdgeInsets.fromLTRB(0, 48, 12, 0),
  });

  Color _colorForEnv(Env env) {
    if (env == Env.prod) return Colors.red.shade800;
    if (env == Env.staging) return Colors.orange.shade700;
    if (env == Env.dev) return Colors.blue.shade700;
    return Colors.blueGrey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: EnvConfigService.instance.current,
      builder: (context, config, _) {
        final label =
            '${config.isBaseUrlOverridden ? '⚡ ' : ''}${config.env.name.toUpperCase()}';
        final color = _colorForEnv(config.env);

        final badge = Align(
          alignment: alignment,
          child: Padding(
            padding: margin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );

        if (config.isBaseUrlOverridden) {
          return _PulsingBadge(child: badge);
        }
        return badge;
      },
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  final Widget child;
  const _PulsingBadge({required this.child});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

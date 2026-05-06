import 'package:flutter/material.dart';

import '../env_config_service.dart';
import '../env_model.dart';

/// A persistent, lightweight environment indicator badge.
///
/// Display [EnvStatusBadge] in your widget tree (typically in a [Stack]
/// above your main content) to provide a constant visual reminder of the
/// active environment. It reacts to [EnvConfigService.current] changes
/// without requiring any manual state management.
///
/// When [EnvConfig.isBaseUrlOverridden] is `true`, a ⚡ prefix is added and
/// the badge pulses gently (opacity 1.0 ↔ 0.7, 1.5 s period) to draw
/// attention to the custom URL. The animation respects the user's
/// `prefers-reduced-motion` system setting via `MediaQuery.of(context).disableAnimations`.
///
/// ## Colour mapping
///
/// | Environment | Badge colour               |
/// |-------------|----------------------------|
/// | dev         | `Colors.blue.shade700`     |
/// | staging     | `Colors.orange.shade700`   |
/// | prod        | `Colors.red.shade800`      |
/// | custom      | `Colors.purple.shade700`   |
///
/// ## Usage
///
/// ```dart
/// Stack(
///   children: [
///     MyApp(),
///     if (kDebugMode)
///       EnvStatusBadge(service: EnvConfigService.instance),
///   ],
/// )
/// ```
class EnvStatusBadge extends StatelessWidget {
  /// The service whose [EnvConfig] drives this badge.
  final EnvConfigService service;

  /// Where within the screen to anchor the badge.
  ///
  /// Defaults to [Alignment.topRight].
  final Alignment alignment;

  /// Margin applied to the badge when positioned using [Align].
  ///
  /// Defaults to `EdgeInsets.fromLTRB(0, 48, 12, 0)` which places the badge
  /// below the status bar on the right-hand side.
  final EdgeInsets margin;

  /// Creates an [EnvStatusBadge].
  const EnvStatusBadge({
    super.key,
    required this.service,
    this.alignment = Alignment.topRight,
    this.margin = const EdgeInsets.fromLTRB(0, 48, 12, 0),
  });

  Color _colorForEnv(Env env) {
    switch (env) {
      case Env.dev:
        return Colors.blue.shade700;
      case Env.staging:
        return Colors.orange.shade700;
      case Env.prod:
        return Colors.red.shade800;
      case Env.custom:
        return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: service.current,
      builder: (BuildContext ctx, EnvConfig config, Widget? _) {
        final String label =
            '${config.isBaseUrlOverridden ? '⚡ ' : ''}${config.env.name.toUpperCase()}';
        final Color bg = _colorForEnv(config.env);

        final Widget badge = Align(
          alignment: alignment,
          child: Padding(
            padding: margin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
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
          // Respect the user's reduced-motion preference.
          final bool reduceMotion =
              MediaQuery.maybeOf(ctx)?.disableAnimations ?? false;
          if (reduceMotion) return badge;
          return _PulsingBadge(child: badge);
        }

        return badge;
      },
    );
  }
}

/// Internal widget that animates the badge opacity (1.0 ↔ 0.7, 1.5 s loop).
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

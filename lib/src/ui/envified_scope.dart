import 'package:flutter/material.dart';
import '../models/env.dart';
import '../service/env_config_service.dart';

/// A widget that injects the current [EnvConfig] into the widget tree
/// and automatically rebuilds when the environment changes.
///
/// Usage:
/// ```dart
/// EnvifiedScope(
///   service: EnvConfigService.instance,
///   builder: (context, config) {
///     return MaterialApp(...);
///   }
/// )
/// ```
class EnvifiedScope extends StatelessWidget {
  final EnvConfigService service;
  final Widget Function(BuildContext context, EnvConfig config) builder;

  const EnvifiedScope({
    super.key,
    required this.service,
    required this.builder,
  });

  /// Allows descendants to read the current config directly.
  static EnvConfig of(BuildContext context) {
    return EnvConfigService.instance.current.value;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: service.current,
      builder: (context, config, _) {
        return builder(context, config);
      },
    );
  }
}

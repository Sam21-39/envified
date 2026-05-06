import 'package:flutter/foundation.dart';

/// Represents the target deployment environment.
///
/// Each value corresponds to a matching `.env.*` asset file:
/// - [dev]     → `.env.dev`
/// - [staging] → `.env.staging`
/// - [prod]    → `.env.prod`
/// - [custom]  → no dedicated file; uses the shared `.env` fallback plus a
///               custom base URL stored via [EnvConfigService.setBaseUrl].
///
/// @see EnvConfigService
/// @see EnvConfig
enum Env {
  /// Development environment. Maps to `.env.dev`.
  dev,

  /// Staging / QA environment. Maps to `.env.staging`.
  staging,

  /// Production environment. Maps to `.env.prod`.
  ///
  /// When `allowProdSwitch` is `false`, switching away from this environment
  /// or overriding the base URL will throw [EnvifiedLockException].
  prod,

  /// Custom environment. Uses the shared `.env` fallback file values.
  ///
  /// Intended for developer-defined configurations supplied entirely via
  /// [EnvConfigService.setBaseUrl] at runtime.
  custom,
}

/// Extension helpers on [Env] for asset path resolution and display labels.
extension EnvX on Env {
  /// Returns the asset path of the `.env` file for this environment.
  ///
  /// Returns `null` for [Env.custom] because no dedicated file exists.
  String? get assetPath {
    switch (this) {
      case Env.dev:
        return '.env.dev';
      case Env.staging:
        return '.env.staging';
      case Env.prod:
        return '.env.prod';
      case Env.custom:
        return null;
    }
  }

  /// Short display label used in the [EnvDebugPanel] chip row.
  String get label {
    switch (this) {
      case Env.dev:
        return 'Dev';
      case Env.staging:
        return 'Staging';
      case Env.prod:
        return 'Prod';
      case Env.custom:
        return 'Custom';
    }
  }

  /// Parses an [Env] from its [name] string, returning [fallback] if not found.
  static Env fromName(String name, {Env fallback = Env.dev}) {
    return Env.values.firstWhere(
      (e) => e.name == name,
      orElse: () => fallback,
    );
  }
}

/// Extension providing a human-readable long-form label for [Env].
///
/// Intended for display in audit logs, status badges, and other places
/// where the short [EnvX.label] is not descriptive enough.
///
/// Example:
/// ```dart
/// print(Env.dev.longLabel);     // "Development"
/// print(Env.staging.longLabel); // "Staging"
/// print(Env.prod.longLabel);    // "Production"
/// print(Env.custom.longLabel);  // "Custom"
/// ```
extension EnvName on Env {
  /// Returns the full human-readable environment name.
  String get longLabel => switch (this) {
        Env.dev => 'Development',
        Env.staging => 'Staging',
        Env.prod => 'Production',
        Env.custom => 'Custom',
      };
}

/// An immutable snapshot of the active environment configuration.
///
/// Holds the resolved key-value map from the active `.env*` file, the
/// current base URL (which may be overridden), and metadata about the
/// override state.
///
/// Instances are exposed through [EnvConfigService.current] as a
/// [ValueNotifier], so widgets can `listen` for changes without polling.
///
/// Example:
/// ```dart
/// final config = EnvConfigService.instance.current.value;
/// print(config.env.label);         // "DEV"
/// print(config.baseUrl);           // "https://dev.api.myapp.com"
/// print(config.isBaseUrlOverridden); // false
/// print(config.values['TIMEOUT']); // "30"
/// ```
///
/// @see EnvConfigService
/// @see Env
@immutable
class EnvConfig {
  /// The active [Env] variant.
  final Env env;

  /// The resolved base URL for outbound HTTP requests.
  ///
  /// Defaults to the value of the `BASE_URL` key in the active `.env*` file.
  /// Can be overridden at runtime via [EnvConfigService.setBaseUrl].
  final String baseUrl;

  /// The full merged key-value map from the active `.env*` file.
  ///
  /// Values from the specific env file take precedence over values from the
  /// shared `.env` fallback file.
  final Map<String, String> values;

  /// Whether [baseUrl] was set manually via [EnvConfigService.setBaseUrl].
  ///
  /// When `true`, [baseUrl] may differ from the `BASE_URL` entry in [values].
  final bool isBaseUrlOverridden;

  /// Creates an [EnvConfig].
  ///
  /// All fields are required and immutable after construction.
  const EnvConfig({
    required this.env,
    required this.baseUrl,
    required this.values,
    this.isBaseUrlOverridden = false,
  });

  /// Returns a copy of this [EnvConfig] with the specified fields replaced.
  ///
  /// Only the fields you pass are changed; all others retain their current
  /// values.
  ///
  /// Example:
  /// ```dart
  /// final updated = config.copyWith(baseUrl: 'https://custom.api.com');
  /// ```
  EnvConfig copyWith({
    Env? env,
    String? baseUrl,
    Map<String, String>? values,
    bool? isBaseUrlOverridden,
  }) {
    return EnvConfig(
      env: env ?? this.env,
      baseUrl: baseUrl ?? this.baseUrl,
      values: values ?? this.values,
      isBaseUrlOverridden: isBaseUrlOverridden ?? this.isBaseUrlOverridden,
    );
  }

  /// Serialises this [EnvConfig] to a JSON-compatible map.
  ///
  /// Useful for debugging or logging.
  Map<String, Object> toJson() {
    return {
      'env': env.name,
      'baseUrl': baseUrl,
      'values': values,
      'isBaseUrlOverridden': isBaseUrlOverridden,
    };
  }

  /// Deserialises an [EnvConfig] from a JSON-compatible [map].
  ///
  /// Used internally to restore persisted state.
  factory EnvConfig.fromJson(Map<String, dynamic> map) {
    return EnvConfig(
      env: EnvX.fromName(map['env'] as String? ?? Env.dev.name),
      baseUrl: map['baseUrl'] as String? ?? '',
      values: Map<String, String>.from(
        (map['values'] as Map<Object?, Object?>?) ?? <String, String>{},
      ),
      isBaseUrlOverridden: map['isBaseUrlOverridden'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnvConfig &&
        other.env == env &&
        other.baseUrl == baseUrl &&
        mapEquals(other.values, values) &&
        other.isBaseUrlOverridden == isBaseUrlOverridden;
  }

  @override
  int get hashCode => Object.hash(env, baseUrl, values, isBaseUrlOverridden);

  @override
  String toString() => 'EnvConfig(env: ${env.name}, baseUrl: $baseUrl, '
      'isBaseUrlOverridden: $isBaseUrlOverridden, '
      'valueCount: ${values.length})';
}

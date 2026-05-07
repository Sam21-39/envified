import 'package:flutter/foundation.dart';

/// Represents a deployment environment.
///
/// Environments are discovered at runtime from `.env.*` files.
/// The environment name is derived from the file extension.
///
/// Example:
/// - `.env.dev`     → [name: 'dev', label: 'Dev']
/// - `.env.future`  → [name: 'future', label: 'Future']
/// - `.env`         → [name: 'prod', label: 'Production', isProduction: true]
@immutable
class Env {
  /// The internal identifier (lowercase).
  final String name;

  /// The human-readable label.
  final String label;

  /// The exact filename in assets.
  final String assetFileName;

  /// Whether this environment represents production.
  ///
  /// Integrity checks and production locks are enforced only when this is true.
  final bool isProduction;

  /// Creates an [Env].
  const Env({
    required this.name,
    required this.label,
    required this.assetFileName,
    this.isProduction = false,
  });

  /// Standard development environment.
  static const dev = Env(
    name: 'dev',
    label: 'Dev',
    assetFileName: '.env.dev',
  );

  /// Standard staging environment.
  static const staging = Env(
    name: 'staging',
    label: 'Staging',
    assetFileName: '.env.staging',
  );

  /// Standard production environment.
  static const prod = Env(
    name: 'prod',
    label: 'Production',
    assetFileName: '.env.prod',
    isProduction: true,
  );

  /// Create an [Env] from a filename.
  factory Env.fromFileName(String fileName) {
    // Strip leading path if present
    final name = fileName.split('/').last;

    if (name == '.env') {
      return prod.copyWith(assetFileName: name);
    }

    final extension = name.startsWith('.env.') ? name.substring(5) : name;
    final cleanName = extension.toLowerCase();

    // Match Production aliases
    if (cleanName == 'prod' || cleanName == 'production') {
      return prod.copyWith(assetFileName: name, name: cleanName);
    }

    // Match Staging aliases
    if (cleanName == 'stag' || cleanName == 'staging') {
      return staging.copyWith(assetFileName: name, name: cleanName);
    }

    // Match Dev aliases
    if (cleanName == 'dev' || cleanName == 'development') {
      return dev.copyWith(assetFileName: name, name: cleanName);
    }

    return Env(
      name: cleanName,
      label: cleanName[0].toUpperCase() + cleanName.substring(1),
      assetFileName: name,
      isProduction: false,
    );
  }

  /// Returns a copy of this [Env] with specific fields replaced.
  Env copyWith({
    String? name,
    String? label,
    String? assetFileName,
    bool? isProduction,
  }) {
    return Env(
      name: name ?? this.name,
      label: label ?? this.label,
      assetFileName: assetFileName ?? this.assetFileName,
      isProduction: isProduction ?? this.isProduction,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Env &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          assetFileName == other.assetFileName;

  @override
  int get hashCode => name.hashCode ^ assetFileName.hashCode;

  @override
  String toString() => 'Env(name: $name, isProduction: $isProduction)';
}

/// An immutable snapshot of the active environment configuration.
@immutable
class EnvConfig {
  /// The active [Env].
  final Env env;

  /// The resolved base URL for outbound HTTP requests.
  final String baseUrl;

  /// The full merged key-value map from the active `.env*` file.
  final Map<String, String> values;

  /// Whether [baseUrl] was set manually via [EnvConfigService.setBaseUrl].
  final bool isBaseUrlOverridden;

  /// Creates an [EnvConfig].
  const EnvConfig({
    required this.env,
    required this.baseUrl,
    required this.values,
    this.isBaseUrlOverridden = false,
  });

  /// Returns a copy of this [EnvConfig] with the specified fields replaced.
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

  /// Keys that are considered sensitive and should be blurred by default.
  static const List<String> _sensitiveKeys = [
    'API_KEY',
    'SECRET_KEY',
    'TOKEN',
    'PASSWORD',
    'PRIVATE_KEY',
    'AUTH_TOKEN',
    'JWT',
    'OAUTH_SECRET',
  ];

  /// Check if a key contains sensitive data.
  static bool isSensitiveKey(String key) {
    final upper = key.toUpperCase();
    return _sensitiveKeys.any((sensitive) => upper.contains(sensitive));
  }

  /// Serialises this [EnvConfig] to a JSON-compatible map.
  Map<String, Object> toJson() {
    return {
      'env': env.name,
      'assetFileName': env.assetFileName,
      'isProduction': env.isProduction,
      'label': env.label,
      'baseUrl': baseUrl,
      'values': values,
      'isBaseUrlOverridden': isBaseUrlOverridden,
    };
  }

  /// Deserialises an [EnvConfig] from a JSON-compatible [map].
  factory EnvConfig.fromJson(Map<String, dynamic> map) {
    final envName = map['env'] as String? ?? 'dev';
    final assetFileName = map['assetFileName'] as String? ?? '.env.$envName';

    return EnvConfig(
      env: Env(
        name: envName,
        label: map['label'] as String? ?? envName,
        assetFileName: assetFileName,
        isProduction: map['isProduction'] as bool? ?? false,
      ),
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

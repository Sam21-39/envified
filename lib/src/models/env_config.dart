import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'env.dart';

/// An immutable snapshot of the active environment configuration.
@immutable
class EnvConfig {
  /// The active environment.
  final Env env;

  /// The active base URL (e.g., for API calls).
  final String baseUrl;

  /// All key-value pairs loaded from the .env file.
  final Map<String, String> values;

  /// The timestamp when this configuration was loaded.
  final DateTime loadedAt;

  /// Returns true if the [baseUrl] differs from the one in [values].
  bool get isBaseUrlOverridden => values['BASE_URL'] != baseUrl;

  EnvConfig({
    required this.env,
    required this.baseUrl,
    required Map<String, String> values,
    required this.loadedAt,
  }) : values = values is UnmodifiableMapView<String, String>
            ? values
            : UnmodifiableMapView(values);

  /// Creates a copy of this [EnvConfig] with updated fields.
  EnvConfig copyWith({
    Env? env,
    String? baseUrl,
    Map<String, String>? values,
  }) =>
      EnvConfig(
        env: env ?? this.env,
        baseUrl: baseUrl ?? this.baseUrl,
        values: values ?? this.values,
        loadedAt: loadedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvConfig &&
          runtimeType == other.runtimeType &&
          env == other.env &&
          baseUrl == other.baseUrl &&
          mapEquals(values, other.values);

  @override
  int get hashCode =>
      env.hashCode ^
      baseUrl.hashCode ^
      Object.hashAll(values.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => 'EnvConfig(env: ${env.name}, baseUrl: $baseUrl)';
}

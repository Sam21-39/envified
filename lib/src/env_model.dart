/// The available runtime environments.
enum Env { dev, staging, prod, custom }

/// Immutable value object representing the active environment config.
///
/// ```dart
/// const config = EnvConfig(env: Env.dev, baseUrl: 'https://dev.api.com');
/// ```
class EnvConfig {
  /// The active environment slot.
  final Env env;

  /// The base URL in use for this config.
  final String baseUrl;

  /// Optional key-value extras (feature flags, timeouts, etc.).
  final Map<String, String> extras;

  const EnvConfig({
    required this.env,
    required this.baseUrl,
    this.extras = const {},
  });

  /// Returns a copy with selected fields replaced.
  EnvConfig copyWith({
    Env? env,
    String? baseUrl,
    Map<String, String>? extras,
  }) =>
      EnvConfig(
        env: env ?? this.env,
        baseUrl: baseUrl ?? this.baseUrl,
        extras: extras ?? this.extras,
      );

  /// Serialises to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'env': env.name,
        'baseUrl': baseUrl,
        'extras': extras,
      };

  /// Deserialises from persisted JSON.
  factory EnvConfig.fromJson(Map<String, dynamic> json) => EnvConfig(
        env: Env.values.byName(json['env'] as String),
        baseUrl: json['baseUrl'] as String,
        extras: Map<String, String>.from(json['extras'] as Map),
      );

  @override
  String toString() => 'EnvConfig(env: ${env.name}, baseUrl: $baseUrl)';

  @override
  bool operator ==(Object other) =>
      other is EnvConfig && other.env == env && other.baseUrl == baseUrl;

  @override
  int get hashCode => Object.hash(env, baseUrl);
}

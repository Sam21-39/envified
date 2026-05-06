/// The available runtime environments.
enum Env { dev, staging, prod, custom }

/// Immutable value object representing the active environment configuration.
///
/// Holds the active environment, its base URL, and the fully resolved set of
/// environment variables for that environment (global vars merged with
/// per-environment overrides, where per-env values take priority).
///
/// ```dart
/// const config = EnvConfig(
///   env: Env.dev,
///   baseUrl: 'https://dev.api.com',
///   vars: {'LOG_LEVEL': 'verbose'},
/// );
/// ```
class EnvConfig {
  /// The active environment slot.
  final Env env;

  /// The base URL in use for this config.
  final String baseUrl;

  /// The fully resolved environment variables for this config.
  /// This is a merge of global `vars` and the per-env `varsByEnv` override,
  /// where per-env values take priority.
  final Map<String, String> vars;

  const EnvConfig({
    required this.env,
    required this.baseUrl,
    this.vars = const {},
  });

  /// Returns a copy with selected fields replaced.
  EnvConfig copyWith({
    Env? env,
    String? baseUrl,
    Map<String, String>? vars,
  }) =>
      EnvConfig(
        env: env ?? this.env,
        baseUrl: baseUrl ?? this.baseUrl,
        vars: vars ?? this.vars,
      );

  /// Serialises to JSON for persistence.
  /// Note: only `env` and `baseUrl` are persisted. `vars` are always
  /// resolved from the in-memory definitions on startup for security.
  Map<String, dynamic> toJson() => {
        'env': env.name,
        'baseUrl': baseUrl,
      };

  /// Deserialises from persisted JSON.
  factory EnvConfig.fromJson(Map<String, dynamic> json) => EnvConfig(
        env: Env.values.byName(json['env'] as String),
        baseUrl: json['baseUrl'] as String,
        // vars are not persisted - they are always resolved at runtime
      );

  @override
  String toString() =>
      'EnvConfig(env: ${env.name}, baseUrl: $baseUrl, vars: $vars)';

  @override
  bool operator ==(Object other) =>
      other is EnvConfig && other.env == env && other.baseUrl == baseUrl;

  @override
  int get hashCode => Object.hash(env, baseUrl);
}

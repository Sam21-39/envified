import 'package:flutter/foundation.dart';
import 'env_model.dart';
import 'env_storage.dart';

/// Singleton service for managing runtime environment switching and secure
/// access to compile-time environment variables.
///
/// ## Setup - call once in `main()` before `runApp()`:
///
/// ```dart
/// // 1. Read your compile-time secrets (injected via --dart-define or
/// //    --dart-define-from-file). These are baked into the binary at build
/// //    time and are NEVER stored in a file on disk.
/// const apiKey = String.fromEnvironment('API_KEY');
/// const sentryDsn = String.fromEnvironment('SENTRY_DSN');
///
/// await EnvConfigService.instance.init(
///   urls: {
///     Env.dev:     'https://dev.api.example.com',
///     Env.staging: 'https://staging.api.example.com',
///     Env.prod:    'https://api.example.com',
///   },
///   // Global vars available across ALL environments
///   vars: {
///     'API_KEY': apiKey,
///     'SENTRY_DSN': sentryDsn,
///   },
///   // Per-environment overrides (merged on top of global vars)
///   varsByEnv: {
///     Env.dev:     {'LOG_LEVEL': 'verbose', 'FEATURE_X': 'true'},
///     Env.staging: {'LOG_LEVEL': 'info',    'FEATURE_X': 'true'},
///     Env.prod:    {'LOG_LEVEL': 'error',   'FEATURE_X': 'false'},
///   },
/// );
/// runApp(const MyApp());
/// ```
///
/// ## Reading values anywhere in your app:
///
/// ```dart
/// // Throws StateError if key is missing (use for required values)
/// final apiKey = EnvConfigService.instance.get('API_KEY');
///
/// // Returns null if key is missing (use for optional values)
/// final flag = EnvConfigService.instance.maybeGet('FEATURE_X');
/// ```
///
/// ## Reacting to environment changes:
///
/// ```dart
/// EnvConfigService.instance.current.addListener(() {
///   final config = EnvConfigService.instance.current.value;
///   _dio.options.baseUrl = config.baseUrl;
///   print('LOG_LEVEL is now: ${config.vars['LOG_LEVEL']}');
/// });
/// ```
class EnvConfigService {
  EnvConfigService._();

  /// The global singleton instance.
  static final instance = EnvConfigService._();

  final _storage = EnvStorage();
  Map<Env, String> _urls = {};

  // Global vars available across all environments (compile-time constants).
  Map<String, String> _globalVars = {};

  // Per-environment variable overrides. Merged on top of _globalVars.
  Map<Env, Map<String, String>> _varsByEnv = {};

  /// The currently active [EnvConfig]. Subscribe with [ValueNotifier.addListener]
  /// or wrap your widget in [EnvifiedScope] / [ValueListenableBuilder] to
  /// rebuild on change.
  final ValueNotifier<EnvConfig> current = ValueNotifier(
    const EnvConfig(env: Env.dev, baseUrl: ''),
  );

  /// Resolves the merged variable map for the given [env].
  /// Per-env values take priority over global vars.
  /// BASE_URL is always injected automatically from the resolved baseUrl.
  Map<String, String> _resolveVars(Env env, String baseUrl) {
    return {
      ..._globalVars,
      ...(_varsByEnv[env] ?? {}),
      // BASE_URL is always kept in sync with the active baseUrl.
      // This ensures get('BASE_URL') always matches current.value.baseUrl.
      'BASE_URL': baseUrl,
    };
  }

  /// Initializes the service. Must be awaited before [runApp].
  ///
  /// - [urls]: Base URLs per environment (required).
  /// - [vars]: Global compile-time variables available in all environments.
  ///   Pass values read from `String.fromEnvironment(...)`. These are held
  ///   in memory only and are never written to disk.
  /// - [varsByEnv]: Per-environment variable overrides. Merged on top of
  ///   [vars] when an environment is active. Per-env values take priority.
  /// - [defaultEnv]: The fallback environment if nothing was previously saved.
  ///
  /// Restores the last persisted environment selection automatically.
  Future<void> init({
    required Map<Env, String> urls,
    Env defaultEnv = Env.dev,
    Map<String, String> vars = const {},
    Map<Env, Map<String, String>> varsByEnv = const {},
  }) async {
    _urls = urls;
    _globalVars = vars;
    _varsByEnv = varsByEnv;

    final saved = await _storage.load();
    final env = saved?.env ?? defaultEnv;
    final baseUrl = saved?.baseUrl ?? urls[env] ?? '';

    current.value = EnvConfig(
      env: env,
      baseUrl: baseUrl,
      vars: _resolveVars(env, baseUrl),
    );
  }

  /// Switches to a preset [Env] slot. Persists the selection automatically.
  /// The resolved [EnvConfig.vars] will be updated to match the new environment.
  /// [EnvConfig.vars] will always contain an up-to-date `BASE_URL` key.
  Future<void> switchTo(Env env) async {
    final baseUrl = _urls[env] ?? current.value.baseUrl;
    final config = EnvConfig(
      env: env,
      baseUrl: baseUrl,
      vars: _resolveVars(env, baseUrl),
    );
    current.value = config;
    await _storage.save(config);
  }

  /// Sets a fully custom URL. Sets the env to [Env.custom].
  /// The `BASE_URL` var is automatically updated to reflect the new URL.
  /// Variables are resolved using [Env.custom]'s override map merged with
  /// global vars.
  Future<void> setCustomUrl(String url) async {
    final config = EnvConfig(
      env: Env.custom,
      baseUrl: url,
      vars: _resolveVars(Env.custom, url),
    );
    current.value = config;
    await _storage.save(config);
  }

  /// Returns the value for [key] from the currently active environment's
  /// resolved variable map.
  ///
  /// Throws a [StateError] if the key does not exist. Use this for required
  /// values so that missing configuration fails loudly at startup.
  ///
  /// ```dart
  /// final apiKey = EnvConfigService.instance.get('API_KEY');
  /// ```
  String get(String key) {
    final value = current.value.vars[key];
    if (value == null) {
      throw StateError(
        'EnvConfigService: key "$key" not found in the current environment '
        '(${current.value.env.name}). '
        'Make sure it is defined in `vars` or `varsByEnv` during init().',
      );
    }
    return value;
  }

  /// Returns the value for [key] from the currently active environment's
  /// resolved variable map, or `null` if it does not exist.
  ///
  /// Use this for optional configuration values.
  ///
  /// ```dart
  /// final flag = EnvConfigService.instance.maybeGet('FEATURE_X');
  /// if (flag == 'true') { ... }
  /// ```
  String? maybeGet(String key) => current.value.vars[key];

  /// Clears persisted config and resets to [Env.dev] with default vars.
  Future<void> reset() async {
    await _storage.clear();
    final baseUrl = _urls[Env.dev] ?? '';
    current.value = EnvConfig(
      env: Env.dev,
      baseUrl: baseUrl,
      vars: _resolveVars(Env.dev, baseUrl),
    );
  }
}

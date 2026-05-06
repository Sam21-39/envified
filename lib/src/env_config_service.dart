import 'package:flutter/foundation.dart';
import 'env_model.dart';
import 'env_storage.dart';

/// Singleton service for managing runtime environment switching.
///
/// ## Setup - call once in `main()` before `runApp()`:
///
/// ```dart
/// await EnvConfigService.instance.init(
///   urls: {
///     Env.dev:     'https://dev.api.appamania.in',
///     Env.staging: 'https://staging.api.appamania.in',
///     Env.prod:    'https://api.appamania.in',
///   },
/// );
/// runApp(const MyApp());
/// ```
///
/// ## Reading the current URL anywhere in your app:
///
/// ```dart
/// final url = EnvConfigService.instance.current.value.baseUrl;
/// ```
///
/// ## Reacting to changes (e.g. in an API client):
///
/// ```dart
/// EnvConfigService.instance.current.addListener(() {
///   _dio.options.baseUrl = EnvConfigService.instance.current.value.baseUrl;
/// });
/// ```
class EnvConfigService {
  EnvConfigService._();

  /// The global singleton instance.
  static final instance = EnvConfigService._();

  final _storage = EnvStorage();
  Map<Env, String> _urls = {};

  /// The currently active [EnvConfig]. Subscribe with [ValueNotifier.addListener]
  /// or wrap your widget in [ValueListenableBuilder] to rebuild on change.
  final ValueNotifier<EnvConfig> current = ValueNotifier(
    const EnvConfig(env: Env.dev, baseUrl: ''),
  );

  /// Initializes the service. Must be awaited before [runApp].
  ///
  /// Restores the last persisted config automatically.
  /// Falls back to [defaultEnv] (default: [Env.dev]) if nothing is saved.
  Future<void> init({
    required Map<Env, String> urls,
    Env defaultEnv = Env.dev,
  }) async {
    _urls = urls;
    final saved = await _storage.load();
    current.value = saved ??
        EnvConfig(
          env: defaultEnv,
          baseUrl: urls[defaultEnv] ?? '',
        );
  }

  /// Switches to a preset [Env] slot. Persists the change automatically.
  Future<void> switchTo(Env env) async {
    final config = EnvConfig(
      env: env,
      baseUrl: _urls[env] ?? current.value.baseUrl,
    );
    current.value = config;
    await _storage.save(config);
  }

  /// Sets a fully custom URL. Sets the env to [Env.custom].
  Future<void> setCustomUrl(String url) async {
    final config = current.value.copyWith(
      env: Env.custom,
      baseUrl: url,
    );
    current.value = config;
    await _storage.save(config);
  }

  /// Clears persisted config and resets to [Env.dev].
  Future<void> reset() async {
    await _storage.clear();
    current.value = EnvConfig(
      env: Env.dev,
      baseUrl: _urls[Env.dev] ?? '',
    );
  }
}

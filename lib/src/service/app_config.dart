import 'package:flutter/foundation.dart';

import '../models/env.dart';
import 'env_config_service.dart';

/// Thin facade over [EnvConfigService] providing the canonical `AppConfig`
/// access pattern used across Appamania projects.
///
/// All methods delegate to [EnvConfigService.instance].
///
/// ```dart
/// await AppConfig.init(defaultEnv: Env.dev);
/// final url = AppConfig.get('BASE_URL');
/// ```
class AppConfig {
  AppConfig._();

  /// Initialises the underlying [EnvConfigService].
  static Future<void> init({
    Env? defaultEnv,
    bool persistSelection = true,
    bool allowProdSwitch = false,
    Map<Env, String>? urls,
    Set<Env>? productionEnvs,
    Future<void> Function(Env from, Env to)? onBeforeSwitch,
    void Function(EnvConfig config)? onAfterSwitch,
    List<String>? allowedUrls,
  }) {
    return EnvConfigService.instance.init(
      defaultEnv: defaultEnv,
      persistSelection: persistSelection,
      allowProdSwitch: allowProdSwitch,
      urls: urls,
      productionEnvs: productionEnvs,
      onBeforeSwitch: onBeforeSwitch,
      onAfterSwitch: onAfterSwitch,
      allowedUrls: allowedUrls,
    );
  }

  /// Returns the value for [key] from the active environment config.
  static String get(String key, {String fallback = ''}) =>
      EnvConfigService.instance.get(key, fallback: fallback);

  static bool getBool(String key, {bool fallback = false}) =>
      EnvConfigService.instance.getBool(key, fallback: fallback);

  static int getInt(String key, {int fallback = 0}) =>
      EnvConfigService.instance.getInt(key, fallback: fallback);

  static double getDouble(String key, {double fallback = 0.0}) =>
      EnvConfigService.instance.getDouble(key, fallback: fallback);

  static Uri? getUri(String key) => EnvConfigService.instance.getUri(key);

  static List<String> getList(String key, {String separator = ','}) =>
      EnvConfigService.instance.getList(key, separator: separator);

  /// Reactive accessor — rebuilds widgets when the active config changes.
  static ValueNotifier<EnvConfig> get configNotifier =>
      EnvConfigService.instance.current;

  /// The active [EnvConfig] snapshot.
  static EnvConfig get config => EnvConfigService.instance.current.value;

  /// The active base URL.
  static String get baseUrl => config.baseUrl;
}

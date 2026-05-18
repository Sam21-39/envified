import 'package:envified_example/core/config/app_env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'secrets.g.dart';

class AppConfig {
  AppConfig._();

  /// Bootstraps configurations. Must be called in `main.dart` before `runApp()`.
  static Future<void> init(AppEnvironment env,
      {AssetBundle? customBundle}) async {
    await AppEnv.instance.initialize(env, customBundle: customBundle);
    _validateMandatorySecrets();
  }

  /// Safety checks on startup.
  static void _validateMandatorySecrets() {
    final mandatoryKeys = [
      'ENCRYPTION_KEY',
      'BASIC_AUTH_PASSWORD',
      'APP_AUTH_KEY',
      'API_SECRET'
    ];

    for (final key in mandatoryKeys) {
      if (!AppSecrets.contains(key)) {
        throw StateError(
            'CRITICAL: Required build secret "$key" is missing! Rebuild application with proper secrets.');
      }
    }
  }

  /// Unified accessor. Checks runtime configurations first and falls back to build secrets.
  static String get(String key) {
    final runtimeMap = AppEnv.instance.config.rawPairs;
    if (runtimeMap.containsKey(key)) {
      return runtimeMap[key]!;
    }
    return AppSecrets.get(key);
  }

  // --- Secret accessors delegated to AppSecrets ---
  static String get encryptionKey => AppSecrets.encryptionKey;
  static String get basicAuthPassword => AppSecrets.basicAuthPassword;
  static String get appAuthKey => AppSecrets.appAuthKey;
  static String get apiSecret => AppSecrets.apiSecret;

  static AppEnvironment get environment => AppEnv.instance.config.environment;
  static String get environmentName => AppEnv.instance.config.environmentName;
  static String get baseUrl => AppEnv.instance.config.baseUrl;

  static bool isFeatureEnabled(String flagName) {
    return AppEnv.instance.config.featureFlags[flagName] ?? false;
  }

  static ValueListenable<RuntimeConfig?> get configNotifier =>
      AppEnv.instance.configNotifier;
}

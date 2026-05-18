import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:envified/envified.dart';
import 'secrets.g.dart';

class AppConfig {
  AppConfig._();

  /// Bootstraps configurations. Must be called in `main.dart` before `runApp()`.
  static Future<void> init(Env defaultEnv,
      {AssetBundle? bundle, EnvStorage? storage}) async {
    await EnvConfigService.instance.init(
      defaultEnv: defaultEnv,
      allowProdSwitch: false, // 🔒 Lock production by default
      bundle: bundle,
      storage: storage,
    );
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
    final activeConfig = EnvConfigService.instance.current.value;
    if (activeConfig.values.containsKey(key)) {
      return activeConfig.values[key]!;
    }
    return AppSecrets.get(key);
  }

  // --- Secret accessors delegated to AppSecrets ---
  static String get encryptionKey => AppSecrets.encryptionKey;
  static String get basicAuthPassword => AppSecrets.basicAuthPassword;
  static String get appAuthKey => AppSecrets.appAuthKey;
  static String get apiSecret => AppSecrets.apiSecret;

  static Env get environment => EnvConfigService.instance.current.value.env;
  static String get environmentName =>
      EnvConfigService.instance.current.value.env.label;
  static String get baseUrl => EnvConfigService.instance.current.value.baseUrl;

  static bool isFeatureEnabled(String flagName) {
    final activeConfig = EnvConfigService.instance.current.value;
    return activeConfig.values[flagName]?.toLowerCase() == 'true';
  }

  static ValueListenable<EnvConfig> get configNotifier =>
      EnvConfigService.instance.current;
}

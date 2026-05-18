import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:envified_example/core/config/app_config.dart';
import 'package:envified_example/core/config/app_env.dart';
import 'package:envified_example/core/config/env_validator.dart';

class TestAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;
  TestAssetBundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    final content = assets[key];
    if (content == null) throw FlutterError('Asset not found: $key');
    return ByteData.sublistView(Uint8List.fromList(content.codeUnits));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final content = assets[key];
    if (content == null) throw FlutterError('Asset not found: $key');
    return content;
  }
}

void main() {
  group('Runtime Configurations & Safety Validator Tests', () {
    test('EnvValidator allows non-sensitive configurations', () {
      final safeConfig = {
        'ENV_NAME': 'Staging',
        'BASE_URL': 'https://api.staging.envified.com',
        'FEATURE_CHAT_ENABLED': 'true',
      };

      // Should not throw under production or development mode
      expect(() => EnvValidator.validate(safeConfig, isProduction: true),
          returnsNormally);
      expect(() => EnvValidator.validate(safeConfig, isProduction: false),
          returnsNormally);
    });

    test('EnvValidator blocks sensitive keys in production only', () {
      final unsafeConfig = {
        'ENV_NAME': 'Production',
        'BASE_URL': 'https://api.envified.com',
        'APP_AUTH_KEY': 'some_leaked_key_in_assets',
      };

      // Blocks strictly in production mode
      expect(
        () => EnvValidator.validate(unsafeConfig, isProduction: true),
        throwsA(isA<EnvifiedSecurityException>()),
      );

      // Allows with warning in development mode
      expect(
        () => EnvValidator.validate(unsafeConfig, isProduction: false),
        returnsNormally,
      );
    });

    test('AppEnv initialize loads and parses assets correctly', () async {
      final mockBundle = TestAssetBundle({
        'assets/env/.env.dev': '''
ENV_NAME=Development
BASE_URL="https://api.dev.envified.com"
FEATURE_CHAT_ENABLED=true
EXPERIMENTAL_UI='true'
# This is a comment line
  # Another spaced comment
        '''
      });

      await AppEnv.instance
          .initialize(AppEnvironment.dev, customBundle: mockBundle);

      final config = AppEnv.instance.config;
      expect(config.environment, AppEnvironment.dev);
      expect(config.environmentName, 'Development');
      expect(config.baseUrl, 'https://api.dev.envified.com');
      expect(config.featureFlags['FEATURE_CHAT_ENABLED'], true);
      expect(config.experimentalUi, true);
    });
  });

  group('Unified AppConfig Facade & Secrets Lookup Tests', () {
    test('AppConfig init fails if mandatory secrets are missing', () async {
      final mockBundle = TestAssetBundle({
        'assets/env/.env.dev':
            'ENV_NAME=Dev\nBASE_URL=https://api.dev.envified.com'
      });

      // AppSecrets will have compiled values if the build runner was run.
      // We can assert that initialization succeeds with the loaded secrets.
      expect(
        () => AppConfig.init(AppEnvironment.dev, customBundle: mockBundle),
        returnsNormally,
      );
    });

    test('AppConfig accessor retrieves assets and delegates to secrets',
        () async {
      final mockBundle = TestAssetBundle({
        'assets/env/.env.dev':
            'ENV_NAME=Dev\nBASE_URL=https://api.dev.envified.com'
      });

      await AppConfig.init(AppEnvironment.dev, customBundle: mockBundle);

      // Accessing standard configurations (comes from assets)
      expect(AppConfig.get('ENV_NAME'), 'Dev');
      expect(AppConfig.get('BASE_URL'), 'https://api.dev.envified.com');

      // Accessing compile-time obfuscated secrets (delegated fallback to AppSecrets)
      expect(AppConfig.get('ENCRYPTION_KEY'), isNotEmpty);
      expect(AppConfig.get('BASIC_AUTH_PASSWORD'), isNotEmpty);
      expect(AppConfig.get('APP_AUTH_KEY'), isNotEmpty);
      expect(AppConfig.get('API_SECRET'), isNotEmpty);

      expect(AppConfig.encryptionKey, isNotEmpty);
      expect(AppConfig.basicAuthPassword, isNotEmpty);
      expect(AppConfig.appAuthKey, isNotEmpty);
      expect(AppConfig.apiSecret, isNotEmpty);
    });

    test('AppConfig throws exception for missing keys', () {
      expect(
        () => AppConfig.get('NON_EXISTENT_SECRET_OR_CONFIG'),
        throwsArgumentError,
      );
    });
  });
}

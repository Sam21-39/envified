import 'package:envified/src/audit_entry.dart';
import 'package:envified/src/env_config_service.dart';
import 'package:envified/src/env_model.dart';
import 'package:envified/src/env_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/widgets.dart';

class MockAssetBundle extends Mock implements AssetBundle {}

class MockEnvStorage extends Mock implements EnvStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EnvConfigService service;
  late MockAssetBundle bundle;
  late MockEnvStorage storage;

  setUpAll(() {
    registerFallbackValue(Env.dev);
    registerFallbackValue(
        const EnvConfig(env: Env.dev, baseUrl: '', values: {}));
    registerFallbackValue(
        AuditEntry(timestamp: DateTime.now(), action: 'test'));
  });

  setUp(() {
    service = EnvConfigService.instance;
    service.resetForTesting();
    bundle = MockAssetBundle();
    storage = MockEnvStorage();

    // Mock .env
    when(() => bundle.loadString('.env')).thenAnswer(
        (_) async => 'BASE_URL=https://prod.com\nAPI_KEY=secret_prod');
    // Mock .env.dev
    when(() => bundle.loadString('.env.dev')).thenAnswer(
        (_) async => 'BASE_URL=https://dev.com\nAPI_KEY=secret_dev');

    // Mock storage
    when(() => storage.loadConfig()).thenAnswer((_) async => null);
    when(() => storage.saveConfig(any())).thenAnswer((_) async => {});
    when(() => storage.appendAudit(any())).thenAnswer((_) async => {});
    when(() => storage.saveUrlToHistory(any())).thenAnswer((_) async => {});
  });

  group('v2.2.0 Logic Tests', () {
    test('restartNeeded is false after init', () async {
      await service.init(
        bundle: bundle,
        storage: storage,
        urls: {Env.dev: 'https://dev.com', Env.prod: 'https://prod.com'},
        autoDiscover: false,
      );

      expect(service.restartNeeded.value, isFalse);
    });

    test('restartNeeded is true after switching environment', () async {
      await service.init(
        bundle: bundle,
        storage: storage,
        allowProdSwitch: true, // Allow switching back from prod
        urls: {Env.dev: 'https://dev.com', Env.prod: 'https://prod.com'},
        autoDiscover: false,
      );

      await service.switchTo(Env.prod);
      expect(service.restartNeeded.value, isTrue);

      await service.switchTo(Env.dev);
      expect(service.restartNeeded.value, isFalse);
    });

    test('restartNeeded is true after URL override', () async {
      await service.init(
        bundle: bundle,
        storage: storage,
        urls: {Env.dev: 'https://dev.com', Env.prod: 'https://prod.com'},
        autoDiscover: false,
      );

      await service.setBaseUrl('https://custom.com');
      expect(service.restartNeeded.value, isTrue);

      await service.clearBaseUrlOverride();
      expect(service.restartNeeded.value, isFalse);
    });

    test('isSensitiveKey detection', () {
      expect(EnvConfig.isSensitiveKey('API_KEY'), isTrue);
      expect(EnvConfig.isSensitiveKey('MY_SECRET_KEY'), isTrue);
      expect(EnvConfig.isSensitiveKey('DB_PASSWORD'), isTrue);
      expect(EnvConfig.isSensitiveKey('AUTH_TOKEN'), isTrue);
      expect(EnvConfig.isSensitiveKey('JWT_SECRET'), isTrue);
      expect(EnvConfig.isSensitiveKey('BASE_URL'), isFalse);
      expect(EnvConfig.isSensitiveKey('APP_NAME'), isFalse);
    });
  });
}

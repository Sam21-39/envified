import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/envified.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:envified/src/parser/env_file_parser.dart';
import 'test_helper.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EnvConfigService svc;
  late FakeFlutterSecureStorage fakeStorage;
  late EnvStorage envStorage;
  late FakeAssetBundle bundle;

  setUp(() async {
    EnvConfigService.resetInstance();
    fakeStorage = FakeFlutterSecureStorage();
    envStorage = EnvStorage(store: fakeStorage);
    bundle = FakeAssetBundle();

    EnvConfigService.overrideForTesting(
      storage: envStorage,
      parser: const EnvFileParser(),
    );
    svc = EnvConfigService.instance;

    bundle.register(
        'assets/env/.env', 'BASE_URL=https://dev.api.com\nKEY=DEV_VALUE');
    bundle.register(
        'assets/env/.env.prod', 'BASE_URL=https://api.com\nKEY=PROD_VALUE');
  });

  group('EnvConfigService.init()', () {
    test('loads default environment', () async {
      await svc.init(bundle: bundle);
      expect(svc.current.value.env, Env.dev);
      expect(svc.current.value.baseUrl, 'https://dev.api.com');
    });

    test('restores persisted environment', () async {
      await envStorage.saveActiveEnv('prod');
      await svc.init(bundle: bundle);
      expect(svc.current.value.env, Env.prod);
    });

    test('applies additional sensitive keys', () async {
      await svc.init(sensitiveKeys: ['MY_SECRET'], bundle: bundle);
      expect(svc.isSensitive('MY_SECRET'), isTrue);
    });
  });

  group('EnvConfigService.switchTo()', () {
    test('updates configuration and persists selection', () async {
      await svc.init(bundle: bundle);
      await svc.switchTo(Env.prod);

      expect(svc.current.value.env, Env.prod);
      expect(await envStorage.loadActiveEnv(), 'prod');
    });

    test('throws EnvifiedLockException when locked in Prod', () async {
      await svc.init(
          defaultEnv: Env.prod, allowProdSwitch: false, bundle: bundle);
      expect(
          () => svc.switchTo(Env.dev), throwsA(isA<EnvifiedLockException>()));
    });
  });

  group('EnvConfigService.setBaseUrl()', () {
    test('overrides base URL and appends to history', () async {
      await svc.init(bundle: bundle);
      await svc.setBaseUrl('https://custom.com');

      expect(svc.current.value.baseUrl, 'https://custom.com');
      expect(svc.current.value.isBaseUrlOverridden, isTrue);
      expect(await svc.loadUrlHistory(), contains('https://custom.com'));
    });

    test('throws EnvifiedLockException when locked in Prod', () async {
      await svc.init(
          defaultEnv: Env.prod, allowProdSwitch: false, bundle: bundle);
      expect(() => svc.setBaseUrl('https://evil.com'),
          throwsA(isA<EnvifiedLockException>()));
    });
  });

  group('typed getters', () {
    test('getInt parses correctly', () async {
      bundle.register('assets/env/.env', 'PORT=8080');
      await svc.init(bundle: bundle);
      expect(svc.getInt('PORT'), 8080);
    });

    test('getBool handles various truthy values', () async {
      bundle.register('assets/env/.env', 'DEBUG=true\nENABLED=1\nFEATURE=yes');
      await svc.init(bundle: bundle);
      expect(svc.getBool('DEBUG'), isTrue);
      expect(svc.getBool('ENABLED'), isTrue);
      expect(svc.getBool('FEATURE'), isTrue);
    });
  });

  group('Audit Log', () {
    test('operations append to audit log notifier', () async {
      await svc.init(bundle: bundle);
      await svc.switchTo(Env.prod);

      expect(svc.auditLog.value.length, 1);
      expect(svc.auditLog.value.first.action, AuditAction.envSwitch);
    });
  });

  group('Integrity Verification', () {
    test('throws EnvifiedTamperException on hash mismatch', () async {
      // 1. Initial load (saves hashes)
      bundle.register('assets/env/.env', 'BASE_URL=https://dev.api.com');
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://prod.api.com');
      await svc.init(bundle: bundle, verifyIntegrity: true);

      // 2. Switch to prod to save its hash
      await svc.switchTo(Env.prod);

      // 3. Switch back to dev
      await svc.switchTo(Env.dev);

      // 4. Tamper with prod file
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://hacked.com');

      // 5. Attempt to switch to prod again -> should throw
      expect(() => svc.switchTo(Env.prod),
          throwsA(isA<EnvifiedTamperException>()));
    });
  });

  group('Restart Needed Logic', () {
    test('restartNeeded is false after init', () async {
      await svc.init(bundle: bundle);
      expect(svc.restartNeeded.value, isFalse);
    });

    test('restartNeeded is true after environment switch', () async {
      await svc.init(bundle: bundle);
      await svc.switchTo(Env.prod);
      expect(svc.restartNeeded.value, isTrue);
    });

    test('restartNeeded returns to false after switching back to initial',
        () async {
      await svc.init(bundle: bundle);
      await svc.switchTo(Env.prod);
      expect(svc.restartNeeded.value, isTrue);

      await svc.switchTo(Env.dev);
      expect(svc.restartNeeded.value, isFalse);
    });

    test('acknowledgeRestart clears the flag', () async {
      await svc.init(bundle: bundle);
      await svc.switchTo(Env.prod);
      expect(svc.restartNeeded.value, isTrue);

      svc.acknowledgeRestart();
      expect(svc.restartNeeded.value, isFalse);
    });
  });
}

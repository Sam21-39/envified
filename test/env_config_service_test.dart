import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/envified.dart';
import 'package:envified/src/env_storage.dart';

/// A simple fake implementation of [FlutterSecureStorage] for testing.
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
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
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }
}

/// Helper to register a fake asset in the root bundle.
void _registerAsset(String key, String content) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final String assetKey = const StringCodec().decodeMessage(message) ?? '';
    if (assetKey == key) {
      return const StringCodec().encodeMessage(content);
    }
    return null;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final EnvConfigService svc = EnvConfigService.instance;
  late FakeFlutterSecureStorage fakeStorage;
  late EnvStorage envStorage;

  setUp(() async {
    fakeStorage = FakeFlutterSecureStorage();
    envStorage = EnvStorage(storage: fakeStorage);

    _registerAsset(
      '.env',
      'APP_NAME=TestApp\nTIMEOUT=30\nBASE_URL=https://api.example.com\n',
    );

    _registerAsset(
      '.env.dev',
      'BASE_URL=https://dev.api.example.com\nDEBUG=true\n',
    );
    _registerAsset(
      '.env.staging',
      'BASE_URL=https://staging.api.example.com\nDEBUG=true\n',
    );
    _registerAsset(
      '.env.prod',
      'BASE_URL=https://api.example.com\nDEBUG=false\n',
    );
  });

  group('EnvConfigService.init()', () {
    test('defaults to Env.dev on first launch', () async {
      await svc.init(defaultEnv: Env.dev, storage: envStorage);
      expect(svc.current.value.env, Env.dev);
    });

    test('baseUrl is taken from .env.dev BASE_URL', () async {
      await svc.init(defaultEnv: Env.dev, storage: envStorage);
      expect(svc.current.value.baseUrl, 'https://dev.api.example.com');
    });

    test('merged values include fallback keys', () async {
      await svc.init(defaultEnv: Env.dev, storage: envStorage);
      expect(svc.current.value.values['APP_NAME'], 'TestApp');
    });

    test('restores persisted env on second init()', () async {
      await svc.init(defaultEnv: Env.dev, persistSelection: true, storage: envStorage);
      await svc.switchTo(Env.staging);

      await svc.init(defaultEnv: Env.dev, persistSelection: true, storage: envStorage);
      expect(svc.current.value.env, Env.staging);
    });

    test('does not restore persisted env when persistSelection is false', () async {
      await svc.init(defaultEnv: Env.dev, persistSelection: true, storage: envStorage);
      await svc.switchTo(Env.staging);

      await svc.init(defaultEnv: Env.dev, persistSelection: false, storage: envStorage);
      expect(svc.current.value.env, Env.dev);
    });
  });

  group('EnvConfigService.switchTo()', () {
    setUp(() async {
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: false, storage: envStorage);
    });

    test('updates current.value to the new env', () async {
      await svc.switchTo(Env.staging);
      expect(svc.current.value.env, Env.staging);
    });

    test('updates baseUrl to the new env BASE_URL', () async {
      await svc.switchTo(Env.staging);
      expect(svc.current.value.baseUrl, 'https://staging.api.example.com');
    });

    test('switching to prod is allowed from dev', () async {
      await svc.switchTo(Env.prod);
      expect(svc.current.value.env, Env.prod);
    });

    test('throws EnvifiedLockException when leaving prod and locked', () async {
      await svc.switchTo(Env.prod);
      expect(
        () => svc.switchTo(Env.dev),
        throwsA(isA<EnvifiedLockException>()),
      );
    });
  });

  group('EnvConfigService.setBaseUrl()', () {
    setUp(() async {
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: false, storage: envStorage);
    });

    test('sets isBaseUrlOverridden to true', () async {
      await svc.setBaseUrl('https://custom.example.com');
      expect(svc.current.value.isBaseUrlOverridden, isTrue);
    });

    test('updates baseUrl to the provided URL', () async {
      await svc.setBaseUrl('https://custom.example.com');
      expect(svc.current.value.baseUrl, 'https://custom.example.com');
    });
  });

  group('EnvConfigService.reset()', () {
    test('returns to defaultEnv', () async {
      await svc.init(defaultEnv: Env.dev, persistSelection: true, storage: envStorage);
      await svc.switchTo(Env.staging);
      await svc.reset();
      expect(svc.current.value.env, Env.dev);
    });

    test('clears persisted storage', () async {
      await svc.init(defaultEnv: Env.dev, persistSelection: true, storage: envStorage);
      await svc.switchTo(Env.staging);
      await svc.reset();

      final stored = await envStorage.loadConfig();
      expect(stored, isNull);
    });
  });

  group('EnvConfigService Security', () {
    test('isProdLocked returns true when in prod and allowProdSwitch is false', () async {
      await svc.init(defaultEnv: Env.prod, allowProdSwitch: false, storage: envStorage);
      expect(svc.isProdLocked, isTrue);
    });

    test('isProdLocked returns false when in dev', () async {
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: false, storage: envStorage);
      expect(svc.isProdLocked, isFalse);
    });

    test('allowProdSwitch property is correctly exposed', () async {
      await svc.init(allowProdSwitch: true, storage: envStorage);
      expect(svc.allowProdSwitch, isTrue);

      await svc.init(allowProdSwitch: false, storage: envStorage);
      expect(svc.allowProdSwitch, isFalse);
    });
  });

  group('EnvConfigService.get()', () {
    setUp(() async {
      await svc.init(defaultEnv: Env.dev, storage: envStorage);
    });

    test('returns value for existing key', () {
      expect(svc.get('APP_NAME'), 'TestApp');
    });

    test('returns fallback for missing key', () {
      expect(svc.get('MISSING_KEY', fallback: 'default'), 'default');
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:envified/envified.dart';

/// Helper to register a fake asset in the root bundle.
void _registerAsset(String key, String content) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final String assetKey =
        const StringCodec().decodeMessage(message) ?? '';
    if (assetKey == key) {
      return const StringCodec().encodeMessage(content);
    }
    // Return null for unregistered assets — simulates missing file.
    return null;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Re-obtain the singleton; we manipulate its internal state via init().
  final EnvConfigService svc = EnvConfigService.instance;

  setUp(() async {
    // Fresh SharedPreferences for every test.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Register a shared `.env` fallback asset.
    _registerAsset(
      '.env',
      'APP_NAME=TestApp\nTIMEOUT=30\nBASE_URL=https://api.example.com\n',
    );

    // Register per-env assets.
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
      await svc.init(defaultEnv: Env.dev);
      expect(svc.current.value.env, Env.dev);
    });

    test('baseUrl is taken from .env.dev BASE_URL', () async {
      await svc.init(defaultEnv: Env.dev);
      expect(svc.current.value.baseUrl, 'https://dev.api.example.com');
    });

    test('merged values include fallback keys', () async {
      await svc.init(defaultEnv: Env.dev);
      // APP_NAME comes from the shared .env fallback.
      expect(svc.current.value.values['APP_NAME'], 'TestApp');
    });

    test('restores persisted env on second init()', () async {
      // First init — switches to staging and persists.
      await svc.init(defaultEnv: Env.dev, persistSelection: true);
      await svc.switchTo(Env.staging);

      // Second init — should restore staging from SharedPreferences.
      await svc.init(defaultEnv: Env.dev, persistSelection: true);
      expect(svc.current.value.env, Env.staging);
    });

    test('does not restore persisted env when persistSelection is false',
        () async {
      await svc.init(defaultEnv: Env.dev, persistSelection: true);
      await svc.switchTo(Env.staging);

      await svc.init(defaultEnv: Env.dev, persistSelection: false);
      expect(svc.current.value.env, Env.dev);
    });
  });

  group('EnvConfigService.switchTo()', () {
    setUp(() async {
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: false);
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

    test('switchTo(prod) from prod is a no-op (same env, no throw)', () async {
      await svc.switchTo(Env.prod);
      // Switching to the same env should not throw.
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

    test('does not throw when leaving prod and allowProdSwitch is true',
        () async {
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: true);
      await svc.switchTo(Env.prod);
      await svc.switchTo(Env.dev); // Should not throw.
      expect(svc.current.value.env, Env.dev);
    });
  });

  group('EnvConfigService.setBaseUrl()', () {
    setUp(() async {
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: false);
    });

    test('sets isBaseUrlOverridden to true', () async {
      await svc.setBaseUrl('https://custom.example.com');
      expect(svc.current.value.isBaseUrlOverridden, isTrue);
    });

    test('updates baseUrl to the provided URL', () async {
      await svc.setBaseUrl('https://custom.example.com');
      expect(svc.current.value.baseUrl, 'https://custom.example.com');
    });

    test('throws EnvifiedLockException when prod-locked', () async {
      await svc.switchTo(Env.prod);
      expect(
        () => svc.setBaseUrl('https://custom.example.com'),
        throwsA(isA<EnvifiedLockException>()),
      );
    });
  });

  group('EnvConfigService.clearBaseUrlOverride()', () {
    setUp(() async {
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: false);
      await svc.setBaseUrl('https://custom.example.com');
    });

    test('restores BASE_URL from .env file', () async {
      await svc.clearBaseUrlOverride();
      expect(svc.current.value.baseUrl, 'https://dev.api.example.com');
    });

    test('sets isBaseUrlOverridden to false', () async {
      await svc.clearBaseUrlOverride();
      expect(svc.current.value.isBaseUrlOverridden, isFalse);
    });

    test('throws EnvifiedLockException when prod-locked', () async {
      // Switch to prod first, which activates the production lock.
      await svc.init(defaultEnv: Env.dev, allowProdSwitch: false);
      await svc.switchTo(Env.prod);
      expect(
        () => svc.clearBaseUrlOverride(),
        throwsA(isA<EnvifiedLockException>()),
      );
    });
  });

  group('EnvConfigService.reset()', () {
    test('returns to defaultEnv', () async {
      await svc.init(defaultEnv: Env.dev, persistSelection: true);
      await svc.switchTo(Env.staging);
      await svc.reset();
      expect(svc.current.value.env, Env.dev);
    });

    test('clears persisted selection so second init starts fresh', () async {
      await svc.init(defaultEnv: Env.dev, persistSelection: true);
      await svc.switchTo(Env.staging);
      await svc.reset();

      // Re-init after reset should default to Env.dev (nothing persisted).
      await svc.init(defaultEnv: Env.dev, persistSelection: true);
      expect(svc.current.value.env, Env.dev);
    });
  });

  group('EnvConfigService.get()', () {
    setUp(() async {
      await svc.init(defaultEnv: Env.dev);
    });

    test('returns value for existing key', () {
      expect(svc.get('APP_NAME'), 'TestApp');
    });

    test('returns fallback for missing key', () {
      expect(svc.get('MISSING_KEY', fallback: 'default'), 'default');
    });

    test('returns empty string fallback by default for missing key', () {
      expect(svc.get('TOTALLY_MISSING'), '');
    });
  });
}

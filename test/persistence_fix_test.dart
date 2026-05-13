import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'test_helper.dart';

class MockAssetBundle extends Mock implements AssetBundle {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final EnvConfigService svc = EnvConfigService.instance;
  late FakeFlutterSecureStorage fakeStorage;
  late EnvStorage envStorage;
  late FakeAssetBundle bundle;

  setUp(() {
    svc.resetForTesting();
    fakeStorage = FakeFlutterSecureStorage();
    envStorage = EnvStorage(storage: fakeStorage);
    bundle = FakeAssetBundle();

    // Register .env
    bundle.register('.env', 'BASE_URL=https://prod.com\n');
    bundle.register('.env.dev', 'BASE_URL=https://dev.com\n');
    bundle.register('.env.staging', 'BASE_URL=https://staging.com\n');
  });

  group('Persistence Fix Verification', () {
    test('Setting a URL on Dev persists after restart', () async {
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        persistSelection: true,
      );

      await svc.setBaseUrl('https://custom-dev.com');
      expect(svc.current.value.baseUrl, 'https://custom-dev.com');

      // Re-initialize (simulating app restart)
      svc.resetForTesting();
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        persistSelection: true,
      );

      expect(svc.current.value.env, Env.dev);
      expect(svc.current.value.baseUrl, 'https://custom-dev.com');
      expect(svc.current.value.isBaseUrlOverridden, isTrue);
    });

    test('Switching environment uses target environment defaults, preserving original override', () async {
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        persistSelection: true,
      );

      await svc.setBaseUrl('https://custom-dev.com');
      
      // Switch to staging
      await svc.switchTo(Env.staging);
      expect(svc.current.value.env, Env.staging);
      expect(svc.current.value.baseUrl, 'https://staging.com'); // Uses staging default
      expect(svc.current.value.isBaseUrlOverridden, isFalse);

      // Switch back to dev
      await svc.switchTo(Env.dev);
      expect(svc.current.value.env, Env.dev);
      expect(svc.current.value.baseUrl, 'https://custom-dev.com'); // Restores dev override
      expect(svc.current.value.isBaseUrlOverridden, isTrue);
    });

    test('Clearing an override in one environment doesn\'t affect another', () async {
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        persistSelection: true,
      );

      await svc.setBaseUrl('https://custom-dev.com');
      
      await svc.switchTo(Env.staging);
      await svc.setBaseUrl('https://custom-staging.com');
      
      expect(svc.current.value.baseUrl, 'https://custom-staging.com');
      
      await svc.clearBaseUrlOverride();
      expect(svc.current.value.baseUrl, 'https://staging.com');
      
      await svc.switchTo(Env.dev);
      expect(svc.current.value.baseUrl, 'https://custom-dev.com'); // Still has its own override
    });

    test('.env fallback works correctly when a specific environment file lacks BASE_URL', () async {
      // .env.dev exists but has no BASE_URL
      bundle.register('.env.dev', 'SOME_KEY=value\n');
      
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        persistSelection: true,
      );

      // Should fall back to .env BASE_URL
      expect(svc.current.value.baseUrl, 'https://prod.com');
    });

    test('Robust BASE_URL extraction handles spaces and comments', () async {
      bundle.register('.env.dev', ' # Comment\n  BASE_URL  =  https://spaced.com  \n');
      
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        persistSelection: true,
      );

      expect(svc.current.value.baseUrl, 'https://spaced.com');
    });
  });
}

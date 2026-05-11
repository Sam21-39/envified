import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:envified/src/parser/env_file_parser.dart';
import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EnvConfigService svc;
  late FakeFlutterSecureStorage fakeStorage;
  late EnvStorage envStorage;
  late FakeAssetBundle bundle;

  setUp(() async {
    EnvConfigService.resetInstance(); // Reset singleton state
    fakeStorage = FakeFlutterSecureStorage();
    envStorage = EnvStorage(store: fakeStorage);
    bundle = FakeAssetBundle();

    EnvConfigService.overrideForTesting(
      storage: envStorage,
      parser: const EnvFileParser(),
    );
    svc = EnvConfigService.instance;
  });

  group('EnvConfigService.init', () {
    test('loads default env when storage is empty', () async {
      bundle.register('assets/env/.env', 'BASE_URL=https://dev.api.com');
      await svc.init(bundle: bundle);

      expect(svc.current.value.env, Env.dev);
      expect(svc.current.value.baseUrl, 'https://dev.api.com');
    });

    test('loads persisted env from storage', () async {
      await fakeStorage.write(key: 'envified.active_env', value: 'staging');
      bundle.register(
          'assets/env/.env.staging', 'BASE_URL=https://staging.api.com');

      await svc.init(bundle: bundle);

      expect(svc.current.value.env.name, 'staging');
      expect(svc.current.value.baseUrl, 'https://staging.api.com');
    });

    test('applies sensitive keys to configuration', () async {
      bundle.register('assets/env/.env', 'MY_KEY=secret\nOTHER=123');
      await svc.init(
        bundle: bundle,
        sensitiveKeys: ['MY_KEY'],
      );

      expect(svc.isSensitive('MY_KEY'), isTrue);
      expect(svc.isSensitive('OTHER'), isFalse);
      expect(svc.isSensitive('PASSWORD'), isTrue); // default
    });
  });

  group('EnvConfigService.switchTo', () {
    test('updates current config and persists change', () async {
      bundle.register('assets/env/.env', 'BASE_URL=https://dev.com');
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://prod.com');

      await svc.init(bundle: bundle);
      await svc.switchTo(Env.prod);

      expect(svc.current.value.env, Env.prod);
      expect(await fakeStorage.read(key: 'envified.active_env'), 'prod');
    });

    test('blocks switching TO prod when allowProdSwitch is false', () async {
      bundle.register('assets/env/.env', 'BASE_URL=https://dev.com');
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://prod.com');
      await svc.init(
        bundle: bundle,
        allowProdSwitch: false,
      );

      await svc.switchTo(Env.prod);
      expect(svc.current.value.env, Env.dev); // Unchanged
    });

    test('allows switching AWAY from prod even when allowProdSwitch is false', () async {
      bundle.register('assets/env/.env', 'BASE_URL=https://dev.com');
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://prod.com');
      await svc.init(
        defaultEnv: Env.prod,
        bundle: bundle,
        allowProdSwitch: false,
      );

      await svc.switchTo(Env.dev);
      expect(svc.current.value.env, Env.dev); // Allowed
    });
  });

  group('EnvConfigService Value Accessors', () {
    test('get returns values by key', () async {
      bundle.register('assets/env/.env', 'KEY=VALUE');
      await svc.init(bundle: bundle);
      expect(svc.get('KEY'), 'VALUE');
      expect(svc.get('MISSING'), isNull);
    });

    test('getBool parses boolean values', () async {
      bundle.register('assets/env/.env', 'T=true\nF=false\nN=notbool');
      await svc.init(bundle: bundle);
      expect(svc.getBool('T'), isTrue);
      expect(svc.getBool('F'), isFalse);
      expect(svc.getBool('N'), isFalse);
    });

    test('getInt parses integers', () async {
      bundle.register('assets/env/.env', 'I=42\nS=string');
      await svc.init(bundle: bundle);
      expect(svc.getInt('I'), 42);
      expect(svc.getInt('S', fallback: 7), 7);
    });
  });
}

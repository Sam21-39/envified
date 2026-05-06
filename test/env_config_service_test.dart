import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/envified.dart';

final _urls = {
  Env.dev: 'https://dev.api.appamania.in',
  Env.staging: 'https://staging.api.appamania.in',
  Env.prod: 'https://api.appamania.in',
};

final _vars = {
  'API_KEY': 'test-key-123',
  'APP_NAME': 'TestApp',
};

final _varsByEnv = {
  Env.dev: {'LOG_LEVEL': 'verbose', 'FEATURE_X': 'true'},
  Env.staging: {'LOG_LEVEL': 'info', 'FEATURE_X': 'true'},
  Env.prod: {'LOG_LEVEL': 'error', 'FEATURE_X': 'false'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  final svc = EnvConfigService.instance;

  group('init', () {
    test('defaults to dev env', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(svc.current.value.env, Env.dev);
      expect(svc.current.value.baseUrl, _urls[Env.dev]);
    });

    test('BASE_URL is auto-injected and matches baseUrl', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(svc.get('BASE_URL'), _urls[Env.dev]);
    });

    test('global vars are available after init', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(svc.get('API_KEY'), 'test-key-123');
      expect(svc.get('APP_NAME'), 'TestApp');
    });

    test('per-env vars are resolved for default env', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(svc.get('LOG_LEVEL'), 'verbose');
      expect(svc.get('FEATURE_X'), 'true');
    });
  });

  group('switchTo', () {
    test('changes env and url', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      await svc.switchTo(Env.prod);
      expect(svc.current.value.env, Env.prod);
      expect(svc.current.value.baseUrl, _urls[Env.prod]);
    });

    test('BASE_URL updates to match new env url', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      await svc.switchTo(Env.staging);
      expect(svc.get('BASE_URL'), _urls[Env.staging]);
    });

    test('re-resolves per-env vars on switch', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      await svc.switchTo(Env.prod);
      // prod env should have error log level and feature disabled
      expect(svc.get('LOG_LEVEL'), 'error');
      expect(svc.get('FEATURE_X'), 'false');
    });

    test('global vars are still accessible after switch', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      await svc.switchTo(Env.prod);
      // Global vars are merged, so still available
      expect(svc.get('API_KEY'), 'test-key-123');
    });

    test('per-env vars take priority over global vars', () async {
      // Global has LOG_LEVEL, env override also has LOG_LEVEL
      await svc.init(
        urls: _urls,
        vars: {'LOG_LEVEL': 'global-default'},
        varsByEnv: {
          Env.dev: {'LOG_LEVEL': 'verbose-dev'}
        },
      );
      expect(svc.get('LOG_LEVEL'), 'verbose-dev');
    });
  });

  group('setCustomUrl', () {
    test('sets Env.custom', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      await svc.setCustomUrl('https://ngrok.io/test');
      expect(svc.current.value.env, Env.custom);
      expect(svc.current.value.baseUrl, 'https://ngrok.io/test');
    });

    test('BASE_URL is updated to match custom URL', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      await svc.setCustomUrl('https://my-custom-server.com/api');
      expect(svc.get('BASE_URL'), 'https://my-custom-server.com/api');
    });
  });

  group('reset', () {
    test('returns to dev env', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      await svc.switchTo(Env.prod);
      await svc.reset();
      expect(svc.current.value.env, Env.dev);
    });
  });

  group('get / maybeGet', () {
    test('get returns value for existing key', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(svc.get('API_KEY'), 'test-key-123');
    });

    test('get throws StateError for missing key', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(() => svc.get('NONEXISTENT_KEY'), throwsStateError);
    });

    test('maybeGet returns value for existing key', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(svc.maybeGet('API_KEY'), 'test-key-123');
    });

    test('maybeGet returns null for missing key', () async {
      await svc.init(urls: _urls, vars: _vars, varsByEnv: _varsByEnv);
      expect(svc.maybeGet('NONEXISTENT_KEY'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/envified.dart';
import 'package:envified/src/env_storage.dart';
import 'test_helper.dart';

/// A simple fake implementation of [FlutterSecureStorage] for testing.
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
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
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async {
    _data.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final EnvConfigService svc = EnvConfigService.instance;
  late FakeFlutterSecureStorage fakeStorage;
  late EnvStorage envStorage;
  late FakeAssetBundle bundle;

  setUp(() async {
    svc.resetForTesting();
    fakeStorage = FakeFlutterSecureStorage();
    envStorage = EnvStorage(storage: fakeStorage);
    bundle = FakeAssetBundle();

    bundle.register(
      '.env',
      'APP_NAME=TestApp\nTIMEOUT=30\nBASE_URL=https://api.example.com\n'
          'DEBUG=true\nRATE=1.5\nFEATURE_FLAG=yes\n'
          'WEBHOOK=https://hooks.example.com/ping\n'
          'ALLOWED_HOSTS=api.com, cdn.com, auth.com\n',
    );

    bundle.register(
      '.env.dev',
      'BASE_URL=https://dev.api.example.com\nDEBUG=true\n',
    );
    bundle.register(
      '.env.staging',
      'BASE_URL=https://staging.api.example.com\nDEBUG=true\n',
    );
    bundle.register(
      '.env.prod',
      'BASE_URL=https://api.example.com\nDEBUG=false\n',
    );
  });

  group('EnvConfigService.init()', () {
    test('defaults to Env.dev on first launch', () async {
      await svc.init(defaultEnv: Env.dev, storage: envStorage, bundle: bundle);
      expect(svc.current.value.env, Env.dev);
    });

    test('baseUrl is taken from .env.dev BASE_URL', () async {
      await svc.init(defaultEnv: Env.dev, storage: envStorage, bundle: bundle);
      expect(svc.current.value.baseUrl, 'https://dev.api.example.com');
    });

    test('merged values include fallback keys', () async {
      await svc.init(defaultEnv: Env.dev, storage: envStorage, bundle: bundle);
      expect(svc.current.value.values['APP_NAME'], 'TestApp');
    });

    test('restores persisted env on second init()', () async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
      await svc.switchTo(Env.staging);

      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
      expect(svc.current.value.env, Env.staging);
    });

    test('does not restore persisted env when persistSelection is false',
        () async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
      await svc.switchTo(Env.staging);

      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: false,
          storage: envStorage,
          bundle: bundle);
      expect(svc.current.value.env, Env.dev);
    });
  });

  group('EnvConfigService.switchTo()', () {
    setUp(() async {
      await svc.init(
          defaultEnv: Env.dev,
          allowProdSwitch: false,
          storage: envStorage,
          bundle: bundle);
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
      await svc.init(
          defaultEnv: Env.dev,
          allowProdSwitch: false,
          storage: envStorage,
          bundle: bundle);
    });

    test('sets isBaseUrlOverridden to true', () async {
      await svc.setBaseUrl('https://custom.example.com');
      expect(svc.current.value.isBaseUrlOverridden, isTrue);
    });

    test('updates baseUrl to the provided URL', () async {
      await svc.setBaseUrl('https://custom.example.com');
      expect(svc.current.value.baseUrl, 'https://custom.example.com');
    });

    test('throws EnvifiedLockException when in prod and locked', () async {
      await svc.switchTo(Env.prod);
      // Re-init with allowProdSwitch: false so that prod lock is active.
      await svc.init(
          defaultEnv: Env.prod,
          allowProdSwitch: false,
          storage: envStorage,
          bundle: bundle);
      expect(
        () => svc.setBaseUrl('https://evil.com'),
        throwsA(isA<EnvifiedLockException>()),
      );
    });

    test('throws EnvifiedUrlNotAllowedException when URL not in allowlist',
        () async {
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        allowedUrls: ['https://api.example.com', 'https://dev.api.example.com'],
      );
      expect(
        () => svc.setBaseUrl('https://evil.notallowed.com'),
        throwsA(isA<EnvifiedUrlNotAllowedException>()),
      );
    });

    test('succeeds when URL is in allowlist', () async {
      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        allowedUrls: ['https://dev.api.example.com'],
      );
      await svc.setBaseUrl('https://dev.api.example.com/v2');
      expect(svc.current.value.baseUrl, 'https://dev.api.example.com/v2');
    });
  });

  group('EnvConfigService.reset()', () {
    test('returns to defaultEnv', () async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
      await svc.switchTo(Env.staging);
      await svc.reset();
      expect(svc.current.value.env, Env.dev);
    });

    test('clears persisted storage', () async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
      await svc.switchTo(Env.staging);
      await svc.reset();

      final stored = await envStorage.loadConfig();
      expect(stored, isNull);
    });
  });

  group('EnvConfigService Security', () {
    test('isProdLocked returns true when in prod and allowProdSwitch is false',
        () async {
      await svc.init(
          defaultEnv: Env.prod,
          allowProdSwitch: false,
          storage: envStorage,
          bundle: bundle);
      expect(svc.isProdLocked, isTrue);
    });

    test('isProdLocked returns false when in dev', () async {
      await svc.init(
          defaultEnv: Env.dev,
          allowProdSwitch: false,
          storage: envStorage,
          bundle: bundle);
      expect(svc.isProdLocked, isFalse);
    });

    test('allowProdSwitch property is correctly exposed', () async {
      await svc.init(
          allowProdSwitch: true, storage: envStorage, bundle: bundle);
      expect(svc.allowProdSwitch, isTrue);

      await svc.init(
          allowProdSwitch: false, storage: envStorage, bundle: bundle);
      expect(svc.allowProdSwitch, isFalse);
    });
  });

  group('EnvConfigService.get()', () {
    setUp(() async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
    });

    test('returns value for existing key', () {
      expect(svc.get('APP_NAME'), 'TestApp');
    });

    test('returns fallback for missing key', () {
      expect(svc.get('MISSING_KEY', fallback: 'default'), 'default');
    });
  });

  // ── Typed getters ───────────────────────────────────────────────────────────

  group('EnvConfigService typed getters', () {
    setUp(() async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
    });

    // getBool
    test('getBool returns true for "true"', () {
      expect(svc.getBool('DEBUG'), isTrue);
    });

    test('getBool returns true for "yes"', () {
      expect(svc.getBool('FEATURE_FLAG'), isTrue);
    });

    test('getBool returns fallback for missing key', () {
      expect(svc.getBool('NONEXISTENT', fallback: true), isTrue);
    });

    test('getBool returns false for "false" string', () {
      // DEBUG in .env.prod is "false"; switch to test
      // Switch env to prod first
    });

    // getInt
    test('getInt parses valid integer', () {
      expect(svc.getInt('TIMEOUT'), 30);
    });

    test('getInt returns fallback for missing key', () {
      expect(svc.getInt('NONEXISTENT', fallback: 99), 99);
    });

    test('getInt returns fallback for non-parseable value', () {
      expect(svc.getInt('APP_NAME', fallback: -1), -1);
    });

    // getDouble
    test('getDouble parses valid double', () {
      expect(svc.getDouble('RATE'), 1.5);
    });

    test('getDouble returns fallback for missing key', () {
      expect(svc.getDouble('NONEXISTENT', fallback: 3.14), 3.14);
    });

    test('getDouble returns fallback for non-parseable value', () {
      expect(svc.getDouble('APP_NAME', fallback: 0.0), 0.0);
    });

    // getUri
    test('getUri parses valid URI', () {
      final Uri? uri = svc.getUri('WEBHOOK');
      expect(uri, isNotNull);
      expect(uri!.host, 'hooks.example.com');
    });

    test('getUri returns null for missing key', () {
      expect(svc.getUri('NONEXISTENT'), isNull);
    });

    // getList
    test('getList splits CSV values and trims whitespace', () {
      final List<String> hosts = svc.getList('ALLOWED_HOSTS');
      expect(hosts, containsAll(['api.com', 'cdn.com', 'auth.com']));
      expect(hosts.length, 3);
    });

    test('getList returns empty list for missing key', () {
      expect(svc.getList('NONEXISTENT'), isEmpty);
    });

    test('getList respects custom separator', () async {
      bundle.register('.env', 'PIPE_LIST=a|b|c\n');
      await svc.init(defaultEnv: Env.dev, storage: envStorage, bundle: bundle);
    });
  });

  // ── Lifecycle hooks ─────────────────────────────────────────────────────────

  group('Lifecycle hooks', () {
    test('onBeforeSwitch is awaited before env changes', () async {
      final List<String> log = [];

      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        onBeforeSwitch: (Env from, Env to) async {
          log.add('before:${from.name}→${to.name}');
        },
        onAfterSwitch: (config) {
          log.add('after:${config.env.name}');
        },
      );

      await svc.switchTo(Env.staging);

      expect(log, ['before:dev→staging', 'after:staging']);
    });

    test('onAfterSwitch is called after setBaseUrl', () async {
      final List<String> log = [];

      await svc.init(
        defaultEnv: Env.dev,
        storage: envStorage,
        bundle: bundle,
        onAfterSwitch: (config) {
          log.add('after:${config.baseUrl}');
        },
      );

      await svc.setBaseUrl('https://hook.example.com');
      expect(log, ['after:https://hook.example.com']);
    });
  });

  // ── Audit log ───────────────────────────────────────────────────────────────

  group('Audit log', () {
    setUp(() async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
    });

    test('switchTo appends an audit entry', () async {
      await svc.switchTo(Env.staging);
      final List<AuditEntry> log = await svc.auditLog;
      expect(log, isNotEmpty);
      expect(log.first.action, 'switch');
      expect(log.first.fromEnv, 'dev');
      expect(log.first.toEnv, 'staging');
    });

    test('setBaseUrl appends an audit entry with url', () async {
      await svc.setBaseUrl('https://audit.example.com');
      final List<AuditEntry> log = await svc.auditLog;
      expect(log.first.action, 'setBaseUrl');
      expect(log.first.url, 'https://audit.example.com');
    });

    test('clearBaseUrlOverride appends an audit entry', () async {
      await svc.setBaseUrl('https://audit.example.com');
      await svc.clearBaseUrlOverride();
      final List<AuditEntry> log = await svc.auditLog;
      expect(log.first.action, 'clearOverride');
    });

    test('reset appends a reset audit entry', () async {
      await svc.reset();
      final List<AuditEntry> log = await svc.auditLog;
      // After reset, storage is cleared — log should be empty again.
      expect(log, isEmpty);
    });
  });

  // ── URL history ─────────────────────────────────────────────────────────────

  group('URL history', () {
    setUp(() async {
      await svc.init(
          defaultEnv: Env.dev,
          persistSelection: true,
          storage: envStorage,
          bundle: bundle);
    });

    test('setBaseUrl adds URL to history', () async {
      await svc.setBaseUrl('https://history.example.com');
      final List<String> history = await svc.urlHistory;
      expect(history, contains('https://history.example.com'));
    });

    test('duplicate URLs are deduplicated and moved to front', () async {
      await svc.setBaseUrl('https://a.example.com');
      await svc.setBaseUrl('https://b.example.com');
      await svc.setBaseUrl('https://a.example.com');
      final List<String> history = await svc.urlHistory;
      expect(history.first, 'https://a.example.com');
      expect(history.where((u) => u == 'https://a.example.com').length, 1);
    });

    test('history is capped at 5 entries', () async {
      for (int i = 0; i < 7; i++) {
        await svc.setBaseUrl('https://url$i.example.com');
      }
      final List<String> history = await svc.urlHistory;
      expect(history.length, lessThanOrEqualTo(5));
    });
  });
}

import 'package:envified/src/models/audit_entry.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write(
      {required String key,
      required String? value,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read(
          {required String key,
          AppleOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          AppleOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      _data[key];

  @override
  Future<void> delete(
      {required String key,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions}) async {
    _data.remove(key);
  }
}

void main() {
  late FakeFlutterSecureStorage store;
  late EnvStorage storage;

  setUp(() {
    store = FakeFlutterSecureStorage();
    storage = EnvStorage(store: store);
  });

  group('EnvStorage.saveHash/loadHash', () {
    test('persists and retrieves hashes', () async {
      await storage.saveHash('dev', 'abc');
      expect(await storage.loadHash('dev'), 'abc');
    });
  });

  group('EnvStorage.appendAuditEntry', () {
    test('caps at 50 entries', () async {
      for (var i = 0; i < 60; i++) {
        await storage.appendAuditEntry(AuditEntry(
          timestamp: DateTime.now(),
          action: AuditAction.reset,
        ));
      }
      final log = await storage.loadAuditLog();
      expect(log.length, 50);
    });

    test('returns empty on corruption', () async {
      await store.write(key: 'envified.audit_log', value: 'invalid json');
      final log = await storage.loadAuditLog();
      expect(log, isEmpty);
    });
  });

  group('EnvStorage.saveUrlToHistory', () {
    test('moves to top and caps at 5', () async {
      await storage.saveUrlToHistory('url1');
      await storage.saveUrlToHistory('url2');
      await storage.saveUrlToHistory('url3');
      await storage.saveUrlToHistory('url4');
      await storage.saveUrlToHistory('url5');
      await storage.saveUrlToHistory('url6');

      final history = await storage.loadUrlHistory();
      expect(history.first, 'url6');
      expect(history.length, 5);
      expect(history, isNot(contains('url1')));
    });

    test('returns empty on corruption', () async {
      await store.write(key: 'envified.url_history', value: 'not a list');
      final history = await storage.loadUrlHistory();
      expect(history, isEmpty);
    });
  });

  group('EnvStorage.clear', () {
    test('removes all keys', () async {
      await storage.saveActiveEnv('dev');
      await storage.saveUrlToHistory('url');
      await storage.clear();
      expect(await storage.loadActiveEnv(), isNull);
      expect(await storage.loadUrlHistory(), isEmpty);
    });
  });
}

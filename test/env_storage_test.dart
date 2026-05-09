import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:envified/src/models/audit_entry.dart';
import 'package:envified/src/models/env.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('EnvStorage', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late EnvStorage storage;

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      storage = EnvStorage(store: mockSecureStorage);
      registerFallbackValue(AuditAction.envSwitch);
    });

    test('saveActiveEnv writes name to secure storage', () async {
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await storage.saveActiveEnv('staging');

      verify(() => mockSecureStorage.write(
            key: 'envified.active_env',
            value: 'staging',
          )).called(1);
    });

    test('loadActiveEnv restores name', () async {
      when(() => mockSecureStorage.read(key: 'envified.active_env'))
          .thenAnswer((_) async => 'prod');

      final result = await storage.loadActiveEnv();
      expect(result, 'prod');
    });

    test('saveUrlToHistory adds URL and maintains history limit', () async {
      when(() => mockSecureStorage.read(key: 'envified.url_history'))
          .thenAnswer((_) async => '["url1", "url2"]');
      when(() => mockSecureStorage.write(
            key: 'envified.url_history',
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await storage.saveUrlToHistory('url3');

      verify(() => mockSecureStorage.write(
            key: 'envified.url_history',
            value: any(named: 'value', that: contains('url3')),
          )).called(1);
    });

    test('appendAuditEntry adds entry and respects ring buffer limit',
        () async {
      when(() => mockSecureStorage.read(key: 'envified.audit_log'))
          .thenAnswer((_) async => '[]');
      when(() => mockSecureStorage.write(
            key: 'envified.audit_log',
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final entry = AuditEntry(
        timestamp: DateTime.now(),
        action: AuditAction.envSwitch,
        fromEnv: Env.dev,
        toEnv: Env.prod,
      );

      await storage.appendAuditEntry(entry);

      verify(() => mockSecureStorage.write(
            key: 'envified.audit_log',
            value: any(named: 'value', that: contains('dev')),
          )).called(1);
    });

    test('clear deletes all keys', () async {
      when(() => mockSecureStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await storage.clear();

      verify(() => mockSecureStorage.delete(key: 'envified.active_env'))
          .called(1);
      verify(() => mockSecureStorage.delete(key: 'envified.audit_log'))
          .called(1);
      verify(() => mockSecureStorage.delete(key: 'envified.url_history'))
          .called(1);
    });
  });
}

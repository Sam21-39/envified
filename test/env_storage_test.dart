import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/src/models/env.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('EnvStorage', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late EnvStorage storage;

    final testConfig = EnvConfig(
      env: Env.staging,
      baseUrl: 'https://staging.api.com',
      values: const {'TIMEOUT': '5000'},
      isBaseUrlOverridden: true,
      loadedAt: DateTime.now(),
    );

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      storage = EnvStorage(storage: mockSecureStorage);
    });

    test('saveConfig writes JSON to secure storage', () async {
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await storage.saveConfig(testConfig);

      verify(() => mockSecureStorage.write(
            key: 'envified_config',
            value: any(named: 'value', that: contains('staging')),
          )).called(1);
    });

    test('loadConfig restores EnvConfig from valid JSON', () async {
      const json =
          '{"env":"staging","baseUrl":"https://staging.api.com","values":{"TIMEOUT":"5000"},"isBaseUrlOverridden":true,"loadedAt":"2026-05-12T00:00:00.000"}';

      when(() => mockSecureStorage.read(key: 'envified_config'))
          .thenAnswer((_) async => json);

      final result = await storage.loadConfig();

      expect(result, isNotNull);
      expect(result!.env, Env.staging);
      expect(result.baseUrl, 'https://staging.api.com');
      expect(result.isBaseUrlOverridden, isTrue);
    });

    test('loadConfig returns null for empty/missing storage', () async {
      when(() => mockSecureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      expect(await storage.loadConfig(), isNull);
    });

    test(
        'loadConfig returns null and handles errors gracefully on malformed JSON',
        () async {
      when(() => mockSecureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => '{invalid_json}');

      expect(await storage.loadConfig(), isNull);
    });

    test('clear deletes the config key', () async {
      when(() => mockSecureStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await storage.clear();

      verify(() => mockSecureStorage.delete(key: 'envified_config')).called(1);
    });
  });
}

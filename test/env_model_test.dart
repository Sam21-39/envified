import 'package:flutter_test/flutter_test.dart';

import 'package:envified/envified.dart';

void main() {
  group('EnvConfig', () {
    const baseConfig = EnvConfig(
      env: Env.dev,
      baseUrl: 'https://dev.api.example.com',
      values: {'KEY': 'value', 'BASE_URL': 'https://dev.api.example.com'},
    );

    test('isBaseUrlOverridden defaults to false', () {
      expect(baseConfig.isBaseUrlOverridden, isFalse);
    });

    test('copyWith replaces only specified fields', () {
      final updated = baseConfig.copyWith(
        baseUrl: 'https://other.com',
        isBaseUrlOverridden: true,
      );
      expect(updated.env, Env.dev); // unchanged
      expect(updated.values, baseConfig.values); // unchanged
      expect(updated.baseUrl, 'https://other.com');
      expect(updated.isBaseUrlOverridden, isTrue);
    });

    test('copyWith with no args returns equivalent config', () {
      final copy = baseConfig.copyWith();
      expect(copy, equals(baseConfig));
    });

    test('toJson / fromJson roundtrip preserves all fields', () {
      final json = baseConfig.toJson();
      final restored = EnvConfig.fromJson(
        json.map((k, v) => MapEntry(k, v)),
      );
      expect(restored.env, baseConfig.env);
      expect(restored.baseUrl, baseConfig.baseUrl);
      expect(restored.values, baseConfig.values);
      expect(restored.isBaseUrlOverridden, baseConfig.isBaseUrlOverridden);
    });

    test('toJson / fromJson roundtrip with override set', () {
      final overridden = baseConfig.copyWith(
        baseUrl: 'https://custom.com',
        isBaseUrlOverridden: true,
      );
      final json = overridden.toJson();
      final restored = EnvConfig.fromJson(
        json.map((k, v) => MapEntry(k, v)),
      );
      expect(restored.isBaseUrlOverridden, isTrue);
      expect(restored.baseUrl, 'https://custom.com');
    });

    test('equality operator compares all fields', () {
      const a = EnvConfig(
        env: Env.prod,
        baseUrl: 'https://api.com',
        values: {'A': '1'},
      );
      const b = EnvConfig(
        env: Env.prod,
        baseUrl: 'https://api.com',
        values: {'A': '1'},
      );
      expect(a, equals(b));
    });

    test('equality operator detects difference in values map', () {
      const a = EnvConfig(
        env: Env.dev,
        baseUrl: 'https://dev.com',
        values: {'A': '1'},
      );
      const b = EnvConfig(
        env: Env.dev,
        baseUrl: 'https://dev.com',
        values: {'A': '2'},
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('Env', () {
    test('assetFileName returns correct filenames', () {
      expect(Env.dev.assetFileName, '.env.dev');
      expect(Env.staging.assetFileName, '.env.staging');
      expect(Env.prod.assetFileName, '.env.prod');
    });

    test('label returns display string', () {
      expect(Env.dev.label, 'Dev');
      expect(Env.staging.label, 'Staging');
      expect(Env.prod.label, 'Production');
    });

    test('Env.fromFileName parses correctly', () {
      expect(Env.fromFileName('.env.dev'), Env.dev);
      expect(Env.fromFileName('.env.future').name, 'future');
      expect(Env.fromFileName('.env.future').label, 'Future');
    });

    test('Env.fromFileName treats .env as Production', () {
      final env = Env.fromFileName('.env');
      expect(env.isProduction, isTrue);
      expect(env.label, 'Production');
    });

    test('isSensitiveKey detection rules', () {
      final service = EnvConfigService.instance;
      expect(service.isSensitive('STRIPE_KEY'), isTrue);
      expect(service.isSensitive('API_KEY'), isTrue);
      expect(service.isSensitive('PUBLIC_KEY'), isTrue);
      expect(service.isSensitive('KEY'), isTrue);
      expect(service.isSensitive('TIMEOUT'), isFalse);
      expect(service.isSensitive('MONKEY'), isFalse);
      expect(service.isSensitive('TURKEY'), isFalse);
    });
  });
}

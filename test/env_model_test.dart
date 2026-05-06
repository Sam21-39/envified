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
    test('assetPath returns correct paths', () {
      expect(Env.dev.assetPath, '.env.dev');
      expect(Env.staging.assetPath, '.env.staging');
      expect(Env.prod.assetPath, '.env.prod');
      expect(Env.custom.assetPath, isNull);
    });

    test('label returns short display string', () {
      expect(Env.dev.label, 'Dev');
      expect(Env.staging.label, 'Staging');
      expect(Env.prod.label, 'Prod');
      expect(Env.custom.label, 'Custom');
    });

    test('EnvX.fromName parses known names', () {
      expect(EnvX.fromName('dev'), Env.dev);
      expect(EnvX.fromName('staging'), Env.staging);
      expect(EnvX.fromName('prod'), Env.prod);
      expect(EnvX.fromName('custom'), Env.custom);
    });

    test('EnvX.fromName returns fallback for unknown name', () {
      expect(EnvX.fromName('unknown'), Env.dev);
      expect(EnvX.fromName('unknown', fallback: Env.staging), Env.staging);
    });
  });
}

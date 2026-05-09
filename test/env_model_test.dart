import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';

void main() {
  final now = DateTime.now();

  group('EnvConfig', () {
    final baseConfig = EnvConfig(
      env: Env.dev,
      baseUrl: 'https://dev.api.example.com',
      values: {'KEY': 'value', 'BASE_URL': 'https://dev.api.example.com'},
      loadedAt: now,
    );

    test('isBaseUrlOverridden defaults to false', () {
      expect(baseConfig.isBaseUrlOverridden, isFalse);
    });

    test('isBaseUrlOverridden returns true when baseUrl is different', () {
      final overridden = baseConfig.copyWith(baseUrl: 'https://custom.com');
      expect(overridden.isBaseUrlOverridden, isTrue);
    });

    test('copyWith replaces only specified fields', () {
      final updated = baseConfig.copyWith(
        baseUrl: 'https://other.com',
      );
      expect(updated.env, Env.dev); // unchanged
      expect(updated.values, baseConfig.values); // unchanged
      expect(updated.baseUrl, 'https://other.com');
    });

    test('copyWith with no args returns equivalent config', () {
      final copy = baseConfig.copyWith();
      expect(copy, equals(baseConfig));
    });

    test('equality operator compares fields', () {
      final a = EnvConfig(
        env: Env.prod,
        baseUrl: 'https://api.com',
        values: {'A': '1'},
        loadedAt: now,
      );
      final b = EnvConfig(
        env: Env.prod,
        baseUrl: 'https://api.com',
        values: {'A': '1'},
        loadedAt: now,
      );
      expect(a, equals(b));
    });

    test('equality operator detects difference in values map', () {
      final a = EnvConfig(
        env: Env.dev,
        baseUrl: 'https://dev.com',
        values: {'A': '1'},
        loadedAt: now,
      );
      final b = EnvConfig(
        env: Env.dev,
        baseUrl: 'https://dev.com',
        values: {'A': '2'},
        loadedAt: now,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('Env', () {
    test('label returns display string', () {
      expect(Env.dev.label, 'Dev');
      expect(Env.staging.label, 'Staging');
      expect(Env.prod.label, 'Prod');
    });

    test('Env.dynamic creates custom environments', () {
      final env = Env.dynamic('future');
      expect(env.name, 'future');
      expect(env.label, 'Future');
    });

    test('Env.dynamic with empty suffix returns dev', () {
      expect(Env.dynamic(''), Env.dev);
    });

    test('equality and hashcode', () {
      final e1 = Env.dynamic('test');
      final e2 = Env.dynamic('test');
      final e3 = Env.dynamic('other');

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1, isNot(equals(e3)));
    });
  });
}

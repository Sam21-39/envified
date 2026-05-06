import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';

void main() {
  group('EnvConfig', () {
    test('copyWith replaces only specified fields', () {
      const original = EnvConfig(
        env: Env.dev,
        baseUrl: 'https://dev.com',
        vars: {'KEY': 'val'},
      );
      final copy = original.copyWith(env: Env.prod);
      expect(copy.env, Env.prod);
      expect(copy.baseUrl, 'https://dev.com');
      expect(copy.vars, {'KEY': 'val'});
    });

    test('toJson / fromJson roundtrip (vars not persisted)', () {
      const config = EnvConfig(
        env: Env.staging,
        baseUrl: 'https://staging.appamania.in',
        vars: {'SECRET': 'should-not-persist'},
      );
      final json = config.toJson();

      // vars should NOT appear in toJson (security: never write secrets to disk)
      expect(json.containsKey('vars'), isFalse);

      final restored = EnvConfig.fromJson(json);
      expect(restored.env, Env.staging);
      expect(restored.baseUrl, 'https://staging.appamania.in');
      // vars are always empty after fromJson - resolved in memory at init
      expect(restored.vars, isEmpty);
    });

    test('equality is based on env and baseUrl only', () {
      const a = EnvConfig(
        env: Env.prod,
        baseUrl: 'https://api.appamania.in',
        vars: {'X': '1'},
      );
      const b = EnvConfig(
        env: Env.prod,
        baseUrl: 'https://api.appamania.in',
        vars: {'X': '2'},
      );
      expect(a, b); // vars do not affect equality
    });

    test('copyWith with new vars replaces vars', () {
      const original = EnvConfig(
        env: Env.dev,
        baseUrl: 'https://dev.com',
        vars: {'A': '1'},
      );
      final copy = original.copyWith(vars: {'A': '2', 'B': '3'});
      expect(copy.vars, {'A': '2', 'B': '3'});
    });
  });
}

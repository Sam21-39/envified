import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';

void main() {
  group('EnvConfig', () {
    test('copyWith replaces only specified fields', () {
      const original = EnvConfig(env: Env.dev, baseUrl: 'https://dev.com');
      final copy = original.copyWith(env: Env.prod);
      expect(copy.env, Env.prod);
      expect(copy.baseUrl, 'https://dev.com');
    });

    test('toJson / fromJson roundtrip', () {
      const config = EnvConfig(
        env: Env.staging,
        baseUrl: 'https://staging.appamania.in',
        extras: {'timeout': '30'},
      );
      final json = config.toJson();
      final restored = EnvConfig.fromJson(json);
      expect(restored, config);
    });

    test('equality ignores extras', () {
      const a = EnvConfig(env: Env.prod, baseUrl: 'https://api.appamania.in');
      const b = EnvConfig(
        env: Env.prod,
        baseUrl: 'https://api.appamania.in',
        extras: {'x': 'y'},
      );
      expect(a, b);
    });
  });
}

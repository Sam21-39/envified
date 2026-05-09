import 'package:envified/src/models/envified_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvifiedExceptions', () {
    test('EnvifiedLockException toString', () {
      final ex = EnvifiedLockException('Locked');
      expect(ex.toString(), contains('EnvifiedLockException: Locked'));
    });

    test('EnvifiedUrlNotAllowedException toString', () {
      final ex = EnvifiedUrlNotAllowedException('https://evil.com');
      expect(ex.toString(),
          contains('URL "https://evil.com" is not in the allowlist'));
    });

    test('EnvifiedTamperException toString', () {
      final ex = EnvifiedTamperException('.env.prod');
      expect(ex.toString(), contains('Integrity check failed for .env.prod'));
    });
  });
}

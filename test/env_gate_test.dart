import 'package:envified/src/gate/env_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvGate', () {
    test('verify returns true for correct pin', () {
      final gate = EnvGate(pin: '1234');
      expect(gate.verify('1234'), isTrue);
    });

    test('verify returns false for incorrect pin', () {
      final gate = EnvGate(pin: '1234');
      expect(gate.verify('0000'), isFalse);
    });

    test('hashes are different for different pins', () {
      final gate1 = EnvGate(pin: '1234');
      final gate2 = EnvGate(pin: '1235');
      // We can't access _hashedPin directly, but verify proves they are different
      expect(gate1.verify('1235'), isFalse);
      expect(gate2.verify('1234'), isFalse);
    });
  });
}

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// A secure access gate for the debug panel.
///
/// Uses SHA-256 hashing with a static salt to verify PIN attempts without
/// ever storing the plain text PIN in memory or storage.
class EnvGate {
  final String _hashedPin;

  /// Creates a gate with a required [pin].
  EnvGate({required String pin}) : _hashedPin = _hash(pin);

  static String _hash(String pin) {
    // Salt with a package-specific prefix to prevent rainbow table attacks.
    const salt = 'envified.gate.v1:';
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }

  /// Verifies if the provided [attempt] matches the original PIN.
  bool verify(String attempt) => _hash(attempt) == _hashedPin;
}

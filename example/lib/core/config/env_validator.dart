class EnvifiedSecurityException implements Exception {
  final String message;
  final String key;
  EnvifiedSecurityException(this.message, this.key);

  @override
  String toString() => 'EnvifiedSecurityException: $message (Key: "$key")';
}

class EnvValidator {
  static const List<String> blockedPatterns = [
    'SECRET',
    'PASSWORD',
    'TOKEN',
    'PRIVATE',
    'KEY',
    'AUTH'
  ];

  /// Checks key names in non-sensitive configurations for security patterns.
  /// Throws [EnvifiedSecurityException] strictly in production mode.
  static void validate(Map<String, String> config,
      {required bool isProduction}) {
    for (final entry in config.entries) {
      final upperKey = entry.key.toUpperCase();
      for (final pattern in blockedPatterns) {
        if (upperKey.contains(pattern)) {
          if (isProduction) {
            throw EnvifiedSecurityException(
              'Sensitive key pattern "$pattern" detected inside plain runtime config asset.',
              entry.key,
            );
          }
        }
      }
    }
  }
}

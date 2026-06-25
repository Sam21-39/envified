import '../models/env_tier.dart';

/// Routes a key lookup to the correct [EnvTier] based on `envified.yaml`
/// `key_types` configuration.
///
/// Keys not present in [keyTypes] default to [EnvTier.runtime].
class TierResolver {
  /// Maps key names (uppercase) to their assigned tier.
  final Map<String, EnvTier> keyTypes;

  /// Glob-style patterns that always route to [EnvTier.secret].
  final List<String> sensitiveKeyPatterns;

  const TierResolver({
    this.keyTypes = const {},
    this.sensitiveKeyPatterns = const [
      'API_KEY',
      'SECRET',
      'TOKEN',
      'PASSWORD',
      'PRIVATE_KEY',
      'AUTH_TOKEN',
      'JWT',
      'OAUTH_SECRET',
    ],
  });

  /// Resolves the [EnvTier] for [key].
  EnvTier resolve(String key) {
    final upper = key.toUpperCase();

    // Explicit mapping wins.
    if (keyTypes.containsKey(upper)) return keyTypes[upper]!;

    // Sensitive-pattern heuristic → secret tier.
    for (final pattern in sensitiveKeyPatterns) {
      if (upper.contains(pattern.toUpperCase())) return EnvTier.secret;
    }

    return EnvTier.runtime;
  }

  /// Returns true if [key] should never appear as a plain Dart string.
  bool isSecret(String key) => resolve(key) != EnvTier.runtime;
}

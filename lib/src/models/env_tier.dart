/// The security tier assigned to a configuration key.
///
/// - [runtime] — Tier 1: decrypted at init time, returned as a plain Dart
///   value via the method channel. Suitable for `BASE_URL`, feature flags, etc.
/// - [secret] — Tier 2: stays encrypted in native storage; accessed only via
///   [SecretHandle.resolve] — never materialised as a long-lived Dart [String].
/// - [remote] — Tier 3: never compiled into the binary; fetched from a
///   developer-operated delivery endpoint on first launch.
enum EnvTier { runtime, secret, remote }

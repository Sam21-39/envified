/// Exception thrown when an action is blocked by the production lock.
///
/// This exception is raised by [EnvConfigService] when a caller attempts to
/// switch environments or override the base URL while the active environment
/// is [Env.prod] and `allowProdSwitch` was set to `false` during
/// [EnvConfigService.init].
///
/// Example:
/// ```dart
/// try {
///   await EnvConfigService.instance.setBaseUrl('https://other.com');
/// } on EnvifiedLockException catch (e) {
///   print(e.message); // "Locked in production"
/// }
/// ```
///
/// @see EnvConfigService.init
/// @see EnvConfigService.switchTo
/// @see EnvConfigService.setBaseUrl
/// @see EnvConfigService.clearBaseUrlOverride
class EnvifiedLockException implements Exception {
  /// Human-readable reason for the lock violation.
  final String message;

  /// Creates an [EnvifiedLockException] with the given [message].
  const EnvifiedLockException(this.message);

  @override
  String toString() => 'EnvifiedLockException: $message';
}

/// Exception thrown when an `.env*` asset file fails an integrity check.
///
/// [EnvFileParser.verifyIntegrity] computes a SHA-256 hash of each `.env*`
/// file on first load and stores it securely. On subsequent loads the hash is
/// recomputed and compared. If the hashes differ this exception is thrown,
/// indicating that the file was modified after the app was first run —
/// a potential sign of tampering.
///
/// Example:
/// ```dart
/// try {
///   await EnvConfigService.instance.init(
///     defaultEnv: Env.dev,
///     verifyIntegrity: true,
///   );
/// } on EnvifiedTamperException catch (e) {
///   print(e); // EnvifiedTamperException: .env file ".env.dev" has been modified ...
/// }
/// ```
///
/// @see EnvConfigService.init
/// @see EnvFileParser.verifyIntegrity
class EnvifiedTamperException implements Exception {
  /// The asset path of the file whose integrity check failed.
  final String assetPath;

  /// Creates an [EnvifiedTamperException] for the given [assetPath].
  const EnvifiedTamperException(this.assetPath);

  @override
  String toString() =>
      'EnvifiedTamperException: .env file "$assetPath" has been modified '
      'since first load. This may indicate tampering.';
}

/// Exception thrown when [EnvConfigService.setBaseUrl] is called with a URL
/// that is not in the optional allowlist provided during
/// [EnvConfigService.init].
///
/// Example:
/// ```dart
/// try {
///   await EnvConfigService.instance.setBaseUrl('https://evil.example.com');
/// } on EnvifiedUrlNotAllowedException catch (e) {
///   print(e); // EnvifiedUrlNotAllowedException: URL "https://evil.example.com" is not in the allowed list.
/// }
/// ```
class EnvifiedUrlNotAllowedException implements Exception {
  /// The URL that was rejected.
  final String url;

  /// Creates an [EnvifiedUrlNotAllowedException] for the given [url].
  const EnvifiedUrlNotAllowedException(this.url);

  @override
  String toString() =>
      'EnvifiedUrlNotAllowedException: URL "$url" is not in the allowed list.';
}

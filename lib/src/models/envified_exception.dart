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
/// Thrown when a `.env` file's contents differ from the hash recorded
/// on first load, indicating possible tampering.
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

/// Exception thrown when auto-discovery fails to find any `.env.*` files.
///
/// Thrown by [EnvConfigService.init] when `autoDiscover` is `true` but no
/// matching assets are found in the bundle manifest.
class EnvifiedMissingFileException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Creates an [EnvifiedMissingFileException] with the given [message].
  const EnvifiedMissingFileException(this.message);

  @override
  String toString() => 'EnvifiedMissingFileException: $message';
}

/// Exception thrown when the native platform layer returns an error.
///
/// Wraps a [PlatformException] from the `in.appamania.envified/channel`
/// method channel into a typed Dart exception.
class EnvifiedNativeException implements Exception {
  /// The platform error code, e.g. `ENVIFIED_KEY_NOT_FOUND`.
  final String code;

  /// Human-readable description of the error.
  final String message;

  const EnvifiedNativeException({required this.code, required this.message});

  @override
  String toString() => 'EnvifiedNativeException[$code]: $message';
}

/// Exception thrown when an environment switch fails mid-lifecycle and is
/// rolled back.
///
/// [failedAdapter] identifies which service adapter caused the failure.
class EnvifiedSwitchException implements Exception {
  /// The name of the adapter that threw during [reinitialize].
  final String failedAdapter;

  /// The underlying error.
  final Object cause;

  const EnvifiedSwitchException({
    required this.failedAdapter,
    required this.cause,
  });

  @override
  String toString() =>
      'EnvifiedSwitchException: adapter "$failedAdapter" failed — $cause';
}

/// Exception thrown when key rotation fails or produces an inconsistent state.
class EnvifiedKeyRotationException implements Exception {
  final String message;

  const EnvifiedKeyRotationException(this.message);

  @override
  String toString() => 'EnvifiedKeyRotationException: $message';
}

/// Exception thrown when an action is blocked by the production lock.
///
/// This exception is raised by [EnvConfigService] when a caller attempts to
/// switch environments or override the base URL while the active environment
/// is [Env.prod] and `allowProdSwitch` was set to `false` during [EnvConfigService.init].
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

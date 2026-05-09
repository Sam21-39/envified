/// Exception thrown when an action is blocked due to production lock.
class EnvifiedLockException implements Exception {
  final String message;
  EnvifiedLockException(
      [this.message = 'Action blocked: Production is locked.']);

  @override
  String toString() => 'EnvifiedLockException: $message';
}

/// Exception thrown when a base URL override is not in the allowlist.
class EnvifiedUrlNotAllowedException implements Exception {
  final String url;
  EnvifiedUrlNotAllowedException(this.url);

  @override
  String toString() =>
      'EnvifiedUrlNotAllowedException: URL "$url" is not in the allowlist.';
}

/// Exception thrown when an environment file fails integrity verification.
class EnvifiedTamperException implements Exception {
  final String path;
  EnvifiedTamperException(this.path);

  @override
  String toString() =>
      'EnvifiedTamperException: Integrity check failed for $path.';
}

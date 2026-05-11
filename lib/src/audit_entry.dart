import 'dart:convert';

/// An immutable record of a single action performed by [EnvConfigService].
///
/// [AuditEntry] instances are appended to secure storage by every mutating
/// operation on the service and can be retrieved via
/// [EnvConfigService.auditLog].
///
/// The log retains at most 50 entries; older entries are dropped when the
/// limit is reached.
///
/// Example:
/// ```dart
/// final log = await EnvConfigService.instance.auditLog;
/// for (final entry in log) {
///   print('${entry.timestamp} — ${entry.action}');
/// }
/// ```
///
/// @see EnvConfigService.auditLog
class AuditEntry {
  /// When the action occurred (UTC).
  final DateTime timestamp;

  /// The action that was performed.
  ///
  /// One of: `'switch'`, `'setBaseUrl'`, `'clearOverride'`, `'reset'`.
  final String action;

  /// The environment name before a `'switch'` action, or `null` otherwise.
  final String? fromEnv;

  /// The environment name after a `'switch'` action, or `null` otherwise.
  final String? toEnv;

  /// The URL affected by a `'setBaseUrl'` action, or `null` otherwise.
  final String? url;

  /// Creates an [AuditEntry].
  const AuditEntry({
    required this.timestamp,
    required this.action,
    this.fromEnv,
    this.toEnv,
    this.url,
  });

  /// Serialises this entry to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        if (fromEnv != null) 'fromEnv': fromEnv,
        if (toEnv != null) 'toEnv': toEnv,
        if (url != null) 'url': url,
      };

  /// Deserialises an [AuditEntry] from a JSON-compatible [j] map.
  factory AuditEntry.fromJson(Map<String, dynamic> j) {
    return AuditEntry(
      timestamp: DateTime.parse(j['timestamp'] as String),
      action: j['action'] as String,
      fromEnv: j['fromEnv'] as String?,
      toEnv: j['toEnv'] as String?,
      url: j['url'] as String?,
    );
  }

  /// Serialises this entry to a JSON string for storage.
  String toJsonString() => jsonEncode(toJson());

  /// Deserialises an [AuditEntry] from a JSON string.
  factory AuditEntry.fromJsonString(String source) {
    final dynamic decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return AuditEntry.fromJson(decoded);
    }
    throw FormatException('Invalid AuditEntry JSON: $source');
  }

  @override
  String toString() => 'AuditEntry(timestamp: $timestamp, action: $action, '
      'fromEnv: $fromEnv, toEnv: $toEnv, url: $url)';
}

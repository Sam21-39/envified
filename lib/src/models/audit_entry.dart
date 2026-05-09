import 'package:flutter/foundation.dart';
import 'env.dart';

/// Supported actions that can be recorded in the audit log.
enum AuditAction {
  /// Switched from one environment to another.
  envSwitch,

  /// Overrode the base URL manually.
  urlOverride,

  /// Reset the base URL to the .env default.
  urlReset,

  /// Full storage reset.
  reset,
}

/// A single record in the encrypted audit log.
@immutable
class AuditEntry {
  final DateTime timestamp;
  final AuditAction action;
  final Env? fromEnv;
  final Env? toEnv;
  final String? url;

  const AuditEntry({
    required this.timestamp,
    required this.action,
    this.fromEnv,
    this.toEnv,
    this.url,
  });

  /// Serializes the [AuditEntry] to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'action': action.name,
        if (fromEnv != null) 'fromEnv': fromEnv!.name,
        if (toEnv != null) 'toEnv': toEnv!.name,
        if (url != null) 'url': url,
      };

  /// Deserializes an [AuditEntry] from a JSON map.
  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        action: AuditAction.values.byName(json['action'] as String),
        fromEnv: json['fromEnv'] != null
            ? Env.dynamic(json['fromEnv'] as String)
            : null,
        toEnv: json['toEnv'] != null
            ? Env.dynamic(json['toEnv'] as String)
            : null,
        url: json['url'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEntry &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          action == other.action &&
          fromEnv == other.fromEnv &&
          toEnv == other.toEnv &&
          url == other.url;

  @override
  int get hashCode =>
      timestamp.hashCode ^
      action.hashCode ^
      fromEnv.hashCode ^
      toEnv.hashCode ^
      url.hashCode;
}

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A single record in the encrypted audit log.
@immutable
class AuditEntry {
  /// The time at which the action occurred.
  final DateTime timestamp;

  /// The type of action performed.
  ///
  /// One of: 'switch', 'setBaseUrl', 'clearOverride', 'reset'.
  final String action;

  /// The environment name before the change (if applicable).
  final String? fromEnv;

  /// The environment name after the change (if applicable).
  final String? toEnv;

  /// The manual URL override applied (if applicable).
  final String? url;

  /// Creates a new audit entry.
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
        'action': action,
        if (fromEnv != null) 'fromEnv': fromEnv,
        if (toEnv != null) 'toEnv': toEnv,
        if (url != null) 'url': url,
      };

  /// Deserializes an [AuditEntry] from a JSON map.
  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        action: json['action'] as String,
        fromEnv: json['fromEnv'] as String?,
        toEnv: json['toEnv'] as String?,
        url: json['url'] as String?,
      );

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

  @override
  String toString() => 'AuditEntry(timestamp: $timestamp, action: $action, '
      'fromEnv: $fromEnv, toEnv: $toEnv, url: $url)';
}

/// Formats an audit timestamp as MM-dd-YYYY HH:mm:ss in local time.
String formatAuditTimestamp(DateTime dt) {
  final local = dt.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$mm-$dd-$yyyy $hh:$min:$ss';
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/audit_entry.dart';
import '../models/env.dart';

/// Internal wrapper for [FlutterSecureStorage] to persist environment settings.
///
/// Uses AES encryption (on Android) and Keychain (on iOS) to ensure that
/// even runtime configuration overrides and audit logs are stored securely.
///
/// In addition to the main [EnvConfig], this class manages:
/// - A URL history list (max 5 entries) under [_kUrlHistoryKey].
/// - An audit log (max [_kMaxAuditEntries] entries) under [_kAuditKey].
/// - Arbitrary raw key-value pairs used by [EnvFileParser.verifyIntegrity].
class EnvStorage {
  static const String _keyConfig = 'envified_config';
  static const String _kUrlHistoryKey = 'envified_url_history_v1';
  static const String _kAuditKey = 'envified_audit_v1';
  static const String _kOverridesKey = 'envified_overrides_v1';
  static const int _kMaxAuditEntries = 50;
  static const int _kMaxUrlHistory = 5;

  final FlutterSecureStorage _storage;

  /// Creates an [EnvStorage] instance.
  const EnvStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  // ── Config ─────────────────────────────────────────────────────────────────

  /// Persists the [config] to secure storage.
  Future<void> saveConfig(EnvConfig config) async {
    final String json = jsonEncode(config.toJson());
    await _storage.write(key: _keyConfig, value: json);
  }

  /// Restores the [EnvConfig] from secure storage.
  ///
  /// Returns `null` if no configuration is persisted.
  Future<EnvConfig?> loadConfig() async {
    try {
      final String? json = await _storage.read(key: _keyConfig);
      if (json == null || json.isEmpty) return null;

      final dynamic map = jsonDecode(json);
      if (map is Map<String, dynamic>) {
        return EnvConfig.fromJson(map);
      }
    } catch (_) {
      // If parsing fails or storage is corrupted, return null to fallback to defaults.
    }
    return null;
  }

  /// Clears all persisted environment settings, URL history, and audit log.
  Future<void> clear() async {
    await _storage.delete(key: _keyConfig);
    await _storage.delete(key: _kUrlHistoryKey);
    await _storage.delete(key: _kAuditKey);
    await _storage.delete(key: _kOverridesKey);
  }

  // ── Raw key-value (used by integrity hashes) ───────────────────────────────

  /// Reads a raw string value for [key] from secure storage.
  ///
  /// Returns `null` if the key does not exist.
  Future<String?> readRaw(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  /// Writes a raw [value] string under [key] in secure storage.
  Future<void> writeRaw(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // ── URL History ────────────────────────────────────────────────────────────

  /// Prepends [url] to the persisted URL history list.
  ///
  /// - Deduplicates: if [url] already appears in the list it is moved to the
  ///   front rather than added again.
  /// - Trims: the list is capped at 5 items. Older entries are discarded.
  /// - Persists: the updated list is written to secure storage under
  ///   [_kUrlHistoryKey] as a JSON array of strings.
  Future<void> saveUrlToHistory(String url) async {
    final List<String> history = await loadUrlHistory();

    // Move to front if already present, otherwise prepend.
    history.remove(url);
    history.insert(0, url);

    // Enforce maximum size.
    final List<String> trimmed = history.take(_kMaxUrlHistory).toList();

    await _storage.write(
      key: _kUrlHistoryKey,
      value: jsonEncode(trimmed),
    );
  }

  /// Returns the list of recently used URLs, newest first.
  ///
  /// Returns an empty list if no history has been saved or if parsing fails.
  Future<List<String>> loadUrlHistory() async {
    try {
      final String? raw = await _storage.read(key: _kUrlHistoryKey);
      if (raw == null || raw.isEmpty) return <String>[];

      final dynamic decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // Corrupted data — return empty list.
    }
    return <String>[];
  }

  // ── Audit Log ──────────────────────────────────────────────────────────────

  /// Appends [entry] to the secure audit log.
  ///
  /// Entries are stored as a JSON array. Once the log reaches
  /// [_kMaxAuditEntries] the oldest entry is dropped.
  Future<void> appendAudit(AuditEntry entry) async {
    final List<AuditEntry> existing = await loadAuditLog();
    existing.insert(0, entry);

    // Enforce maximum log size.
    final List<AuditEntry> trimmed = existing.take(_kMaxAuditEntries).toList();

    final List<Map<String, dynamic>> jsonList =
        trimmed.map((e) => e.toJson()).toList();

    await _storage.write(
      key: _kAuditKey,
      value: jsonEncode(jsonList),
    );
  }

  /// Returns all persisted [AuditEntry] records, newest first.
  ///
  /// Returns an empty list if no log exists or if parsing fails.
  Future<List<AuditEntry>> loadAuditLog() async {
    try {
      final String? raw = await _storage.read(key: _kAuditKey);
      if (raw == null || raw.isEmpty) return <AuditEntry>[];

      final dynamic decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(AuditEntry.fromJson)
            .toList();
      }
    } catch (_) {
      // Corrupted data — return empty list.
    }
    return <AuditEntry>[];
  }

  // ── Overrides ──────────────────────────────────────────────────────────────

  /// Persists the map of per-environment URL overrides.
  Future<void> saveOverrides(Map<String, String> overrides) async {
    await _storage.write(
      key: _kOverridesKey,
      value: jsonEncode(overrides),
    );
  }

  /// Restores the map of per-environment URL overrides.
  Future<Map<String, String>> loadOverrides() async {
    try {
      final String? raw = await _storage.read(key: _kOverridesKey);
      if (raw == null || raw.isEmpty) return <String, String>{};

      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, String>.from(decoded);
      }
    } catch (_) {
      // Corrupted data.
    }
    return <String, String>{};
  }
}

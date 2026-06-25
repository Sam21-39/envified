import 'dart:convert';

import '../channel/envified_channel.dart';
import '../models/audit_entry.dart';
import '../models/env.dart';

/// Persistence layer for environment config, audit log, URL history, and
/// per-environment URL overrides.
///
/// All storage is delegated to the native method channel ([EnvifiedChannel]),
/// which uses Android Keystore / iOS Keychain-backed encrypted storage.
/// There is no dependency on `flutter_secure_storage`.
class EnvStorage {
  static const int _kMaxAuditEntries = 50;
  static const int _kMaxUrlHistory = 5;
  static const String _kUrlHistoryKey = 'url_history';
  static const String _kOverridesKey = 'url_overrides';

  final EnvifiedChannel _channel;

  const EnvStorage({required EnvifiedChannel channel}) : _channel = channel;

  // ── Config ─────────────────────────────────────────────────────────────────

  /// Persists [config] via the native channel.
  Future<void> saveConfig(EnvConfig config) async {
    await _channel.persistConfig(
      configJson: jsonEncode(config.toJson()),
      env: config.env.name,
    );
  }

  /// Restores the [EnvConfig] from native storage. Returns null if none exists.
  Future<EnvConfig?> loadConfig({required String envName}) async {
    try {
      final json = await _channel.loadConfig(env: envName);
      if (json == null || json.isEmpty) return null;
      final dynamic map = jsonDecode(json);
      if (map is Map<String, dynamic>) return EnvConfig.fromJson(map);
    } catch (_) {
      // Corrupted or missing — fall back to defaults.
    }
    return null;
  }

  /// Clears all persisted state (config, overrides, audit log, URL history).
  Future<void> clear() async {
    await _channel.clearConfig();
  }

  // ── Raw key-value (used by integrity hashes & misc metadata) ──────────────

  /// Reads a raw string value from native storage. Returns null if not found.
  Future<String?> readRaw(String key) async {
    return _channel.loadConfig(env: 'raw_$key');
  }

  /// Writes a raw string value to native storage.
  Future<void> writeRaw(String key, String value) async {
    await _channel.persistConfig(configJson: value, env: 'raw_$key');
  }

  // ── URL History ────────────────────────────────────────────────────────────

  /// Prepends [url] to the URL history, deduplicating and capping at 5 items.
  Future<void> saveUrlToHistory(String url) async {
    final history = await loadUrlHistory();
    history.remove(url);
    history.insert(0, url);
    final trimmed = history.take(_kMaxUrlHistory).toList();
    await _channel.persistConfig(
      configJson: jsonEncode(trimmed),
      env: _kUrlHistoryKey,
    );
  }

  /// Returns URL history, newest first. Empty list on failure.
  Future<List<String>> loadUrlHistory() async {
    try {
      final raw = await _channel.loadConfig(env: _kUrlHistoryKey);
      if (raw == null || raw.isEmpty) return <String>[];
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return <String>[];
  }

  // ── Audit Log ──────────────────────────────────────────────────────────────

  /// Appends [entry] to the audit log. Oldest entry dropped when over 50.
  Future<void> appendAudit(AuditEntry entry) async {
    await _channel.appendAuditEntry(entryJson: jsonEncode(entry.toJson()));
  }

  /// Returns all audit entries, newest first.
  Future<List<AuditEntry>> loadAuditLog() async {
    try {
      final entries = await _channel.loadAuditLog();
      return entries
          .map((e) {
            try {
              final dynamic m = jsonDecode(e);
              if (m is Map<String, dynamic>) return AuditEntry.fromJson(m);
            } catch (_) {}
            return null;
          })
          .whereType<AuditEntry>()
          .toList()
          .reversed
          .take(_kMaxAuditEntries)
          .toList();
    } catch (_) {
      return <AuditEntry>[];
    }
  }

  // ── Overrides ──────────────────────────────────────────────────────────────

  /// Persists per-environment URL overrides map.
  Future<void> saveOverrides(Map<String, String> overrides) async {
    await _channel.persistConfig(
      configJson: jsonEncode(overrides),
      env: _kOverridesKey,
    );
  }

  /// Loads per-environment URL overrides map.
  Future<Map<String, String>> loadOverrides() async {
    try {
      final raw = await _channel.loadConfig(env: _kOverridesKey);
      if (raw == null || raw.isEmpty) return <String, String>{};
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, String>.from(decoded);
    } catch (_) {}
    return <String, String>{};
  }
}

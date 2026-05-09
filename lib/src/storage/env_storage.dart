import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/audit_entry.dart';

/// Abstract interface for environment configuration storage.
///
/// Enables easy mocking for unit tests.
abstract interface class EnvStorageInterface {
  /// Persists the name of the active environment.
  Future<void> saveActiveEnv(String envName);

  /// Loads the name of the active environment.
  Future<String?> loadActiveEnv();

  /// Persists the SHA-256 hash of an environment file.
  Future<void> saveHash(String envName, String hash);

  /// Loads the saved SHA-256 hash of an environment file.
  Future<String?> loadHash(String envName);

  /// Appends a new entry to the audit log.
  Future<void> appendAuditEntry(AuditEntry entry);

  /// Loads the entire audit log.
  Future<List<AuditEntry>> loadAuditLog();

  /// Adds a URL to the history of manual overrides.
  Future<void> saveUrlToHistory(String url);

  /// Loads the history of base URL overrides.
  Future<List<String>> loadUrlHistory();

  /// Clears all envified-related storage.
  Future<void> clear();
}

/// Concrete implementation of [EnvStorageInterface] using [FlutterSecureStorage].
class EnvStorage implements EnvStorageInterface {
  final FlutterSecureStorage _store;

  static const _keyActiveEnv = 'envified.active_env';
  static const _keyHashPrefix = 'envified.hash.';
  static const _keyAuditLog = 'envified.audit_log';
  static const _keyUrlHistory = 'envified.url_history';

  static const _auditLogMaxEntries = 50;
  static const _urlHistoryMax = 5;

  const EnvStorage({FlutterSecureStorage? store})
      : _store = store ?? const FlutterSecureStorage();

  @override
  Future<void> saveActiveEnv(String envName) =>
      _store.write(key: _keyActiveEnv, value: envName);

  @override
  Future<String?> loadActiveEnv() => _store.read(key: _keyActiveEnv);

  @override
  Future<void> saveHash(String envName, String hash) =>
      _store.write(key: '$_keyHashPrefix$envName', value: hash);

  @override
  Future<String?> loadHash(String envName) =>
      _store.read(key: '$_keyHashPrefix$envName');

  @override
  Future<void> appendAuditEntry(AuditEntry entry) async {
    final existing = await loadAuditLog();
    final updated = [...existing, entry];

    // Ring buffer: keep only the most recent N entries
    final capped = updated.length > _auditLogMaxEntries
        ? updated.sublist(updated.length - _auditLogMaxEntries)
        : updated;

    final encoded = jsonEncode(capped.map((e) => e.toJson()).toList());
    await _store.write(key: _keyAuditLog, value: encoded);
  }

  @override
  Future<List<AuditEntry>> loadAuditLog() async {
    final raw = await _store.read(key: _keyAuditLog);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return []; // Return empty on corruption
    }
  }

  @override
  Future<void> saveUrlToHistory(String url) async {
    final history = await loadUrlHistory();
    // Move to top, remove duplicates, take top 5
    final updated = [url, ...history.where((u) => u != url)]
        .take(_urlHistoryMax)
        .toList();
    await _store.write(key: _keyUrlHistory, value: jsonEncode(updated));
  }

  @override
  Future<List<String>> loadUrlHistory() async {
    final raw = await _store.read(key: _keyUrlHistory);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _store.delete(key: _keyActiveEnv),
      _store.delete(key: _keyAuditLog),
      _store.delete(key: _keyUrlHistory),
    ]);
  }
}

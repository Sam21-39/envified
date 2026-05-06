import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'env_model.dart';

// Versioned key - bump suffix if the schema ever changes
const _kStorageKey = 'envified_config_v2';

/// Internal storage adapter. Uses flutter_secure_storage (Keychain on iOS,
/// Keystore on Android) to securely persist the active environment selection.
///
/// SECURITY NOTE: Only the environment name and base URL are persisted.
/// Environment variables (vars) are NEVER written to disk - they are always
/// resolved from in-memory compile-time definitions on each app start.
class EnvStorage {
  final _storage = const FlutterSecureStorage();

  Future<void> save(EnvConfig config) async {
    await _storage.write(
      key: _kStorageKey,
      value: jsonEncode(config.toJson()),
    );
  }

  Future<EnvConfig?> load() async {
    final raw = await _storage.read(key: _kStorageKey);
    if (raw == null) return null;
    try {
      return EnvConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt data - wipe and return null
      await _storage.delete(key: _kStorageKey);
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kStorageKey);
  }
}

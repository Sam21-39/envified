import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'env_model.dart';

/// Internal wrapper for [FlutterSecureStorage] to persist environment settings.
///
/// Uses AES encryption (on Android) and Keychain (on iOS) to ensure that
/// even runtime configuration overrides are stored securely.
class EnvStorage {
  static const String _keyConfig = 'envified_config';

  final FlutterSecureStorage _storage;

  /// Creates an [EnvStorage] instance.
  const EnvStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

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

  /// Clears all persisted environment settings.
  Future<void> clear() async {
    await _storage.delete(key: _keyConfig);
  }
}

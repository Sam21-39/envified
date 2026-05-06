import 'package:shared_preferences/shared_preferences.dart';

import 'env_model.dart';

/// Internal persistence layer for [EnvConfigService].
///
/// This class is **not exported** from the public API. It wraps
/// [SharedPreferences] to read and write the three pieces of state that must
/// survive app restarts:
///
/// | Preference key              | Purpose                                  |
/// |-----------------------------|------------------------------------------|
/// | [_keyEnv]                   | The name of the last-selected [Env]      |
/// | [_keyBaseUrl]               | A manually overridden base URL           |
/// | [_keyCustomUrl]             | The base URL for [Env.custom]            |
///
/// @see EnvConfigService
class EnvStorage {
  /// SharedPreferences key for the persisted [Env] selection.
  static const String _keyEnv = 'envified_env_v1';

  /// SharedPreferences key for the manually overridden base URL.
  static const String _keyBaseUrl = 'envified_base_url_v1';

  /// SharedPreferences key for the [Env.custom] base URL.
  static const String _keyCustomUrl = 'envified_custom_url_v1';

  final SharedPreferences _prefs;

  /// Creates an [EnvStorage] backed by the supplied [SharedPreferences]
  /// instance.
  const EnvStorage(this._prefs);

  /// Factory that asynchronously obtains a [SharedPreferences] instance and
  /// returns a ready-to-use [EnvStorage].
  static Future<EnvStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return EnvStorage(prefs);
  }

  // ── Env selection ────────────────────────────────────────────────────────

  /// Reads the persisted [Env] name, returning [fallback] if none is stored.
  Env readEnv({Env fallback = Env.dev}) {
    final stored = _prefs.getString(_keyEnv);
    if (stored == null) return fallback;
    return EnvX.fromName(stored, fallback: fallback);
  }

  /// Persists [env] so it can be restored on the next app launch.
  Future<void> writeEnv(Env env) =>
      _prefs.setString(_keyEnv, env.name);

  /// Clears the persisted [Env] selection.
  Future<void> clearEnv() => _prefs.remove(_keyEnv);

  // ── Base URL override ────────────────────────────────────────────────────

  /// Reads the persisted base URL override, returning `null` if none exists.
  String? readBaseUrlOverride() => _prefs.getString(_keyBaseUrl);

  /// Persists a base URL override.
  Future<void> writeBaseUrlOverride(String url) =>
      _prefs.setString(_keyBaseUrl, url);

  /// Clears the persisted base URL override.
  Future<void> clearBaseUrlOverride() => _prefs.remove(_keyBaseUrl);

  // ── Custom env URL ───────────────────────────────────────────────────────

  /// Reads the persisted [Env.custom] base URL, returning `null` if not set.
  String? readCustomUrl() => _prefs.getString(_keyCustomUrl);

  /// Persists the [Env.custom] base URL.
  Future<void> writeCustomUrl(String url) =>
      _prefs.setString(_keyCustomUrl, url);

  /// Clears the persisted [Env.custom] base URL.
  Future<void> clearCustomUrl() => _prefs.remove(_keyCustomUrl);

  // ── Full reset ───────────────────────────────────────────────────────────

  /// Clears all envified-related keys from [SharedPreferences].
  Future<void> clearAll() async {
    await Future.wait(<Future<bool>>[
      _prefs.remove(_keyEnv),
      _prefs.remove(_keyBaseUrl),
      _prefs.remove(_keyCustomUrl),
    ]);
  }
}

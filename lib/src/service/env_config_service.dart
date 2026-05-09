import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import '../models/audit_entry.dart';
import '../models/env.dart';
import '../models/env_config.dart';
import '../models/envified_exception.dart';
import '../parser/env_file_parser.dart';
import '../storage/env_storage.dart';

/// The core service responsible for managing environment configurations.
///
/// This service handles initialization, environment switching, base URL
/// overrides, and provides reactive updates via [ValueNotifier].
class EnvConfigService {
  EnvConfigService._({
    required EnvStorageInterface storage,
    required EnvFileParser parser,
  })  : _storage = storage,
        _parser = parser;

  static EnvConfigService? _instance;

  /// Returns the singleton instance of [EnvConfigService].
  static EnvConfigService get instance {
    _instance ??= EnvConfigService._(
      storage: const EnvStorage(),
      parser: const EnvFileParser(),
    );
    return _instance!;
  }

  /// Overrides the singleton instance for testing purposes.
  @visibleForTesting
  static void overrideForTesting({
    required EnvStorageInterface storage,
    required EnvFileParser parser,
  }) {
    _instance = EnvConfigService._(storage: storage, parser: parser);
  }

  /// Resets the singleton instance (primarily for tests).
  @visibleForTesting
  static void resetInstance() => _instance = null;

  final EnvStorageInterface _storage;
  final EnvFileParser _parser;

  /// The current active configuration.
  final ValueNotifier<EnvConfig> current = ValueNotifier(_defaultConfig);

  /// Whether a restart is recommended due to configuration changes.
  final ValueNotifier<bool> restartNeeded = ValueNotifier(false);

  /// The list of recent audit entries.
  final ValueNotifier<List<AuditEntry>> auditLog = ValueNotifier([]);

  EnvConfig? _initialConfig;
  bool _allowProdSwitch = true;

  /// Whether switching away from production is allowed.
  bool get allowProdSwitch => _allowProdSwitch;

  /// Returns true if the service is currently in production and [allowProdSwitch] is false.
  bool get isProdLocked => current.value.env == Env.prod && !_allowProdSwitch;

  AssetBundle? _bundle;

  static EnvConfig get _defaultConfig => EnvConfig(
        env: Env.dev,
        baseUrl: '',
        values: const {},
        loadedAt: DateTime.now(),
      );

  /// List of keys whose values should be blurred in the UI.
  final List<String> _sensitiveKeys = [
    'API_KEY',
    'TOKEN',
    'SECRET',
    'PASSWORD',
    'AUTH',
  ];

  /// Returns true if the [key] is considered sensitive.
  bool isSensitive(String key) {
    final k = key.toUpperCase();
    return _sensitiveKeys.any((s) => k.contains(s));
  }

  /// Initializes the service.
  ///
  /// Call this once in `main()` before `runApp()`.
  ///
  /// [defaultEnv] — The environment to load if none is persisted.
  /// [autoDiscover] — Whether to scan for .env files automatically.
  /// [verifyIntegrity] — Whether to verify SHA-256 hashes of .env files.
  /// [allowProdSwitch] — Whether to allow switching away from production.
  /// [sensitiveKeys] — Additional keys to blur in the UI.
  /// [bundle] — Custom asset bundle for loading .env files (useful for tests).
  Future<void> init({
    Env defaultEnv = Env.dev,
    bool autoDiscover = true,
    bool verifyIntegrity = false,
    bool allowProdSwitch = true,
    List<String>? sensitiveKeys,
    AssetBundle? bundle,
  }) async {
    _bundle = bundle;
    _allowProdSwitch = allowProdSwitch;
    if (sensitiveKeys != null) {
      _sensitiveKeys.addAll(sensitiveKeys.map((k) => k.toUpperCase()));
    }
    final persistedEnvName = await _storage.loadActiveEnv();
    final envToLoad =
        persistedEnvName != null ? Env.dynamic(persistedEnvName) : defaultEnv;

    await _loadEnv(envToLoad);
    _initialConfig = current.value;
    auditLog.value = await _storage.loadAuditLog();
  }

  /// Switches the active environment.
  Future<void> switchTo(Env env) async {
    if (isProdLocked) {
      throw EnvifiedLockException(
          'Cannot switch environment while locked in Production.');
    }
    final from = current.value.env;
    if (from == env) return;

    await _loadEnv(env);
    await _storage.saveActiveEnv(env.name);
    await _appendAudit(AuditAction.envSwitch, from: from, to: env);
    _checkRestartNeeded();
  }

  /// Overrides the base URL for the current environment.
  Future<void> setBaseUrl(String url) async {
    if (isProdLocked) {
      throw EnvifiedLockException(
          'Cannot override URL while locked in Production.');
    }
    if (!_isValidUrl(url)) throw ArgumentError('Invalid URL: $url');

    await _storage.saveUrlToHistory(url);
    current.value = current.value.copyWith(baseUrl: url);
    await _appendAudit(AuditAction.urlOverride, url: url);
    _checkRestartNeeded();
  }

  /// Acknowledges that a restart has occurred, clearing the [restartNeeded] flag.
  void acknowledgeRestart() {
    _initialConfig = current.value;
    restartNeeded.value = false;
  }

  /// Returns the recent URL override history.
  Future<List<String>> loadUrlHistory() => _storage.loadUrlHistory();

  /// Resets the configuration and storage to defaults.
  Future<void> reset() async {
    await _storage.clear();
    await init();
    await _appendAudit(AuditAction.reset);
  }

  Future<void> _loadEnv(Env env) async {
    final path = env.name == 'dev' ? '.env' : '.env.${env.name}';
    final values = await _parser.loadAsset(
          'assets/env/$path',
          bundle: _bundle,
        ) ??
        {};

    current.value = EnvConfig(
      env: env,
      baseUrl: values['BASE_URL'] ?? '',
      values: values,
      loadedAt: DateTime.now(),
    );
  }

  void _checkRestartNeeded() {
    restartNeeded.value = current.value != _initialConfig;
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  Future<void> _appendAudit(
    AuditAction action, {
    Env? from,
    Env? to,
    String? url,
  }) async {
    final entry = AuditEntry(
      timestamp: DateTime.now(),
      action: action,
      fromEnv: from,
      toEnv: to,
      url: url,
    );
    await _storage.appendAuditEntry(entry);
    auditLog.value = await _storage.loadAuditLog();
  }

  // Typed Getters

  /// Retrieves a raw string value for [key].
  String? get(String key) => current.value.values[key];

  /// Retrieves a boolean value for [key].
  bool getBool(String key, {bool fallback = false}) {
    final v = get(key)?.toLowerCase();
    if (v == null) return fallback;
    return v == 'true' || v == '1' || v == 'yes';
  }

  /// Retrieves an integer value for [key].
  int getInt(String key, {int fallback = 0}) =>
      int.tryParse(get(key) ?? '') ?? fallback;

  /// Retrieves a double value for [key].
  double getDouble(String key, {double fallback = 0.0}) =>
      double.tryParse(get(key) ?? '') ?? fallback;

  /// Retrieves a [Uri] value for [key].
  Uri? getUri(String key) => Uri.tryParse(get(key) ?? '');

  /// Retrieves a list of strings for [key], split by [separator].
  List<String> getList(String key, {String separator = ','}) => (get(key) ?? '')
      .split(separator)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Disposes all [ValueNotifier]s.
  void dispose() {
    current.dispose();
    restartNeeded.dispose();
    auditLog.dispose();
  }
}

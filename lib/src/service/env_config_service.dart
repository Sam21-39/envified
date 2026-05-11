import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show AssetBundle, rootBundle, AssetManifest;
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

  /// The list of discovered environments.
  final ValueNotifier<List<Env>> availableEnvironments = ValueNotifier([
    Env.dev,
    Env.staging,
    Env.prod,
  ]);

  final Map<Env, String> _envPaths = {};

  EnvConfig? _initialConfig;
  bool _allowProdSwitch = true;
  bool _verifyIntegrity = false;
  bool _autoDiscover = true;

  final Set<Env> _productionEnvs = {Env.prod};

  /// Whether switching away from production is allowed.
  bool get allowProdSwitch => _allowProdSwitch;

  /// Returns true if the service is currently in a production-like environment and [allowProdSwitch] is false.
  bool get isProdLocked =>
      _productionEnvs.contains(current.value.env) && !_allowProdSwitch;

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
    // Rule: treated as sensitive if KEY appears as a full
    // word-boundary segment — i.e. the key ends with _KEY or equals KEY.
    // This catches STRIPE_KEY, API_KEY, PUBLIC_KEY but NOT MONKEY or TURKEY.
    final k = key.toUpperCase();
    if (k == 'KEY' || k.endsWith('_KEY')) return true;

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
    List<Env>? productionEnvs,
    List<String>? sensitiveKeys,
    AssetBundle? bundle,
  }) async {
    _bundle = bundle;
    _allowProdSwitch = allowProdSwitch;
    _verifyIntegrity = verifyIntegrity;
    _autoDiscover = autoDiscover;

    if (productionEnvs != null) {
      _productionEnvs.addAll(productionEnvs);
    }
    if (sensitiveKeys != null) {
      _sensitiveKeys.addAll(sensitiveKeys.map((k) => k.toUpperCase()));
    }

    if (_autoDiscover) {
      await _discoverEnvironments();
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

  /// Marks the current configuration as the new baseline, clearing [restartNeeded].
  void markAsApplied() {
    _initialConfig = current.value;
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
    final assetPath = _envPaths[env] ??
        'assets/env/.env${env == Env.dev ? '' : '.${env.name}'}';

    final activeBundle = _bundle ?? rootBundle;
    String content;
    if (!_autoDiscover &&
        env.name != 'dev' &&
        env.name != 'prod' &&
        env.name != 'staging') {
      // If auto-discovery is off, we only allow loading the standard 3 environments.
      // This is a minimal implementation of "controlling discovery".
      content = '';
    } else {
      try {
        content = await activeBundle.loadString(assetPath);
      } catch (_) {
        content = '';
      }
    }

    if (_verifyIntegrity && content.isNotEmpty) {
      final currentHash = _parser.computeHash(content);
      final savedHash = await _storage.loadHash(env.name);

      if (savedHash == null) {
        // Trust on first use
        await _storage.saveHash(env.name, currentHash);
      } else if (savedHash != currentHash) {
        throw EnvifiedTamperException(assetPath);
      }
    }

    final values = _parser.parseString(content);

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

  Future<void> _discoverEnvironments() async {
    try {
      final bundle = _bundle ?? rootBundle;
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      final allAssets = manifest.listAssets();

      final envFiles = await _parser.discoverEnvFiles(allAssets);
      if (kDebugMode) {
        debugPrint(
            'Envified: Found ${envFiles.length} env files in manifest: $envFiles');
      }

      final discoveredEnvs = <Env>{};

      for (final path in envFiles) {
        final fileName = path.split('/').last;
        if (fileName == '.env') {
          discoveredEnvs.add(Env.dev);
          _envPaths[Env.dev] = path;
          continue;
        }

        final parts = fileName.split('.');
        if (parts.length >= 3) {
          final suffix = parts.last;
          Env? discovered;
          if (suffix == 'prod') {
            discovered = Env.prod;
          } else if (suffix == 'staging') {
            discovered = Env.staging;
          } else if (suffix == 'dev') {
            discovered = Env.dev;
          } else {
            discovered = Env.dynamic(suffix);
          }

          discoveredEnvs.add(discovered);
          _envPaths[discovered] = path;
        }
      }

      if (discoveredEnvs.isNotEmpty) {
        // Keep default order but add discovered ones
        final result = <Env>[];
        if (discoveredEnvs.contains(Env.dev)) result.add(Env.dev);
        if (discoveredEnvs.contains(Env.staging)) result.add(Env.staging);
        if (discoveredEnvs.contains(Env.prod)) result.add(Env.prod);

        for (final env in discoveredEnvs) {
          if (!result.contains(env)) result.add(env);
        }
        availableEnvironments.value = result;
      }
    } catch (e) {
      // Non-fatal, fallback to defaults
      debugPrint('Envified: Auto-discovery failed: $e');
    }
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
  Uri? getUri(String key) {
    final value = get(key);
    return value != null ? Uri.tryParse(value) : null;
  }

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

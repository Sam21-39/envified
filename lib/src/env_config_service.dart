import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'audit_entry.dart';
import 'env_file_parser.dart';
import 'env_model.dart';
import 'env_storage.dart';
import 'envified_exception.dart';

/// The central singleton service for runtime environment management.
class EnvConfigService {
  // ── Singleton ─────────────────────────────────────────────────────────────

  EnvConfigService._();

  /// The global singleton instance of [EnvConfigService].
  static final EnvConfigService instance = EnvConfigService._();

  // ── State ─────────────────────────────────────────────────────────────────

  /// The currently active [EnvConfig], exposed as a [ValueNotifier].
  final ValueNotifier<EnvConfig> current = ValueNotifier<EnvConfig>(
    const EnvConfig(
      env: Env.dev,
      baseUrl: '',
      values: <String, String>{},
    ),
  );

  /// True if the environment/URL has changed since last init.
  /// When true, the app should be restarted for changes to take effect.
  ValueListenable<bool> get restartNeeded => _restartNeeded;
  final ValueNotifier<bool> _restartNeeded = ValueNotifier<bool>(false);

  // ── Private fields ────────────────────────────────────────────────────────

  bool _allowProdSwitch = false;
  bool _persistSelection = true;
  Env _defaultEnv = Env.dev;
  bool _initialised = false;
  bool _verifyIntegrity = false;
  List<String>? _allowedUrls;
  Map<Env, String> _urls = <Env, String>{};
  String _assetDir = '';
  AssetBundle? _bundle;

  /// The environment that was active when init() was called.
  late Env _initialEnv;

  /// The base URL that was active when init() was called.
  late String _initialBaseUrl;

  /// Cached fallback `.env` values loaded once during [init].
  Map<String, String> _fallbackValues = <String, String>{};

  late EnvStorage _storage;
  final EnvFileParser _parser = EnvFileParser();

  // Lifecycle hooks.
  Future<void> Function(Env from, Env to)? _onBeforeSwitch;
  void Function(EnvConfig config)? _onAfterSwitch;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialises the service by loading all available environment asset files.
  Future<void> init({
    Env defaultEnv = Env.dev,
    bool persistSelection = true,
    bool allowProdSwitch = false,
    bool verifyIntegrity = false,
    EnvStorage? storage,
    Future<void> Function(Env from, Env to)? onBeforeSwitch,
    void Function(EnvConfig config)? onAfterSwitch,
    List<String>? allowedUrls,
    Map<Env, String>? urls,
    bool autoDiscover = true,
    String assetDir = '',
    AssetBundle? bundle,
  }) async {
    _defaultEnv = defaultEnv;
    _persistSelection = persistSelection;
    _allowProdSwitch = allowProdSwitch;
    _verifyIntegrity = verifyIntegrity;
    _onBeforeSwitch = onBeforeSwitch;
    _onAfterSwitch = onAfterSwitch;
    _allowedUrls = allowedUrls;
    _assetDir = assetDir;
    _bundle = bundle;

    // Auto-discover if urls not provided and autoDiscover is true
    if ((urls == null || urls.isEmpty) && autoDiscover) {
      urls = await _parser.discoverAndExtractUrls(
        assetDir: assetDir,
        bundle: bundle,
      );
    }

    if (urls == null || urls.isEmpty) {
      throw const EnvifiedMissingFileException(
        'No environment files discovered and none provided manually.',
      );
    }

    _urls = urls;

    // Initialise storage.
    _storage = storage ?? const EnvStorage();

    // Load the shared fallback `.env` file.
    final String fallbackPath = '$_assetDir.env';

    // We treat .env as Production for integrity purposes if it's our only prod source
    // or simply always verify it if requested, but requirement says only Prod envs.
    // However, .env is often a fallback for all.
    _fallbackValues = await _parser.parse(fallbackPath, bundle: _bundle);

    // Restore persisted state if enabled.
    Env activeEnv = defaultEnv;
    String? baseUrlOverride;

    if (_persistSelection) {
      final stored = await _storage.loadConfig();
      if (stored != null) {
        // Find the matching discovered env (by name and filename)
        final match = _urls.keys.firstWhere(
          (e) => e.name == stored.env.name,
          orElse: () => stored.env,
        );
        activeEnv = match;
        if (stored.isBaseUrlOverridden) {
          baseUrlOverride = stored.baseUrl;
        }
      }
    }

    // Verify + load the environment-specific file.
    final String specificPath = '$_assetDir${activeEnv.assetFileName}';

    // REQUIREMENT: verifyIntegrity should only do verification for Production related env.
    if (_verifyIntegrity && activeEnv.isProduction) {
      await _parser.verifyIntegrity(specificPath, _storage, bundle: _bundle);
      // Also verify fallback if it's the prod file
      if (activeEnv.assetFileName == '.env') {
        await _parser.verifyIntegrity(fallbackPath, _storage, bundle: _bundle);
      }
    }

    final merged = await _loadMerged(activeEnv);

    // Determine base URL.
    final String baseUrl;
    final bool isOverridden;

    if (baseUrlOverride != null && baseUrlOverride.isNotEmpty) {
      baseUrl = baseUrlOverride;
      isOverridden = true;
    } else {
      baseUrl = _urls[activeEnv] ?? merged['BASE_URL'] ?? '';
      isOverridden = false;
    }

    current.value = EnvConfig(
      env: activeEnv,
      baseUrl: baseUrl,
      values: merged,
      isBaseUrlOverridden: isOverridden,
    );

    // Remember the initial state to detect if a restart is needed later.
    _initialEnv = activeEnv;
    _initialBaseUrl = baseUrl;
    _restartNeeded.value = false;

    _initialised = true;
  }

  /// Call this when the app has been restarted/re-initialized to reset the
  /// [restartNeeded] flag and capture the current state as the new baseline.
  void acknowledgeRestart() {
    _initialEnv = current.value.env;
    _initialBaseUrl = current.value.baseUrl;
    _restartNeeded.value = false;
  }

  // ── Switching ─────────────────────────────────────────────────────────────

  /// Switches the active environment to [env].
  Future<void> switchTo(Env env) async {
    _assertInitialised();

    // Block leaving prod when locked.
    if (!_allowProdSwitch &&
        current.value.env.isProduction &&
        !env.isProduction) {
      throw const EnvifiedLockException(
        'Cannot switch away from production when allowProdSwitch is false.',
      );
    }

    // Fire before-switch hook.
    if (_onBeforeSwitch != null) {
      await _onBeforeSwitch!(current.value.env, env);
    }

    final Env fromEnv = current.value.env;

    // Verify integrity if switching to production
    if (_verifyIntegrity && env.isProduction) {
      await _parser.verifyIntegrity('$_assetDir${env.assetFileName}', _storage,
          bundle: _bundle);
    }

    final merged = await _loadMerged(env);

    // Reset override when switching environments.
    final String baseUrl = _urls[env] ?? merged['BASE_URL'] ?? '';
    const bool isOverridden = false;

    current.value = EnvConfig(
      env: env,
      baseUrl: baseUrl,
      values: merged,
      isBaseUrlOverridden: isOverridden,
    );

    // Check if a restart is needed.
    _restartNeeded.value = (env != _initialEnv || baseUrl != _initialBaseUrl);

    _onAfterSwitch?.call(current.value);

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
    }

    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'switch',
      fromEnv: fromEnv.name,
      toEnv: env.name,
    ));
  }

  /// Returns the original BASE_URL for [env] as defined in its `.env` file.
  String getOriginalUrl(Env env) {
    return _urls[env] ?? '';
  }

  // ── Value access ──────────────────────────────────────────────────────────

  String get(String key, {String fallback = ''}) {
    return current.value.values[key] ?? fallback;
  }

  bool getBool(String key, {bool fallback = false}) {
    final String? raw = current.value.values[key];
    if (raw == null) return fallback;
    return const {'true', '1', 'yes'}.contains(raw.toLowerCase());
  }

  int getInt(String key, {int fallback = 0}) {
    final String? raw = current.value.values[key];
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  double getDouble(String key, {double fallback = 0.0}) {
    final String? raw = current.value.values[key];
    if (raw == null) return fallback;
    return double.tryParse(raw) ?? fallback;
  }

  Uri? getUri(String key) {
    final String? raw = current.value.values[key];
    if (raw == null || raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  List<String> getList(String key, {String separator = ','}) {
    final String? raw = current.value.values[key];
    if (raw == null || raw.isEmpty) return <String>[];
    return raw.split(separator).map((e) => e.trim()).toList();
  }

  // ── Base URL override ─────────────────────────────────────────────────────

  Future<void> setBaseUrl(String url) async {
    _assertInitialised();
    _assertNotProdLocked('Cannot override base URL in production.');
    _assertUrlAllowed(url);

    current.value = current.value.copyWith(
      baseUrl: url,
      isBaseUrlOverridden: true,
    );

    // Check if a restart is needed.
    _restartNeeded.value =
        (current.value.env != _initialEnv || url != _initialBaseUrl);

    _onAfterSwitch?.call(current.value);

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
      await _storage.saveUrlToHistory(url);
    }

    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'setBaseUrl',
      url: url,
    ));
  }

  Future<void> clearBaseUrlOverride() async {
    _assertInitialised();
    _assertNotProdLocked('Cannot clear base URL override in production.');

    final restoredUrl = current.value.values['BASE_URL'] ?? '';

    current.value = current.value.copyWith(
      baseUrl: restoredUrl,
      isBaseUrlOverridden: false,
    );

    // Check if a restart is needed.
    _restartNeeded.value =
        (current.value.env != _initialEnv || restoredUrl != _initialBaseUrl);

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
    }

    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'clearOverride',
    ));
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> reset() async {
    _assertInitialised();

    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'reset',
    ));

    if (_persistSelection) {
      await _storage.clear();
    }

    await init(
      defaultEnv: _defaultEnv,
      persistSelection: _persistSelection,
      allowProdSwitch: _allowProdSwitch,
      verifyIntegrity: _verifyIntegrity,
      storage: _storage,
      onBeforeSwitch: _onBeforeSwitch,
      onAfterSwitch: _onAfterSwitch,
      allowedUrls: _allowedUrls,
      assetDir: _assetDir,
      bundle: _bundle,
    );
  }

  // ── Audit log ─────────────────────────────────────────────────────────────

  Future<List<AuditEntry>> get auditLog => _storage.loadAuditLog();

  /// Returns the list of environments discovered during [init].
  List<Env> get availableEnvs => _urls.keys.toList()
    ..sort((a, b) {
      if (a.isProduction != b.isProduction) {
        return a.isProduction ? 1 : -1;
      }
      return a.name.compareTo(b.name);
    });

  // ── URL history ───────────────────────────────────────────────────────────

  Future<List<String>> get urlHistory => _storage.loadUrlHistory();

  // ── Internal helpers ──────────────────────────────────────────────────────

  bool get isProdLocked => !_allowProdSwitch && current.value.env.isProduction;

  bool get allowProdSwitch => _allowProdSwitch;

  Future<Map<String, String>> _loadMerged(Env env) async {
    final assetPath = '$_assetDir${env.assetFileName}';
    final specific = await _parser.parse(assetPath, bundle: _bundle);
    return _parser.merge(_fallbackValues, specific);
  }

  void _assertInitialised() {
    if (!_initialised) {
      throw StateError(
        'EnvConfigService has not been initialised.',
      );
    }
  }

  void _assertNotProdLocked(String message) {
    if (isProdLocked) {
      throw EnvifiedLockException(message);
    }
  }

  void _assertUrlAllowed(String url) {
    final List<String>? allowed = _allowedUrls;
    if (allowed == null || allowed.isEmpty) return;
    final bool permitted = allowed.any((prefix) => url.startsWith(prefix));
    if (!permitted) {
      throw EnvifiedUrlNotAllowedException(url);
    }
  }

  /// Internal reset for unit testing only.
  @visibleForTesting
  void resetForTesting() {
    _initialised = false;
    current.value = const EnvConfig(
      env: Env.dev,
      baseUrl: '',
      values: <String, String>{},
    );
    _urls = <Env, String>{};
    _fallbackValues = <String, String>{};
    _allowProdSwitch = false;
    _persistSelection = true;
    _defaultEnv = Env.dev;
    _verifyIntegrity = false;
    _allowedUrls = null;
    _assetDir = '';
    _bundle = null;
    _onBeforeSwitch = null;
    _onAfterSwitch = null;
  }
}

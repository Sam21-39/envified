import 'package:flutter/foundation.dart';

import 'audit_entry.dart';
import 'env_file_parser.dart';
import 'env_model.dart';
import 'env_storage.dart';
import 'envified_exception.dart';

/// The central singleton service for runtime environment management.
///
/// [EnvConfigService] is the primary entry point to the envified package. It:
///
/// 1. Loads and parses `.env*` asset files at startup via [init].
/// 2. Exposes the active configuration as a [ValueNotifier] — [current] —
///    which widgets can listen to for reactive UI updates.
/// 3. Allows switching between [Env] values at runtime without a rebuild via
///    [switchTo].
/// 4. Supports a persistent base-URL override independent of the `.env` file
///    via [setBaseUrl] / [clearBaseUrlOverride].
/// 5. Enforces a configurable production lock that prevents accidental
///    config changes in production builds.
/// 6. Optionally verifies the SHA-256 integrity of loaded `.env*` files.
/// 7. Provides typed accessors ([getBool], [getInt], [getDouble], [getUri],
///    [getList]) alongside the raw string [get] method.
/// 8. Emits lifecycle hooks ([onBeforeSwitch], [onAfterSwitch]) for external
///    observers.
/// 9. Maintains a tamper-evident, encrypted audit log accessible via [auditLog].
///
/// ## Setup
///
/// Call [init] once before [runApp]:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await EnvConfigService.instance.init(
///     defaultEnv: Env.dev,
///     persistSelection: true,
///     allowProdSwitch: false,
///     verifyIntegrity: true,
///     onBeforeSwitch: (from, to) async {
///       debugPrint('Switching from ${from.name} to ${to.name}');
///     },
///     onAfterSwitch: (config) {
///       debugPrint('Now on: ${config.baseUrl}');
///     },
///   );
///
///   runApp(const MyApp());
/// }
/// ```
///
/// ## Reading values
///
/// ```dart
/// final service = EnvConfigService.instance;
/// final timeout  = service.getInt('TIMEOUT', fallback: 30);
/// final enabled  = service.getBool('FEATURE_FLAG');
/// final url      = service.current.value.baseUrl;
/// ```
///
/// @see Env
/// @see EnvConfig
/// @see EnvifiedLockException
/// @see EnvifiedTamperException
class EnvConfigService {
  // ── Singleton ─────────────────────────────────────────────────────────────

  EnvConfigService._();

  /// The global singleton instance of [EnvConfigService].
  ///
  /// Always use this field rather than constructing a new instance.
  static final EnvConfigService instance = EnvConfigService._();

  // ── State ─────────────────────────────────────────────────────────────────

  /// The currently active [EnvConfig], exposed as a [ValueNotifier].
  ///
  /// Subscribe to this notifier to rebuild widgets automatically whenever the
  /// active environment or base URL changes:
  ///
  /// ```dart
  /// ValueListenableBuilder<EnvConfig>(
  ///   valueListenable: EnvConfigService.instance.current,
  ///   builder: (context, config, _) => Text(config.baseUrl),
  /// );
  /// ```
  final ValueNotifier<EnvConfig> current = ValueNotifier<EnvConfig>(
    const EnvConfig(
      env: Env.dev,
      baseUrl: '',
      values: <String, String>{},
    ),
  );

  // ── Private fields ────────────────────────────────────────────────────────

  bool _allowProdSwitch = false;
  bool _persistSelection = true;
  Env _defaultEnv = Env.dev;
  bool _initialised = false;
  bool _verifyIntegrity = false;
  List<String>? _allowedUrls;

  /// Cached fallback `.env` values loaded once during [init].
  Map<String, String> _fallbackValues = <String, String>{};

  late EnvStorage _storage;
  final EnvFileParser _parser = EnvFileParser();

  // Lifecycle hooks.
  Future<void> Function(Env from, Env to)? _onBeforeSwitch;
  void Function(EnvConfig config)? _onAfterSwitch;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialises the service by loading all available `.env*` asset files.
  ///
  /// This method **must** be called before any other method on this service.
  /// It is safe to call [init] more than once (e.g. after [reset]); subsequent
  /// calls re-load all files and re-apply persisted state.
  ///
  /// Parameters:
  ///
  /// - [defaultEnv]: The environment to use on first launch (before any
  ///   persistent selection exists). Defaults to [Env.dev].
  /// - [persistSelection]: When `true` (the default), the active [Env]
  ///   selection and any base URL override are written to
  ///   encrypted storage (`flutter_secure_storage`) and restored on subsequent launches.
  /// - [allowProdSwitch]: When `false` (the default), switching away from
  ///   [Env.prod] or overriding the base URL while in production is blocked.
  ///   See [EnvifiedLockException].
  /// - [verifyIntegrity]: When `true`, each `.env*` file is SHA-256 hashed on
  ///   first load and the hash is stored securely. On subsequent loads the hash
  ///   is recomputed and compared. A mismatch throws [EnvifiedTamperException].
  /// - [onBeforeSwitch]: Optional async callback invoked before [switchTo]
  ///   changes [current]. Receives the current and target [Env] values.
  /// - [onAfterSwitch]: Optional synchronous callback invoked after [switchTo]
  ///   or [setBaseUrl] updates [current]. Receives the new [EnvConfig].
  /// - [allowedUrls]: Optional list of URL prefixes permitted by [setBaseUrl].
  ///   When supplied, any URL that does not start with an entry in this list
  ///   throws [EnvifiedUrlNotAllowedException].
  ///
  /// @throws [EnvifiedTamperException] if [verifyIntegrity] is `true` and a
  ///   `.env*` file has been tampered with since the first load.
  ///
  /// ```dart
  /// await EnvConfigService.instance.init(
  ///   defaultEnv: Env.dev,
  ///   persistSelection: true,
  ///   allowProdSwitch: false,
  ///   verifyIntegrity: true,
  /// );
  /// ```
  Future<void> init({
    Env defaultEnv = Env.dev,
    bool persistSelection = true,
    bool allowProdSwitch = false,
    bool verifyIntegrity = false,
    EnvStorage? storage,
    Future<void> Function(Env from, Env to)? onBeforeSwitch,
    void Function(EnvConfig config)? onAfterSwitch,
    List<String>? allowedUrls,
  }) async {
    _defaultEnv = defaultEnv;
    _persistSelection = persistSelection;
    _allowProdSwitch = allowProdSwitch;
    _verifyIntegrity = verifyIntegrity;
    _onBeforeSwitch = onBeforeSwitch;
    _onAfterSwitch = onAfterSwitch;
    _allowedUrls = allowedUrls;

    // Initialise storage (uses FlutterSecureStorage internally).
    _storage = storage ?? const EnvStorage();

    // Load the shared fallback `.env` file.
    if (_verifyIntegrity) {
      await _parser.verifyIntegrity('.env', _storage);
    }
    _fallbackValues = await _parser.parse('.env');

    // Restore persisted state if enabled.
    Env activeEnv = defaultEnv;
    String? baseUrlOverride;

    if (_persistSelection) {
      final stored = await _storage.loadConfig();
      if (stored != null) {
        activeEnv = stored.env;
        if (stored.isBaseUrlOverridden) {
          baseUrlOverride = stored.baseUrl;
        }
      }
    }

    // Verify + load the environment-specific file.
    final String? specificPath = activeEnv.assetPath;
    if (_verifyIntegrity && specificPath != null) {
      await _parser.verifyIntegrity(specificPath, _storage);
    }
    final merged = await _loadMerged(activeEnv);

    // Determine base URL — prefer restored override.
    final String baseUrl;
    final bool isOverridden;

    if (baseUrlOverride != null && baseUrlOverride.isNotEmpty) {
      baseUrl = baseUrlOverride;
      isOverridden = true;
    } else {
      baseUrl = merged['BASE_URL'] ?? '';
      isOverridden = false;
    }

    current.value = EnvConfig(
      env: activeEnv,
      baseUrl: baseUrl,
      values: merged,
      isBaseUrlOverridden: isOverridden,
    );

    _initialised = true;
  }

  // ── Switching ─────────────────────────────────────────────────────────────

  /// Switches the active environment to [env] and reloads the matching
  /// `.env*` file.
  ///
  /// The [current] notifier is updated synchronously after the async load
  /// completes, triggering any listening [ValueListenableBuilder] widgets.
  ///
  /// Persists the new selection to encrypted storage (`flutter_secure_storage`) if `persistSelection`
  /// was `true` during [init].
  ///
  /// Lifecycle hooks:
  /// - If [onBeforeSwitch] was supplied to [init], it is awaited before the
  ///   config changes.
  /// - If [onAfterSwitch] was supplied, it is called synchronously after
  ///   the config changes.
  ///
  /// @throws [EnvifiedLockException] if the current environment is [Env.prod],
  /// `allowProdSwitch` is `false`, and [env] is **not** [Env.prod] (i.e.
  /// attempting to leave production is blocked).
  ///
  /// Switching **to** [Env.prod] from any other env is always allowed.
  ///
  /// ```dart
  /// await EnvConfigService.instance.switchTo(Env.staging);
  /// ```
  Future<void> switchTo(Env env) async {
    _assertInitialised();

    // Block leaving prod when locked.
    if (!_allowProdSwitch && current.value.env == Env.prod && env != Env.prod) {
      throw const EnvifiedLockException(
        'Cannot switch away from production when allowProdSwitch is false.',
      );
    }

    // Fire before-switch hook.
    if (_onBeforeSwitch != null) {
      await _onBeforeSwitch!(current.value.env, env);
    }

    final Env fromEnv = current.value.env;

    final merged = await _loadMerged(env);

    // Reset override when switching environments.
    final String baseUrl = merged['BASE_URL'] ?? '';
    const bool isOverridden = false;

    current.value = EnvConfig(
      env: env,
      baseUrl: baseUrl,
      values: merged,
      isBaseUrlOverridden: isOverridden,
    );

    // Fire after-switch hook.
    _onAfterSwitch?.call(current.value);

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
    }

    // Append audit entry.
    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'switch',
      fromEnv: fromEnv.name,
      toEnv: env.name,
    ));
  }

  // ── Value access ──────────────────────────────────────────────────────────

  /// Reads a single value from the active [EnvConfig.values] map.
  ///
  /// Returns [fallback] if the [key] is not present in the current
  /// environment's merged key-value map.
  ///
  /// ```dart
  /// final timeout = EnvConfigService.instance.get('TIMEOUT', fallback: '30');
  /// ```
  String get(String key, {String fallback = ''}) {
    return current.value.values[key] ?? fallback;
  }

  /// Returns the value for [key] parsed as a [bool].
  ///
  /// The following strings (case-insensitive) are considered `true`:
  /// `'true'`, `'1'`, `'yes'`.  Everything else evaluates to `false`.
  ///
  /// Returns [fallback] if the [key] is not present.
  ///
  /// ```dart
  /// final debugMode = EnvConfigService.instance.getBool('DEBUG');
  /// ```
  bool getBool(String key, {bool fallback = false}) {
    final String? raw = current.value.values[key];
    if (raw == null) return fallback;
    return const {'true', '1', 'yes'}.contains(raw.toLowerCase());
  }

  /// Returns the value for [key] parsed as an [int].
  ///
  /// Returns [fallback] if the key is missing or the value cannot be parsed.
  ///
  /// ```dart
  /// final timeout = EnvConfigService.instance.getInt('TIMEOUT', fallback: 30);
  /// ```
  int getInt(String key, {int fallback = 0}) {
    final String? raw = current.value.values[key];
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  /// Returns the value for [key] parsed as a [double].
  ///
  /// Returns [fallback] if the key is missing or the value cannot be parsed.
  ///
  /// ```dart
  /// final rate = EnvConfigService.instance.getDouble('RATE_LIMIT', fallback: 1.5);
  /// ```
  double getDouble(String key, {double fallback = 0.0}) {
    final String? raw = current.value.values[key];
    if (raw == null) return fallback;
    return double.tryParse(raw) ?? fallback;
  }

  /// Returns the value for [key] parsed as a [Uri].
  ///
  /// Returns `null` if the key is missing or [Uri.tryParse] fails.
  ///
  /// ```dart
  /// final endpoint = EnvConfigService.instance.getUri('WEBHOOK_URL');
  /// if (endpoint != null) { /* ... */ }
  /// ```
  Uri? getUri(String key) {
    final String? raw = current.value.values[key];
    if (raw == null || raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  /// Returns the value for [key] split by [separator] (default: `','`).
  ///
  /// Each element is trimmed of surrounding whitespace. Returns an empty list
  /// if the key is missing.
  ///
  /// ```dart
  /// final hosts = EnvConfigService.instance.getList('ALLOWED_HOSTS');
  /// // .env: ALLOWED_HOSTS=api.com, cdn.com, auth.com
  /// // → ['api.com', 'cdn.com', 'auth.com']
  /// ```
  List<String> getList(String key, {String separator = ','}) {
    final String? raw = current.value.values[key];
    if (raw == null || raw.isEmpty) return <String>[];
    return raw.split(separator).map((e) => e.trim()).toList();
  }

  // ── Base URL override ─────────────────────────────────────────────────────

  /// Overrides the active [EnvConfig.baseUrl] with [url].
  ///
  /// Sets [EnvConfig.isBaseUrlOverridden] to `true` and persists the override
  /// in encrypted storage (`flutter_secure_storage`) if `persistSelection` was `true` during [init].
  ///
  /// When [allowedUrls] was supplied to [init], [url] must start with at least
  /// one of the listed prefixes, otherwise [EnvifiedUrlNotAllowedException] is
  /// thrown.
  ///
  /// @throws [EnvifiedLockException] if the current environment is [Env.prod]
  /// and `allowProdSwitch` is `false`.
  /// @throws [EnvifiedUrlNotAllowedException] if the URL is not in the
  ///   allowlist configured via [init].
  ///
  /// ```dart
  /// await EnvConfigService.instance.setBaseUrl('https://custom.api.com');
  /// ```
  Future<void> setBaseUrl(String url) async {
    _assertInitialised();
    _assertNotProdLocked('Cannot override base URL in production.');
    _assertUrlAllowed(url);

    current.value = current.value.copyWith(
      baseUrl: url,
      isBaseUrlOverridden: true,
    );

    // Fire after-switch hook.
    _onAfterSwitch?.call(current.value);

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
      await _storage.saveUrlToHistory(url);
    }

    // Append audit entry.
    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'setBaseUrl',
      url: url,
    ));
  }

  /// Clears the base URL override and restores the `BASE_URL` from the active
  /// `.env*` file.
  ///
  /// @throws [EnvifiedLockException] if the current environment is [Env.prod]
  /// and `allowProdSwitch` is `false`.
  ///
  /// ```dart
  /// await EnvConfigService.instance.clearBaseUrlOverride();
  /// ```
  Future<void> clearBaseUrlOverride() async {
    _assertInitialised();
    _assertNotProdLocked('Cannot clear base URL override in production.');

    final restoredUrl = current.value.values['BASE_URL'] ?? '';

    current.value = current.value.copyWith(
      baseUrl: restoredUrl,
      isBaseUrlOverridden: false,
    );

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
    }

    // Append audit entry.
    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'clearOverride',
    ));
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Clears all persisted envified state and re-initialises to [_defaultEnv].
  ///
  /// After calling this method, the service behaves as if it were run for the
  /// first time — no env selection is persisted and no base URL override is
  /// active.
  ///
  /// ```dart
  /// await EnvConfigService.instance.reset();
  /// ```
  Future<void> reset() async {
    _assertInitialised();

    // Append audit before clearing storage.
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
      onBeforeSwitch: _onBeforeSwitch,
      onAfterSwitch: _onAfterSwitch,
      allowedUrls: _allowedUrls,
    );
  }

  // ── Audit log ─────────────────────────────────────────────────────────────

  /// Returns all [AuditEntry] records, newest first.
  ///
  /// The log retains at most 50 entries. Each mutating operation
  /// ([switchTo], [setBaseUrl], [clearBaseUrlOverride], [reset]) appends a
  /// new entry automatically.
  ///
  /// ```dart
  /// final entries = await EnvConfigService.instance.auditLog;
  /// for (final e in entries) {
  ///   print('${e.timestamp} — ${e.action}');
  /// }
  /// ```
  Future<List<AuditEntry>> get auditLog => _storage.loadAuditLog();

  // ── URL history ───────────────────────────────────────────────────────────

  /// Returns the list of recently used base URLs, newest first (max 5).
  ///
  /// History is populated automatically whenever [setBaseUrl] is called.
  ///
  /// ```dart
  /// final history = await EnvConfigService.instance.urlHistory;
  /// ```
  Future<List<String>> get urlHistory => _storage.loadUrlHistory();

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Whether the prod-lock is currently active for the calling operation.
  bool get isProdLocked => !_allowProdSwitch && current.value.env == Env.prod;

  /// Whether [allowProdSwitch] was set to `true` during [init].
  bool get allowProdSwitch => _allowProdSwitch;

  /// Loads and merges values for [env] with the shared fallback.
  Future<Map<String, String>> _loadMerged(Env env) async {
    final assetPath = env.assetPath;
    if (assetPath == null) {
      // Env.custom — return fallback values only.
      return Map<String, String>.from(_fallbackValues);
    }
    final specific = await _parser.parse(assetPath);
    return _parser.merge(_fallbackValues, specific);
  }

  /// Throws [StateError] if [init] has not been called.
  void _assertInitialised() {
    if (!_initialised) {
      throw StateError(
        'EnvConfigService has not been initialised. '
        'Call await EnvConfigService.instance.init() before using the service.',
      );
    }
  }

  /// Throws [EnvifiedLockException] if the production lock is active.
  void _assertNotProdLocked(String message) {
    if (isProdLocked) {
      throw EnvifiedLockException(message);
    }
  }

  /// Throws [EnvifiedUrlNotAllowedException] if [url] is not in [_allowedUrls].
  void _assertUrlAllowed(String url) {
    final List<String>? allowed = _allowedUrls;
    if (allowed == null || allowed.isEmpty) return;
    final bool permitted = allowed.any((prefix) => url.startsWith(prefix));
    if (!permitted) {
      throw EnvifiedUrlNotAllowedException(url);
    }
  }
}

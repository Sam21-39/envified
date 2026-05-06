import 'package:flutter/foundation.dart';

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
/// final timeout = service.get('TIMEOUT', fallback: '30');
/// final url     = service.current.value.baseUrl;
/// ```
///
/// @see Env
/// @see EnvConfig
/// @see EnvifiedLockException
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

  /// Cached fallback `.env` values loaded once during [init].
  Map<String, String> _fallbackValues = <String, String>{};

  late EnvStorage _storage;
  final EnvFileParser _parser = EnvFileParser();

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
  ///   [SharedPreferences] and restored on subsequent launches.
  /// - [allowProdSwitch]: When `false` (the default), switching away from
  ///   [Env.prod] or overriding the base URL while in production is blocked.
  ///   See [EnvifiedLockException].
  ///
  /// ```dart
  /// await EnvConfigService.instance.init(
  ///   defaultEnv: Env.dev,
  ///   persistSelection: true,
  ///   allowProdSwitch: false,
  /// );
  /// ```
  Future<void> init({
    Env defaultEnv = Env.dev,
    bool persistSelection = true,
    bool allowProdSwitch = false,
    EnvStorage? storage,
  }) async {
    _defaultEnv = defaultEnv;
    _persistSelection = persistSelection;
    _allowProdSwitch = allowProdSwitch;

    // Initialise storage (uses FlutterSecureStorage internally).
    _storage = storage ?? const EnvStorage();

    // Load the shared fallback `.env` file.
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

    // Load the specific env file and merge with fallback.
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
  /// Persists the new selection to [FlutterSecureStorage] if `persistSelection`
  /// was `true` during [init].
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
    if (!_allowProdSwitch &&
        current.value.env == Env.prod &&
        env != Env.prod) {
      throw const EnvifiedLockException(
        'Cannot switch away from production when allowProdSwitch is false.',
      );
    }

    final merged = await _loadMerged(env);

    // Determine base URL after switch.
    final String baseUrl;
    final bool isOverridden;

    // Reset override when switching environments, unless it's explicitly handled.
    // In this package, we clear the override on env switch to ensure consistency.
    baseUrl = merged['BASE_URL'] ?? '';
    isOverridden = false;

    current.value = EnvConfig(
      env: env,
      baseUrl: baseUrl,
      values: merged,
      isBaseUrlOverridden: isOverridden,
    );

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
    }
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

  // ── Base URL override ─────────────────────────────────────────────────────

  /// Overrides the active [EnvConfig.baseUrl] with [url].
  ///
  /// Sets [EnvConfig.isBaseUrlOverridden] to `true` and persists the override
  /// in [FlutterSecureStorage] if `persistSelection` was `true` during [init].
  ///
  /// @throws [EnvifiedLockException] if the current environment is [Env.prod]
  /// and `allowProdSwitch` is `false`.
  ///
  /// ```dart
  /// await EnvConfigService.instance.setBaseUrl('https://custom.api.com');
  /// ```
  Future<void> setBaseUrl(String url) async {
    _assertInitialised();
    _assertNotProdLocked('Cannot override base URL in production.');

    current.value = current.value.copyWith(
      baseUrl: url,
      isBaseUrlOverridden: true,
    );

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
    }
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

    if (_persistSelection) {
      await _storage.clear();
    }

    await init(
      defaultEnv: _defaultEnv,
      persistSelection: _persistSelection,
      allowProdSwitch: _allowProdSwitch,
    );
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Whether the prod-lock is currently active for the calling operation.
  bool get isProdLocked =>
      !_allowProdSwitch && current.value.env == Env.prod;

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
}

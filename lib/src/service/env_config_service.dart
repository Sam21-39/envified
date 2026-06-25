import 'package:flutter/foundation.dart';

import '../channel/envified_channel.dart';
import '../models/audit_entry.dart';
import '../models/env.dart';
import '../models/envified_exception.dart';
import '../storage/env_storage.dart';
import '../adapters/envified_service_adapter.dart';

/// The central singleton service for runtime environment management.
///
/// v4.0.0 changes from v3.x:
/// - `.env.*` files are **never** read at runtime. All config values come from
///   the native layer, pre-loaded by `envified build --env=<name>` at build time.
/// - Persistence delegates to [EnvifiedChannel] (Android Keystore / iOS
///   Keychain) instead of `flutter_secure_storage`.
/// - [switchTo] follows an 8-step lifecycle with rollback on adapter failure.
/// - Production lock is enforced in the native layer on release builds.
class EnvConfigService {
  // ── Singleton ─────────────────────────────────────────────────────────────

  EnvConfigService._();

  /// The global singleton instance.
  static final EnvConfigService instance = EnvConfigService._();

  // ── State ─────────────────────────────────────────────────────────────────

  /// The currently active [EnvConfig], exposed as a [ValueNotifier].
  final ValueNotifier<EnvConfig> current = ValueNotifier<EnvConfig>(
    EnvConfig(
      env: Env.dev,
      baseUrl: '',
      values: const <String, String>{},
      loadedAt: DateTime.now(),
    ),
  );

  /// True if the environment/URL has changed since the last [init].
  ValueListenable<bool> get restartNeeded => _restartNeeded;
  final ValueNotifier<bool> _restartNeeded = ValueNotifier<bool>(false);

  // ── Private fields ────────────────────────────────────────────────────────

  bool _allowProdSwitch = false;
  bool _persistSelection = true;
  Env _defaultEnv = Env.dev;
  bool _initialised = false;
  List<String>? _allowedUrls;

  /// Environments discovered from the pre-built registry (name → base URL).
  Map<Env, String> _urls = <Env, String>{};

  Set<Env> _productionEnvs = {Env.prod};
  Map<String, String> _urlOverrides = <String, String>{};

  late Env _initialEnv;
  late String _initialBaseUrl;

  late EnvStorage _storage;
  late EnvifiedChannel _channel;

  /// Registered service adapters, in registration order.
  final List<EnvifiedServiceAdapter> _adapters = [];

  // Lifecycle hooks.
  Future<void> Function(Env from, Env to)? _onBeforeSwitch;
  void Function(EnvConfig config)? _onAfterSwitch;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialises the service.
  ///
  /// In v4.0.0 [envAssetPaths], [autoDiscover], [verifyIntegrity], and
  /// [bundle] are ignored — discovery and integrity verification happen at
  /// build time via the CLI. They are accepted (and silently ignored) so that
  /// call sites compiled against v3.x continue to compile unmodified.
  Future<void> init({
    Env? defaultEnv,
    bool persistSelection = true,
    bool allowProdSwitch = false,
    EnvStorage? storage,
    EnvifiedChannel? channel,
    Future<void> Function(Env from, Env to)? onBeforeSwitch,
    void Function(EnvConfig config)? onAfterSwitch,
    List<String>? allowedUrls,
    Map<Env, String>? urls,
    Set<Env>? productionEnvs,
    // v3.x compat params — accepted but ignored.
    @Deprecated('No-op in v4: discovery is CLI-only')
    List<String> envAssetPaths = const [],
    @Deprecated('No-op in v4: use envified build') bool verifyIntegrity = false,
    @Deprecated('No-op in v4') bool autoDiscover = true,
    @Deprecated('No-op in v4') Object? bundle,
    @Deprecated('Use envAssetPaths instead') String assetDir = '',
  }) async {
    _persistSelection = persistSelection;
    _allowProdSwitch = allowProdSwitch;
    _onBeforeSwitch = onBeforeSwitch;
    _onAfterSwitch = onAfterSwitch;
    _allowedUrls = allowedUrls;
    _productionEnvs = productionEnvs ?? {Env.prod};

    _channel = channel ?? EnvifiedChannel();
    _storage = storage ?? EnvStorage(channel: _channel);

    // Provision the native key for the default environment.
    await _channel.initialize(env: defaultEnv?.name ?? 'dev');

    // Populate URL registry. In a real v4.0.0 build the CLI pre-generates a
    // Dart constant map (`lib/src/generated/envified_registry.g.dart`) that is
    // imported here. For Phase 1 we fall back to the manually supplied [urls]
    // so the service remains functional before the CLI integration is complete.
    if (urls != null && urls.isNotEmpty) {
      _urls = urls;
    } else {
      // Minimal fallback: treat defaultEnv as the only known environment.
      final env = defaultEnv ?? Env.dev;
      _urls = {env: ''};
    }

    Env activeEnv = defaultEnv ??
        _urls.keys.firstWhere(
          (e) => e.name == 'dev' || e.name == 'development',
          orElse: () => _urls.keys.first,
        );
    _defaultEnv = activeEnv;

    // Restore persisted selection.
    if (_persistSelection) {
      _urlOverrides = await _storage.loadOverrides();
      final stored = await _storage.loadConfig(envName: activeEnv.name);
      if (stored != null) {
        final match = _urls.keys.firstWhere(
          (e) => e.name == stored.env.name,
          orElse: () => stored.env,
        );
        activeEnv = match;
      }
    }

    final String? override = _urlOverrides[activeEnv.name];
    final String baseUrl;
    final bool isOverridden;

    if (override != null && override.isNotEmpty) {
      baseUrl = override;
      isOverridden = true;
    } else {
      baseUrl = _urls[activeEnv] ?? '';
      isOverridden = false;
    }

    current.value = EnvConfig(
      env: activeEnv,
      baseUrl: baseUrl,
      values: const <String, String>{},
      loadedAt: DateTime.now(),
      isBaseUrlOverridden: isOverridden,
    );

    _initialEnv = activeEnv;
    _initialBaseUrl = baseUrl;
    _restartNeeded.value = false;
    _initialised = true;

    // Initialize registered adapters.
    for (final adapter in _adapters) {
      try {
        await adapter.initialize(current.value);
      } catch (_) {
        // Adapter init failures are non-fatal during boot; they surface on switch.
      }
    }
  }

  // ── Adapter registration ──────────────────────────────────────────────────

  /// Registers a [EnvifiedServiceAdapter]. Must be called before [init].
  void registerAdapter(EnvifiedServiceAdapter adapter) {
    if (_adapters.any((a) => a.adapterName == adapter.adapterName)) return;
    _adapters.add(adapter);
  }

  // ── Switching ─────────────────────────────────────────────────────────────

  /// Switches the active environment to [env] using the 8-step lifecycle.
  ///
  /// If any adapter fails during [reinitialize], the switch is rolled back and
  /// [EnvifiedSwitchException] is thrown.
  Future<void> switchTo(Env env) async {
    _assertInitialised();

    final targetEnv = _urls.keys.firstWhere(
      (e) => e.name == env.name,
      orElse: () => env,
    );

    // Step 1 — production lock check.
    if (!_allowProdSwitch &&
        !current.value.env.isProduction &&
        targetEnv.isProduction) {
      debugPrint('Envified: switching TO production is blocked.');
      return;
    }

    // Step 2 — before-switch hook.
    if (_onBeforeSwitch != null) {
      await _onBeforeSwitch!(current.value.env, targetEnv);
    }

    final Env fromEnv = current.value.env;
    final EnvConfig fromConfig = current.value;

    // Step 3 — activate native key context for target env.
    await _channel.initialize(env: targetEnv.name);

    // Step 4 — resolve new config values.
    final String? override = _urlOverrides[targetEnv.name];
    final String baseUrl;
    final bool isOverridden;
    if (override != null && override.isNotEmpty) {
      baseUrl = override;
      isOverridden = true;
    } else {
      baseUrl = _urls[targetEnv] ?? '';
      isOverridden = false;
    }

    final newConfig = EnvConfig(
      env: targetEnv,
      baseUrl: baseUrl,
      values: const <String, String>{},
      loadedAt: DateTime.now(),
      isBaseUrlOverridden: isOverridden,
    );

    // Step 5 — re-initialize each adapter; roll back on failure.
    final List<EnvifiedServiceAdapter> initialized = [];
    for (final adapter in _adapters) {
      try {
        await adapter.reinitialize(fromConfig, newConfig);
        initialized.add(adapter);
      } catch (e) {
        // Rollback all successfully re-initialized adapters.
        for (final done in initialized.reversed) {
          try {
            await done.reinitialize(newConfig, fromConfig);
          } catch (_) {}
        }
        // Restore native key context to the old env.
        await _channel.initialize(env: fromEnv.name);
        throw EnvifiedSwitchException(
          failedAdapter: adapter.adapterName,
          cause: e,
        );
      }
    }

    // Step 6 — update current config.
    current.value = newConfig;

    // Step 7 — persist new selection.
    _restartNeeded.value =
        (targetEnv != _initialEnv || baseUrl != _initialBaseUrl);

    if (_persistSelection) {
      await _storage.saveConfig(current.value);
    }

    // Step 8 — after-switch hook + audit.
    _onAfterSwitch?.call(current.value);

    await _storage.appendAudit(AuditEntry(
      timestamp: DateTime.now().toUtc(),
      action: 'switch',
      fromEnv: fromEnv.name,
      toEnv: targetEnv.name,
    ));
  }

  /// Signals that the app has been restarted; resets the restart-needed flag.
  void acknowledgeRestart() {
    _initialEnv = current.value.env;
    _initialBaseUrl = current.value.baseUrl;
    _restartNeeded.value = false;
  }

  // ── Value access ──────────────────────────────────────────────────────────

  String get(String key, {String fallback = ''}) =>
      current.value.values[key] ?? fallback;

  bool getBool(String key, {bool fallback = false}) {
    final raw = current.value.values[key];
    if (raw == null) return fallback;
    return const {'true', '1', 'yes'}.contains(raw.toLowerCase());
  }

  int getInt(String key, {int fallback = 0}) {
    final raw = current.value.values[key];
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  double getDouble(String key, {double fallback = 0.0}) {
    final raw = current.value.values[key];
    if (raw == null) return fallback;
    return double.tryParse(raw) ?? fallback;
  }

  Uri? getUri(String key) {
    final raw = current.value.values[key];
    if (raw == null || raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  List<String> getList(String key, {String separator = ','}) {
    final raw = current.value.values[key];
    if (raw == null || raw.isEmpty) return <String>[];
    return raw.split(separator).map((e) => e.trim()).toList();
  }

  bool isProduction(Env env) => _productionEnvs.contains(env);
  bool get autoDiscover => false;
  bool get verifyIntegrity => false;
  Set<Env> get productionEnvs => _productionEnvs;
  bool isSensitive(String key) => EnvConfig.isSensitiveKey(key);
  bool get isProdLocked => !_allowProdSwitch && current.value.env.isProduction;
  bool get allowProdSwitch => _allowProdSwitch;

  String getOriginalUrl(Env env) => _urls[env] ?? '';

  List<Env> get availableEnvs => _urls.keys.toList()
    ..sort((a, b) {
      if (a.isProduction != b.isProduction) return a.isProduction ? 1 : -1;
      return a.name.compareTo(b.name);
    });

  // ── Base URL override ─────────────────────────────────────────────────────

  Future<void> setBaseUrl(String url) async {
    _assertInitialised();
    _assertNotProdLocked('Cannot override base URL in production.');
    _assertUrlAllowed(url);

    current.value = current.value.copyWith(
      baseUrl: url,
      isBaseUrlOverridden: true,
    );
    _restartNeeded.value =
        (current.value.env != _initialEnv || url != _initialBaseUrl);
    _onAfterSwitch?.call(current.value);

    if (_persistSelection) {
      _urlOverrides[current.value.env.name] = url;
      await _storage.saveOverrides(_urlOverrides);
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

    final restoredUrl = _urls[current.value.env] ?? '';
    current.value = current.value.copyWith(
      baseUrl: restoredUrl,
      isBaseUrlOverridden: false,
    );
    _restartNeeded.value =
        (current.value.env != _initialEnv || restoredUrl != _initialBaseUrl);

    if (_persistSelection) {
      _urlOverrides.remove(current.value.env.name);
      await _storage.saveOverrides(_urlOverrides);
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

    if (_persistSelection) await _storage.clear();

    await init(
      defaultEnv: _defaultEnv,
      persistSelection: _persistSelection,
      allowProdSwitch: _allowProdSwitch,
      storage: _storage,
      channel: _channel,
      onBeforeSwitch: _onBeforeSwitch,
      onAfterSwitch: _onAfterSwitch,
      allowedUrls: _allowedUrls,
      urls: _urls,
    );
  }

  // ── Audit / History ───────────────────────────────────────────────────────

  Future<List<AuditEntry>> get auditLog => _storage.loadAuditLog();
  Future<List<String>> get urlHistory => _storage.loadUrlHistory();

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _assertInitialised() {
    if (!_initialised) {
      throw StateError('EnvConfigService has not been initialised.');
    }
  }

  void _assertNotProdLocked(String message) {
    if (isProdLocked) throw EnvifiedLockException(message);
  }

  void _assertUrlAllowed(String url) {
    final allowed = _allowedUrls;
    if (allowed == null || allowed.isEmpty) return;
    if (!allowed.any((prefix) => url.startsWith(prefix))) {
      throw EnvifiedUrlNotAllowedException(url);
    }
  }

  // ── Testing helpers ───────────────────────────────────────────────────────

  @visibleForTesting
  void resetForTesting() {
    _initialised = false;
    current.value = EnvConfig(
      env: Env.dev,
      baseUrl: '',
      values: const <String, String>{},
      loadedAt: DateTime.now(),
    );
    _urls = <Env, String>{};
    _allowProdSwitch = false;
    _persistSelection = true;
    _defaultEnv = Env.dev;
    _allowedUrls = null;
    _onBeforeSwitch = null;
    _onAfterSwitch = null;
    _urlOverrides = <String, String>{};
    _adapters.clear();
    _restartNeeded.value = false;
  }

  @visibleForTesting
  static void resetInstance() => instance.resetForTesting();

  @visibleForTesting
  static void overrideForTesting(
      {EnvStorage? storage, EnvifiedChannel? channel}) {
    if (storage != null) instance._storage = storage;
    if (channel != null) instance._channel = channel;
  }
}

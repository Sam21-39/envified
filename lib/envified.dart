/// envified — Runtime environment switching for Flutter with native AES-256-GCM security.
///
/// v4.0.0: `.env.*` files are never bundled as Flutter assets. All config is
/// pre-compiled by the `envified` CLI into a hardware-backed native registry
/// (Android Keystore / iOS Keychain). Secrets never materialise as Dart heap
/// strings.
///
/// ## Quick start
///
/// ```dart
/// import 'package:envified/envified.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await AppConfig.init(
///     defaultEnv: Env.dev,
///     allowProdSwitch: false,
///   );
///
///   runApp(
///     MaterialApp(
///       builder: (context, child) => EnvifiedOverlay(
///         service: EnvConfigService.instance,
///         enabled: kDebugMode,
///         gate: const EnvGate(pin: '1234'),
///         trigger: const EnvTrigger.tap(count: 7),
///         child: child ?? const SizedBox.shrink(),
///       ),
///     ),
///   );
/// }
/// ```
///
/// ## Public API
///
/// | Symbol                           | Purpose                                              |
/// |----------------------------------|------------------------------------------------------|
/// | [AppConfig]                      | Facade: `init`, `get`, `getBool`, `getInt`, …        |
/// | [EnvConfigService]               | Singleton service — switch, adapters, lifecycle      |
/// | [Env]                            | Environment identity (name, isProduction, …)         |
/// | [EnvConfig]                      | Immutable config snapshot                            |
/// | [EnvTier]                        | Tier routing: runtime / secret / remote              |
/// | [SecretHandle]                   | Opaque Tier-2 secret reference (never a Dart String) |
/// | [TierResolver]                   | Routes keys to tiers from envified.yaml config       |
/// | [EnvifiedServiceAdapter]         | Interface for Firebase / Supabase / Maps adapters    |
/// | [EnvifiedLockException]          | Production lock violation                            |
/// | [EnvifiedTamperException]        | GCM tag / integrity failure                          |
/// | [EnvifiedUrlNotAllowedException] | URL not in allowlist                                 |
/// | [EnvifiedSwitchException]        | Adapter failure during switchTo (with rollback)      |
/// | [EnvifiedNativeException]        | Typed wrapper for PlatformException from channel     |
/// | [AuditEntry]                     | Single record in the audit log                       |
/// | [EnvDebugPanel]                  | Standalone debug widget                              |
/// | [EnvifiedOverlay]                | Floating-button overlay wrapper                      |
/// | [EnvStatusBadge]                 | Persistent env indicator badge                       |
/// | [EnvGate]                        | PIN access gate for the debug panel                  |
/// | [EnvTrigger]                     | Gesture to open the panel (tap / shake / edge-swipe) |
library envified;

// Core models
export 'src/models/env.dart' show Env, EnvConfig;
export 'src/models/env_tier.dart' show EnvTier;
export 'src/models/secret_handle.dart' show SecretHandle;
export 'src/models/audit_entry.dart' show AuditEntry;
export 'src/models/envified_exception.dart'
    show
        EnvifiedLockException,
        EnvifiedTamperException,
        EnvifiedUrlNotAllowedException,
        EnvifiedMissingFileException,
        EnvifiedNativeException,
        EnvifiedSwitchException,
        EnvifiedKeyRotationException;

// Channel
export 'src/channel/envified_channel.dart' show EnvifiedChannel;

// Resolver
export 'src/resolver/tier_resolver.dart' show TierResolver;

// Adapters
export 'src/adapters/envified_service_adapter.dart' show EnvifiedServiceAdapter;

// Service
export 'src/service/env_config_service.dart' show EnvConfigService;
export 'src/service/app_config.dart' show AppConfig;

// Storage (retained for custom-storage advanced usage)
export 'src/storage/env_storage.dart' show EnvStorage;

// UI
export 'src/ui/env_gate.dart' show EnvGate;
export 'src/ui/env_debug_panel.dart' show EnvDebugPanel;
export 'src/ui/envified_overlay.dart' show EnvifiedOverlay;
export 'src/ui/env_status_badge.dart' show EnvStatusBadge;
export 'src/ui/env_trigger.dart' show EnvTrigger, EnvTriggerDetector;

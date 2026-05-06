/// envified — Runtime environment switching for Flutter.
///
/// Load `.env` files, switch dev/staging/prod/custom at runtime, override
/// base URLs, and lock production config — no rebuild required.
///
/// ## Quick start
///
/// ```dart
/// import 'package:envified/envified.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await EnvConfigService.instance.init(
///     defaultEnv: Env.dev,
///     persistSelection: true,
///     allowProdSwitch: false,
///     verifyIntegrity: true,
///     onBeforeSwitch: (from, to) async {
///       debugPrint('Switching: ${from.name} → ${to.name}');
///     },
///     onAfterSwitch: (config) {
///       debugPrint('Active env: ${config.env.longLabel}');
///     },
///   );
///
///   runApp(
///     MaterialApp(
///       builder: (context, child) => EnvifiedOverlay(
///         service: EnvConfigService.instance,
///         enabled: kDebugMode,
///         gate: EnvGate(pin: '1234'),
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
/// | Symbol                         | Purpose                                              |
/// |-------------------------------|------------------------------------------------------|
/// | [Env]                          | Enum of supported environments                       |
/// | [EnvConfig]                    | Immutable snapshot of the active configuration       |
/// | [EnvConfigService]             | Singleton service — init, switch, get, setBaseUrl    |
/// | [EnvifiedLockException]        | Thrown when the production lock blocks an action     |
/// | [EnvifiedTamperException]      | Thrown when a .env file hash mismatches baseline     |
/// | [EnvifiedUrlNotAllowedException] | Thrown when setBaseUrl rejects a non-allowlisted URL|
/// | [AuditEntry]                   | A single record in the encrypted audit log           |
/// | [EnvDebugPanel]                | Standalone debug widget for manual placement         |
/// | [EnvifiedOverlay]              | Floating-button overlay wrapper                      |
/// | [EnvStatusBadge]               | Persistent env indicator badge with pulse animation  |
/// | [EnvGate]                      | PIN / biometric access gate for the debug panel      |
/// | [EnvTrigger]                   | Sealed class defining the gesture to open the panel  |
library envified;

export 'src/env_model.dart' show Env, EnvConfig, EnvX, EnvName;
export 'src/env_config_service.dart' show EnvConfigService;
export 'src/envified_exception.dart'
    show
        EnvifiedLockException,
        EnvifiedTamperException,
        EnvifiedUrlNotAllowedException;
export 'src/audit_entry.dart' show AuditEntry;
export 'src/env_gate.dart' show EnvGate;
export 'src/ui/env_debug_panel.dart' show EnvDebugPanel;
export 'src/ui/envified_overlay.dart' show EnvifiedOverlay;
export 'src/ui/env_status_badge.dart' show EnvStatusBadge;
export 'src/ui/env_trigger.dart' show EnvTrigger;

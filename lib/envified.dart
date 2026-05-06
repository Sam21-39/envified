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
///   );
///
///   runApp(
///     EnvifiedOverlay(
///       service: EnvConfigService.instance,
///       enabled: kDebugMode,
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ## Public API
///
/// | Symbol                | Purpose                                              |
/// |-----------------------|------------------------------------------------------|
/// | [Env]                 | Enum of supported environments                       |
/// | [EnvConfig]           | Immutable snapshot of the active configuration       |
/// | [EnvConfigService]    | Singleton service — init, switch, get, setBaseUrl    |
/// | [EnvifiedLockException] | Thrown when the production lock blocks an action   |
/// | [EnvDebugPanel]       | Standalone debug widget for manual placement         |
/// | [EnvifiedOverlay]     | Floating-button overlay wrapper                      |
library envified;

export 'src/env_model.dart' show Env, EnvConfig, EnvX;
export 'src/env_config_service.dart' show EnvConfigService;
export 'src/envified_exception.dart' show EnvifiedLockException;
export 'src/ui/env_debug_panel.dart' show EnvDebugPanel;
export 'src/ui/envified_overlay.dart' show EnvifiedOverlay;

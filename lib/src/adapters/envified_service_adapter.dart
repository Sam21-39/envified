import '../models/env.dart';

/// Interface for services that must be re-initialized when the active
/// environment changes.
///
/// Register adapters via [EnvConfigService.registerAdapter] before calling
/// [EnvConfigService.init]. Each adapter participates in the 8-step switch
/// lifecycle and is rolled back automatically if it throws during
/// [reinitialize].
abstract interface class EnvifiedServiceAdapter {
  /// Unique name identifying this adapter (e.g. `"firebase"`, `"supabase"`).
  String get adapterName;

  /// Called once during [EnvConfigService.init] with the initial config.
  Future<void> initialize(EnvConfig config);

  /// Called during [EnvConfigService.switchTo] to transition from [from] to
  /// [to]. If this throws, the switch is rolled back.
  Future<void> reinitialize(EnvConfig from, EnvConfig to);

  /// Called when the adapter is no longer needed (e.g. on [EnvConfigService.reset]).
  Future<void> dispose();
}

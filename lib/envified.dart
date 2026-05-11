/// envified — Runtime environment switching for Flutter.
///
/// Load `.env` files, switch dev/staging/prod at runtime, override
/// base URLs, and compute integrity hashes — no rebuild required.
library envified;

export 'src/models/env.dart';
export 'src/models/env_config.dart';
export 'src/models/envified_exception.dart';
export 'src/models/audit_entry.dart'
    show AuditEntry, AuditAction, formatAuditTimestamp;

export 'src/gate/env_gate.dart';
export 'src/service/env_config_service.dart';
export 'src/triggers/env_trigger.dart' show EnvTrigger, EnvShakeDetector;

export 'src/ui/envified_overlay.dart';
export 'src/ui/env_status_badge.dart';
export 'src/ui/env_debug_panel.dart';

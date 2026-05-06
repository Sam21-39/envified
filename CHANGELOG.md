# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-06

### Added

- **Runtime environment switching** — Switch between `dev`, `staging`, `prod`,
  and `custom` environments without a rebuild.
- **`.env` file loading** — Parses `.env`, `.env.dev`, `.env.staging`, and
  `.env.prod` from Flutter assets at runtime. Supports shared fallback values
  with per-environment overrides.
- **Base URL override** — `setBaseUrl()` and `clearBaseUrlOverride()` allow
  changing the active API base URL independently of the `.env` file. Overrides
  persist across restarts via `SharedPreferences`.
- **Production lock** — When `allowProdSwitch: false` (default), switching away
  from `Env.prod` or modifying the base URL throws `EnvifiedLockException`,
  preventing accidental config changes in production.
- **`EnvConfigService` singleton** — Central service with `init()`, `switchTo()`,
  `get()`, `setBaseUrl()`, `clearBaseUrlOverride()`, and `reset()`.
- **`EnvConfig` model** — Immutable snapshot with `copyWith`, `toJson`,
  `fromJson`, and equality.
- **`EnvifiedOverlay` widget** — Transparent wrapper that injects a floating
  🌿 button into the Overlay; opens `EnvDebugPanel` in a bottom sheet.
- **`EnvDebugPanel` widget** — Standalone debug panel with env switcher,
  URL override field, key-value table, reset button, and prod-lock UI.
- **`EnvifiedLockException`** — Typed exception for all production-lock
  violations.
- **Persistence** — Active env selection and base URL override survive app
  restarts via `SharedPreferences`.
- **`ValueNotifier<EnvConfig>`** — Reactive integration; widgets can rebuild
  automatically on env changes.

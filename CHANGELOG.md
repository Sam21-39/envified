# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.8] - 2026-05-07

### Improved
- **Showcase Cleanup**: Renamed internal assets for a more professional repository structure (`envified-demo.gif`).
- **Security Documentation**: Added critical disclaimers about `.env` asset security vs. encrypted runtime persistence.
- **Developer UX**: Added PIN code best practice comments to documentation snippets.
- **Documentation Polish**: De-duplicated support links and synced all feature tables with recent API changes.

## [2.0.7] - 2026-05-07

### Removed
- **Removed `local_auth` Dependency**: Removed biometric authentication completely to prevent upstream dependency conflicts, reducing package size and simplifying platform setup. The debug panel is still securely protected via the PIN code gate.

## [2.0.6] - 2026-05-07

### Fixed
- Fixed critical bug where `EnvGate` PIN dialog would crash when `EnvifiedOverlay` was placed in `MaterialApp.builder` due to missing `Navigator` context. The PIN dialog is now rendered directly via `OverlayEntry`.
- Fixed compilation error in `env_gate.dart`: updated `local_auth` API usage
  - Replaced deprecated `AuthenticationOptions` with `AndroidAuthMessages` via `authMessages`
  - Now fully compatible with `local_auth >= 2.2.0 < 4.0.0`
- Fixed platform declarations in `pubspec.yaml` (`android`, `ios`) for full pub.dev platform support scoring

### Improved
- Platform support score: now 20/20 points (up from 0/20)
- Code compiles cleanly (zero errors, zero warnings)

## [2.0.5] - 2026-05-07

### Improved
- Added explicit platform declaration (`platforms: flutter`) for full pub.dev platform support scoring
- Tightened all dependency version constraints for better stability signaling
  - Changed `^x.y.z` to `>=x.y.z <(x+1).0.0` across all dependencies
- Expanded documentation: added FAQ section, platform setup instructions, and API reference
- Enhanced example app to showcase all 8 major features
- Added showcase GIF to README to visualize the debug panel in action
- Complete README overhaul with a premium presentation and feature highlights

### Fixed
- Dependency resolution confidence (platform support +10 pts, dependency stability +20 pts)

## [2.0.4] - 2026-05-07

- Added PayWithChai support page (direct UPI — paywithchai.in/appamania)
- Updated README support section with real payment tiers
- Added funding field to pubspec.yaml for pub.dev Support button

## [2.0.3] - 2026-05-07

- Fix: README images now load correctly on pub.dev (raw.githubusercontent.com URLs)

## [2.0.2] - 2026-05-07

- Fix: widened constraints for `flutter_secure_storage` (v10), `local_auth` (v3), and `sensors_plus` (v7) to support the latest major versions without breaking backward compatibility.

## [2.0.1] - 2026-05-07

- Fix: resolved dartdoc cross-reference warnings for internal symbols
- Fix: replaced unresolvable [FlutterSecureStorage] references with prose
- Fix: replaced unresolvable [EnvFileParser.verifyIntegrity] reference
- Fix: replaced unresolvable [MediaQuery.disableAnimations] reference

## [2.0.0] - 2026-05-07

### Major Release 🚀 — Eight Improvements

#### 1. Tamper Detection (`verifyIntegrity`)
- `EnvFileParser.verifyIntegrity()` computes a SHA-256 hash of each `.env*` file on first load and stores it in `flutter_secure_storage`.
- Subsequent loads recompute and compare — a hash mismatch throws the new `EnvifiedTamperException`.
- Opt-in via `EnvConfigService.init(verifyIntegrity: true)`.

#### 2. Access Token Gate (`EnvGate`)
- New `EnvGate` class exported from the public API.
- Supports secure PIN-code authentication before allowing access to the debug panel.
- (Note: Biometric support was temporarily included in early v2 betas but removed in v2.0.7 to ensure upstream dependency stability).
- Pass `gate: EnvGate(pin: '1234')` to `EnvifiedOverlay` to require auth before revealing the debug panel.
- PIN dialog implemented inline (no third-party packages) with 4 obscured digit fields.
- Auto-clears authentication state when the app is backgrounded.

#### 3. Typed Get Helpers
- `getBool(key)` — accepts `'true'`, `'1'`, `'yes'` (case-insensitive).
- `getInt(key)` — wraps `int.tryParse`.
- `getDouble(key)` — wraps `double.tryParse`.
- `getUri(key)` — wraps `Uri.tryParse`, returns `null` on failure.
- `getList(key, {separator})` — splits and trims CSV values.

#### 4. Lifecycle Hooks
- `onBeforeSwitch: Future<void> Function(Env from, Env to)?` — awaited before `switchTo()` changes the active env.
- `onAfterSwitch: void Function(EnvConfig config)?` — called after `switchTo()` and `setBaseUrl()`.
- Both hooks are supplied to `EnvConfigService.init()`.
- New `EnvName` extension on `Env` with `longLabel` (e.g. `"Development"`, `"Production"`).

#### 5. URL History Picker
- `EnvStorage.saveUrlToHistory()` / `loadUrlHistory()` — persists up to 5 recent URLs (deduped, newest-first) in secure storage.
- `EnvConfigService.urlHistory` exposes the list.
- `EnvDebugPanel` shows a "Recent" row of tappable `ActionChip` widgets below the URL override field.
- Tapping a chip applies the URL and updates the text field.

#### 6. Env Status Badge (`EnvStatusBadge`)
- New standalone `EnvStatusBadge` widget.
- Colour-coded per environment (blue / orange / red / purple).
- Pulsing opacity animation (1.0 ↔ 0.7, 1.5 s) when `isBaseUrlOverridden` is `true`.
- Respects `MediaQuery.disableAnimations` (system reduced-motion preference).
- Configurable `alignment` and `margin`.

#### 7. Gesture Trigger Config (`EnvTrigger`)
- New `sealed class EnvTrigger` replacing the hard-coded FAB tap.
- `EnvTrigger.tap(count: 7)` — N rapid taps within 800 ms (default).
- `EnvTrigger.shake(threshold: 15.0)` — accelerometer shake via `sensors_plus`, 2 s debounce.
- `EnvTrigger.edgeSwipe(edgeWidth: 20)` — right-edge inward swipe via `Listener`.
- Pass `trigger:` to `EnvifiedOverlay`.
- Added `showFab: false` option to `EnvifiedOverlay` to enable a true "stealth mode" where the floating 🌿 button is hidden and the trigger is the exclusive way to access the panel.
- Fixed a bug where taps on the panel or FAB incorrectly advanced the hidden tap count, ensuring triggers accurately reflect gesture counts.

#### 8. Audit Log
- `AuditEntry` model (exported) with `timestamp`, `action`, `fromEnv`, `toEnv`, `url`.
- Every mutation (`switchTo`, `setBaseUrl`, `clearBaseUrlOverride`, `reset`) appends an entry to `flutter_secure_storage`.
- Log is capped at 50 entries; oldest are dropped.
- `EnvConfigService.auditLog` returns the full list.
- `EnvDebugPanel` shows an expandable "Activity log (N entries)" tile with the last 10 entries.

#### Auto-lock on Background
- `EnvifiedOverlay` registers an `AppLifecycleListener` on `onHide` / `onPause`.
- The panel closes and authentication is cleared whenever the app moves to background.

### New Dependencies
- `sensors_plus: ^5.0.0`
- `crypto: ^3.0.0`
- `flutter_secure_storage: ^9.0.0` (Encrypted persistence)

### Breaking Changes
- `Env.label` now returns short form (`'Dev'`, `'Staging'`, `'Prod'`, `'Custom'`).
  Use the new `Env.longLabel` (via `EnvName` extension) for full names.
- `EnvStorage.clear()` now also deletes URL history and audit log keys.

### Migration Guide from 1.0.0
```dart
// Before
await EnvConfigService.instance.init(defaultEnv: Env.dev);

// After (all new params are optional with safe defaults)
await EnvConfigService.instance.init(
  defaultEnv: Env.dev,
  verifyIntegrity: false, // opt-in
  onBeforeSwitch: null,   // optional
  onAfterSwitch: null,    // optional
  allowedUrls: null,      // optional
);

// EnvifiedOverlay — new optional params
EnvifiedOverlay(
  service: EnvConfigService.instance,
  enabled: kDebugMode,
  gate: null,                              // optional
  trigger: const EnvTrigger.tap(count: 7), // default unchanged
  showFab: true,                           // optional (set to false for stealth mode)
  child: child!,
)
```

---

## [1.0.0] - 2026-05-06

### Initial Stable Release 🚀

- **Runtime Environment Switching** — Seamlessly swap between `dev`, `staging`, `prod`, and `custom` without rebuilding your app.
- **Enterprise-Grade Security** — Fully encrypted persistence layer using `flutter_secure_storage`. Choices and overrides are stored in Keychain/Keystore.
- **Production Lock** — Prevent accidental environment switches or URL overrides in production builds.
- **API URL Overrides** — Dynamically point your app to any backend URL at runtime (perfect for local testing or PR reviews).
- **Premium Debug UI** — Built-in, horizontally scrollable action chip panel and floating action button that only appears in debug mode.
- **Zero-Overhead** — Debug components are completely optimized out in release builds.
- **Bulletproof Reliability** — Comprehensive unit test suite covering parsing, models, storage, and service logic.

## [0.1.2] - 2026-05-06
- Security upgrade to encrypted storage.
- Storage injection for unit testing.

## [0.1.0] - 2026-05-06
- Initial beta release.

# 🌿 envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![pub points](https://img.shields.io/pub/points/envified?color=blue)](https://pub.dev/packages/envified/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart CI](https://github.com/Sam21-39/envified/actions/workflows/dart.yml/badge.svg)](https://github.com/Sam21-39/envified/actions/workflows/dart.yml)
[![Buy me a Chai](https://img.shields.io/badge/☕%20Support%20-paywithchai-FF5722?style=flat)](https://paywithchai.in/appamania)

> **Stop rebuilding. Start switching.** ⚡  
> Runtime environment magic for Flutter apps. No hot reload needed.

---

## The Problem

You're a Flutter developer. Every time you need to test a different API endpoint—local dev server, staging, production—you rebuild the app. With `--dart-define` flags. Or `.env` files baked into the binary. Or multiple entry points. It's tedious. It's error-prone. It breaks flow.

**What if you could swap environments in 0.2 seconds? No rebuild. No compilation. Just tap, tap, done.**

That's `envified`.

---

## What is envified?

`envified` is a **production-grade environment manager** for Flutter that lives entirely at runtime.

- 🚀 **Swap dev ↔ prod in 200ms** — no rebuild, no hot reload
- 🔒 **Prod lock by default** — prevent accidental data disasters  
- 🧪 **Override any URL** — test against local tunnels, PR branches, anywhere
- 🔐 **PIN gate** — secure the debug panel
- 📋 **Full audit trail** — log every switch and URL change
- ⚙️ **Zero production overhead** — stripped out completely in release builds
- 🎨 **Premium debug UI** — dark-luxury design, fully customizable

It's not just a config switcher. It's **enterprise-grade security** meets **developer quality of life**.

> [!NOTE]  
> **Security Note:** While `envified` encrypts the active configuration state and overrides on the device (via Keychain/Keystore), the base `.env` files stored in your Flutter assets remain plaintext. Never store high-stakes production secrets directly in `.env` files; they should be fetched at runtime from a secure vault or used for non-sensitive configuration only.

---

## 📸 See It In Action

<p align="center">
  <img src="https://raw.githubusercontent.com/Sam21-39/envified/main/example/assets/gifs/envified-demo.gif" width="280" alt="Live demo: tap to switch" />
</p>

---

## v2.0+ — What's Inside

| Feature | What It Does | Why You Care |
|---------|-------------|--------------|
| **Tamper Detection** | SHA-256 hashes `.env*` files; throws if modified | Catch rogue config changes on rooted devices |
| **Access Gate** | PIN dialog before opening panel | QA devices don't leak sensitive switches |
| **Typed Getters** | `getBool()`, `getInt()`, `getUri()`, `getList()` | No more string parsing bugs |
| **Lifecycle Hooks** | `onBeforeSwitch` / `onAfterSwitch` callbacks | Flush HTTP queues, log analytics, etc. |
| **URL History** | Last 5 URLs one-tap available | Faster testing against recent tunnels |
| **Status Badge** | Persistent `[DEV]` indicator in your app | Never forget what env you're testing |
| **Gesture Triggers** | Tap N times, shake, or swipe edge to open | Customize to your preference |
| **Audit Log** | Encrypted log of every switch (capped 50 entries) | "Who changed prod at 3pm?" |
| **Auto-lock** | Panel closes when app backgrounded | Shoulder-surf proof |

---

## Quick Start (3 Steps)

### 1️⃣ Install

```yaml
dependencies:
  envified: ^2.0.7
```

### 2️⃣ Add `.env` Files

Create in `assets/env/`:

```env
# .env (shared across all envs)
APP_NAME=MyApp
TIMEOUT=30

# .env.dev
BASE_URL=https://dev.api.myapp.com
DEBUG=true

# .env.staging
BASE_URL=https://staging.api.myapp.com
DEBUG=false

# .env.prod
BASE_URL=https://api.myapp.com
DEBUG=false
```

Register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/env/.env
    - assets/env/.env.dev
    - assets/env/.env.staging
    - assets/env/.env.prod
```

### 3️⃣ Initialize

In `main.dart`, before `runApp()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    allowProdSwitch: false,    // ⚠️ Lock prod by default
    verifyIntegrity: true,     // 🔐 Detect tampering
    onBeforeSwitch: (from, to) {
      debugPrint('Switching: ${from.name} → ${to.name}');
    },
  );

  runApp(const MyApp());
}
```

Wrap your app with the overlay:

```dart
MaterialApp(
  builder: (context, child) => EnvifiedOverlay(
    service: EnvConfigService.instance,
    enabled: kDebugMode,                        // 🚫 Hidden in production
    gate: EnvGate(pin: '1234'), // 🔐 PIN (Don't hardcode in a real app)
    trigger: const EnvTrigger.tap(count: 7),    // 7-tap to open
    child: child ?? const SizedBox.shrink(),
  ),
  home: const MyApp(),
)
```

**Done.** 7 taps anywhere on the screen and you can switch environments in real-time.

---

## Core Usage Patterns

### Reading Values

```dart
final svc = EnvConfigService.instance;

// String
final name = svc.get('APP_NAME');

// Typed (with fallbacks)
final timeout  = svc.getInt('TIMEOUT', fallback: 30);
final debug    = svc.getBool('DEBUG');
final apiUrl   = svc.getUri('BASE_URL');
final hosts    = svc.getList('ALLOWED_HOSTS'); // comma-separated
```

### Reacting to Switches

`EnvConfigService.current` is a `ValueNotifier`. Use it with:

**ValueListenableBuilder:**
```dart
ValueListenableBuilder<EnvConfig>(
  valueListenable: EnvConfigService.instance.current,
  builder: (context, config, _) {
    return Text('Env: ${config.env.name} (${config.baseUrl})');
  },
)
```

**Listener (one-time setup):**
```dart
EnvConfigService.instance.current.addListener(() {
  final config = EnvConfigService.instance.current.value;
  dio.options.baseUrl = config.baseUrl;
  analytics.setProperty('env', config.env.name);
});
```

### Customizing the Panel

```dart
EnvifiedOverlay(
  service: EnvConfigService.instance,
  trigger: EnvTrigger.shake(),                    // Shake to open
  gate: EnvGate(pin: '0000'),                     // PIN only (fetch securely in prod)
  showFab: false,                                 // Stealth mode (hidden button)
  child: child!,
)
```

### Adding the Status Badge

Display a persistent env indicator (optional):

```dart
Stack(
  children: [
    MyApp(),
    if (kDebugMode)
      EnvStatusBadge(
        service: EnvConfigService.instance,
        alignment: Alignment.topRight,            // Corner position
      ),
  ],
)
```

The badge pulses amber when a custom URL override is active.

---

## Security & Production Safety

### 🔒 Production Lock

By default, `allowProdSwitch: false` locks the production environment:

```dart
await EnvConfigService.instance.init(
  allowProdSwitch: false,  // ← Once in prod, can't switch out
);
```

This prevents accidental data disasters. To unlock (dev only):

```dart
allowProdSwitch: true  // Use only in debug/test builds
```

### 🔐 Access Gate (PIN)

Require authentication before opening the debug panel:

```dart
EnvGate(pin: '1234')                          // PIN only (Don't hardcode in real apps)
```

The gate auto-clears when the app is backgrounded. Next open requires re-auth.

### ✅ Tamper Detection

SHA-256 integrity checks on `.env*` files:

```dart
await EnvConfigService.instance.init(
  verifyIntegrity: true,  // 🔍 Detect if .env was modified
);
```

Throws `EnvifiedTamperException` if a file changes after first load (rooted device attack detection).

### 📋 Audit Log

Every switch and URL change is logged (encrypted, capped at 50 entries):

```dart
final entries = await EnvConfigService.instance.auditLog;
for (final entry in entries) {
  print('${entry.timestamp} — ${entry.action}');
  // e.g. "2026-05-07T10:30:00Z — switch (dev → prod)"
}
```

Last 10 entries visible in the debug panel.

### ⚙️ Zero Production Overhead

All debug code is wrapped in `kDebugMode`:

```dart
EnvifiedOverlay(
  enabled: kDebugMode,  // ← Entire widget tree stripped in release
  ...
)
```

Tree-shaking removes the button, panel, and all gates from your release APK/IPA. **Zero bytes added to production.**

---

## Gesture Triggers

Choose how to open the panel:

| Trigger | Example | Best for |
|---------|---------|----------|
| **Tap N times** | `EnvTrigger.tap(count: 7)` | Universal (no special hardware) |
| **Shake** | `EnvTrigger.shake(threshold: 15.0)` | Mobile-friendly, intuitive |
| **Edge swipe** | `EnvTrigger.edgeSwipe(edgeWidth: 20)` | Stealth (easy to hide) |

**Stealth mode:** Set `showFab: false` to hide the floating button and use *only* the gesture:

```dart
EnvifiedOverlay(
  trigger: EnvTrigger.shake(),
  showFab: false,  // 👻 Button completely hidden
  child: child!,
)
```

---

## State Management Integration

`envified` is framework-agnostic. Integrate with any state management:

### GetX

```dart
Get.put(EnvConfigService.instance, permanent: true);

// Later, anywhere:
final svc = Get.find<EnvConfigService>();
final baseUrl = svc.current.value.baseUrl;
```

### Riverpod

```dart
final envServiceProvider = Provider<EnvConfigService>((ref) {
  return EnvConfigService.instance;
});

final baseUrlProvider = Provider<String>((ref) {
  final svc = ref.watch(envServiceProvider);
  return svc.current.value.baseUrl;
});
```

### BLoC

```dart
EnvConfigService.instance.current.addListener(() {
  add(EnvChanged(EnvConfigService.instance.current.value));
});
```

---

## Lifecycle Hooks

Run code before/after environment switches:

```dart
await EnvConfigService.instance.init(
  onBeforeSwitch: (from, to) async {
    // Flush pending HTTP requests
    await _api.flushQueue();
    // Wait for active transactions to complete
    await _db.waitForCommits();
  },
  onAfterSwitch: (config) {
    // Update HTTP client
    _dio.options.baseUrl = config.baseUrl;
    // Log to analytics
    _analytics.logEvent('env_switched', {'env': config.env.name});
    // Refresh UI
    _eventBus.emit(EnvChangedEvent(config));
  },
);
```

---

## Migration from v1.0.0

All new features are **optional** with sensible defaults. Your existing v1.0.0 code works unchanged:

```dart
// v1.0.0 style — still works
await EnvConfigService.instance.init(defaultEnv: Env.dev);

EnvifiedOverlay(
  service: EnvConfigService.instance,
  enabled: kDebugMode,
  child: child!,
)
```

The only **breaking change**: `EnvStorage.clear()` now also wipes URL history and audit log (desired for full reset). If you need selective deletion, use the new targeted methods.

---

## ❓ FAQ

**Q: Does this slow down my app?**  
A: No. The service is lazy-initialized and UI is completely stripped in release builds via tree-shaking. Zero impact.

**Q: What if a `.env` file is deleted?**  
A: The service throws `EnvifiedMissingFileException` on init. This is intentional — fail loudly, not silently.

**Q: Can I switch prod at runtime?**  
A: Only if you set `allowProdSwitch: true`. Default is locked for safety. Recommended: unlock only in debug builds.

**Q: What about secrets and API keys?**  
A: Don't put secrets in `.env` files. Use a secure backend. `.env` is for non-sensitive config only (URLs, timeouts, feature flags).

**Q: Do users see the debug button in production?**  
A: No. All debug code is wrapped in `if (kDebugMode)` and stripped via tree-shaking in release builds.

**Q: Can I customize colors and fonts?**  
A: Yes. Pass `EnvifiedTheme` to `EnvifiedOverlay` to override everything.

**Q: Works with web?**  
A: Partially. Web doesn't support shake detection. Tap trigger and PIN gate work fine.

---

## 🔄 API Reference

**Full docs:** [pub.dev/documentation/envified](https://pub.dev/documentation/envified)

### EnvConfigService (Singleton)

```dart
// Initialization
await EnvConfigService.instance.init({
  defaultEnv,           // Env.dev (default)
  allowProdSwitch,      // false (default, locked)
  verifyIntegrity,      // false (default)
  onBeforeSwitch,       // Function?
  onAfterSwitch,        // Function?
});

// Reading values
final value = svc.get('KEY');
final bool = svc.getBool('DEBUG');
final int = svc.getInt('TIMEOUT', fallback: 30);
final uri = svc.getUri('BASE_URL');
final list = svc.getList('ALLOWED_HOSTS');

// Switching
await svc.switchTo(Env.prod);
await svc.setBaseUrl('https://custom.url');
await svc.clearBaseUrlOverride();

// Lifecycle
svc.current              // ValueNotifier<EnvConfig>
await svc.auditLog      // List<AuditEntry>

// Reset
await svc.reset();
```

### Widgets

```dart
// Overlay + Panel
EnvifiedOverlay(
  service: EnvConfigService.instance,
  enabled: kDebugMode,
  gate: EnvGate(...),
  trigger: EnvTrigger.tap(),
  showFab: true,
  child: child,
)

// Status indicator
EnvStatusBadge(
  service: EnvConfigService.instance,
  alignment: Alignment.topRight,
)

// Manual panel (no overlay)
EnvDebugPanel(
  service: EnvConfigService.instance,
)
```

### Models

```dart
enum Env { dev, staging, prod, custom }

class EnvConfig {
  final Env env;
  final String baseUrl;
  final Map<String, String> extras;
}

class EnvGate {
  EnvGate({String? pin});
}

sealed class EnvTrigger {
  factory EnvTrigger.tap({int count = 7}) = _TapTrigger;
  factory EnvTrigger.shake({double threshold = 15.0}) = _ShakeTrigger;
  factory EnvTrigger.edgeSwipe({double edgeWidth = 20}) = _EdgeSwipeTrigger;
}

class AuditEntry {
  final DateTime timestamp;
  final String action;        // 'switch', 'setBaseUrl', etc.
  final String? fromEnv;
  final String? toEnv;
  final String? url;
}
```

---

## 🤝 Contributing

Found a bug? Have a feature idea? We'd love your help!

1. **Fork** the repo
2. **Create a branch** — `git checkout -b feat/amazing-idea`
3. **Make changes** — add tests for new code
4. **Commit** — `git commit -m 'feat: add amazing idea'`
5. **Push** — `git push origin feat/amazing-idea`
6. **Open a PR** — and let's ship it together! 🚀

See [CONTRIBUTING.md](https://github.com/Sam21-39/envified/blob/main/CONTRIBUTING.md) for details.

---

## 🐛 Issues & Feedback

- **Bug report?** → [GitHub Issues](https://github.com/Sam21-39/envified/issues)
- **Feature request?** → [GitHub Discussions](https://github.com/Sam21-39/envified/discussions)
- **Security concern?** → Email security@appamania.in (private disclosure)

---

## Support the Project ☕

`envified` is **100% open source and free**. Built and maintained by [Sumit Pal](https://appamania.in) in spare time.

If it saves you hours of rebuild time, consider buying me a chai. Direct UPI — zero fees, 100% goes to me.

| | Amount | What it means |
|---|---|---|
| ☕ | [₹20](https://paywithchai.in/appamania) | You liked it |
| 🍵 | [₹50](https://paywithchai.in/appamania) | Saved you time |
| 🚀 | [₹100](https://paywithchai.in/appamania) | In production |

---

## 📄 License

MIT © [Appamania](https://appamania.in)

**Built with ❤️ for Flutter developers who value time, security, and sanity.**

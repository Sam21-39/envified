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
- 🔐 **Premium PIN gate** — secure the debug panel with glassmorphic UI
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

## 🚀 Zero-Config Auto-Discovery (v2.1.0+)

`envified` now automatically scans your `assets/env/` directory for any `.env.*` files. No manual mapping required!

```dart
// No need to specify URLs — they're discovered automatically!
await EnvConfigService.instance.init();

// ✅ Finds .env.dev, .env.staging, .env.prod, .env.uat, etc.
// ✅ Extracts BASE_URL from each
// ✅ Auto-populates the UI
```

The debug panel automatically generates buttons for every discovered environment. A standalone `.env` file is treated as **Production** by default.

---

## 📦 Features

| Feature | What It Does | Why You Care |
|---------|-------------|--------------|
| **Auto-Discovery** | Scans assets for `.env.*` files | Zero config; just add a file and it works |
| **Tamper Detection** | SHA-256 hashes `.env*` files | Catch rogue config changes on rooted devices |
| **Access Gate** | Premium PIN dialog before opening panel | QA devices don't leak sensitive switches |
| **Typed Getters** | `getBool()`, `getInt()`, `getUri()`, `getList()` | No more string parsing bugs |
| **Lifecycle Hooks** | `onBeforeSwitch` / `onAfterSwitch` callbacks | Flush HTTP queues, log analytics, etc. |
| **URL History** | Last 5 URLs one-tap available | Faster testing against recent tunnels |
| **Status Badge** | Persistent `[DEV]` indicator in your app | Never forget what env you're testing |
| **Gesture Triggers** | Tap N times, shake, or swipe edge to open | Customize to your preference |
| **Audit Log** | Encrypted log of every switch | "Who changed prod at 3pm?" |

---

## Quick Start (3 Steps)

### 1️⃣ Install

```yaml
dependencies:
  envified: ^2.1.0
```

### 2️⃣ Add `.env` Files

Create in `assets/env/`:

```env
# .env.dev
BASE_URL=https://dev.api.myapp.com
DEBUG=true

# .env.prod
BASE_URL=https://api.myapp.com
DEBUG=false
```

Register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/env/
```

### 3️⃣ Initialize

In `main.dart`, before `runApp()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    allowProdSwitch: false,    // ⚠️ Lock prod by default
    verifyIntegrity: true,     // 🔐 Detect tampering (Prod only)
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
    gate: EnvGate(pin: '1234'),                 // 🔐 Secure PIN gate
    child: child ?? const SizedBox.shrink(),
  ),
  home: const MyApp(),
)
```

---

## Core Usage Patterns

### Reading Values

```dart
final svc = EnvConfigService.instance;

final name     = svc.get('APP_NAME');
final timeout  = svc.getInt('TIMEOUT', fallback: 30);
final debug    = svc.getBool('DEBUG');
final apiUrl   = svc.getUri('BASE_URL');
```

### Reacting to Switches

`EnvConfigService.current` is a `ValueNotifier`.

```dart
EnvConfigService.instance.current.addListener(() {
  final config = EnvConfigService.instance.current.value;
  dio.options.baseUrl = config.baseUrl;
  print('Active env: ${config.env.name}');
});
```

---

## Security & Production Safety

### 🔒 Production Lock
By default, `allowProdSwitch: false` locks the production environment. Once the app starts in a production-identified environment (e.g., via `.env.prod`), switching is disabled.

### ✅ Tamper Detection
When `verifyIntegrity: true` is set, `envified` computes a SHA-256 hash of your production `.env` files. If the files are modified (e.g., on a rooted device), it throws `EnvifiedTamperException`.

### ⚙️ Zero Production Overhead
All debug components (buttons, panels, gates) are wrapped in `kDebugMode` checks. Flutter's tree-shaker removes them entirely from release builds. **Zero bytes added to your production IPA/APK.**

---

## 🔄 API Reference

### Env (Class)
Replaced the enum with a dynamic class.
- `Env.dev`, `Env.staging`, `Env.prod` (Standard constants)
- `Env.fromFileName(name)` (Factory for discovered files)
- `env.isProduction` (Boolean flag)

### EnvConfigService
- `init()`: Discover files and load state.
- `switchTo(Env)`: Change environment at runtime.
- `setBaseUrl(url)`: Override the current URL.
- `current`: `ValueNotifier<EnvConfig>`.

---

## 🤝 Contributing

See [CONTRIBUTING.md](https://github.com/Sam21-39/envified/blob/main/CONTRIBUTING.md) for details. Found a bug? Open an [Issue](https://github.com/Sam21-39/envified/issues)!

---

## Support the Project ☕

`envified` is **100% open source and free**. If it saves you hours of rebuild time, consider supporting the maintainer:

[₹20 — Support](https://paywithchai.in/appamania) | [₹100 — Production Use](https://paywithchai.in/appamania)

---

## 📄 License

MIT © [Appamania](https://appamania.in)

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
- 🔄 **Smart Restart Detection** — know when dependencies need re-initialization
- 🔒 **Prod lock by default** — prevent accidental data disasters  
- 🔐 **Sensitive Data Protection** — automatic blurring of API keys and tokens
- 🧪 **Override any URL** — test against local tunnels, PR branches, anywhere
- 🛡️ **Premium PIN gate** — secure the debug panel with modern UI
- 📋 **Full audit trail** — visual timeline of every switch and URL change
- ⚙️ **Zero production overhead** — stripped out entirely in release builds
- 🎨 **Enterprise UX** — premium card-based design with dark mode support

It's not just a config switcher. It's **enterprise-grade security** meets **developer quality of life**.

> [!NOTE]  
> **Security Note:** While `envified` encrypts the active configuration state and overrides on the device (via Keychain/Keystore), the base `.env` files stored in your Flutter assets remain plaintext. Never store high-stakes production secrets directly in `.env` files; they should be fetched at runtime from a secure vault or used for non-sensitive configuration only.

---

## 📸 See It In Action

<p align="center">
  <img src="https://raw.githubusercontent.com/Sam21-39/envified/main/example/assets/gifs/envified-demo.gif" width="280" alt="Live demo: tap to switch" />
</p>

---

## 🔄 Smart Restart Detection (v2.2.0+)

When you switch environments or override the API URL, `envified` knows that dependency re-initialization is needed. It shows a prominent banner:

**"Restart app to apply changes"**

One tap "Restart now" and the app re-initializes cleanly. This prevents silent bugs where HTTP clients or Firebase remain bound to the old environment.

---

## 🔐 Sensitive Data Protection (v2.2.0+)

API keys, tokens, and secrets in your `.env` files are automatically detected and blurred by default:

- **Tap to reveal** sensitive values
- **One-tap copy** to clipboard
- **Stay hidden** in screenshots or screen shares
- Detected keys: `API_KEY`, `SECRET_KEY`, `TOKEN`, `PASSWORD`, `JWT`, etc.

---

## 🚀 Zero-Config Auto-Discovery

`envified` automatically scans your `assets/env/` directory for any `.env.*` files. No manual mapping required!

```dart
// No need to specify URLs — they're discovered automatically!
await EnvConfigService.instance.init();

// ✅ Finds .env.dev, .env.staging, .env.prod, .env.uat, etc.
// ✅ Extracts BASE_URL from each
// ✅ Auto-populates the UI
```

---

## 📦 Features

| Feature | What It Does | Why You Care |
|---------|-------------|--------------|
| **Smart Restart** | Detects when env changes require restart | Prevents connection/state caching bugs |
| **Data Protection** | Blurs sensitive keys (API_KEY, etc.) | Security in screenshots & screen shares |
| **Auto-Discovery** | Scans assets for `.env.*` files | Zero config; just add a file and it works |
| **Alias Support** | Handles `dev`, `stag`, `production`, etc. | Follows industry standard naming conventions |
| **Tamper Detection** | SHA-256 hashes `.env*` files | Catch rogue config changes on rooted devices |
| **Access Gate** | Modern PIN dialog before opening panel | QA devices don't leak sensitive switches |
| **URL Validation** | Live feedback on custom API URLs | Prevent typos and invalid endpoint formats |
| **Audit Log** | Vertical timeline of every switch | "Who changed prod at 3pm?" |
| **Status Badge** | Persistent `[DEV]` indicator in your app | Never forget what env you're testing |
| **Gesture Triggers** | Tap N times, shake, or swipe edge to open | Access the panel your way |

---

## Quick Start (3 Steps)

### 1️⃣ Install

```yaml
dependencies:
  envified: ^2.2.0
```

### 2️⃣ Add `.env` Files

Create in `assets/env/`:

```env
# .env.dev
BASE_URL=https://dev.api.myapp.com
API_KEY=sk_test_51Mz...

# .env.prod
BASE_URL=https://api.myapp.com
API_KEY=sk_live_92A...
```

Register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/env/
```

### 3️⃣ Initialize

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    onAfterSwitch: (config) {
      // Listen for restart needed
      EnvConfigService.instance.restartNeeded.addListener(() {
        debugPrint('Dependencies must re-initialize');
      });
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
    enabled: kDebugMode,
    gate: EnvGate(pin: '1234'),
    onRestart: () {
      // Trigger a hard restart (e.g. using phoenix or SystemNavigator)
      SystemNavigator.pop();
    },
    child: child!,
  ),
  home: const MyHomePage(),
)
```

---

## 🤝 Contributing

See [CONTRIBUTING.md](https://github.com/Sam21-39/envified/blob/main/CONTRIBUTING.md) for details. Found a bug? Open an [Issue](https://github.com/Sam21-39/envified/issues)!

---

## Support the Project ☕

If `envified` saves your rebuild time and improves your workflow, you can support the project here:

👉 https://paywithchai.in/appamania

---

## 📄 License

MIT © [Appamania](https://appamania.in)

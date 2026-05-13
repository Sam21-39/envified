# 🌿 envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![pub points](https://img.shields.io/pub/points/envified?color=blue)](https://pub.dev/packages/envified/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart CI](https://github.com/Sam21-39/envified/actions/workflows/ci.yml/badge.svg)](https://github.com/Sam21-39/envified/actions/workflows/ci.yml)
[![Sponsor](https://img.shields.io/badge/Sponsor-Appamania-EA4AAA?style=flat&logo=buy-me-a-coffee&logoColor=white)](https://paywithchai.in/appamania)

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

## 🚀 What's New in v3.2.1

Building on the foundation of v3.0.0, we've added major improvements to privacy, safety, and UX:

| Feature | What it does |
|---------|--------------|
| 🕶️ **Auto-Sensitive Detection** | Keys ending in `_KEY` or `KEY` (e.g., `STRIPE_KEY`) are now **automatically** hidden. No manual tagging required. |
| 🔒 **Robust Production Lock** | `allowProdSwitch: false` now correctly locks the UI *towards* production, preventing accidental "deployments" from your debug build. |
| 📦 **Collapsible Config** | The Configuration section in the debug panel is now collapsible by default, keeping the UI clean and focused on your audit log. |
| 🛡️ **Full-Screen EnvGate** | The PIN gate is now a full-screen modal with a dark scrim, better keyboard handling, and auto-dismissal. |
| 🕒 **Formatted History** | Audit log timestamps are now local and human-readable (`MM-dd-YYYY HH:mm:ss`). |
| 🎚️ **Badge Toggle** | New `isShowEnvLabel` flag allows you to hide the status badge while keeping the gesture trigger active. |

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
  envified: ^3.2.1
```

Then run:

```bash
flutter pub get
```

No build_runner. No code gen. No magic incantations. Just a package that installs like a normal package. Revolutionary, we know.

---

### 2. Create Your Environment Files

Drop these into `assets/env/`:

```text
assets/
└── env/
    ├── .env.dev
    ├── .env.staging   ← optional, but you probably want it
    └── .env.prod
```

Each file is a plain `.env` file. Nothing exotic:

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

## 🔒 Production Locking — The Guardian Angel

Two scenarios where production locking saves you:

**Scenario A — Release builds**  
**Set `allowProdSwitch: false` and pass `enabled: false` to `EnvifiedOverlay`. The panel is gone. The service ignores switch attempts. Your prod build is clean and your users have no idea any of this exists.

**Scenario B — The brave "always prod" setup**  
Maybe you want the panel available in staging but default to Prod and lock it there:

```dart
await EnvConfigService.instance.init(
  defaultEnv: Env.prod,
  allowProdSwitch: false, // once you're in Prod, you stay in Prod
);
```

Now, if anyone (your QA lead, your over-curious intern, your past self at 11 PM) tries to switch away, they get a loud `EnvifiedLockException` and a UI that has already greyed out the controls. The audit log records the attempt. The blame is documented.

```dart
// Catching the exception if you need to handle it gracefully:
try {
  await EnvConfigService.instance.switchTo(Env.dev);
} on EnvifiedLockException catch (e) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Nice try.'),
      content: Text(e.message),
    ),
  );
}
```

---

## 🔍 Reading Values

Once initialized, getting a value is a single line:

```dart
final svc = EnvConfigService.instance;

// String (use .get)
final apiUrl = svc.get('API_URL');

// Boolean (use .getBool)
final debugMode = svc.getBool('DEBUG', fallback: false);

// Integer (use .getInt)
final timeout = svc.getInt('API_TIMEOUT', fallback: 30);
```

---

## Troubleshooting

### Q: "No .env.* files discovered"

**Cause:** Asset files not registered in pubspec.yaml

**Fix:**
```yaml
flutter:
  assets:
    - assets/env/
```

Run: `flutter clean && flutter pub get`

### Q: Environment switches but API still hits old endpoint

**Cause:** HTTP client cached the URL at startup

**Fix:** Tap "Restart now" in the debug panel to re-initialize or listen to `restartNeeded`.

---

## Integration with HTTP Clients

### Dio

```dart
import 'package:dio/dio.dart';
import 'package:envified/envified.dart';

final dio = Dio();

Future<void> setupDio() async {
  await EnvConfigService.instance.init();
  
  // Set initial base URL
  dio.options.baseUrl = EnvConfigService.instance.current.value.baseUrl;
  
  // Listen for environment changes
  EnvConfigService.instance.current.addListener(() {
    dio.options.baseUrl = EnvConfigService.instance.current.value.baseUrl;
  });
}
```

---

## API Stability & Versioning

### Semantic Versioning

This package follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0) — Breaking changes to public API
- **MINOR** (0.1.0) — New features, backwards compatible
- **PATCH** (0.0.1) — Bug fixes, backwards compatible

---

## 💚 Support & Sponsorship

`envified` is free and open source, built with ☕ by **Sumit Pal** ([@appamania](https://appamania.in)).

| Tier | Link | What it buys |
|---|---|---|
| ☕ A sip of chai | [₹20](https://paywithchai.in/appamania) | You liked the package |
| 🍵 A full cup | [₹50](https://paywithchai.in/appamania) | It saved you real time |
| 🚀 Keep the lights on | [₹100](https://paywithchai.in/appamania) | You ship with it in prod |

[![Buy me a Chai](https://img.shields.io/badge/☕%20Buy%20me%20a%20Chai-FF5722?style=for-the-badge&logo=upi&logoColor=white)](https://paywithchai.in/appamania)

## 🤝 Contributing

We welcome all contributions! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a PR.

- 🐛 [Report a Bug](https://github.com/Sam21-39/envified/issues/new?template=bug_report.md)
- 💡 [Request a Feature](https://github.com/Sam21-39/envified/issues/new?template=feature_request.md)
- 🔀 [Open a Pull Request](https://github.com/Sam21-39/envified/pulls)

## 📄 License

MIT © [Appamania](https://appamania.in)

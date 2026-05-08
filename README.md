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

## Smart Restart Detection (v2.2.1+)

When you switch environments or override the API URL, `envified` knows that 
dependency re-initialization is needed. The debug panel shows a prominent banner:

```
⚠️ Restart app to apply changes
Dependencies must re-initialize with the new environment.
[Restart now]
```

### Why Restart is Needed

These packages cache at initialization time:
- **HTTP clients** (Dio, http) — re-establish connections
- **Firebase** — re-initializes with new config
- **State management** — may cache environment-specific state
- **API services** — may have bound to old URLs

Switching environments mid-app doesn't re-initialize these. You must restart.

### Detecting Changes

The service tracks:
- Environment switches: `switchTo(Env.prod)` → flag set
- URL overrides: `setBaseUrl('https://custom.com')` → flag set
- Returns to initial: `reset()` → flag cleared if back to initial state

### Using the Restart Flag

Listen to restart state:

```dart
EnvConfigService.instance.restartNeeded.addListener(() {
  final needsRestart = EnvConfigService.instance.restartNeeded.value;
  if (needsRestart) {
    // Show a notification or banner
    debugPrint('Restart needed!');
  }
});
```

### Implementing the Restart

When user taps "Restart now", you need to restart the entire app:

**Option 1: Using flutter_phoenix**
```dart
import 'package:flutter_phoenix/flutter_phoenix.dart';

Phoenix.rebirth(context);
```

**Option 2: Using GetX**
```dart
Get.offAll(() => const MyApp());
```

**Option 3: Manual (no package required)**
```dart
SystemNavigator.pop();  // Close app, OS will restart it
```

---

## Sensitive Data Protection (v2.2.1+)

API keys, tokens, and secrets in your `.env` files are automatically 
detected and blurred by default in the debug panel.

### Automatically Detected Keys

These keys are considered sensitive and blurred:
- `API_KEY`, `SECRET_KEY`, `TOKEN`
- `PASSWORD`, `PRIVATE_KEY`, `AUTH_TOKEN`
- `JWT`, `OAUTH_SECRET`, `CLIENT_SECRET`
- Any key containing these words (case-insensitive)

### Blurred Display

Sensitive values show: "🔓 Tap to reveal"

When tapped:
- Value is revealed
- A copy button appears
- User can copy to clipboard
- Hiding again by tapping the revealed value

### Why This Matters

Prevents:
- Accidental exposure in screenshots
- Secrets visible when screen is shared
- Keys captured in video recordings
- Shoulder-surfing attacks

### Example

```env
# .env.dev
API_KEY=sk_test_1234567890
DATABASE_URL=postgresql://user:pass@localhost
AUTH_TOKEN=bearer_token_xyz
TIMEOUT=30
```

In the debug panel:
```
API_KEY        🔓 Tap to reveal [copy]
DATABASE_URL   postgresql://user:pass@localhost [copy]
AUTH_TOKEN     🔓 Tap to reveal [copy]
TIMEOUT        30 [copy]
```

After tapping API_KEY:
```
API_KEY        sk_test_1234567890 [copy]
```

### Custom Sensitive Keys

To add custom sensitive keys:

```dart
// In env_model.dart
static const List<String> _sensitiveKeys = [
  'API_KEY',
  'SECRET_KEY',
  'TOKEN',
  'PASSWORD',
  'PRIVATE_KEY',
  'AUTH_TOKEN',
  'JWT',
  'OAUTH_SECRET',
  'YOUR_CUSTOM_KEY',  // ← Add here
];
```

---

## Zero-Config Environment Discovery (v2.1.0+)

If you follow the naming convention `.env.dev`, `.env.staging`, `.env.prod`, 
envified automatically discovers them without manual mapping.

### Setup

Create your environment files:
```bash
assets/env/
├── .env              # Shared defaults (optional)
├── .env.dev          # Dev environment
├── .env.staging      # Staging environment
└── .env.prod         # Production environment
```

Each file must have a `BASE_URL` line:

```env
# .env.dev
BASE_URL=https://dev.api.yourapp.com
DEBUG=true
TIMEOUT=30

# .env.prod
BASE_URL=https://api.yourapp.com
DEBUG=false
TIMEOUT=5
```

### Zero-Config Initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Automatic discovery — no manual urls mapping!
  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    autoDiscover: true,  // ← enabled by default
  );

  runApp(const MyApp());
}
```

The service automatically:
- ✅ Finds `.env.dev`, `.env.staging`, `.env.prod`
- ✅ Extracts BASE_URL from each
- ✅ Creates environment buttons in the debug panel
- ✅ Enables switching between all discovered environments

### Discovered Files

The service looks for assets matching pattern: `.env.*`

If you have:
- `.env.dev` → creates `Env.dev` button
- `.env.staging` → creates `Env.staging` button
- `.env.prod` → creates `Env.prod` button
- `.env.qa` → creates custom `Env.qa` button
- `.env.custom_server` → creates custom button

### Fallback Values

If a `.env.*` file is missing BASE_URL:

```dart
// In init()
const defaultUrl = 'https://api.example.com';

// The service will use this if BASE_URL not found
final url = _extractBaseUrl(content) ?? defaultUrl;
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
  envified: ^2.2.1
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

## Best Practices for .env Files

### File Organization

```
assets/env/
├── .env                 # Shared across all environments
├── .env.dev             # Development environment
├── .env.staging         # Staging/testing environment
└── .env.prod            # Production environment
```

### .env (Shared Defaults)

```env
# Shared config used by all environments
# Use for values that don't change per-environment

APP_NAME=MyApp
APP_VERSION=1.0.0
ANALYTICS_ENABLED=true
CRASH_REPORTING_ENABLED=true
LOG_LEVEL=info
```

### Accessing Values

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

## 🤝 Contributing

See [CONTRIBUTING.md](https://github.com/Sam21-39/envified/blob/main/CONTRIBUTING.md) for details. Found a bug? Open an [Issue](https://github.com/Sam21-39/envified/issues)!

---

## Support the Project ☕

If `envified` saves your rebuild time and improves your workflow, you can support the project here:

👉 https://paywithchai.in/appamania

---

## 📄 License

MIT © [Appamania](https://appamania.in)

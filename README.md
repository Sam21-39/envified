# 🌿 envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![pub points](https://img.shields.io/pub/points/envified?color=blue)](https://pub.dev/packages/envified/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart CI](https://github.com/Sam21-39/envified/actions/workflows/ci.yml/badge.svg)](https://github.com/Sam21-39/envified/actions/workflows/ci.yml)

> **Stop rebuilding. Start switching.** ⚡  
> Runtime environment magic for Flutter apps. Reactive, secure, and premium.

---

## 🚀 What's New in v3.0.0

- ⚛️ **Reactive Architecture** — Built on `ValueNotifier` for real-time UI updates across your app.
- 🏗️ **Singleton Pattern** — Access the environment from anywhere via `EnvConfigService.instance`.
- 🔒 **Production Lock** — Prevent switching away from Production in sensitive builds.
- 🛡️ **Improved DI** — First-class support for `AssetBundle` injection and testing overrides.
- 🎨 **Luxury UI** — Redesigned debug panel with smooth animations and better audit visibility.
- 🧪 **Robust Testing** — Modernized test suite with deep coverage for edge cases.

---

## 📦 Features

| Feature | What It Does | Why You Care |
|---------|-------------|--------------|
| **Reactive State** | `ValueListenable` updates | UI reacts instantly to environment changes |
| **Production Lock** | `isProdLocked` logic | Zero risk of accidental staging/dev switches in Prod |
| **Sensitive Data** | Auto-blurring of secrets | Security during screen shares and demos |
| **Auto-Discovery** | Scans assets for `.env.*` | No manual mapping required; just add a file |
| **Audit Log** | Visual timeline of changes | Full accountability for configuration shifts |
| **Status Badge** | Floating environment indicator | Instant context on which env is active |
| **Shake to Open** | Interactive gesture triggers | Access the panel quickly without UI clutter |

---

## 🛠️ Quick Start

### 1. Install

```yaml
dependencies:
  envified: ^3.0.0
```

### 2. Configure Assets

Create your environment files in `assets/env/`:

```env
# .env.dev
BASE_URL=https://dev.api.myapp.com
API_KEY=sk_test_123

# .env.prod
BASE_URL=https://api.myapp.com
API_KEY=sk_live_abc
```

Register them in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/env/
```

### 3. Initialize

Initialize the service in your `main()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    allowProdSwitch: kDebugMode, // Lock switching in release
    sensitiveKeys: ['API_KEY', 'JWT_TOKEN'],
  );

  runApp(const MyApp());
}
```

### 4. Wrap with Overlay

```dart
MaterialApp(
  builder: (context, child) => EnvifiedOverlay(
    enabled: kDebugMode,
    gate: EnvGate(pin: '8888'),
    trigger: const EnvTrigger.shake(),
    child: child!,
  ),
  home: const MyHomePage(),
)
```

---

## ⚛️ Reactive Usage

Since v3.0.0, the environment state is reactive. Use `ValueListenableBuilder` to rebuild UI when the environment changes:

```dart
ValueListenableBuilder<EnvConfig>(
  valueListenable: EnvConfigService.instance.current,
  builder: (context, config, _) {
    return Text('Current Base URL: ${config.baseUrl}');
  },
)
```

---

## 🔒 Production Locking

Safety first. You can prevent environment switching when the app is in Production:

```dart
// In main.dart
await EnvConfigService.instance.init(
  defaultEnv: Env.prod,
  allowProdSwitch: false, // Switching away from Prod is now forbidden
);
```

Attempts to switch will throw an `EnvifiedLockException`, and the UI will disable switching options automatically.

---

## 🧪 Testing

`envified` v3 is designed for testability. You can override the service with fakes:

```dart
EnvConfigService.overrideForTesting(
  storage: MyFakeStorage(),
  parser: const EnvFileParser(),
);
```

---

## 📄 License

MIT © [Appamania](https://appamania.in)

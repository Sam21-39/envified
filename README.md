# Envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A powerful, highly customizable runtime environment switching service for Flutter. Envified serves as a **secure alternative to `flutter_dotenv`** — it manages compile-time secrets, per-environment variable overrides, and runtime env selection, all with no-compromise security.

---

## Why Not Just Use flutter_dotenv?

When you bundle a `.env` file as a Flutter asset, it is **readable by anyone**. An APK is a ZIP archive; anyone can rename it to `.zip`, extract it, and open your `.env` file in a text editor.

Envified takes a fundamentally different, secure approach:

| | `flutter_dotenv` | `envified` |
|---|---|---|
| Secret storage | Plain text asset file in APK | Baked into binary at compile time |
| Runtime selection | No | Yes - dev/staging/prod switching |
| Persistence | No | Yes - encrypted Keychain/Keystore |
| Per-env variables | No | Yes - feature flags, log levels, etc. |
| Extractable from APK | **YES** | **No** |

---

## How It Works: The Security Model

**Compile-time secrets** are injected via `--dart-define` or `--dart-define-from-file` at build time. Dart bakes these into the compiled binary — there is no file to extract.

**Runtime env selection** (which of your configured environments is active) is the only thing persisted, stored securely in the platform Keychain (iOS) or Keystore (Android) via `flutter_secure_storage` — never in SharedPreferences or a file.

**Environment variables** (feature flags, log levels, etc.) are held in memory only. They are resolved fresh from your in-memory definitions on every app start and **never written to disk**.

---

## Getting Started

```yaml
dependencies:
  envified: ^0.1.0
  flutter_secure_storage: ^9.0.0
```

> **Note:** `flutter_secure_storage` requires platform-specific setup. See the [Android](https://pub.dev/packages/flutter_secure_storage#android) and [iOS](https://pub.dev/packages/flutter_secure_storage#ios) instructions.

Create a `.env.json` file for each environment (**add all of them to `.gitignore`**):

```json
{
  "API_KEY": "your-secret-key",
  "SENTRY_DSN": "https://xxx@sentry.io/123",
  "APP_NAME": "MyApp"
}
```

---

## Initialization

```dart
import 'package:envified/envified.dart';

// Read compile-time constants baked in by --dart-define.
// These are NOT stored in any file - they are part of the binary.
const _apiKey = String.fromEnvironment('API_KEY');
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    // 1. Per-environment base URLs (required)
    urls: {
      Env.dev:     'https://dev.api.example.com',
      Env.staging: 'https://staging.api.example.com',
      Env.prod:    'https://api.example.com',
    },
    defaultEnv: Env.dev,

    // 2. Global compile-time secrets (available in ALL environments)
    vars: {
      'API_KEY':    _apiKey,
      'SENTRY_DSN': _sentryDsn,
    },

    // 3. Per-environment variable overrides (merged on top of global vars)
    //    Per-env values take priority over global vars.
    varsByEnv: {
      Env.dev:     {'LOG_LEVEL': 'verbose', 'FEATURE_X': 'true',  'TIMEOUT': '10000'},
      Env.staging: {'LOG_LEVEL': 'info',    'FEATURE_X': 'true',  'TIMEOUT': '8000'},
      Env.prod:    {'LOG_LEVEL': 'error',   'FEATURE_X': 'false', 'TIMEOUT': '5000'},
    },
  );

  runApp(const MyApp());
}
```

### Build Commands

```bash
# Development
flutter run --dart-define-from-file=.env.dev.json

# Staging
flutter run --dart-define-from-file=.env.staging.json

# Production
flutter build apk --dart-define-from-file=.env.prod.json
```

---

## Reading Variables

```dart
// get() - throws StateError if key is missing (use for required values)
final apiKey = EnvConfigService.instance.get('API_KEY');
final logLevel = EnvConfigService.instance.get('LOG_LEVEL');

// maybeGet() - returns null if key is missing (use for optional values)
final featureX = EnvConfigService.instance.maybeGet('FEATURE_X');
if (featureX == 'true') {
  // show new feature
}

// Access via the current config directly
final vars = EnvConfigService.instance.current.value.vars;
```

---

## Runtime Environment Switching

```dart
// Switch to staging programmatically (persisted to Keychain/Keystore)
await EnvConfigService.instance.switchTo(Env.staging);

// Set a fully custom URL (e.g. for QA to point at a local server)
await EnvConfigService.instance.setCustomUrl('https://my-ngrok-url.io/api');

// Reset to default env
await EnvConfigService.instance.reset();
```

---

## Reacting to Changes in the Widget Tree

Wrap your app with `EnvifiedScope` to automatically rebuild when the environment changes:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EnvifiedScope(
      service: EnvConfigService.instance,
      builder: (context, config) {
        return MaterialApp(
          title: EnvConfigService.instance.get('APP_NAME'),
          home: const MyHomePage(),
        );
      },
    );
  }
}
```

Access the current config anywhere below `EnvifiedScope`:

```dart
final config = EnvifiedScope.of(context);
print(config.env);     // Env.dev
print(config.baseUrl); // https://dev.api.example.com
print(config.vars);    // {'LOG_LEVEL': 'verbose', 'API_KEY': '...', ...}
```

Or listen programmatically (e.g. in an API client):

```dart
EnvConfigService.instance.current.addListener(() {
  final config = EnvConfigService.instance.current.value;
  dio.options.baseUrl = config.baseUrl;
});
```

---

## Security Checklist

- [ ] Add all `.env.*.json` files to `.gitignore`
- [ ] Never hard-code secret values as plain strings in Dart code
- [ ] Use `String.fromEnvironment('KEY')` and pass via `--dart-define-from-file`
- [ ] Store secret files in a secrets manager (e.g. GitHub Actions secrets, Doppler) for CI/CD
- [ ] Build production releases with obfuscation: `flutter build apk --obfuscate --split-debug-info=<path>`

---

## Additional Information

Check out the `/example` folder in the [GitHub repository](https://github.com/appamania/envified) for a complete, runnable example demonstrating all features including compile-time secrets, per-env variables, runtime switching, and simulated network requests.

Created with ❤️ by [Appamania](https://appamania.in).

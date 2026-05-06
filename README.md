# Envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A powerful, developer-friendly package for runtime environment switching in Flutter applications. Switch seamlessly between `dev`, `staging`, and `prod` environments without ever rebuilding your app. Envified is designed as a highly customizable, core logic service to power your own custom debugging UI.

---

## Features

- **⚡ Runtime Switching:** Switch between `dev`, `staging`, and `prod` instantly without recompiling.
- **🛠 Manual URL Overrides:** Let your QA team or developers test specific server URLs on the fly.
- **🔒 Secure Storage:** Persists environment configurations securely using `flutter_secure_storage`.
- **🧩 Highly Customizable:** Gives you full programmatic control so you can build your own environment selector UI or hidden developer menus.
- **🏗 EnvifiedScope:** A convenient InheritedWidget wrapper to automatically rebuild your app when the environment changes.

---

## Getting Started

Add `envified` and its required dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  envified: ^0.1.0
  flutter_secure_storage: ^9.0.0
```

> **Note:** Because `envified` uses `flutter_secure_storage`, ensure you have met the platform-specific setup requirements for [Android](https://pub.dev/packages/flutter_secure_storage#android) and [iOS](https://pub.dev/packages/flutter_secure_storage#ios).

---

## Initialization

Initialize the `EnvConfigService` in your `main.dart` before calling `runApp`. You must provide your base URLs for each environment.

```dart
import 'package:flutter/material.dart';
import 'package:envified/envified.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    urls: {
      Env.dev: 'https://dev.api.example.com',
      Env.staging: 'https://staging.api.example.com',
      Env.prod: 'https://api.example.com',
    },
    defaultEnv: Env.dev,
  );

  runApp(const MyApp());
}
```

---

## Usage: Direct Service Access (Programmatic)

You can trigger environment changes programmatically and interact directly with the singleton service. This allows you to wire up your own custom buttons or secret gestures.

```dart
// Switch to Staging
await EnvConfigService.instance.switchTo(Env.staging);

// Set a custom URL manually
await EnvConfigService.instance.setCustomUrl('https://my-local-server.com/api');

// Reset to default
await EnvConfigService.instance.reset();

// Listen to changes manually
EnvConfigService.instance.current.addListener(() {
  final currentConfig = EnvConfigService.instance.current.value;
  print("Environment changed to: ${currentConfig.env.name}");
});
```

---

## Usage: EnvifiedScope (Listening in the Widget Tree)

To easily rebuild portions of your app (or the whole app) when the environment changes, simply wrap your widget tree with `EnvifiedScope`. 

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Wrap with EnvifiedScope to react to environment changes
    return EnvifiedScope(
      service: EnvConfigService.instance,
      builder: (context, config) {
        return MaterialApp(
          title: 'My App',
          home: const MyHomePage(),
        );
      },
    );
  }
}
```

### Accessing the Current Configuration

Anywhere below `EnvifiedScope` in your app, you can effortlessly access the active environment and base URL using:

```dart
final config = EnvifiedScope.of(context);

print(config.env); // e.g. Env.dev
print(config.baseUrl); // e.g. 'https://dev.api.example.com'
```

---

## Additional Information

Check out the `/example` folder in the [GitHub repository](https://github.com/appamania/envified) for a complete, runnable example demonstrating programmatic environment switching and simulated network requests.

Created with ❤️ by [Appamania](https://appamania.in).

# 🌿 envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

### Stop Rebuilding. Start Switching. 🚀

Tired of waiting for Flutter to rebuild just to check your app against `staging`? Still hard-coding base URLs like it's 2015? 

**envified** is the runtime brain for your Flutter app. Load your `.env` files, swap environments on the fly, and override your API URLs—all without a single `hot reload`.

---

## 📸 The "Look Ma, No Rebuilds!" UI

`envified` ships with a premium, dark-luxury debug overlay. It stays invisible in production but pops up when you need it most.

<p align="center">
  <img src="example/assets/images/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20Max%20-%202026-05-06%20at%2023.13.56.png" width="300" alt="envified Floating Button" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="example/assets/images/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20Max%20-%202026-05-06%20at%2023.13.51.png" width="300" alt="envified Debug Panel" />
</p>

---

## ✨ Why You'll Love It

- ⚡️ **Switch in Seconds**: Swap from `dev` to `prod` in 0.2 seconds. No compilation, no coffee breaks.
- 🔒 **The "Safety First" Lock**: We lock your `prod` environment by default. No accidental data deletions here.
- 🧪 **API Mad Scientist Mode**: Override your base URL at runtime. Test against that local tunnel or a specific PR branch instantly.
- 💾 **Memory Like an Elephant**: Your selections and URL overrides persist across app restarts.
- ⚙️ **Ghost in the Machine**: The debug UI is stripped out completely in release builds. Zero overhead.

---

## 🛠 Quick Start (30 Seconds)

### 1. Grab the Package
```yaml
dependencies:
  envified: ^0.1.0
```

### 2. Toss in your `.env` files
Create your `.env` files and tell Flutter where they are in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/env/.env          # Shared defaults
    - assets/env/.env.dev      # Dev overrides
    - assets/env/.env.staging  # Staging overrides
    - assets/env/.env.prod     # Prod overrides
```

### 3. Light the Fuse
Initialize before `runApp()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    allowProdSwitch: false, // Lock prod for safety!
  );

  runApp(const MyApp());
}
```

---

## 🪄 The Magic Sauce

### Injecting the Overlay
Wrap your app using the `builder` pattern. This puts the 🌿 button on top of every screen.

```dart
MaterialApp(
  builder: (context, child) => EnvifiedOverlay(
    service: EnvConfigService.instance,
    enabled: kDebugMode, // Only show in debug!
    child: child ?? const SizedBox.shrink(),
  ),
  home: const MyAwesomeApp(),
)
```

### Grabbing Values
It's as simple as reading a variable:

```dart
final config = EnvConfigService.instance.current.value;

print(config.baseUrl);           // "https://api.example.com"
print(config.values['API_KEY']); // "shhh_its_a_secret"
```

---

## 🥊 envified vs. The Others

| Feature | `envified` | Traditional `.env` |
| :--- | :---: | :---: |
| Switch at runtime | ✅ Yes | ❌ No |
| Change URL without rebuild | ✅ Yes | ❌ No |
| Persistent overrides | ✅ Yes | ❌ No |
| Production Lock | ✅ Yes | ❌ No |
| **Happiness Levels** | 📈 Stonks | 📉 Sadness |

---

## 🔒 Security: The "Prod Lock"

We've all been there. You accidentally hit a "Delete All" button while thinking you were in `dev`. `envified` stops the nightmare:

- **Switching out of Prod?** Forbidden. 🚫
- **Overriding a Prod URL?** Not on our watch. 👮‍♂️

To unlock, you must explicitly change your initialization code.

---

## 📄 License

MIT. Go build something amazing. 🚀

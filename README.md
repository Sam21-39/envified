# 🌿 envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart CI](https://github.com/Sam21-39/envified/actions/workflows/dart.yml/badge.svg)](https://github.com/Sam21-39/envified/actions/workflows/dart.yml)

### Stop Rebuilding. Start Switching. 🚀

**envified** is the runtime brain for your Flutter app. Load your `.env` files, swap environments on the fly, override API URLs, authenticate access with a PIN or biometric, detect tampering, and keep a full audit trail — all without a single `hot reload`.

---

## 📸 The "Look Ma, No Rebuilds!" UI

`envified` ships with a premium, dark-luxury debug overlay. It stays invisible in production but pops up when you need it most.

<p align="center">
  <img src="https://raw.githubusercontent.com/Sam21-39/envified/main/example/assets/images/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20Max%20-%202026-05-06%20at%2023.13.56.png" width="300" alt="envified Floating Button" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/Sam21-39/envified/main/example/assets/images/Simulator%20Screenshot%20-%20iPhone%2017%20Pro%20Max%20-%202026-05-06%20at%2023.13.51.png" width="300" alt="envified Debug Panel" />
</p>

---

## ✨ What's New in v2.0.0

| # | Feature | Summary |
|---|---------|---------|
| 1 | **Tamper Detection** | SHA-256 hash every `.env*` file on first load; throw `EnvifiedTamperException` if modified |
| 2 | **Access Gate** | PIN dialog or biometric auth before opening the debug panel |
| 3 | **Typed Getters** | `getBool`, `getInt`, `getDouble`, `getUri`, `getList` |
| 4 | **Lifecycle Hooks** | `onBeforeSwitch` / `onAfterSwitch` callbacks in `init()` |
| 5 | **URL History** | Last 5 URLs auto-saved; one-tap chips in the debug panel |
| 6 | **Status Badge** | `EnvStatusBadge` — colour-coded, pulsing when URL override is active |
| 7 | **Gesture Trigger** | Tap N times, shake the device, or swipe from the right edge |
| 8 | **Audit Log** | Encrypted, capped-at-50 activity log; visible in the debug panel |
| + | **Auto-lock** | Panel closes and re-requires auth when app is backgrounded |

---

## ✨ Why You'll Love It

- ⚡️ **Switch in Seconds**: Swap from `dev` to `prod` in 0.2 seconds. No compilation, no coffee breaks.
- 🔒 **The "Safety First" Lock**: We lock your `prod` environment by default. No accidental data deletions here.
- 🧪 **API Mad Scientist Mode**: Override your base URL at runtime. Test against that local tunnel or a specific PR branch instantly.
- 💾 **Memory Like an Elephant**: Your selections and URL overrides persist across app restarts.
- ⚙️ **Ghost in the Machine**: The debug UI is stripped out completely in release builds. Zero overhead.
- 🔍 **Tamper-Evident**: SHA-256 integrity checks catch any `.env` file modification after first launch.
- 📋 **Full Audit Trail**: Every environment switch and URL change is logged securely.

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_secure_storage` | AES (Android) / Keychain (iOS) encrypted persistence |
| `local_auth` | Biometric / device-credential authentication |
| `sensors_plus` | Accelerometer for shake-to-open trigger |
| `crypto` | SHA-256 hashing for tamper detection |

---

## 🛠 Quick Start (30 Seconds)

### 1. Grab the Package
```yaml
dependencies:
  envified: ^2.0.0
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
    allowProdSwitch: false,   // Lock prod for safety!
    verifyIntegrity: true,    // Tamper detection
    onBeforeSwitch: (from, to) async {
      debugPrint('Switching: ${from.longLabel} → ${to.longLabel}');
    },
    onAfterSwitch: (config) {
      debugPrint('Now on: ${config.baseUrl}');
    },
  );

  runApp(const MyApp());
}
```

---

## 🪄 The Magic Sauce

### Injecting the Overlay

Wrap your app using the `builder` pattern. Configure the trigger and optional gate:

```dart
MaterialApp(
  builder: (context, child) => EnvifiedOverlay(
    service: EnvConfigService.instance,
    enabled: kDebugMode,             // Only show in debug!
    gate: EnvGate(pin: '1234'),      // PIN protection
    trigger: const EnvTrigger.tap(count: 7), // 7 rapid taps
    showFab: true,                   // Set to false for "stealth mode"
    child: child ?? const SizedBox.shrink(),
  ),
  home: const MyAwesomeApp(),
)
```

### Adding the Status Badge

Display a persistent env indicator anywhere in your UI:

```dart
Stack(
  children: [
    MyApp(),
    if (kDebugMode)
      EnvStatusBadge(service: EnvConfigService.instance),
  ],
)
```

### Grabbing Values (Typed)

```dart
final svc = EnvConfigService.instance;

// Raw string
final name = svc.get('APP_NAME');

// Typed helpers
final timeout    = svc.getInt('TIMEOUT', fallback: 30);
final isDebug    = svc.getBool('DEBUG');
final rate       = svc.getDouble('RATE_LIMIT', fallback: 1.0);
final webhook    = svc.getUri('WEBHOOK_URL');
final allowHosts = svc.getList('ALLOWED_HOSTS');
```

---

## 🔒 Access Gate

Protect the debug panel with a PIN or biometrics:

```dart
// PIN only
EnvGate(pin: '1234')

// Biometric only (Face ID / fingerprint)
EnvGate(biometric: true)

// Either method works
EnvGate(pin: '1234', biometric: true)
```

The gate is automatically cleared when the app is backgrounded, so the next open always requires re-authentication.

---

## 🎯 Gesture Triggers

| Trigger | Constructor | Description |
|---------|-------------|-------------|
| Tap N times | `EnvTrigger.tap(count: 7)` | Tap any area 7 times within 800 ms |
| Shake device | `EnvTrigger.shake(threshold: 15.0)` | Accelerometer shake (2 s debounce) |
| Edge swipe | `EnvTrigger.edgeSwipe(edgeWidth: 20)` | Swipe inward from the right edge |

**Stealth Mode:** Set `showFab: false` on `EnvifiedOverlay` to completely hide the floating 🌿 button, making your chosen trigger the *only* way to access the debug panel.

---

## 🔍 Tamper Detection

```dart
await EnvConfigService.instance.init(
  verifyIntegrity: true,
);
```

On first launch the SHA-256 hash of each `.env*` file is stored securely. On every subsequent launch the hash is recomputed. If a file has been modified an `EnvifiedTamperException` is thrown.

---

## 📋 Audit Log

Every mutating action is logged automatically:

```dart
final entries = await EnvConfigService.instance.auditLog;
for (final entry in entries) {
  print('${entry.timestamp} — ${entry.action}');
  // e.g. "2026-05-07T10:30:00Z — switch (dev → staging)"
}
```

The log is stored in `flutter_secure_storage`, capped at 50 entries, and the last 10 entries are visible in the `EnvDebugPanel`.

---

## 🔒 Enterprise-Grade Security

1. **Encrypted Persistence**: Every environment switch and URL override is persisted using **AES encryption** on Android and the **Secure Keychain** on iOS.
2. **Production Lock**: `allowProdSwitch: false` prevents leaving production or overriding URLs.
3. **URL Allowlist**: Supply `allowedUrls: ['https://api.myapp.com']` to reject unexpected base URLs.
4. **Tamper Detection**: SHA-256 integrity checks on `.env*` files.
5. **Zero-Leak Release**: The debug 🌿 button and panel are completely optimized out in release builds.

---

## ⚙️ Platform Setup

### `local_auth` — Biometric Authentication

#### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

Also ensure your `MainActivity` extends `FlutterFragmentActivity`:
```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

#### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Used to authenticate access to the envified debug panel.</string>
```

### `sensors_plus` — Shake Trigger

No additional setup required. Works out of the box on Android and iOS.

---

## 🔄 Migration from v1.0.0

All new parameters in `init()` and `EnvifiedOverlay()` are **optional** with safe defaults. Your existing v1.0.0 code will compile and run without changes.

```dart
// v1.0.0 — still works unchanged
await EnvConfigService.instance.init(defaultEnv: Env.dev);

EnvifiedOverlay(
  service: EnvConfigService.instance,
  enabled: kDebugMode,
  child: child!,
)
```

The only **breaking change** is `EnvStorage.clear()` now also wipes URL history and the audit log (desired behaviour for a full reset). If you relied on clear() preserving history, use selective deletion instead.

---

## 🤝 Contributing (Join the Cult! 🌿)

Got an idea to make `envified` even more magical? We love PRs!

1. **Fork it**: Click that button at the top right.
2. **Branch it**: `git checkout -b feature/my-amazing-idea`.
3. **Code it**: Make your changes (and add tests, or the lint gods will be angry).
4. **Commit it**: `git commit -m 'Add some magic'`.
5. **Push it**: `git push origin feature/my-amazing-idea`.
6. **Open a PR**: And wait for the applause. 👏

---

## 🐛 Found a Bug? (The "Oh No!" Section)

If something isn't working right, or you have a feature request that just can't wait:

1. Head over to the [Issue Tracker](https://github.com/Sam21-39/envified/issues).
2. Search if someone else already complained about it.
3. If not, open a new issue. Be descriptive! "It's broken" helps no one.

---

## 📄 License

MIT. Go build something amazing. 🚀

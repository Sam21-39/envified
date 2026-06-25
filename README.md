# envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![pub points](https://img.shields.io/pub/points/envified?color=blue)](https://pub.dev/packages/envified/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart CI](https://github.com/Sam21-39/envified/actions/workflows/ci.yml/badge.svg)](https://github.com/Sam21-39/envified/actions/workflows/ci.yml)
[![Sponsor](https://img.shields.io/badge/Sponsor-Appamania-EA4AAA?style=flat&logo=buy-me-a-coffee&logoColor=white)](https://paywithchai.in/appamania)

> **Stop rebuilding. Start switching.**
> Runtime environment switching for Flutter — hardware-backed secrets, zero asset-bundle exposure.

---

## The Problem

You're a Flutter developer. Every time you need to test a different API endpoint you rebuild the app. Secrets baked into asset bundles are trivially extractable with `unzip`. XOR-obfuscated Dart strings reconstruct on the heap. Neither approach is secure.

**envified v4 fixes the root cause: secrets never leave the native Keystore/Keychain.**

---

## What is envified?

`envified` is a **production-grade Flutter plugin** for runtime environment management with native-layer security.

- **AES-256-GCM** — secrets encrypted at build time, decrypted on-device only
- **Android Keystore** — StrongBox (API 28+) with silent TEE fallback
- **iOS CryptoKit + Keychain** — `SymmetricKey` stored behind `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- **Zero asset-bundle exposure** — no `.env.*` files in your APK/IPA
- **Runtime env switching** — swap dev/staging/prod in ~200ms, no rebuild
- **Adapter-aware lifecycle** — 8-step `switchTo()` with automatic rollback
- **CLI tooling** — `envified setup`, `build`, `scan`, `check`; no `build_runner`
- **Prod lock by default** — prevent accidental data disasters
- **Full audit trail** — visual timeline of every switch

---

## What's New in v4.0.0-alpha

| What changed | Details |
|---|---|
| Pure-Dart → Flutter plugin | Native Android (Kotlin) + iOS (Swift) required |
| XOR obfuscation → AES-256-GCM | Hardware-backed keys via Keystore / Keychain |
| Asset bundle → zero-exposure | No `.env.*` files shipped in the binary |
| build_runner → CLI tool | `dart run tool/envified_cli/bin/envified.dart build --env=dev` |
| `flutter_secure_storage` → method channel | `in.appamania.envified/channel` (16 native methods) |
| New: `SecretHandle` | Tier-2 opaque reference — plaintext never stored in Dart heap |
| New: `EnvTier` | `runtime` / `secret` / `remote` routing |
| New: `AppConfig` facade | `AppConfig.get()`, `getBool()`, `getInt()`, `configNotifier` |

See [CHANGELOG.md](./CHANGELOG.md) for the full list and breaking changes.

---

## Security Architecture

```
.env.dev (never committed)
        │
        ▼
 envified build CLI
  HKDF-SHA256(ENVIFIED_MASTER_KEY, env) → 32-byte AES key
  AES-256-GCM encrypt each value
  write lib/src/generated/envified_registry.dev.g.dart (ciphertext + iv, base64)
  write .envified.lock (SHA-256 per source file)
        │
        ▼  (at runtime on device)
 EnvifiedChannel.initialize(env: 'dev')
  Android: generateKey() → Android Keystore (StrongBox / TEE)
  iOS:     generateKey() → CryptoKit SymmetricKey in Keychain
        │
        ▼
 EnvConfigService.init()
  reads generated registry
  decrypts via channel → native AES-GCM
  Tier-1 (runtime) values available as Dart Strings
  Tier-2 (secret) values wrapped in SecretHandle — never a String
```

---

## Quick Start

### 1. Add the plugin

```yaml
# pubspec.yaml
dependencies:
  envified: ^4.0.0-alpha.1
```

```bash
flutter pub get
```

### 2. Run one-time setup

```bash
dart run tool/envified_cli/bin/envified.dart setup
```

This creates `envified.yaml` and appends `.gitignore` rules for secret files.

### 3. Create your environment files

```env
# .env.dev  (gitignored — never commit)
BASE_URL=https://dev.api.example.com
API_KEY=sk_test_abc123
```

### 4. Build encrypted registry

```bash
# Set your master key once (CI: set ENVIFIED_MASTER_KEY env var)
export ENVIFIED_MASTER_KEY=your-256-bit-hex-key

dart run tool/envified_cli/bin/envified.dart build --env=dev
```

Outputs `lib/src/generated/envified_registry.dev.g.dart` (ciphertext only, no plaintext).

### 5. Initialize in `main.dart`

```dart
import 'package:envified/envified.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.init(
    envs: [Env.dev, Env.staging, Env.prod],
    defaultEnv: Env.dev,
    allowProdSwitch: false,
  );

  runApp(const MyApp());
}
```

### 6. Wrap your app with the debug overlay

```dart
MaterialApp(
  builder: (context, child) => EnvifiedOverlay(
    service: EnvConfigService.instance,
    enabled: kDebugMode,
    gate: EnvGate(pin: '1234'),
    onRestart: () => SystemNavigator.pop(),
    child: child!,
  ),
  home: const MyHomePage(),
)
```

### 7. Read values

```dart
final url    = AppConfig.get('BASE_URL');
final flag   = AppConfig.getBool('FEATURE_X', fallback: false);
final timeout = AppConfig.getInt('TIMEOUT', fallback: 30);
```

---

## CLI Reference

| Command | What it does |
|---|---|
| `envified setup` | Create `envified.yaml` + `.gitignore` rules |
| `envified scan` | Dry-run: discover `.env.*` files without writing anything |
| `envified build --env=<name>` | Encrypt env file, write registry + `.envified.lock` |
| `envified build --all` | Encrypt all discovered environments |
| `envified check` | Validate `.envified.lock` hashes; use as CI gate |

All commands accept `--project-root <path>` to run outside the current directory.

### CI/CD integration

```yaml
# .github/workflows/build.yml
- name: Build envified secrets
  env:
    ENVIFIED_MASTER_KEY: ${{ secrets.ENVIFIED_MASTER_KEY }}
  run: dart run tool/envified_cli/bin/envified.dart build --all

- name: Validate lock
  run: dart run tool/envified_cli/bin/envified.dart check
```

---

## Tier System

| Tier | Dart representation | Storage |
|---|---|---|
| `EnvTier.runtime` | `String` (in memory) | Decrypted at init, freed on switch |
| `EnvTier.secret` | `SecretHandle` (opaque) | Plaintext never in Dart heap; resolved transiently |
| `EnvTier.remote` | Fetched at runtime | Custom `WebSecretProvider` (v4.1) |

Configure tier routing in `envified.yaml`:

```yaml
key_types:
  API_KEY: secret      # wrapped as SecretHandle
  BASE_URL: runtime    # plain String
  WEBHOOK_SECRET: secret
```

Keys matching `sensitive_key_patterns` (`API_KEY`, `SECRET`, `TOKEN`, etc.) default to `secret` tier automatically.

---

## Adapter-Aware Switching

Register service adapters before `init()` to have them re-pointed when the environment changes:

```dart
EnvConfigService.instance
  ..registerAdapter(FirebaseAdapter())
  ..registerAdapter(SupabaseAdapter());

await AppConfig.init(defaultEnv: Env.dev, ...);
```

`switchTo()` runs an 8-step lifecycle: validate → hooks → native init → adapter reinitialize → (rollback on failure) → update state → persist → hooks. If any adapter fails, the switch is atomically rolled back and `EnvifiedSwitchException` is thrown with the failing adapter name.

---

## Migration from v3

| v3 | v4 |
|---|---|
| `assets/env/.env.dev` (in asset bundle) | `.env.dev` (gitignored, CLI-encrypted) |
| `dart run envified` (XOR obfuscator) | `dart run tool/envified_cli/bin/envified.dart build --env=dev` |
| `flutter_secure_storage` (runtime dep) | Native Keystore/Keychain via method channel |
| `EnvConfigService.instance.init(envAssetPaths: ...)` | `AppConfig.init(envs: ..., defaultEnv: ...)` |
| `svc.get('KEY')` | `AppConfig.get('KEY')` (same signature) |
| `EnvifiedOverlay(...)` | Same — no change required |

**Step-by-step migration:**

1. Remove `assets/env/` from `pubspec.yaml flutter.assets`.
2. Move your `.env.*` files out of `assets/` (they no longer belong there).
3. Add them to `.gitignore`.
4. Run `envified setup` then `envified build --all`.
5. Replace `EnvConfigService.instance.init(...)` with `AppConfig.init(...)` in `main.dart`.
6. Run `fvm flutter pub get && fvm flutter build apk` — verify no `.env` files in the APK.

---

## Production Locking

```dart
await AppConfig.init(
  defaultEnv: Env.prod,
  allowProdSwitch: false,  // panel greyed out in prod; switch throws EnvifiedLockException
);
```

---

## Reading Values

```dart
AppConfig.get('API_URL')                          // String?
AppConfig.getBool('FEATURE_FLAG', fallback: false) // bool
AppConfig.getInt('TIMEOUT', fallback: 30)          // int
AppConfig.getDouble('RATE', fallback: 1.0)         // double
AppConfig.getUri('BASE_URL')                       // Uri?
AppConfig.baseUrl                                  // shorthand for BASE_URL
AppConfig.configNotifier                           // ValueNotifier<EnvConfig>
```

---

## Testing

Use `EnvifiedTestHarness` in `test/helpers/` to mock the native channel:

```dart
import 'package:flutter_test/flutter_test.dart';
import '../helpers/envified_test_harness.dart';

void main() {
  late EnvifiedTestHarness harness;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    harness = EnvifiedTestHarness()..register();
  });

  tearDown(() => harness.reset());

  test('reads stored secret', () async {
    // harness provides an in-memory XOR cipher — no native code needed
  });
}
```

---

## Support & Sponsorship

`envified` is free and open source, built with care by **Sumit Pal** ([@appamania](https://appamania.in)).

| Tier | Link | What it buys |
|---|---|---|
| A sip of chai | [₹20](https://paywithchai.in/appamania) | You liked the package |
| A full cup | [₹50](https://paywithchai.in/appamania) | It saved you real time |
| Keep the lights on | [₹100](https://paywithchai.in/appamania) | You ship with it in prod |

[![Buy me a Chai](https://img.shields.io/badge/Buy%20me%20a%20Chai-FF5722?style=for-the-badge&logo=upi&logoColor=white)](https://paywithchai.in/appamania)

## Contributing

We welcome all contributions! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a PR.

- [Report a Bug](https://github.com/Sam21-39/envified/issues/new?template=bug_report.md)
- [Request a Feature](https://github.com/Sam21-39/envified/issues/new?template=feature_request.md)
- [Open a Pull Request](https://github.com/Sam21-39/envified/pulls)

## License

MIT © [Appamania](https://appamania.in)

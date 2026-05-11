# 🌿 envified

[![pub package](https://img.shields.io/pub/v/envified.svg)](https://pub.dev/packages/envified)
[![pub points](https://img.shields.io/pub/points/envified?color=blue)](https://pub.dev/packages/envified/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart CI](https://github.com/Sam21-39/envified/actions/workflows/ci.yml/badge.svg)](https://github.com/Sam21-39/envified/actions/workflows/ci.yml)
[![Sponsor](https://img.shields.io/badge/Sponsor-Appamania-EA4AAA?style=flat&logo=buy-me-a-coffee&logoColor=white)](https://paywithchai.in/appamania)

> **Stop rebuilding. Start switching.** ⚡  
> Runtime environment magic for Flutter apps. Reactive, secure, and — dare we say — a little premium.

---

You know the drill. You push to prod. Five minutes later, Slack is on fire because someone forgot to swap the API key and is now hammering the dev server with real user data. Your PM is typing. The dots won't stop.

**envified exists so that never happens again.**

---

## 🚀 What's New in v3.1.0

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

Because a bullet list isn't enough — here's what each feature actually *does* for you, and why you should care:

### ⚛️ Reactive State — The One That Changes Everything

`ValueListenable<EnvConfig>` is at the core. No global setState calls, no InheritedWidget gymnastics. The moment you switch an environment, the whole app knows. It just works.

### 🔒 Production Lock — Your Last Line of Defence

When `allowProdSwitch: false`, that's it. The UI greys out. The API throws. No one is accidentally pointing five thousand real users at `dev.api.yourapp.com` at 2 AM ever again.

### 🕶️ Sensitive Data Auto-Blurring — For the Screen-Share Sweats

Ever shared your screen in a standup and suddenly your `JWT_TOKEN` is in 4K on everyone's monitor? Mark a key as sensitive and envified blurs it in the panel. Even if someone screenshots it. Yes, really.

### 🔍 Auto-Discovery — Just Drop the File

Point it at `assets/env/` and walk away. No yaml mapping per environment, no manual registration loop. It finds `.env.dev`, `.env.staging`, `.env.prod` by itself. Pure magic, entirely explainable.

### 📜 Audit Log — Accountability, but Make It Pretty

A full visual timeline of every environment switch, with timestamps. When your QA lead asks "wait, was this tested on staging or prod?", you pull up the log and *know*. No guesswork.

### 🟢 Status Badge — The Little Dot That Saves Big Meetings

A floating indicator that shows the active environment at all times. Green for dev, red for prod, whatever you configure. You'll wonder how you ever lived without it after the first week.

### 📳 Shake to Open — Because Tapping Hidden Buttons is for Amateurs

Give your phone a shake. Panel opens. Switch environments. Shake again to close. It's genuinely satisfying and your QA team will use it without being told how.

---

## 🛠️ Setup in Four Steps (Yes, Really Just Four)

### 1. Install

```yaml
dependencies:
  envified: ^3.1.0
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
API_KEY=sk_test_123
FEATURE_FLAG_NEW_CHECKOUT=true

# .env.staging
BASE_URL=https://staging.api.myapp.com
API_KEY=sk_test_staging_456
FEATURE_FLAG_NEW_CHECKOUT=true

# .env.prod
BASE_URL=https://api.myapp.com
API_KEY=sk_live_abc
FEATURE_FLAG_NEW_CHECKOUT=false  # not yet, coward
```

Register the folder in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/env/  # that's it. envified scans the rest.
```

---

### 3. Initialize in `main()`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,

    // Lock the service down in release builds — no switching,
    // no panel, no funny business.
    allowProdSwitch: kDebugMode,

    // These values get auto-blurred in the debug panel.
    // Your standup screenshots will remain safe.
    sensitiveKeys: ['API_KEY', 'JWT_TOKEN', 'STRIPE_SECRET'],

    // (Optional) Define which environments are locked in release mode.
    // Defaults to [Env.prod].
    productionEnvs: [Env.prod, Env.dynamic('canary')],
  );

  runApp(const MyApp());
}
```

---

### 4. Wrap Your App with the Overlay

The overlay is what brings the debug panel, status badge, and shake gesture to life. It lives just inside `MaterialApp.builder`:

```dart
MaterialApp(
  builder: (context, child) => EnvifiedOverlay(
    // Disable entirely in release — ships zero overhead to prod
    enabled: kDebugMode,

    // Require a PIN before allowing any environment switch.
    // Keeps curious fingers out of dangerous territory.
    gate: EnvGate(pin: '8888'),

    // Shake your device to open the panel.
    // Or swap for EnvTrigger.longPress() if you prefer.
    trigger: EnvTrigger.shake(detector: MyShakeDetector()),

    child: child!,
  ),
  home: const MyHomePage(),
),
```

That's it. Your app now has a runtime environment switcher. Go touch some grass — you've earned it.

---

## ⚛️ Reactive Usage — The Good Stuff

Since v3.0.0, `EnvConfigService.instance.current` is a `ValueListenable<EnvConfig>`. That means you can wire it directly into `ValueListenableBuilder` and get real-time UI updates with zero manual `setState` calls:

```dart
ValueListenableBuilder<EnvConfig>(
  valueListenable: EnvConfigService.instance.current,
  builder: (context, config, _) {
    return Column(
      children: [
        Text('🌐 Base URL: ${config.baseUrl}'),
        Text('🔑 API Key: ${config.get('API_KEY')}'),
        Text('🚦 Env: ${config.name.toUpperCase()}'),
      ],
    );
  },
)
```

Switch environments in the panel → the builder fires → the UI updates. No hot reload. No restart. No ceremony.

You can also listen imperatively if `ValueListenableBuilder` isn't your style:

```dart
EnvConfigService.instance.current.addListener(() {
  final newConfig = EnvConfigService.instance.current.value;
  print('Switched to: ${newConfig.name}');
  analytics.track('env_switch', {'env': newConfig.name});
});
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
// Typed getters on EnvConfig:
final baseUrl = EnvConfigService.instance.current.value.baseUrl;

// Generic key lookup (returns String?):
final apiKey = EnvConfigService.instance.current.value.get('API_KEY');

// With a fallback, because nulls are a lifestyle choice you don't have to make:
final timeout = EnvConfigService.instance.current.value.get('TIMEOUT') ?? '30';
```

---

## 🧪 Testing — First-Class, Not an Afterthought

envified v3 was built test-first. The `overrideForTesting` hook lets you swap out every dependency before your first `expect`:

```dart
setUp(() {
  EnvConfigService.overrideForTesting(
    storage: MyFakeStorage(),        // in-memory, no disk I/O
    parser: const EnvFileParser(),   // real parser, fake assets
  );
});

test('switches env and notifies listeners', () async {
  // Inject whatever env files you want via the bundle
  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    bundle: FakeAssetBundle({
      'assets/env/.env': 'BASE_URL=https://test.internal\nAPI_KEY=sk_test_fake',
    }),
  );

  var notified = false;
  EnvConfigService.instance.current.addListener(() => notified = true);

  await EnvConfigService.instance.switchTo(Env.staging);

  expect(notified, isTrue);
  expect(
    EnvConfigService.instance.current.value.name,
    equals('staging'),
  );
});
```

No network calls. No file system. No flakiness. Just fast, deterministic tests that tell you something real.

---

## 🎯 Trigger Options

The overlay ships with multiple ways to open the panel. Pick your style:

```dart
// Shake gesture — the classic (requires a detector)
trigger: EnvTrigger.shake(detector: MyShakeDetector())

// Long press on the status badge or overlay area
trigger: const EnvTrigger.longPress()

// Double-tap anywhere on the overlay
trigger: const EnvTrigger.doubleTap()

// Edge swipe — for that native feeling
trigger: const EnvTrigger.edgeSwipe()
```

---

## 🔐 Gate Options

Control *who* can actually switch:

```dart
// PIN gate — the default
gate: EnvGate(pin: '8888')

// No gate — trust everyone (dev-only, please)
// Simply don't pass a gate to EnvifiedOverlay
```

---

## 🧩 Dynamic Environments — No More Static Enums

envified v3 automatically discovers your environments from the file extensions in `assets/env/`.

- `.env` → **Prod**
- `.env.staging` → **Staging**
- `.env.dev` → **Dev**
- `.env.canary` → **Canary** (discovered automatically!)

You don't need to define an enum anymore. If you want to reference a specific environment in code, use the built-in constants: `Env.dev`, `Env.staging`, `Env.prod`. Or create your own dynamic environment: `final myEnv = Env.dynamic('canary');`.

---

## 📐 Architecture Overview

```text
EnvConfigService (Singleton)
├── current: ValueNotifier<EnvConfig>   ← reactive source of truth
├── init()                               ← loads default env from storage or param
├── switchTo(env)                        ← validates lock, updates notifier, persists
└── overrideForTesting()                 ← injects fakes for unit tests

EnvifiedOverlay (Widget)
├── EnvStatusBadge                       ← floating environment indicator
├── EnvGate                              ← PIN guard
├── EnvTrigger                           ← shake / tap / longPress / doubleTap / swipe
└── EnvPanel                             ← the actual switcher UI + audit log

EnvFileParser
├── Scans AssetBundle for .env.* files
├── Parses KEY=VALUE pairs
└── Returns typed EnvConfig objects
```

---

## 🤝 Contributing

Found a bug? Have a wild idea for a new trigger? PRs are open, issues are welcome, and we read everything.

Please run the tests before opening a PR:

```bash
flutter test
```

And if you're adding a feature, add a test for it. Future-you will be grateful. Past-you is already nodding.

---

## 📄 License

MIT © [Appamania](https://appamania.in)

---

## ☕ Support the Project

If **envified** saves your rebuild time and improves your workflow, consider supporting the project:

👉 **[Pay with Chai](https://paywithchai.in/appamania)**

---

*Built with the belief that developer experience is a feature, not a luxury.*

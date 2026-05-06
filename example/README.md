# envified_example

This directory contains a complete Flutter application demonstrating the `envified` package.

## Features Demonstrated

- **Runtime Environment Switching**: Swap between Dev, Staging, Prod, and Custom environments using `EnvConfigService`.
- **Debug UI Overlay**: Integration of the `EnvifiedOverlay` into the `MaterialApp.builder` to make the panel accessible from anywhere.
- **Stealth Mode & Auth Gate**: Demonstrates how to hide the floating 🌿 button and require a 4-digit PIN (`1234`) and a double-tap gesture (`EnvTrigger.tap(count: 2)`) to reveal the debug panel.
- **URL Overrides & History**: Shows how overridden base URLs are applied to the active configuration.

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

*Note: In the example app, double-tap anywhere on the screen and enter PIN `1234` to access the debug panel.*

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-06

### Initial Stable Release 🚀

- **Runtime Environment Switching** — Seamlessly swap between `dev`, `staging`, `prod`, and `custom` without rebuilding your app.
- **Enterprise-Grade Security** — Fully encrypted persistence layer using `flutter_secure_storage`. Choices and overrides are stored in Keychain/Keystore.
- **Production Lock** — Prevent accidental environment switches or URL overrides in production builds.
- **API URL Overrides** — Dynamically point your app to any backend URL at runtime (perfect for local testing or PR reviews).
- **Premium Debug UI** — Built-in, horizontally scrollable action chip panel and floating action button that only appears in debug mode.
- **Zero-Overhead** — Debug components are completely optimized out in release builds.
- **Bulletproof Reliability** — Comprehensive unit test suite covering parsing, models, storage, and service logic.

## [0.1.2] - 2026-05-06
- Security upgrade to encrypted storage.
- Storage injection for unit testing.

## [0.1.0] - 2026-05-06
- Initial beta release.

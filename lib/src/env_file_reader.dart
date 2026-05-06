import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Reads `.env.json` or `.env` (key=value) files from Flutter assets and
/// returns them as a `Map<String, String>` ready to pass into
/// [EnvConfigService.instance.init] via the `vars` or `varsByEnv` parameters.
///
/// ## Security Note
/// Files loaded via this class are bundled as Flutter assets, which means
/// they CAN be extracted from a release APK/IPA by anyone. Do NOT put
/// private API keys, passwords, or tokens in asset-based env files.
///
/// Use this for non-sensitive configuration: feature flags, log levels,
/// timeouts, analytics IDs, public endpoint names, etc.
///
/// For secrets, use `String.fromEnvironment()` with `--dart-define-from-file`
/// instead (values are baked into the binary and cannot be extracted as a file).
///
/// ## Usage
///
/// ```dart
/// // .env.dev.json (add to pubspec.yaml assets, add ALL to .gitignore)
/// // {
/// //   "LOG_LEVEL": "verbose",
/// //   "FEATURE_X": "true",
/// //   "REQUEST_TIMEOUT": "10000"
/// // }
///
/// await EnvConfigService.instance.init(
///   urls: { ... },
///   varsByEnv: {
///     Env.dev:     await EnvFileReader.fromAsset('assets/.env.dev.json'),
///     Env.staging: await EnvFileReader.fromAsset('assets/.env.staging.json'),
///     Env.prod:    await EnvFileReader.fromAsset('assets/.env.prod.json'),
///   },
/// );
/// ```
class EnvFileReader {
  EnvFileReader._();

  /// Loads a `.env.json` file from Flutter assets.
  ///
  /// The file must contain a flat JSON object with string values:
  /// ```json
  /// {
  ///   "LOG_LEVEL": "verbose",
  ///   "FEATURE_X": "true"
  /// }
  /// ```
  ///
  /// Throws a [FlutterError] if the asset is missing.
  /// Throws a [FormatException] if the JSON is malformed or contains non-string values.
  static Future<Map<String, String>> fromJsonAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  /// Loads a standard `.env` (key=value) file from Flutter assets.
  ///
  /// Format (lines starting with `#` are comments, blank lines are ignored):
  /// ```
  /// # This is a comment
  /// LOG_LEVEL=verbose
  /// FEATURE_X=true
  /// REQUEST_TIMEOUT=10000
  /// ```
  ///
  /// Throws a [FlutterError] if the asset is missing.
  static Future<Map<String, String>> fromDotenvAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final result = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      // Skip blank lines and comments
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex == -1) continue;
      final key = trimmed.substring(0, separatorIndex).trim();
      var value = trimmed.substring(separatorIndex + 1).trim();
      // Strip optional surrounding quotes
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      if (key.isNotEmpty) result[key] = value;
    }
    return result;
  }

  /// Reads all `String.fromEnvironment` values for the provided [keys]
  /// from compile-time `--dart-define` or `--dart-define-from-file` injections.
  ///
  /// This is a convenience helper. Values baked in at compile time are safe
  /// and cannot be extracted as a file from the APK.
  ///
  /// ```dart
  /// vars: EnvFileReader.fromDartDefine(['API_KEY', 'SENTRY_DSN', 'APP_NAME']),
  /// ```
  static Map<String, String> fromDartDefine(
    List<String> keys, {
    String defaultValue = '',
  }) {
    return {
      for (final key in keys)
        key: String.fromEnvironment(key, defaultValue: defaultValue),
    };
  }
}

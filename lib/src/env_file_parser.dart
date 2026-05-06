import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Internal parser for `.env*` asset files.
///
/// This class is **not exported** from the public API. It is used exclusively
/// by [EnvConfigService] to load and merge environment configuration at
/// runtime.
///
/// Parsing rules:
/// - Lines in the form `KEY=VALUE` are accepted.
/// - Lines starting with `#` are treated as comments and ignored.
/// - Surrounding double-quotes on values are stripped: `KEY="value"` → `value`.
/// - Keys with no value (`KEY=`) produce an empty string, not `null`.
/// - Multiline values are not supported.
///
/// @see EnvConfigService
class EnvFileParser {
  /// Loads and parses a single `.env*` file at [assetPath].
  ///
  /// Returns an empty [Map] if the asset is not found (e.g. the developer did
  /// not declare the file in `pubspec.yaml`). All other I/O errors are
  /// re-thrown.
  ///
  /// ```dart
  /// final parser = EnvFileParser();
  /// final values = await parser.parse('.env.dev');
  /// ```
  Future<Map<String, String>> parse(String assetPath) async {
    String content;
    try {
      content = await rootBundle.loadString(assetPath);
    } on FlutterError {
      // Asset not registered or not found — treat as empty.
      return <String, String>{};
    } catch (_) {
      return <String, String>{};
    }
    return _parseContent(content);
  }

  /// Parses raw `.env` [content] into a key-value map.
  Map<String, String> _parseContent(String content) {
    final result = <String, String>{};

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();

      // Skip blank lines and comments.
      if (line.isEmpty || line.startsWith('#')) continue;

      final separatorIndex = line.indexOf('=');
      if (separatorIndex == -1) continue;

      final key = line.substring(0, separatorIndex).trim();
      if (key.isEmpty) continue;

      final rawValue = line.substring(separatorIndex + 1).trim();
      final value = _stripQuotes(rawValue);

      result[key] = value;
    }

    return result;
  }

  /// Strips surrounding double-quotes from [value] if present.
  String _stripQuotes(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  /// Merges [fallback] values with [specific] values.
  ///
  /// Values present in [specific] override those in [fallback]. Values only in
  /// [fallback] are retained as-is.
  ///
  /// ```dart
  /// final merged = parser.merge(fallback, specific);
  /// ```
  Map<String, String> merge(
    Map<String, String> fallback,
    Map<String, String> specific,
  ) {
    return <String, String>{...fallback, ...specific};
  }
}

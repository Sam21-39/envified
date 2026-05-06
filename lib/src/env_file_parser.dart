import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'env_storage.dart';
import 'envified_exception.dart';

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

  /// Verifies the integrity of the `.env*` file at [assetPath].
  ///
  /// On the **first load** of a given file the raw bytes are SHA-256 hashed
  /// and the digest is persisted in [storage] under the key
  /// `envified_hash_<sanitised-path>`.
  ///
  /// On **subsequent loads** the hash is recomputed and compared against the
  /// stored value. If they differ an [EnvifiedTamperException] is thrown.
  ///
  /// If the asset does not exist (e.g. `.env.custom` is optional) this method
  /// returns silently without storing a hash.
  ///
  /// @throws [EnvifiedTamperException] when the file hash does not match the
  ///   stored baseline hash.
  Future<void> verifyIntegrity(String assetPath, EnvStorage storage) async {
    // Load raw bytes; bail out silently when the asset doesn't exist.
    ByteData? data;
    try {
      data = await rootBundle.load(assetPath);
    } on FlutterError {
      return;
    } catch (_) {
      return;
    }

    final Uint8List bytes = data.buffer.asUint8List();
    final String currentHash = sha256.convert(bytes).toString();

    final String storageKey = 'envified_hash_${assetPath.replaceAll('/', '_')}';
    final String? storedHash = await storage.readRaw(storageKey);

    if (storedHash == null) {
      // First load — persist the baseline.
      await storage.writeRaw(storageKey, currentHash);
    } else if (storedHash != currentHash) {
      throw EnvifiedTamperException(assetPath);
    }
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
    if (value.length >= 2) {
      if (value.startsWith('"') && value.endsWith('"')) {
        return value.substring(1, value.length - 1);
      }
      if (value.startsWith("'") && value.endsWith("'")) {
        return value.substring(1, value.length - 1);
      }
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

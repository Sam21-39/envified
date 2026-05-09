import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A pure-Dart parser for .env files.
///
/// Responsible for parsing raw strings, computing hashes for integrity checks,
/// and discovering environment files in the asset bundle.
class EnvFileParser {
  const EnvFileParser();

  /// Parses a raw .env string into a flat map of key-value pairs.
  ///
  /// Handles:
  /// - Comments (starting with #)
  /// - Inline comments (outside of quotes)
  /// - Blank lines
  /// - Quoted values (single or double quotes)
  Map<String, String> parse(String content) {
    final result = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eqIndex = trimmed.indexOf('=');
      if (eqIndex < 1) continue;

      final key = trimmed.substring(0, eqIndex).trim();
      var value = trimmed.substring(eqIndex + 1).trim();

      // Strip inline comments (only outside quotes)
      value = _stripInlineComment(value);

      // Strip surrounding quotes
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      if (key.isNotEmpty) result[key] = value;
    }
    return result;
  }

  String _stripInlineComment(String value) {
    // Only strip # if it has a preceding space (standard .env format)
    // and is not inside quotes.
    final inQuotes = value.startsWith('"') || value.startsWith("'");
    if (inQuotes) return value;

    final hashIndex = value.indexOf(' #');
    return hashIndex >= 0 ? value.substring(0, hashIndex).trim() : value;
  }

  /// Loads an asset from the [rootBundle] and parses it.
  ///
  /// Returns null if the file is not found or cannot be read.
  Future<Map<String, String>?> loadAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return parse(content);
    } catch (_) {
      return null;
    }
  }

  /// Discovers all .env files in the provided list of asset paths.
  ///
  /// Matches `.env` and `.env.suffix` patterns.
  Future<List<String>> discoverEnvFiles(List<String> allAssets) async {
    return allAssets
        .where((path) => RegExp(r'\.env(\.\w+)?$').hasMatch(path))
        .toList();
  }

  /// Computes a deterministic SHA-256 hash of the content for integrity checks.
  String computeHash(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }
}

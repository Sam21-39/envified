import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/env.dart';
import '../storage/env_storage.dart';
import '../models/envified_exception.dart';

/// Internal parser for `.env*` asset files.
class EnvFileParser {
  /// Loads and parses a single `.env*` file at [assetPath].
  Future<Map<String, String>> parse(String assetPath,
      {AssetBundle? bundle}) async {
    final activeBundle = bundle ?? rootBundle;
    String content;
    try {
      content = await activeBundle.loadString(assetPath);
    } on FlutterError {
      return <String, String>{};
    } catch (_) {
      return <String, String>{};
    }
    return _parseContent(content);
  }

  /// Verifies the integrity of the `.env*` file at [assetPath].
  Future<void> verifyIntegrity(
    String assetPath,
    EnvStorage storage, {
    AssetBundle? bundle,
  }) async {
    final activeBundle = bundle ?? rootBundle;
    ByteData? data;
    try {
      data = await activeBundle.load(assetPath);
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
  Map<String, String> merge(
    Map<String, String> fallback,
    Map<String, String> specific,
  ) {
    return <String, String>{...fallback, ...specific};
  }

  /// Discovers all `.env.*` files in the asset bundle.
  Future<Map<Env, String>> discoverAndExtractUrls({
    String assetDir = '',
    bool requireBaseUrl = false,
    AssetBundle? bundle,
  }) async {
    final activeBundle = bundle ?? rootBundle;
    final result = <Env, String>{};

    final envFileRegex = RegExp(r'\.env\.([a-z0-9]+)$');

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(activeBundle);
      final allAssets = manifest.listAssets();

      final assets = assetDir.isEmpty
          ? allAssets
          : allAssets.where((path) => path.startsWith(assetDir));

      bool hasProdExplicit = allAssets.any((a) => a.endsWith('.env.prod'));

      for (final assetPath in assets) {
        final fileName = assetPath.split('/').last;

        // Determine if this is an environment file
        final isProdNaked = fileName == '.env' && !hasProdExplicit;
        final isEnvFile = isProdNaked || envFileRegex.hasMatch(fileName);

        if (!isEnvFile) continue;

        try {
          final content = await activeBundle.loadString(assetPath);
          final baseUrl = _extractBaseUrl(content);

          final env = Env.fromFileName(fileName);
          result[env] = baseUrl;
        } catch (e) {
          if (requireBaseUrl) rethrow;
        }
      }

      if (result.isEmpty) {
        throw const EnvifiedMissingFileException(
          'No environment files discovered. '
          'Create at least .env, .env.dev, or .env.prod.',
        );
      }

      return result;
    } catch (e) {
      if (e is EnvifiedMissingFileException) rethrow;
      throw EnvifiedMissingFileException(
        'Failed to discover environments: $e',
      );
    }
  }

  /// Extracts BASE_URL from .env file content.
  String _extractBaseUrl(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('BASE_URL=')) {
        final value = trimmed.substring('BASE_URL='.length).trim();
        return _stripQuotes(value);
      }
    }
    return '';
  }
}

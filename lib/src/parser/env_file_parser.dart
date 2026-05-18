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

  /// Discovers all `.env.*` files in the asset bundle across flexible list paths.
  Future<Map<Env, String>> discoverAndExtractUrls({
    List<String> envAssetPaths = const ['assets/env/'],
    bool requireBaseUrl = false,
    AssetBundle? bundle,
  }) async {
    final activeBundle = bundle ?? rootBundle;
    final result = <Env, String>{};
    final envFileRegex = RegExp(r'\.env\.([a-z0-9]+)$');
    final scannedPaths = <String>[];

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(activeBundle);
      final allAssets = manifest.listAssets();

      var pathsToScan = List<String>.from(envAssetPaths);

      // Fallback for backwards compatibility: if we default to ['assets/env/']
      // but no assets in the manifest start with 'assets/env/', we check if there are
      // any .env files in the root (i.e. we fallback to scanning '').
      if (pathsToScan.length == 1 && pathsToScan.first == 'assets/env/') {
        final hasEnvAssetsInPath =
            allAssets.any((asset) => asset.startsWith('assets/env/'));
        if (!hasEnvAssetsInPath) {
          pathsToScan = const [''];
        }
      }

      for (final path in pathsToScan) {
        scannedPaths.add(path);

        if (path.isEmpty || path.endsWith('/')) {
          // Directory path (empty string represents root directory)
          final dirAssets = allAssets.where((asset) => asset.startsWith(path));
          bool hasProdExplicit = dirAssets.any((a) => a.endsWith('.env.prod'));

          for (final assetPath in dirAssets) {
            final fileName = assetPath.split('/').last;
            final isProdNaked = fileName == '.env' && !hasProdExplicit;
            final isEnvFile = isProdNaked || envFileRegex.hasMatch(fileName);

            if (!isEnvFile) continue;

            try {
              final content = await activeBundle.loadString(assetPath);
              final baseUrl = _extractBaseUrl(content);
              final env = Env.fromFileName(fileName, path: assetPath);
              result[env] = baseUrl;
            } catch (e) {
              if (requireBaseUrl) rethrow;
            }
          }
        } else {
          // Direct file path
          if (allAssets.contains(path)) {
            final fileName = path.split('/').last;
            try {
              final content = await activeBundle.loadString(path);
              final baseUrl = _extractBaseUrl(content);
              final env = Env.fromFileName(fileName, path: path);
              result[env] = baseUrl;
            } catch (e) {
              if (requireBaseUrl) rethrow;
            }
          }
        }
      }

      if (result.isEmpty) {
        throw EnvifiedMissingFileException(
          'No .env.* files discovered. Scanned: ${scannedPaths.toString()}.\n'
          'Register your .env files in pubspec.yaml under flutter.assets and pass their paths to envAssetPaths.',
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
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex == -1) continue;

      final key = trimmed.substring(0, separatorIndex).trim();
      if (key == 'BASE_URL') {
        final rawValue = trimmed.substring(separatorIndex + 1).trim();
        return _stripQuotes(rawValue);
      }
    }
    return '';
  }
}

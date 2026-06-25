import 'dart:io';
import 'package:path/path.dart' as p;
import '../parser/env_parser.dart';

/// Discovers `.env.*` files from the filesystem (never from Flutter assets).
class EnvScanner {
  static const List<String> defaultScanPaths = [
    '.',
    'config/env',
    'secrets',
    'env',
  ];

  final String projectRoot;
  final List<String> scanPaths;

  EnvScanner({
    required this.projectRoot,
    List<String>? scanPaths,
  }) : scanPaths = scanPaths ?? defaultScanPaths;

  /// Scans [scanPaths] and returns all discovered env files grouped by
  /// environment name.
  ///
  /// - Ignores template/example files.
  /// - `.env.secrets` files are returned separately in [ScanResult.secretFiles].
  ScanResult scan() {
    final envFiles = <String, File>{}; // env name → file
    final secretFiles = <String, File>{}; // env name (or 'all') → file
    final warnings = <String>[];

    for (final rel in scanPaths) {
      final dir = Directory(p.join(projectRoot, rel));
      if (!dir.existsSync()) continue;

      for (final entry in dir.listSync()) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);

        if (EnvParser.isIgnoredFile(name)) {
          warnings.add('Ignored: ${entry.path}');
          continue;
        }

        if (!name.startsWith('.env')) continue;

        if (name == '.env.secrets' || name.endsWith('.secrets')) {
          // Derive env name: .env.staging.secrets → staging, .env.secrets → 'all'
          final envName = _secretEnvName(name);
          secretFiles[envName] = entry;
        } else if (name == '.env') {
          envFiles['prod'] = entry;
        } else if (name.startsWith('.env.')) {
          final envName = name.substring(5); // strip '.env.'
          if (envName.isNotEmpty) envFiles[envName] = entry;
        }
      }
    }

    return ScanResult(
      envFiles: envFiles,
      secretFiles: secretFiles,
      warnings: warnings,
    );
  }

  String _secretEnvName(String fileName) {
    // .env.secrets → 'all'
    if (fileName == '.env.secrets') return 'all';
    // .env.<name>.secrets → '<name>'
    final match = RegExp(r'^\.env\.(.+)\.secrets$').firstMatch(fileName);
    return match?.group(1) ?? 'all';
  }
}

class ScanResult {
  /// Discovered non-secret env files keyed by environment name.
  final Map<String, File> envFiles;

  /// Discovered secrets files keyed by environment name (`'all'` = global).
  final Map<String, File> secretFiles;

  /// Non-fatal warnings emitted during the scan.
  final List<String> warnings;

  const ScanResult({
    required this.envFiles,
    required this.secretFiles,
    required this.warnings,
  });

  bool get isEmpty => envFiles.isEmpty && secretFiles.isEmpty;
}

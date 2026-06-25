import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../scanner/env_scanner.dart';

/// `envified scan` — dry-run discovery. Prints found/ignored/warned files.
class ScanCommand extends Command<void> {
  @override
  final String name = 'scan';

  @override
  final String description = 'Discover .env.* files without writing anything.';

  ScanCommand() {
    argParser.addOption(
      'project-root',
      abbr: 'r',
      defaultsTo: '.',
      help: 'Path to the Flutter project root.',
    );
  }

  @override
  Future<void> run() async {
    final root = p.absolute(argResults!['project-root'] as String);
    final scanner = EnvScanner(projectRoot: root);
    final result = scanner.scan();

    if (result.isEmpty) {
      stdout.writeln('No .env.* files found in scan paths.');
      stdout.writeln('Searched: ${EnvScanner.defaultScanPaths.join(', ')}');
      return;
    }

    stdout.writeln('Discovered environment files:');
    for (final entry in result.envFiles.entries) {
      stdout.writeln('  [${entry.key}]  ${entry.value.path}');
    }

    if (result.secretFiles.isNotEmpty) {
      stdout.writeln('\nSecret files (will be encrypted, never bundled):');
      for (final entry in result.secretFiles.entries) {
        stdout.writeln('  [${entry.key}]  ${entry.value.path}');
      }
    }

    if (result.warnings.isNotEmpty) {
      stdout.writeln('\nWarnings:');
      for (final w in result.warnings) {
        stdout.writeln('  ⚠  $w');
      }
    }
  }
}

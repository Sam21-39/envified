import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../scanner/env_scanner.dart';

/// `envified check` — validates that the `.envified.lock` is current.
///
/// Exits with code 1 if any secret file is tracked by git, if the lock is
/// missing, or if any file hash has drifted from the lock.
class CheckCommand extends Command<void> {
  @override
  final String name = 'check';

  @override
  final String description =
      'Validate .envified.lock against the current filesystem state.';

  CheckCommand() {
    argParser
      ..addOption('project-root', abbr: 'r', defaultsTo: '.')
      ..addFlag('strict',
          help: 'Fail if any compat shims are still active.',
          defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final root = p.absolute(argResults!['project-root'] as String);
    var failed = false;

    // 1. Verify secrets are not tracked by git.
    failed = _checkGitIgnored(root) || failed;

    // 2. Verify .envified.lock exists.
    final lockFile = File(p.join(root, '.envified.lock'));
    if (!lockFile.existsSync()) {
      stderr.writeln('✗  .envified.lock not found. Run: envified build --all');
      exitCode = 1;
      return;
    }

    // 3. Parse lock and compare hashes.
    failed = _checkLockDrift(root, lockFile) || failed;

    if (!failed) {
      stdout.writeln('✓  envified check passed.');
    } else {
      exitCode = 1;
    }
  }

  bool _checkGitIgnored(String root) {
    final scanner = EnvScanner(projectRoot: root);
    final result = scanner.scan();
    var failed = false;

    for (final file in result.secretFiles.values) {
      final gitCheck = Process.runSync('git', [
        '-C',
        root,
        'ls-files',
        '--error-unmatch',
        file.path,
      ]);
      if (gitCheck.exitCode == 0) {
        stderr.writeln('✗  Secret file is tracked by git: ${file.path}\n'
            '   Add it to .gitignore immediately.');
        failed = true;
      }
    }
    return failed;
  }

  bool _checkLockDrift(String root, File lockFile) {
    var failed = false;

    try {
      final yaml = loadYaml(lockFile.readAsStringSync()) as YamlMap?;
      final envs = yaml?['environments'] as YamlMap?;
      if (envs == null) return false;

      for (final entry in envs.entries) {
        final envName = entry.key as String;
        final meta = entry.value as YamlMap;
        final recordedHash = meta['sha256'] as String?;
        final filePath = meta['file'] as String?;

        if (filePath == null || recordedHash == null) continue;

        final file = File(filePath);
        if (!file.existsSync()) {
          stderr.writeln('✗  [$envName] source file missing: $filePath');
          failed = true;
          continue;
        }

        final currentHash =
            sha256.convert(utf8.encode(file.readAsStringSync())).toString();
        if (currentHash != recordedHash) {
          stderr.writeln(
              '✗  [$envName] file changed since last build: $filePath\n'
              '   Run: envified build --env=$envName');
          failed = true;
        } else {
          stdout.writeln('  ✓  [$envName] hash matches');
        }
      }
    } catch (e) {
      stderr.writeln('✗  Could not parse .envified.lock: $e');
      return true;
    }

    return failed;
  }
}

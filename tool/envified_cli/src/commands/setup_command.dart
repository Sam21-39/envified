import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// `envified setup` — one-time project scaffolding.
///
/// - Creates `envified.yaml` if absent.
/// - Writes `.gitignore` rules for secrets files.
/// - Prints next steps.
class SetupCommand extends Command<void> {
  @override
  final String name = 'setup';

  @override
  final String description =
      'One-time setup: creates envified.yaml and .gitignore rules.';

  SetupCommand() {
    argParser.addOption(
      'project-root',
      abbr: 'r',
      help: 'Path to the Flutter project root.',
      defaultsTo: '.',
    );
  }

  @override
  Future<void> run() async {
    final root = argResults!['project-root'] as String;
    final rootDir = Directory(p.absolute(root));

    if (!rootDir.existsSync()) {
      stderr.writeln('Error: project root "${rootDir.path}" does not exist.');
      exitCode = 1;
      return;
    }

    _writeEnvifiedYaml(rootDir);
    _appendGitignore(rootDir);

    stdout.writeln('✓ envified setup complete.');
    stdout.writeln('');
    stdout.writeln('Next steps:');
    stdout.writeln('  1. Add your .env.dev / .env.staging / .env.prod files.');
    stdout.writeln('  2. Run: envified build --env=dev');
    stdout.writeln('  3. Add ENVIFIED_MASTER_KEY to your CI secrets.');
  }

  void _writeEnvifiedYaml(Directory root) {
    final file = File(p.join(root.path, 'envified.yaml'));
    if (file.existsSync()) {
      stdout.writeln('  envified.yaml already exists — skipping.');
      return;
    }
    file.writeAsStringSync(_defaultYaml);
    stdout.writeln('  Created envified.yaml');
  }

  void _appendGitignore(Directory root) {
    final file = File(p.join(root.path, '.gitignore'));
    const rules = '''

# envified — secrets files must never be committed
.env.secrets
.env.*.secrets
.env.local
.envified_key
''';

    if (file.existsSync()) {
      final content = file.readAsStringSync();
      if (content.contains('.env.secrets')) {
        stdout.writeln('  .gitignore already has envified rules — skipping.');
        return;
      }
      file.writeAsStringSync(content + rules);
    } else {
      file.writeAsStringSync(rules);
    }
    stdout.writeln('  Updated .gitignore');
  }

  static const String _defaultYaml = '''
# envified.yaml — project configuration for envified v4.0.0
# See https://pub.dev/packages/envified for full reference.

# Scan paths (relative to project root). Defaults apply if omitted.
# scan_paths: [., config/env, secrets, env]

default_env: dev
production_envs: [prod]
allow_production_switch: false

# Key tier routing: KEY_NAME: tier1|tier2|tier3
key_types: {}

sensitive_key_patterns:
  - API_KEY
  - SECRET
  - TOKEN
  - PASSWORD
  - PRIVATE_KEY
  - AUTH_TOKEN

services:
  firebase: false
  supabase: false
  google_maps: false

# Per-environment display name and icon (Phase 3)
# identity:
#   dev:  { display_name: "MyApp [Dev]", icon_path: "assets/icons/icon_dev.png" }
#   prod: { display_name: "MyApp",       icon_path: "assets/icons/icon_prod.png" }

# Migration compat
compat:
  dotenv: false
  envied: false
''';
}

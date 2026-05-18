// ignore_for_file: avoid_print
import 'dart:io';
import 'package:envified/src/secrets/secrets_generator.dart';

void main(List<String> args) {
  // Parse command line arguments and environment variables
  String environment = Platform.environment['TARGET_ENV'] ?? '';
  String secretsDir = '.';
  bool verbose = true;

  for (final arg in args) {
    if (arg.startsWith('--env=')) {
      environment = arg.substring(6);
    } else if (arg.startsWith('--secrets-dir=')) {
      secretsDir = arg.substring(14);
    } else if (arg == '--quiet') {
      verbose = false;
    }
  }

  final secretsPath =
      '$secretsDir/.env.secrets${environment.isEmpty ? "" : ".$environment"}';
  final secretsFile = File(secretsPath);

  if (verbose) {
    print('🌿 envified: Running standalone Secrets Generator CLI...');
    print(
        '📂 Target environment: ${environment.isEmpty ? "default" : environment}');
    print('🔍 Looking for secrets at: $secretsPath');
  }

  if (!secretsFile.existsSync()) {
    print('❌ Error: Secrets file not found at "$secretsPath".');
    print(
        'Please create one with sensitive credentials (e.g. API_SECRET=my_secret).');
    exit(1);
  }

  // Auto-scan asset configs to ensure no sensitive key leaks or duplicates
  final assetConfigPaths = <String>[];
  final defaultAssetDir = Directory('assets/env');
  if (defaultAssetDir.existsSync()) {
    defaultAssetDir.listSync().forEach((entity) {
      final fileName = entity.path.split(Platform.pathSeparator).last;
      if (entity is File &&
          (fileName == '.env' || fileName.startsWith('.env.'))) {
        assetConfigPaths.add(entity.path);
      }
    });
  }

  final requiredKeys = <String>[];
  final blocklist = <String>[
    'API_KEY',
    'SECRET_KEY',
    'TOKEN',
    'PASSWORD',
    'PRIVATE_KEY',
    'AUTH_TOKEN',
    'JWT',
    'OAUTH_SECRET',
    '_KEY'
  ];

  try {
    final generator = SecretsGenerator(
      secretsFileDir: secretsDir,
      environment: environment,
      assetConfigPaths: assetConfigPaths,
      blocklist: blocklist,
      requiredKeys: requiredKeys,
      verbose: verbose,
    );

    final secretsFileContent = secretsFile.readAsStringSync();
    final generatedCode = generator.generate(secretsFileContent);

    final outputDir = Directory('lib/core/config');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = File('lib/core/config/secrets.g.dart');
    outputFile.writeAsStringSync(generatedCode);

    if (verbose) {
      print('✅ Success: Generated obfuscated secrets at "${outputFile.path}"!');
    }

    // Automatically format the generated file
    Process.runSync('dart', ['format', outputFile.path]);
  } catch (e) {
    print('❌ Error generating secrets: $e');
    exit(1);
  }
}

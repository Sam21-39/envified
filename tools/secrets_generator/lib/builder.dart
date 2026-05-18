import 'package:build/build.dart';
import 'dart:io';
import 'secrets_generator.dart';

Builder secretsBuilder(BuilderOptions options) {
  // Read inputs from options or platform env variables dynamically
  final secretsDir = options.config['secrets_dir'] as String? ?? '.';
  final targetEnv = Platform.environment['TARGET_ENV'] ??
      options.config['environment'] as String? ??
      '';

  final assetConfigPaths =
      List<String>.from(options.config['asset_config_paths'] ?? const []);
  final blocklist = List<String>.from(options.config['blocklist'] ?? const []);
  final requiredKeys =
      List<String>.from(options.config['required_keys'] ?? const []);
  final verbose = options.config['verbose'] as bool? ?? false;

  return _CustomSecretsBuilder(
    secretsFileDir: secretsDir,
    environment: targetEnv,
    assetConfigPaths: assetConfigPaths,
    blocklist: blocklist,
    requiredKeys: requiredKeys,
    verbose: verbose,
  );
}

class _CustomSecretsBuilder implements Builder {
  final String secretsFileDir;
  final String environment;
  final List<String> assetConfigPaths;
  final List<String> blocklist;
  final List<String> requiredKeys;
  final bool verbose;

  _CustomSecretsBuilder({
    required this.secretsFileDir,
    required this.environment,
    required this.assetConfigPaths,
    required this.blocklist,
    required this.requiredKeys,
    required this.verbose,
  });

  @override
  Map<String, List<String>> get buildExtensions => const {
        '.secrets': ['.g.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final outputId = inputId.changeExtension('.g.dart');

    if (verbose) {
      print(
          'Running Custom Secrets obfuscated builder for environment "$environment"...');
    }

    try {
      final generator = SecretsGenerator(
        secretsFileDir: secretsFileDir,
        environment: environment,
        assetConfigPaths: assetConfigPaths,
        blocklist: blocklist,
        requiredKeys: requiredKeys,
        verbose: verbose,
      );

      // Trigger file read
      final triggerContent = await buildStep.readAsString(inputId);
      final generatedSource = generator.generate(triggerContent);

      await buildStep.writeAsString(outputId, generatedSource);

      if (verbose) {
        print(
            'Successfully wrote obfuscated secrets output to "${outputId.path}".');
      }
    } catch (e) {
      log.severe('Secrets Build Failure: $e');
      rethrow;
    }
  }
}

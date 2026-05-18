import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'env_validator.dart';

enum AppEnvironment { dev, staging, prod }

class RuntimeConfig {
  final AppEnvironment environment;
  final String baseUrl;
  final String environmentName;
  final Map<String, bool> featureFlags;
  final bool experimentalUi;
  final Map<String, String> rawPairs;

  RuntimeConfig({
    required this.environment,
    required this.baseUrl,
    required this.environmentName,
    required this.featureFlags,
    required this.experimentalUi,
    required this.rawPairs,
  });

  factory RuntimeConfig.fromMap(AppEnvironment env, Map<String, String> map) {
    final baseUrl = map['BASE_URL'] ?? 'https://api.default.com';
    final envName = map['ENV_NAME'] ?? env.name;
    final featureFlags = <String, bool>{};

    map.forEach((key, value) {
      if (key.startsWith('FEATURE_')) {
        featureFlags[key] = value.toLowerCase() == 'true';
      }
    });

    final experimentalUi = map['EXPERIMENTAL_UI']?.toLowerCase() == 'true';

    return RuntimeConfig(
      environment: env,
      baseUrl: baseUrl,
      environmentName: envName,
      featureFlags: featureFlags,
      experimentalUi: experimentalUi,
      rawPairs: map,
    );
  }
}

class AppEnv {
  AppEnv._();
  static final AppEnv instance = AppEnv._();

  final ValueNotifier<RuntimeConfig?> _currentConfig =
      ValueNotifier<RuntimeConfig?>(null);
  ValueListenable<RuntimeConfig?> get configNotifier => _currentConfig;

  RuntimeConfig get config {
    if (_currentConfig.value == null) {
      throw StateError(
          'AppEnv has not been initialized. Call initialize() first.');
    }
    return _currentConfig.value!;
  }

  /// Initializes the service by parsing the target environment asset file.
  Future<void> initialize(AppEnvironment env,
      {AssetBundle? customBundle}) async {
    final bundle = customBundle ?? rootBundle;
    final path = 'assets/env/.env.${env.name}';

    String rawContent;
    try {
      rawContent = await bundle.loadString(path);
    } catch (e) {
      throw StateError(
          'Failed to load asset environment file at "$path". Ensure it is added to pubspec.yaml assets.');
    }

    final parsedMap = _parseEnvContent(rawContent);
    EnvValidator.validate(parsedMap, isProduction: env == AppEnvironment.prod);
    _currentConfig.value = RuntimeConfig.fromMap(env, parsedMap);
  }

  /// Parses env file contents line by line.
  Map<String, String> _parseEnvContent(String content) {
    final Map<String, String> result = {};
    final lines = const LineSplitter().convert(content);

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final index = line.indexOf('=');
      if (index == -1) continue;

      final key = line.substring(0, index).trim();
      var val = line.substring(index + 1).trim();

      if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
        val = val.substring(1, val.length - 1);
      } else if (val.startsWith("'") && val.endsWith("'") && val.length >= 2) {
        val = val.substring(1, val.length - 1);
      }

      result[key] = val;
    }
    return result;
  }
}

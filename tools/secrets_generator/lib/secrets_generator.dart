import 'dart:io';
import 'dart:math' as math;

class SecretsGenerator {
  final String secretsFileDir;
  final String environment;
  final List<String> assetConfigPaths;
  final List<String> blocklist;
  final List<String> requiredKeys;
  final bool verbose;

  SecretsGenerator({
    required this.secretsFileDir,
    required this.environment,
    required this.assetConfigPaths,
    required this.blocklist,
    required this.requiredKeys,
    required this.verbose,
  });

  /// Runs the full parsing, validation, XOR obfuscation, and returns generated code.
  String generate(String secretsFileContent) {
    // 1. Resolve secrets path and load secrets
    final secretsPath =
        '$secretsFileDir/.env.secrets${environment.isEmpty ? "" : ".$environment"}';
    final secretsFile = File(secretsPath);
    if (!secretsFile.existsSync()) {
      throw FileSystemException(
          'Secrets file not found at "$secretsPath". Please create one.');
    }

    final secretsMap =
        _parseEnvContent(secretsFile.readAsLinesSync(), secretsPath);

    // 2. Validate required keys
    for (final reqKey in requiredKeys) {
      if (!secretsMap.containsKey(reqKey)) {
        throw FormatException(
            'FATAL BUILD ERROR: Required secret key "$reqKey" is missing from "$secretsPath"!');
      }
    }

    // 3. Scan asset-based configs for leaks and conflicts
    final Map<String, String> runtimeKeys = {};
    for (final path in assetConfigPaths) {
      final file = File(path);
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        final parsed = _parseEnvContent(lines, path);

        for (final entry in parsed.entries) {
          runtimeKeys[entry.key] = path;
          // Check for leak blocklists in asset files
          final upperKey = entry.key.toUpperCase();
          for (final pattern in blocklist) {
            if (upperKey.contains(pattern)) {
              print(
                  'WARNING BUILD LOG: Sensitive key pattern "$pattern" detected in non-sensitive asset at "$path" (Key: "${entry.key}").');
            }
          }
        }
      }
    }

    // Check key collision (mutually exclusive verification)
    for (final key in secretsMap.keys) {
      if (runtimeKeys.containsKey(key)) {
        throw FormatException(
            'FATAL BUILD ERROR: Key "$key" overlaps! Found in both secrets file "$secretsPath" '
            'and non-sensitive runtime asset file "${runtimeKeys[key]}".');
      }
    }

    // 4. Generate the source file content using random XOR obfuscation per field
    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln(
        '// Generated dynamically by secrets_generator build-time builder.');
    buffer.writeln(
        '// Zero external dependencies. XOR memory-only transient decryption.');
    buffer.writeln();
    buffer.writeln('class _SecretValues {');
    buffer.writeln('  _SecretValues._();');
    buffer.writeln();

    // Use Random.secure() to ensure maximum entropy and unpredictable keys on each build run.
    final rand = math.Random.secure();

    for (final entry in secretsMap.entries) {
      final fieldName = _toCamelCase(entry.key);
      final rawBytes = entry.value.codeUnits;

      // Generate unique random XOR key of same length
      final xorKey =
          List<int>.generate(rawBytes.length, (_) => rand.nextInt(256));
      final encryptedBytes =
          List<int>.generate(rawBytes.length, (i) => rawBytes[i] ^ xorKey[i]);

      buffer.writeln('  // Secret representation of ${entry.key}');
      buffer.writeln(
          '  static final List<int> _${fieldName}Bytes = $encryptedBytes;');
      buffer.writeln('  static final List<int> _${fieldName}Key = $xorKey;');
      buffer.writeln(
          '  static String get $fieldName => _decrypt(_${fieldName}Bytes, _${fieldName}Key);');
      buffer.writeln();
    }

    // Universal decryption engine
    buffer.writeln(
        '  static String _decrypt(List<int> encrypted, List<int> key) {');
    buffer.writeln('    final length = encrypted.length;');
    buffer.writeln(
        '    final decrypted = List<int>.generate(length, (i) => encrypted[i] ^ key[i]);');
    buffer.writeln('    return String.fromCharCodes(decrypted);');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();

    // Stable dynamic accessor class
    buffer.writeln('/// Stable public accessor class for application secrets.');
    buffer.writeln('class AppSecrets {');
    buffer.writeln('  AppSecrets._();');
    buffer.writeln();
    buffer.writeln('  static final Map<String, String> _secretsMap = {');
    for (final entry in secretsMap.entries) {
      final fieldName = _toCamelCase(entry.key);
      buffer.writeln("    '${entry.key}': _SecretValues.$fieldName,");
    }
    buffer.writeln('  };');
    buffer.writeln();
    buffer.writeln(
        '  /// Retrieves a compiled secret. Throws a descriptive exception if key is missing.');
    buffer.writeln('  static String get(String key) {');
    buffer.writeln('    final value = _secretsMap[key];');
    buffer.writeln('    if (value == null) {');
    buffer.writeln('      throw ArgumentError(');
    buffer.writeln(
        "        'Secret key \"\$key\" was not found in obfuscated build configurations. '");
    buffer.writeln(
        "        'Ensure it is defined in your secrets file and builder is executed.'");
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln('    return value;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
        '  /// Verifies if a secret exists in the generated configuration.');
    buffer.writeln(
        '  static bool contains(String key) => _secretsMap.containsKey(key);');
    buffer.writeln();

    // Predictable named getters
    for (final entry in secretsMap.entries) {
      final getterName = _toCamelCase(entry.key);
      buffer.writeln('  /// Accessor getter for ${entry.key}');
      buffer
          .writeln('  static String get $getterName => get(\'${entry.key}\');');
      buffer.writeln();
    }
    buffer.writeln('}');

    return buffer.toString();
  }

  Map<String, String> _parseEnvContent(List<String> lines, String sourcePath) {
    final result = <String, String>{};
    for (var i = 0; i < lines.length; i++) {
      final lineNum = i + 1;
      var line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final equalsIndex = line.indexOf('=');
      if (equalsIndex == -1) {
        throw FormatException(
            'Malformed env line $lineNum in "$sourcePath": missing "="');
      }

      final key = line.substring(0, equalsIndex).trim();
      if (key.isEmpty) {
        throw FormatException(
            'Malformed env line $lineNum in "$sourcePath": key cannot be empty');
      }

      var valuePart = line.substring(equalsIndex + 1).trim();

      var value = '';
      if (valuePart.startsWith('"')) {
        final closingQuoteIndex = valuePart.indexOf('"', 1);
        if (closingQuoteIndex == -1) {
          throw FormatException(
              'Malformed env line $lineNum in "$sourcePath": unmatched double quote');
        }
        value = valuePart.substring(1, closingQuoteIndex);
      } else if (valuePart.startsWith("'")) {
        final closingQuoteIndex = valuePart.indexOf("'", 1);
        if (closingQuoteIndex == -1) {
          throw FormatException(
              'Malformed env line $lineNum in "$sourcePath": unmatched single quote');
        }
        value = valuePart.substring(1, closingQuoteIndex);
      } else {
        final hashIndex = valuePart.indexOf('#');
        if (hashIndex != -1) {
          value = valuePart.substring(0, hashIndex).trim();
        } else {
          value = valuePart;
        }
      }

      result[key] = value;
    }
    return result;
  }

  String _toCamelCase(String key) {
    final parts = key.toLowerCase().split('_');
    final buffer = StringBuffer(parts[0]);
    for (var i = 1; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      buffer.write(parts[i][0].toUpperCase() + parts[i].substring(1));
    }
    return buffer.toString();
  }
}

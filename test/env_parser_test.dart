import 'package:envified/src/parser/env_file_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helper.dart';

void main() {
  const parser = EnvFileParser();

  group('EnvFileParser.parseString', () {
    test('parses simple key-value pairs', () {
      const input = 'KEY1=VALUE1\nKEY2=VALUE2';
      final result = parser.parseString(input);
      expect(result['KEY1'], 'VALUE1');
      expect(result['KEY2'], 'VALUE2');
    });

    test('ignores comments and blank lines', () {
      const input = '# Comment\n\nKEY=VALUE\n  # Indented comment';
      final result = parser.parseString(input);
      expect(result.length, 1);
      expect(result['KEY'], 'VALUE');
    });

    test('handles quoted values', () {
      const input = 'KEY1="Double quotes"\nKEY2=\'Single quotes\'';
      final result = parser.parseString(input);
      expect(result['KEY1'], 'Double quotes');
      expect(result['KEY2'], 'Single quotes');
    });

    test('strips inline comments', () {
      const input = 'KEY=VALUE # This is a comment';
      final result = parser.parseString(input);
      expect(result['KEY'], 'VALUE');
    });

    test('handles lines without equals sign', () {
      const input = 'INVALID_LINE\nKEY=VALUE';
      final result = parser.parseString(input);
      expect(result.length, 1);
      expect(result['KEY'], 'VALUE');
    });
  });

  group('EnvFileParser.discoverEnvFiles', () {
    test('identifies .env files correctly', () async {
      final assets = [
        'assets/env/.env',
        'assets/env/.env.dev',
        'assets/env/.env.prod',
        'assets/images/logo.png',
        'lib/main.dart',
      ];
      final discovered = await parser.discoverEnvFiles(assets);
      expect(discovered, contains('assets/env/.env'));
      expect(discovered, contains('assets/env/.env.dev'));
      expect(discovered, contains('assets/env/.env.prod'));
      expect(discovered.length, 3);
    });
  });

  group('EnvFileParser.loadAsset', () {
    test('returns null on load failure', () async {
      final bundle = FakeAssetBundle();
      final result = await parser.loadAsset('missing.env', bundle: bundle);
      expect(result, isNull);
    });
  });
}

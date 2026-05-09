import 'package:flutter_test/flutter_test.dart';
import 'package:envified/src/parser/env_file_parser.dart';
import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnvFileParser', () {
    late EnvFileParser parser;
    late FakeAssetBundle bundle;

    setUp(() {
      bundle = FakeAssetBundle();
      parser = const EnvFileParser();
    });

    group('parseString', () {
      test('parses simple KEY=VALUE', () {
        final result = parser.parseString('KEY=VALUE\nFOO=bar');
        expect(result['KEY'], 'VALUE');
        expect(result['FOO'], 'bar');
      });

      test('ignores comments and empty lines', () {
        final result = parser.parseString('''
# This is a comment
KEY=VALUE

  # Another comment
  OTHER=STUFF
''');
        expect(result.length, 2);
        expect(result['KEY'], 'VALUE');
        expect(result['OTHER'], 'STUFF');
      });

      test('handles quoted values', () {
        final result = parser
            .parseString('KEY="VALUE WITH SPACES"\nFOO=\'single quotes\'');
        expect(result['KEY'], 'VALUE WITH SPACES');
        expect(result['FOO'], 'single quotes');
      });

      test('trims whitespace around keys and values', () {
        final result = parser.parseString('  KEY  =  VALUE  ');
        expect(result['KEY'], 'VALUE');
      });
    });

    group('loadAsset', () {
      test('returns null for missing asset file', () async {
        final result = await parser.loadAsset('.env.none', bundle: bundle);
        expect(result, isNull);
      });

      test('loads and parses asset correctly', () async {
        bundle.register('assets/env/.env.test', 'KEY=VALUE');
        final result =
            await parser.loadAsset('assets/env/.env.test', bundle: bundle);
        expect(result?['KEY'], 'VALUE');
      });
    });

    group('computeHash', () {
      test('generates consistent SHA-256 hashes', () {
        const content = 'KEY=VALUE';
        final h1 = parser.computeHash(content);
        final h2 = parser.computeHash(content);
        final h3 = parser.computeHash('OTHER=VALUE');

        expect(h1, equals(h2));
        expect(h1, isNot(equals(h3)));
        expect(h1.length, 64); // Hex length for SHA-256
      });
    });
  });
}

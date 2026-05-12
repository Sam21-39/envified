import 'package:flutter_test/flutter_test.dart';

import 'package:envified/src/parser/env_file_parser.dart';
import 'package:envified/src/models/env.dart';
import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnvFileParser', () {
    late EnvFileParser parser;
    late FakeAssetBundle bundle;

    setUp(() {
      bundle = FakeAssetBundle();
      parser = EnvFileParser();
    });

    // ── parse() via asset bundle ─────────────────────────────────────────────

    test('returns empty map for missing asset file', () async {
      final result = await parser.parse('.env.none', bundle: bundle);
      expect(result, isEmpty);
    });

    test('parses KEY=VALUE correctly', () async {
      bundle.register('.env.test', 'KEY=VALUE\nFOO=bar\n');
      final result = await parser.parse('.env.test', bundle: bundle);
      expect(result['KEY'], 'VALUE');
      expect(result['FOO'], 'bar');
    });

    test('ignores # comment lines', () async {
      bundle.register(
        '.env.test',
        '# Comment\nKEY=VALUE\n',
      );
      final result = await parser.parse('.env.test', bundle: bundle);
      expect(result.containsKey('#'), isFalse);
      expect(result['KEY'], 'VALUE');
    });

    // ── discovery ────────────────────────────────────────────────────────────

    test('discoverAndExtractUrls finds multiple files', () async {
      bundle.register('.env.dev', 'BASE_URL=https://dev.com');
      bundle.register('.env.prod', 'BASE_URL=https://prod.com');
      bundle.register('.env.future', 'BASE_URL=https://future.com');

      final urls = await parser.discoverAndExtractUrls(bundle: bundle);
      expect(urls.length, 3);
      expect(urls[Env.dev], 'https://dev.com');
      expect(urls[Env.prod], 'https://prod.com');
      expect(urls[Env.fromFileName('.env.future')], 'https://future.com');
    });

    test('discoverAndExtractUrls handles .env as production', () async {
      bundle.register('.env', 'BASE_URL=https://root.com');
      final urls = await parser.discoverAndExtractUrls(bundle: bundle);

      expect(urls.length, 1);
      final env = urls.keys.first;
      expect(env.isProduction, isTrue);
      expect(urls[env], 'https://root.com');
    });
  });
}

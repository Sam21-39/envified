import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:envified/src/env_file_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnvFileParser', () {
    late EnvFileParser parser;

    setUp(() {
      parser = EnvFileParser();
    });

    // ── parse() via asset bundle ─────────────────────────────────────────────

    test('returns empty map for missing asset file', () async {
      // No asset registered — rootBundle will throw FlutterError.
      final result = await parser.parse('.env.does_not_exist');
      expect(result, isEmpty);
    });

    test('parses KEY=VALUE correctly from in-memory bundle', () async {
      _registerAsset('.env.test_kv', 'KEY=VALUE\nFOO=bar\n');
      final result = await parser.parse('.env.test_kv');
      expect(result['KEY'], 'VALUE');
      expect(result['FOO'], 'bar');
    });

    test('ignores # comment lines', () async {
      _registerAsset(
        '.env.test_comment',
        '# This is a comment\nKEY=VALUE\n# Another comment\n',
      );
      final result = await parser.parse('.env.test_comment');
      expect(result.containsKey('#'), isFalse);
      expect(result.length, 1);
      expect(result['KEY'], 'VALUE');
    });

    test('strips quotes from "quoted values"', () async {
      _registerAsset('.env.test_quoted', 'QUOTED="hello world"\nPLAIN=world\n');
      final result = await parser.parse('.env.test_quoted');
      expect(result['QUOTED'], 'hello world');
      expect(result['PLAIN'], 'world');
    });

    test('parses KEY= as empty string', () async {
      _registerAsset('.env.test_empty', 'EMPTY=\nKEY=value\n');
      final result = await parser.parse('.env.test_empty');
      expect(result['EMPTY'], '');
      expect(result['KEY'], 'value');
    });

    test('ignores blank lines', () async {
      _registerAsset('.env.test_blank', '\n\nKEY=VALUE\n\n');
      final result = await parser.parse('.env.test_blank');
      expect(result.length, 1);
    });

    test('handles lines without = separator gracefully', () async {
      _registerAsset('.env.test_nosep', 'INVALID\nKEY=VALUE\n');
      final result = await parser.parse('.env.test_nosep');
      expect(result.containsKey('INVALID'), isFalse);
      expect(result['KEY'], 'VALUE');
    });

    test('trims keys and values', () async {
      _registerAsset('.env.test_trim', '  KEY  =  VALUE  \n');
      final result = await parser.parse('.env.test_trim');
      expect(result['KEY'], 'VALUE');
    });

    test('handles values containing equals signs', () async {
      _registerAsset('.env.test_multieq', 'KEY=VALUE=WITH=EQUALS\n');
      final result = await parser.parse('.env.test_multieq');
      expect(result['KEY'], 'VALUE=WITH=EQUALS');
    });

    test('strips single quotes', () async {
      _registerAsset('.env.test_single', "KEY='single quoted'\n");
      final result = await parser.parse('.env.test_single');
      expect(result['KEY'], 'single quoted');
    });

    test('handles UTF-8 characters', () async {
      _registerAsset('.env.test_utf8', 'EMOJI=🌿\nCHINESE=你好\n');
      final result = await parser.parse('.env.test_utf8');
      expect(result['EMOJI'], '🌿');
      expect(result['CHINESE'], '你好');
    });

    // ── merge() ──────────────────────────────────────────────────────────────

    test('merge() returns union of fallback and specific', () {
      final fallback = {'A': '1', 'B': '2'};
      final specific = {'C': '3'};
      final merged = parser.merge(fallback, specific);
      expect(merged, {'A': '1', 'B': '2', 'C': '3'});
    });

    test('merge() specific wins on key conflict', () {
      final fallback = {'BASE_URL': 'https://api.com', 'SHARED': 'yes'};
      final specific = {'BASE_URL': 'https://dev.api.com'};
      final merged = parser.merge(fallback, specific);
      expect(merged['BASE_URL'], 'https://dev.api.com');
      expect(merged['SHARED'], 'yes');
    });

    test('merge() with empty fallback returns specific', () {
      final fallback = <String, String>{};
      final specific = {'KEY': 'val'};
      expect(parser.merge(fallback, specific), {'KEY': 'val'});
    });

    test('merge() with empty specific returns fallback', () {
      final fallback = {'KEY': 'val'};
      final specific = <String, String>{};
      expect(parser.merge(fallback, specific), {'KEY': 'val'});
    });
  });
}

/// Registers [content] as a fake asset at [key] in the root bundle.
void _registerAsset(String key, String content) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final String assetKey = const StringCodec().decodeMessage(message) ?? '';
    if (assetKey == key) {
      return const StringCodec().encodeMessage(content);
    }
    return null;
  });
}

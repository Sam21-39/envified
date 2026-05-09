import 'package:envified/envified.dart';
import 'package:envified/src/parser/env_file_parser.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helper.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};
  @override
  Future<void> write(
      {required String key,
      required String? value,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read(
          {required String key,
          AppleOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          AppleOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      _data[key];
}

void main() {
  group('EnvStatusBadge', () {
    late FakeAssetBundle bundle;
    late EnvStorage storage;

    setUp(() async {
      EnvConfigService.resetInstance();
      storage = EnvStorage(store: FakeFlutterSecureStorage());
      EnvConfigService.overrideForTesting(
        storage: storage,
        parser: const EnvFileParser(),
      );
      bundle = FakeAssetBundle();
      bundle.register('assets/env/.env', 'BASE_URL=https://dev.api.com');
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://api.com');
    });

    testWidgets('renders current environment name', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnvStatusBadge(),
          ),
        ),
      );

      expect(find.text('DEV'), findsOneWidget);
    });

    testWidgets('renders with bolt icon when overridden', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);
      await EnvConfigService.instance.setBaseUrl('https://custom.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnvStatusBadge(),
          ),
        ),
      );

      expect(find.text('⚡ DEV'), findsOneWidget);
    });

    testWidgets('updates when environment changes', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnvStatusBadge(),
          ),
        ),
      );

      expect(find.text('DEV'), findsOneWidget);

      await EnvConfigService.instance.switchTo(Env.prod);
      await tester.pump();

      expect(find.text('PROD'), findsOneWidget);
    });
  });
}

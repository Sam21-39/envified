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
  group('EnvDebugPanel', () {
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
      bundle.register('assets/env/.env',
          'BASE_URL=https://dev.api.com\nAPI_KEY=secret_123');
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://api.com');
    });

    testWidgets('renders sections correctly', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EnvDebugPanel()),
          ),
        ),
      );

      expect(find.text('ACTIVE ENVIRONMENT'), findsOneWidget);
      expect(find.text('API ENDPOINT'), findsOneWidget);
      expect(find.text('CONFIGURATION'), findsOneWidget);
      expect(find.text('API_KEY'), findsOneWidget);
    });

    testWidgets('reveals sensitive values on tap', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EnvDebugPanel()),
          ),
        ),
      );

      expect(find.text('••••••••••••••••'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.text('secret_123'), findsOneWidget);
    });

    testWidgets('switches environment on chip selection', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EnvDebugPanel()),
          ),
        ),
      );

      await tester.tap(find.text('Prod'));
      await tester.pumpAndSettle();

      expect(EnvConfigService.instance.current.value.env, Env.prod);
    });
  });
}

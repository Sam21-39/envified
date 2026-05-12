import 'package:envified/envified.dart';
import 'package:envified/src/parser/env_file_parser.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helper.dart';

void main() {
  group('EnvDebugPanel', () {
    late FakeAssetBundle bundle;
    late EnvStorage storage;

    setUp(() async {
      EnvConfigService.resetInstance();
      storage = EnvStorage(storage: FakeFlutterSecureStorage());
      EnvConfigService.overrideForTesting(
        storage: storage,
        parser: EnvFileParser(),
      );
      bundle = FakeAssetBundle();
      bundle.register('assets/env/.env',
          'BASE_URL=https://dev.api.com\nAPI_KEY=secret_123');
      bundle.register('assets/env/.env.prod', 'BASE_URL=https://api.com');
    });

    testWidgets('renders sections correctly', (tester) async {
      await EnvConfigService.instance.init(
        bundle: bundle,
        autoDiscover: false,
        urls: {
          Env.dev: 'https://dev.api.com',
          Env.prod: 'https://api.com',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EnvDebugPanel(
                service: EnvConfigService.instance,
                showEnvKeys: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE ENVIRONMENT'), findsOneWidget);
      expect(find.text('API ENDPOINT'), findsOneWidget);
      expect(find.text('CONFIGURATION'), findsOneWidget);

      // ExpansionTile is collapsed by default, must expand to see keys
      await tester.tap(find.text('CONFIGURATION'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('API_KEY'), findsOneWidget);
    });

    testWidgets('reveals sensitive values on tap', (tester) async {
      await EnvConfigService.instance.init(
        bundle: bundle,
        autoDiscover: false,
        urls: {
          Env.dev: 'https://dev.api.com',
          Env.prod: 'https://api.com',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EnvDebugPanel(
                service: EnvConfigService.instance,
                showEnvKeys: true,
              ),
            ),
          ),
        ),
      );

      // ExpansionTile is collapsed by default, must expand to see keys
      await tester.tap(find.text('CONFIGURATION'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('••••••••••••••••'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.text('secret_123'), findsOneWidget);
    });

    testWidgets('switches environment on chip selection', (tester) async {
      await EnvConfigService.instance.init(
        bundle: bundle,
        autoDiscover: false,
        urls: {
          Env.dev: 'https://dev.api.com',
          Env.prod: 'https://api.com',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
                child: EnvDebugPanel(
              service: EnvConfigService.instance,
              showEnvKeys: true,
            )),
          ),
        ),
      );

      await tester.tap(find.text('Prod'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(EnvConfigService.instance.current.value.env, Env.prod);
    });
  });
}

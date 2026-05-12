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
      bundle.register(
        '.env',
        'BASE_URL=https://dev.api.com\nAPI_KEY=secret_123',
      );
      bundle.register('.env.prod', 'BASE_URL=https://api.com');

      // Init once per test — not inside each testWidgets
      await EnvConfigService.instance.init(
        bundle: bundle,
        autoDiscover: false,
        allowProdSwitch: true,
        urls: {
          Env.dev: 'https://dev.api.com',
          Env.prod: 'https://api.com',
        },
      );
    });

    tearDown(() {
      EnvConfigService.resetInstance();
    });

    Widget buildPanel() => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EnvDebugPanel(
                service: EnvConfigService.instance,
                showEnvKeys: true,
              ),
            ),
          ),
        );

    Future<void> ensureConfigurationExpanded(WidgetTester tester) async {
      // Configuration is expanded by default in EnvDebugPanel (_kvExpanded = false now).
      // We check for masked key '••••••••' which is API_KEY.
      if (find.text('••••••••').evaluate().isEmpty) {
        await tester.tap(find.text('CONFIGURATION'));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('renders sections correctly', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump(); // single frame to build

      expect(find.text('ACTIVE ENVIRONMENT'), findsOneWidget);
      expect(find.text('API ENDPOINT'), findsOneWidget);
      expect(find.text('CONFIGURATION'), findsOneWidget);

      await ensureConfigurationExpanded(tester);

      // API_KEY is sensitive, so it should be masked
      expect(find.text('••••••••'), findsOneWidget);
      expect(find.text('API_KEY'), findsNothing);
    });

    testWidgets('reveals sensitive values on tap', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await ensureConfigurationExpanded(tester);

      // Initially masked
      expect(find.text('••••••••'), findsOneWidget);
      expect(find.text('Tap to reveal & copy'), findsOneWidget);

      // Tap the row (the masked key) to reveal
      await tester.tap(find.text('••••••••'));
      await tester.pump();

      // Now revealed
      expect(find.text('API_KEY'), findsOneWidget);
      expect(find.text('secret_123'), findsOneWidget);
      expect(find.byIcon(Icons.copy),
          findsNWidgets(2)); // One for BASE_URL, one for API_KEY
      expect(find.text('Tap to reveal & copy'), findsNothing);
    });

    testWidgets('switches environment on chip selection', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.tap(find.text('Production'));
      await tester.pump(); // Show confirmation dialog

      expect(find.text('Confirm Switch'), findsOneWidget);
      await tester.tap(find.text('Confirm Switch'));

      // env switch is async — give it a moment then pump
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(); // rebuild

      expect(EnvConfigService.instance.current.value.env, Env.prod);
    });
  });
}

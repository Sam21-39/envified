import 'package:envified/envified.dart';
import 'package:envified/src/parser/env_file_parser.dart';
import 'package:envified/src/storage/env_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helper.dart';

void main() {
  group('EnvifiedOverlay', () {
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

    testWidgets('shows status badge by default', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: EnvifiedOverlay(
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      );

      expect(find.byType(EnvStatusBadge), findsOneWidget);
      expect(find.text('DEV'), findsOneWidget);
    });

    testWidgets('opens panel on trigger', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: EnvifiedOverlay(
            trigger: EnvTrigger.doubleTap(),
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      );

      // Verify panel is hidden
      expect(find.byType(EnvDebugPanel), findsNothing);

      // Double tap to open
      final overlay = find.byType(EnvifiedOverlay);
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(overlay);
      await tester.pumpAndSettle();

      expect(find.byType(EnvDebugPanel), findsOneWidget);
    });

    testWidgets('requires PIN when gate is provided', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        MaterialApp(
          home: EnvifiedOverlay(
            trigger:
                const EnvTrigger.tap(count: 1), // Single tap for easy testing
            gate: EnvGate(pin: '1234'),
            child: const Scaffold(body: Text('App Content')),
          ),
        ),
      );

      // Open panel
      await tester.tap(find.text('DEV'));
      await tester.pumpAndSettle();

      // Should show PIN input
      expect(find.text('Enter PIN'), findsOneWidget);

      // Enter wrong PIN
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('VERIFY'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid PIN'), findsOneWidget);

      // Enter correct PIN
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('VERIFY'));
      await tester.pumpAndSettle();

      // Should now show debug panel
      expect(find.byType(EnvDebugPanel), findsOneWidget);
    });

    testWidgets('respects enabled flag', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: EnvifiedOverlay(
            enabled: false,
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      );

      expect(find.byType(EnvStatusBadge), findsNothing);
    });
  });
}

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
    });

    testWidgets('renders child content', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: EnvifiedOverlay(
            child: Text('App Content'),
          ),
        ),
      );

      expect(find.text('App Content'), findsOneWidget);
    });

    testWidgets('shows fab and opens panel on tap', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: EnvifiedOverlay(
            child: Text('App Content'),
          ),
        ),
      );

      expect(find.text('🌿'), findsOneWidget);

      await tester.tap(find.text('🌿'));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE ENVIRONMENT'), findsOneWidget);
    });

    testWidgets('requires pin if gate is provided', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        MaterialApp(
          home: EnvifiedOverlay(
            gate: EnvGate(pin: '1234'),
            child: const Text('App Content'),
          ),
        ),
      );

      await tester.tap(find.text('🌿'));
      await tester.pumpAndSettle();

      expect(find.text('Enter PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE ENVIRONMENT'), findsOneWidget);
    });

    testWidgets('does nothing if disabled', (tester) async {
      await EnvConfigService.instance.init(bundle: bundle);

      await tester.pumpWidget(
        const MaterialApp(
          home: EnvifiedOverlay(
            enabled: false,
            child: Text('App Content'),
          ),
        ),
      );

      expect(find.text('🌿'), findsNothing);
    });
  });
}

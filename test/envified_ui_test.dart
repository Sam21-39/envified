import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:envified/envified.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await EnvConfigService.instance.init(
      urls: {
        Env.dev: 'http://dev',
        Env.prod: 'http://prod',
      },
      defaultEnv: Env.dev,
    );
  });

  testWidgets('EnvifiedScope rebuilds on env change', (tester) async {
    await tester.pumpWidget(
      EnvifiedScope(
        service: EnvConfigService.instance,
        builder: (context, config) {
          return MaterialApp(
            home: Scaffold(
              body: Text('Current: ${config.env.name}'),
            ),
          );
        },
      ),
    );

    expect(find.text('Current: dev'), findsOneWidget);

    await EnvConfigService.instance.switchTo(Env.prod);
    await tester.pumpAndSettle();

    expect(find.text('Current: prod'), findsOneWidget);
  });

  testWidgets('EnvifiedOverlay shows correctly based on env', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EnvifiedOverlay(
          service: EnvConfigService.instance,
          child: const Scaffold(body: Text('App Body')),
        ),
      ),
    );

    // Should be visible in dev
    expect(find.byType(SvgPicture), findsOneWidget);

    // Switch to prod
    await EnvConfigService.instance.switchTo(Env.prod);
    await tester.pumpAndSettle();

    // Should be hidden in prod
    expect(find.byType(SvgPicture), findsNothing);
  });
}

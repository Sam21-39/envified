import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';
import 'package:envified/src/ui/env_trigger.dart';

class MockShakeDetector implements EnvTriggerDetector {
  bool isStarted = false;
  double? threshold;
  VoidCallback? onTrigger;

  @override
  void start(double threshold, VoidCallback onTrigger) {
    isStarted = true;
    this.threshold = threshold;
    this.onTrigger = onTrigger;
  }

  @override
  void stop() {
    isStarted = false;
  }

  void trigger() {
    onTrigger?.call();
  }
}

void main() {
  group('EnvTrigger', () {
    testWidgets('ShakeTrigger calls start/stop on detector', (tester) async {
      final detector = MockShakeDetector();
      bool opened = false;

      final trigger = EnvTrigger.shake(
        threshold: 20.0,
        detector: detector,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: trigger.build(
              child: const Text('Content'),
              onOpen: () => opened = true,
              isActive: true,
            ),
          ),
        ),
      );

      expect(detector.isStarted, isTrue);
      expect(detector.threshold, 20.0);

      detector.trigger();
      expect(opened, isTrue);

      // Rebuild with isActive = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: trigger.build(
              child: const Text('Content'),
              onOpen: () => opened = true,
              isActive: false,
            ),
          ),
        ),
      );

      expect(detector.isStarted, isFalse);
    });

    testWidgets('TapTrigger detects multiple taps', (tester) async {
      bool opened = false;
      const trigger = EnvTrigger.tap(count: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: trigger.build(
              child: const Text('Tap Me'),
              onOpen: () => opened = true,
              isActive: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      expect(opened, isFalse);

      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      expect(opened, isFalse);

      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      expect(opened, isTrue);
    });
  });
}

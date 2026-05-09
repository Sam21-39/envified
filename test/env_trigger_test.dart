import 'package:envified/src/triggers/env_trigger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockShakeDetector implements EnvShakeDetector {
  bool started = false;
  bool stopped = false;
  double? threshold;

  @override
  void start(double threshold, VoidCallback onShake) {
    started = true;
    this.threshold = threshold;
  }

  @override
  void stop() {
    stopped = true;
  }
}

void main() {
  group('TapTrigger', () {
    testWidgets('triggers onOpen after required taps', (tester) async {
      int triggerCount = 0;
      const trigger = EnvTrigger.tap(count: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: trigger.build(
              child: const Text('Tap me'),
              onOpen: () => triggerCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(triggerCount, 0);

      await tester.tap(find.text('Tap me'));
      expect(triggerCount, 0);

      await tester.tap(find.text('Tap me'));
      expect(triggerCount, 1);
    });

    testWidgets('does not trigger if disabled', (tester) async {
      int triggerCount = 0;
      const trigger = EnvTrigger.tap(count: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: trigger.build(
              child: const Text('Tap me'),
              onOpen: () => triggerCount++,
              isActive: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(triggerCount, 0);
    });
  });

  group('ShakeTrigger', () {
    testWidgets('starts and stops detector on lifecycle', (tester) async {
      final detector = MockShakeDetector();
      final trigger = EnvTrigger.shake(detector: detector);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: trigger.build(
              child: const Text('Shake me'),
              onOpen: () {},
            ),
          ),
        ),
      );

      expect(detector.started, isTrue);
      expect(detector.threshold, 15.0);

      await tester.pumpWidget(const SizedBox());
      expect(detector.stopped, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';

void main() {
  group('AuditEntry serialization', () {
    test('roundtrip with env switch', () {
      final DateTime ts = DateTime.utc(2026, 5, 7, 10, 30);
      final original = AuditEntry(
        timestamp: ts,
        action: AuditAction.envSwitch,
        fromEnv: Env.dev,
        toEnv: Env.staging,
      );

      final json = original.toJson();
      final restored = AuditEntry.fromJson(json);

      expect(restored.timestamp, ts);
      expect(restored.action, AuditAction.envSwitch);
      expect(restored.fromEnv, Env.dev);
      expect(restored.toEnv, Env.staging);
    });

    test('roundtrip with url override', () {
      final DateTime ts = DateTime.utc(2026, 5, 7, 11);
      final original = AuditEntry(
        timestamp: ts,
        action: AuditAction.urlOverride,
        url: 'https://custom.api.com',
      );

      final json = original.toJson();
      final restored = AuditEntry.fromJson(json);

      expect(restored.action, AuditAction.urlOverride);
      expect(restored.url, 'https://custom.api.com');
    });

    test('toJson excludes null fields', () {
      final entry = AuditEntry(
        timestamp: DateTime.utc(2026, 5, 7),
        action: AuditAction.reset,
      );

      final json = entry.toJson();

      expect(json.containsKey('fromEnv'), isFalse);
      expect(json.containsKey('toEnv'), isFalse);
      expect(json.containsKey('url'), isFalse);
    });

    test('value equality', () {
      final ts = DateTime.utc(2026, 5, 7);
      final a = AuditEntry(timestamp: ts, action: AuditAction.reset);
      final b = AuditEntry(timestamp: ts, action: AuditAction.reset);
      final c = AuditEntry(timestamp: ts, action: AuditAction.urlReset);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:envified/envified.dart';

void main() {
  group('AuditEntry toJson / fromJson roundtrip', () {
    test('roundtrip with all fields', () {
      final DateTime ts = DateTime.utc(2026, 5, 7, 10, 30, 0);
      final AuditEntry original = AuditEntry(
        timestamp: ts,
        action: 'switch',
        fromEnv: 'dev',
        toEnv: 'staging',
        url: null,
      );

      final Map<String, dynamic> json = original.toJson();
      final AuditEntry restored = AuditEntry.fromJson(json);

      expect(restored.timestamp, ts);
      expect(restored.action, 'switch');
      expect(restored.fromEnv, 'dev');
      expect(restored.toEnv, 'staging');
      expect(restored.url, isNull);
    });

    test('roundtrip with url field', () {
      final DateTime ts = DateTime.utc(2026, 5, 7, 11, 0, 0);
      final AuditEntry original = AuditEntry(
        timestamp: ts,
        action: 'setBaseUrl',
        url: 'https://custom.api.com',
      );

      final Map<String, dynamic> json = original.toJson();
      final AuditEntry restored = AuditEntry.fromJson(json);

      expect(restored.timestamp, ts);
      expect(restored.action, 'setBaseUrl');
      expect(restored.url, 'https://custom.api.com');
      expect(restored.fromEnv, isNull);
      expect(restored.toEnv, isNull);
    });

    test('roundtrip for clearOverride action', () {
      final DateTime ts = DateTime.utc(2026, 5, 7, 12, 0, 0);
      final AuditEntry original = AuditEntry(
        timestamp: ts,
        action: 'clearOverride',
      );

      final Map<String, dynamic> json = original.toJson();
      final AuditEntry restored = AuditEntry.fromJson(json);

      expect(restored.action, 'clearOverride');
      expect(restored.fromEnv, isNull);
      expect(restored.toEnv, isNull);
      expect(restored.url, isNull);
    });

    test('roundtrip for reset action', () {
      final DateTime ts = DateTime.utc(2026, 5, 7, 13, 0, 0);
      final AuditEntry original = AuditEntry(
        timestamp: ts,
        action: 'reset',
      );

      final Map<String, dynamic> json = original.toJson();
      final AuditEntry restored = AuditEntry.fromJson(json);

      expect(restored.action, 'reset');
    });

    test('toJson does not include null fields', () {
      final AuditEntry entry = AuditEntry(
        timestamp: DateTime.utc(2026, 5, 7),
        action: 'reset',
      );

      final Map<String, dynamic> json = entry.toJson();

      expect(json.containsKey('fromEnv'), isFalse);
      expect(json.containsKey('toEnv'), isFalse);
      expect(json.containsKey('url'), isFalse);
    });

    test('toJsonString / fromJsonString roundtrip', () {
      final AuditEntry original = AuditEntry(
        timestamp: DateTime.utc(2026, 5, 7, 10, 0, 0),
        action: 'switch',
        fromEnv: 'dev',
        toEnv: 'prod',
      );

      final String jsonStr = original.toJsonString();
      final AuditEntry restored = AuditEntry.fromJsonString(jsonStr);

      expect(restored.action, original.action);
      expect(restored.fromEnv, original.fromEnv);
      expect(restored.toEnv, original.toEnv);
      expect(restored.timestamp, original.timestamp);
    });

    test('fromJsonString throws FormatException for invalid JSON', () {
      expect(
        () => AuditEntry.fromJsonString('not-json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('toString contains all non-null fields', () {
      final AuditEntry entry = AuditEntry(
        timestamp: DateTime.utc(2026, 5, 7),
        action: 'switch',
        fromEnv: 'dev',
        toEnv: 'staging',
      );
      final String str = entry.toString();
      expect(str, contains('switch'));
      expect(str, contains('dev'));
      expect(str, contains('staging'));
    });
  });

  group('formatAuditTimestamp', () {
    test('formats DateTime as MM-dd-YYYY HH:mm:ss', () {
      final dt = DateTime(2026, 5, 11, 14, 35, 7);
      expect(formatAuditTimestamp(dt), '05-11-2026 14:35:07');
    });
  });
}

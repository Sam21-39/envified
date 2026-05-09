import 'package:envified/src/models/audit_entry.dart';
import 'package:envified/src/models/env.dart';
import 'package:envified/src/ui/audit_log_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditLogViewer', () {
    testWidgets('renders empty state message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuditLogViewer(entries: []),
          ),
        ),
      );

      expect(find.text('No audit history yet.'), findsOneWidget);
    });

    testWidgets('renders audit entries correctly', (tester) async {
      final entries = [
        AuditEntry(
          action: AuditAction.envSwitch,
          fromEnv: Env.dev,
          toEnv: Env.prod,
          timestamp: DateTime(2024, 1, 1, 12),
        ),
        AuditEntry(
          action: AuditAction.urlOverride,
          url: 'https://custom.com',
          timestamp: DateTime(2024, 1, 1, 12, 5),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogViewer(entries: entries),
          ),
        ),
      );

      expect(find.text('Env: dev → prod'), findsOneWidget);
      expect(find.text('URL Override Set'), findsOneWidget);
    });
  });
}

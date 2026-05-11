import 'package:flutter/material.dart';
import '../models/audit_entry.dart';

/// A styled viewer for audit log entries.
class AuditLogViewer extends StatelessWidget {
  /// The list of audit entries to display.
  final List<AuditEntry> entries;

  const AuditLogViewer({
    required this.entries,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No audit history yet.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isLast = index == entries.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // ignore: deprecated_member_use
                        color: _actionColor(entry.action).withOpacity(0.15),
                      ),
                      child: Icon(
                        _actionIcon(entry.action),
                        size: 14,
                        color: _actionColor(entry.action),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          // ignore: deprecated_member_use
                          color: Colors.grey.withOpacity(0.2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _actionLabel(entry),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            formatAuditTimestamp(entry.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      if (entry.url != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            entry.url!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _actionColor(AuditAction action) => switch (action) {
        AuditAction.envSwitch => Colors.blue,
        AuditAction.urlOverride => Colors.amber,
        AuditAction.urlReset => Colors.purple,
        AuditAction.reset => Colors.red,
      };

  IconData _actionIcon(AuditAction action) => switch (action) {
        AuditAction.envSwitch => Icons.swap_horiz,
        AuditAction.urlOverride => Icons.edit,
        AuditAction.urlReset => Icons.clear,
        AuditAction.reset => Icons.restart_alt,
      };

  String _actionLabel(AuditEntry entry) => switch (entry.action) {
        AuditAction.envSwitch =>
          'Env: ${entry.fromEnv?.name ?? '?'} → ${entry.toEnv?.name ?? '?'}',
        AuditAction.urlOverride => 'URL Override Set',
        AuditAction.urlReset => 'Override Cleared',
        AuditAction.reset => 'Configuration Reset',
      };
}

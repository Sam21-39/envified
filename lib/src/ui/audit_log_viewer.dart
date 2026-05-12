import 'package:flutter/material.dart';
import '../models/audit_entry.dart';

/// A styled viewer for audit log entries.
class AuditLogViewer extends StatelessWidget {
  /// The list of audit entries to display.
  final List<AuditEntry> entries;

  /// Creates an [AuditLogViewer].
  const AuditLogViewer({super.key, required this.entries});

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < entries.length; i++)
          _buildItem(context, entries[i], i == entries.length - 1),
      ],
    );
  }

  Widget _buildItem(BuildContext context, AuditEntry entry, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line and icon
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
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
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action details
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
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

  Color _actionColor(String action) => switch (action) {
        'switch' => Colors.blue,
        'setBaseUrl' => Colors.amber,
        'clearOverride' => Colors.purple,
        'reset' => Colors.red,
        _ => Colors.grey,
      };

  IconData _actionIcon(String action) => switch (action) {
        'switch' => Icons.swap_horiz,
        'setBaseUrl' => Icons.edit,
        'clearOverride' => Icons.clear,
        'reset' => Icons.restart_alt,
        _ => Icons.info_outline,
      };

  String _actionLabel(AuditEntry entry) => switch (entry.action) {
        'switch' => 'Env: ${entry.fromEnv} → ${entry.toEnv}',
        'setBaseUrl' => 'URL Override Set',
        'clearOverride' => 'Override Cleared',
        'reset' => 'Configuration Reset',
        _ => entry.action,
      };
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audit_entry.dart';
import '../env_config_service.dart';
import '../env_model.dart';
import '../envified_exception.dart';

/// A self-contained debug panel widget for inspecting and modifying the active
/// environment configuration at runtime.
class EnvDebugPanel extends StatefulWidget {
  /// The [EnvConfigService] instance this panel reads from and writes to.
  final EnvConfigService service;

  /// Optional callback invoked when the user taps "Apply & Restart".
  final VoidCallback? onApply;

  /// Creates an [EnvDebugPanel].
  const EnvDebugPanel({
    super.key,
    required this.service,
    this.onApply,
  });

  @override
  State<EnvDebugPanel> createState() => _EnvDebugPanelState();
}

class _EnvDebugPanelState extends State<EnvDebugPanel> {
  final TextEditingController _urlController = TextEditingController();
  bool _kvExpanded = false;
  bool _auditExpanded = false;
  String? _errorMessage;
  String _configSearchQuery = '';
  bool _showNewConfig = true;
  Env? _pendingEnv;

  List<String> _urlHistory = <String>[];
  List<AuditEntry> _auditEntries = <AuditEntry>[];

  EnvConfigService get _svc => widget.service;

  @override
  void initState() {
    super.initState();
    _svc.current.addListener(_onConfigChanged);
    _syncUrlController();
    _loadHistory();
    _loadAudit();
  }

  @override
  void dispose() {
    _svc.current.removeListener(_onConfigChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) {
      setState(() {
        _syncUrlController();
        _errorMessage = null;
      });
      _loadHistory();
      _loadAudit();
    }
  }

  void _syncUrlController() {
    final config = _svc.current.value;
    if (config.isBaseUrlOverridden) {
      _urlController.text = config.baseUrl;
    } else {
      _urlController.text = '';
    }
  }

  Future<void> _loadHistory() async {
    final List<String> history = await _svc.urlHistory;
    if (mounted) setState(() => _urlHistory = history);
  }

  Future<void> _loadAudit() async {
    final List<AuditEntry> entries = await _svc.auditLog;
    if (mounted) {
      setState(() => _auditEntries = entries.take(10).toList());
    }
  }

  Future<void> _switchEnv(Env env) async {
    if (env.isProduction && !_svc.allowProdSwitch) {
      // If we have a navigator, use showDialog (nicer UX)
      // Otherwise, use inline confirmation.
      final hasNavigator = Navigator.maybeOf(context) != null;
      if (hasNavigator) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Switch to ${env.label}?'),
            content: const Text(
              'This will use the production API. Are you sure you want to proceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade900),
                child: const Text('Switch'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      } else {
        // No Navigator (likely in a root overlay). Use inline confirmation.
        setState(() => _pendingEnv = env);
        return;
      }
    }

    await _performSwitch(env);
  }

  Future<void> _performSwitch(Env env) async {
    try {
      setState(() {
        _showNewConfig = false;
        _pendingEnv = null;
      });
      await _svc.switchTo(env);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _showNewConfig = true;
        });
      }
    } on EnvifiedLockException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _showNewConfig = true;
        });
      }
    }
    await _loadAudit();
  }

  Future<void> _applyUrlOverride() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    try {
      await _svc.setBaseUrl(url);
      if (mounted) setState(() => _errorMessage = null);
    } on EnvifiedLockException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } on EnvifiedUrlNotAllowedException catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
    await _loadHistory();
    await _loadAudit();
  }

  Future<void> _applyHistoryUrl(String url) async {
    _urlController.text = url;
    try {
      await _svc.setBaseUrl(url);
      if (mounted) setState(() => _errorMessage = null);
    } on EnvifiedLockException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } on EnvifiedUrlNotAllowedException catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
    await _loadHistory();
    await _loadAudit();
  }

  Future<void> _clearOverride() async {
    try {
      await _svc.clearBaseUrlOverride();
      if (mounted) setState(() => _errorMessage = null);
    } on EnvifiedLockException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
    await _loadAudit();
  }

  Future<void> _reset() async {
    await _svc.reset();
    if (mounted) setState(() => _errorMessage = null);
    await _loadHistory();
    await _loadAudit();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: _svc.current,
      builder: (context, config, _) {
        final bool locked = _svc.isProdLocked;
        const Color lockColor = Color(0xFFFF6B6B);
        final ThemeData theme = Theme.of(context);
        final ColorScheme cs = theme.colorScheme;

        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showNewConfig
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 400),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              _buildHeader(config, locked, lockColor, cs),

              const SizedBox(height: 16),

              // ── Env switcher ──────────────────────────────────────────────
              if (_pendingEnv != null)
                _buildConfirmSwitch(_pendingEnv!, cs)
              else
                _buildEnvSwitcher(config, locked, cs),

              const SizedBox(height: 20),

              // ── BASE_URL (from .env file) ─────────────────────────────────
              _buildEnvBaseUrlLabel(config, cs),

              const SizedBox(height: 16),

              // ── URL override ──────────────────────────────────────────────
              _buildUrlOverrideField(config, locked),

              // ── URL History chips ─────────────────────────────────────────
              if (_urlHistory.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildUrlHistory(locked, cs),
              ],

              if (config.isBaseUrlOverridden) ...[
                const SizedBox(height: 8),
                _buildClearOverrideButton(locked),
              ],

              // ── Error message ─────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                _buildErrorBanner(_errorMessage!),
              ],

              const SizedBox(height: 20),
              const Divider(),

              // ── Key-value table ───────────────────────────────────────────
              _buildKvTable(config, cs),

              const Divider(),

              // ── Activity log ─────────────────────────────────────────────────
              _buildAuditLog(cs),

              const Divider(),
              const SizedBox(height: 8),

              // ── Action buttons ────────────────────────────────────────────
              _buildActionRow(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    EnvConfig config,
    bool locked,
    Color lockColor,
    ColorScheme cs,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _envColor(config.env).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _envColor(config.env), width: 1.5),
          ),
          child: Text(
            config.env.label,
            style: TextStyle(
              color: _envColor(config.env),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        if (locked) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Locked in production',
            child: Icon(Icons.lock, color: lockColor, size: 18),
          ),
        ],
        const Spacer(),
        Text(
          '🌿 envified',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvSwitcher(
    EnvConfig config,
    bool locked,
    ColorScheme cs,
  ) {
    final List<Env> available = _svc.availableEnvs;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: available.map((e) {
          final isSelected = config.env.name == e.name;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.label),
                  if (e.isProduction && !_svc.allowProdSwitch)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock, size: 12),
                    ),
                ],
              ),
              selected: isSelected,
              onSelected: locked ? null : (_) => _switchEnv(e),
              selectedColor: _envColor(e).withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? _envColor(e) : cs.onSurface,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
              side: BorderSide(
                color: isSelected ? _envColor(e) : cs.outlineVariant,
              ),
              showCheckmark: false,
              tooltip: locked ? 'Locked in production' : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConfirmSwitch(Env env, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Switch to ${env.label}?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This will use the production API.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _pendingEnv = null),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _performSwitch(env),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade900),
                child: const Text('Confirm Switch'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvBaseUrlLabel(EnvConfig config, ColorScheme cs) {
    final fileUrl = config.values['BASE_URL'] ?? '(not set)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BASE_URL from ${config.env.assetFileName}',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withOpacity(0.55),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                fileUrl,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.8),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: fileUrl));
                // ignore: deprecated_member_use
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (messenger != null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('URL copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_all, size: 16),
              tooltip: 'Copy to clipboard',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUrlOverrideField(EnvConfig config, bool locked) {
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: locked ? 'Locked in production' : '',
            child: TextField(
              controller: _urlController,
              enabled: !locked,
              decoration: InputDecoration(
                labelText: 'Override base URL',
                hintText: 'https://custom.api.example.com',
                prefixIcon: const Icon(Icons.link, size: 18),
                suffixIcon: config.isBaseUrlOverridden
                    ? Tooltip(
                        message: 'Override active',
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade400,
                          size: 18,
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: locked ? null : (_) => _applyUrlOverride(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: locked ? 'Locked in production' : 'Apply override',
          child: IconButton.filled(
            onPressed: locked ? null : _applyUrlOverride,
            icon: const Icon(Icons.check, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildUrlHistory(bool locked, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.45),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _urlHistory.map((url) {
            final String truncated =
                url.length > 35 ? '${url.substring(0, 35)}…' : url;
            return ActionChip(
              label: Text(
                truncated,
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: locked ? null : () => _applyHistoryUrl(url),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildClearOverrideButton(bool locked) {
    return Tooltip(
      message: locked ? 'Locked in production' : 'Restore .env value',
      child: TextButton.icon(
        onPressed: locked ? null : _clearOverride,
        icon: const Icon(Icons.undo, size: 16),
        label: const Text('Clear override'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKvTable(EnvConfig config, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _kvExpanded = !_kvExpanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _kvExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: cs.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'All values (${config.values.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_kvExpanded)
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    onChanged: (v) => setState(() => _configSearchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search keys...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                ...config.values.entries
                    .where((e) => e.key
                        .toLowerCase()
                        .contains(_configSearchQuery.toLowerCase()))
                    .map((entry) {
                  return _buildKvRow(entry.key, entry.value, cs);
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildKvRow(String key, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SelectableText(
              key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLog(ColorScheme cs) {
    final int count = _auditEntries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() => _auditExpanded = !_auditExpanded);
            if (_auditExpanded) _loadAudit();
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _auditExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: cs.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Activity log ($count entries)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_auditExpanded)
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _auditEntries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No activity recorded yet.',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : Column(
                    children: _auditEntries
                        .map((entry) => _buildAuditRow(entry, cs))
                        .toList(),
                  ),
          ),
      ],
    );
  }

  Widget _buildAuditRow(AuditEntry entry, ColorScheme cs) {
    final String time =
        '${entry.timestamp.toLocal().hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.toLocal().minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.toLocal().second.toString().padLeft(2, '0')}';

    final String detail = switch (entry.action) {
      'switch' => '${entry.fromEnv ?? '?'} → ${entry.toEnv ?? '?'}',
      'setBaseUrl' => entry.url ?? '',
      'clearOverride' => 'URL override cleared',
      'reset' => 'Service reset',
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: cs.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(width: 10),
          Chip(
            label: Text(
              entry.action,
              style: const TextStyle(fontSize: 10),
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.75),
                fontFamily: 'monospace',
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        ),
        if (widget.onApply != null)
          FilledButton.icon(
            onPressed: widget.onApply,
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Apply & Restart'),
          ),
      ],
    );
  }

  Color _envColor(Env env) {
    if (env.isProduction) return Colors.red.shade700;
    switch (env.name) {
      case 'dev':
        return Colors.blue.shade700;
      case 'staging':
        return Colors.orange.shade700;
      case 'uat':
        return Colors.purple.shade700;
      case 'future':
        return Colors.teal.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }
}

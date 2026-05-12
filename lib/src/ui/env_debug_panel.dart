import 'dart:async';
import 'dart:convert';
import 'package:envified/envified.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audit_log_viewer.dart';

/// A self-contained debug panel widget for inspecting and modifying the active
/// environment configuration at runtime.
class EnvDebugPanel extends StatefulWidget {
  /// The [EnvConfigService] instance this panel reads from and writes to.
  final EnvConfigService service;

  /// Optional callback invoked when the user taps "Restart app to apply changes".
  final VoidCallback? onRestart;
  final bool showEnvKeys;

  /// Creates an [EnvDebugPanel].
  const EnvDebugPanel({
    super.key,
    required this.service,
    this.onRestart,
    required this.showEnvKeys,
  });

  @override
  State<EnvDebugPanel> createState() => _EnvDebugPanelState();
}

class _EnvDebugPanelState extends State<EnvDebugPanel> {
  final TextEditingController _urlController = TextEditingController();
  bool _kvExpanded = true;
  bool _auditExpanded = false;
  String? _errorMessage;
  String _configSearchQuery = '';
  bool _showNewConfig = true;
  bool _showResetConfirm = false;
  Env? _pendingEnv;

  List<String> _urlHistory = <String>[];

  EnvConfigService get _svc => widget.service;

  @override
  void initState() {
    super.initState();
    _svc.current.addListener(_onConfigChanged);
    _syncUrlController();
    _loadHistory();
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

  Future<void> _switchEnv(Env env) async {
    if (env.isProduction && !_svc.current.value.env.isProduction) {
      if (mounted) setState(() => _pendingEnv = env);
      return;
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
  }

  Future<void> _applyUrlOverride(String url) async {
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
  }

  Future<void> _clearOverride() async {
    try {
      await _svc.clearBaseUrlOverride();
      if (mounted) setState(() => _errorMessage = null);
    } on EnvifiedLockException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
  }

  Future<void> _reset() async {
    await _svc.reset();
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _showResetConfirm = false;
      });
    }
    await _loadHistory();
  }

  void _copyAllConfig() {
    final config = _svc.current.value;
    final json = const JsonEncoder.withIndent('  ').convert(config.toJson());
    Clipboard.setData(ClipboardData(text: json));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full config copied as JSON'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState:
          _showNewConfig ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: const SizedBox(height: 400),
      secondChild: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Restart Banner
            ValueListenableBuilder<bool>(
              valueListenable: _svc.restartNeeded,
              builder: (context, needsRestart, _) {
                if (!needsRestart) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RestartBanner(onRestart: widget.onRestart),
                );
              },
            ),

            // Environment Card
            _buildCard(
              title: 'Active Environment',
              icon: Icons.layers_outlined,
              child: _pendingEnv != null
                  ? _buildConfirmSwitch(_pendingEnv!)
                  : _buildEnvSwitcher(),
            ),

            const SizedBox(height: 12),

            // API Endpoint Card
            _buildCard(
              title: 'API Endpoint',
              icon: Icons.link_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _UrlInputField(
                    controller: _urlController,
                    service: _svc,
                    onSubmit: _applyUrlOverride,
                  ),
                  if (_urlHistory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildUrlHistory(),
                  ],
                  if (_svc.current.value.isBaseUrlOverridden) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _svc.isProdLocked ? null : _clearOverride,
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore default URL'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Config Values Card
            _buildCard(
              title: 'Configuration',
              icon: Icons.settings_outlined,
              itemCount: _svc.current.value.values.length,
              expandable: true,
              isExpanded: _kvExpanded,
              onExpandToggle: (val) => setState(() => _kvExpanded = val),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ConfigSearchField(
                      onSearch: (val) =>
                          setState(() => _configSearchQuery = val),
                    ),
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      final entries =
                          _svc.current.value.values.entries.toList();
                      final query = _configSearchQuery.toLowerCase();
                      final filtered = entries.where((e) {
                        return e.key.toLowerCase().contains(query) ||
                            e.value.toLowerCase().contains(query);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(Icons.search_off_outlined,
                                  size: 32, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                query.isEmpty
                                    ? 'No configuration values'
                                    : 'No matches for "$_configSearchQuery"',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (int i = 0; i < filtered.length; i++) ...[
                            _buildKvRow(filtered[i].key, filtered[i].value),
                            if (i < filtered.length - 1)
                              Divider(
                                height: 24,
                                thickness: 1,
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.05),
                              ),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Audit Log Card
            FutureBuilder<List<AuditEntry>>(
              future: _svc.auditLog,
              builder: (context, snapshot) {
                final entries = snapshot.data ?? [];
                return _buildCard(
                  title: 'Activity History',
                  icon: Icons.history_outlined,
                  itemCount: entries.length,
                  expandable: true,
                  isExpanded: _auditExpanded,
                  onExpandToggle: (val) => setState(() => _auditExpanded = val),
                  child: AuditLogViewer(
                      entries: entries.reversed.take(20).toList()),
                );
              },
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _buildErrorBanner(_errorMessage!),
              ),

            const SizedBox(height: 24),

            // Global Actions
            if (_showResetConfirm)
              _buildResetConfirm()
            else
              _ActionButtons(
                onCopyAll: _copyAllConfig,
                onReset: () => setState(() => _showResetConfirm = true),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    int? itemCount,
    bool expandable = false,
    bool isExpanded = true,
    Function(bool)? onExpandToggle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      color: isDark ? Colors.grey.shade900 : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: title,
            icon: icon,
            subtitle: subtitle,
            itemCount: itemCount,
            expandable: expandable,
            isExpanded: isExpanded,
            onToggle: onExpandToggle,
          ),
          if (!expandable || isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildEnvSwitcher() {
    final available = _svc.availableEnvs;
    final current = _svc.current.value.env;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: available.map((env) {
        final isActive = env.name == current.name;
        final hasUrl = _svc.getOriginalUrl(env).isNotEmpty;

        return _EnvButton(
          env: env,
          isActive: isActive,
          onPressed: _svc.isProdLocked ? null : () => _switchEnv(env),
          isLocked: env.isProduction && !_svc.allowProdSwitch,
          hasUrl: hasUrl,
        );
      }).toList(),
    );
  }

  Widget _buildConfirmSwitch(Env env) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                'Switch to ${env.label}?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'This environment may contain production data. Proceed with caution.',
            style: TextStyle(fontSize: 12),
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
                  backgroundColor: Colors.red,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Confirm Switch'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetConfirm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.refresh_rounded, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text(
                'Reset Everything?',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This will clear all custom URLs, your selection history, and the audit log. The app will return to its default configuration.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showResetConfirm = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _reset,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Confirm Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrlHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT OVERRIDES',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _urlHistory.take(5).map((url) {
            return InkWell(
              onTap: _svc.isProdLocked ? null : () => _applyUrlOverride(url),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  url,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKvRow(String key, String value) {
    final isSensitive = EnvConfig.isSensitiveKey(key);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (isSensitive)
              const Icon(Icons.lock_outline, size: 12, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 6),
        SensitiveValueDisplay(
          value: value,
          isSensitive: isSensitive,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvButton extends StatelessWidget {
  final Env env;
  final bool isActive;
  final VoidCallback? onPressed;
  final bool isLocked;
  final bool hasUrl;

  const _EnvButton({
    required this.env,
    required this.isActive,
    required this.hasUrl,
    this.onPressed,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _envColor(env);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statusColor = hasUrl ? color : Colors.amber;

    return Tooltip(
      message: _envTooltip(env),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(isDark ? 0.05 : 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color : color.withOpacity(0.3),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Indicator
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.white : statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                env.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : color,
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock,
                    size: 12, color: isActive ? Colors.white : color),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _envTooltip(Env env) {
    String msg = switch (env.name) {
      'dev' => 'Development: Local/Mock services',
      'staging' => 'Staging: Production-like environment',
      'prod' => 'Production: LIVE data & users',
      _ => '${env.label} Environment',
    };

    if (!hasUrl) msg += ' (No BASE_URL defined)';
    if (isLocked) msg += ' [Locked]';

    return msg;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final int? itemCount;
  final bool expandable;
  final bool isExpanded;
  final Function(bool)? onToggle;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
    this.itemCount,
    this.expandable = false,
    this.isExpanded = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: expandable ? () => onToggle?.call(!isExpanded) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (itemCount != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$itemCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (expandable)
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }
}

class _RestartBanner extends StatelessWidget {
  final VoidCallback? onRestart;

  const _RestartBanner({this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restart_alt, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Restart app to apply changes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Some services require re-initialisation to pick up the new environment.',
            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Restart Now'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SensitiveValueDisplay extends StatefulWidget {
  final String value;
  final bool isSensitive;

  const SensitiveValueDisplay({
    super.key,
    required this.value,
    this.isSensitive = false,
  });

  @override
  State<SensitiveValueDisplay> createState() => _SensitiveValueDisplayState();
}

class _SensitiveValueDisplayState extends State<SensitiveValueDisplay> {
  bool _revealed = false;
  bool _confirming = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (_revealed) {
      _hide();
    } else if (!_confirming) {
      setState(() => _confirming = true);
    }
  }

  void _confirm() {
    _copyValue();
    setState(() {
      _revealed = true;
      _confirming = false;
    });

    // Auto-hide after 5 seconds
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _hide();
    });
  }

  void _hide() {
    _hideTimer?.cancel();
    setState(() {
      _revealed = false;
      _confirming = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_confirming) {
      return InkWell(
        onTap: _confirm,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_open, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Reveal & Copy?',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (_revealed) {
      return InkWell(
        onTap: _hide,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  widget.value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.visibility, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text('Hide',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    if (!widget.isSensitive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                widget.value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              onPressed: _copyValue,
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined,
                size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Tap to reveal & copy',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyValue() {
    Clipboard.setData(ClipboardData(text: widget.value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _UrlInputField extends StatefulWidget {
  final TextEditingController controller;
  final EnvConfigService service;
  final Function(String) onSubmit;

  const _UrlInputField({
    required this.controller,
    required this.service,
    required this.onSubmit,
  });

  @override
  State<_UrlInputField> createState() => _UrlInputFieldState();
}

class _UrlInputFieldState extends State<_UrlInputField> {
  String? _error;

  void _validate(String val) {
    setState(() {
      if (val.isEmpty) {
        _error = null;
      } else if (!val.startsWith('http')) {
        _error = 'Must start with http:// or https://';
      } else {
        try {
          Uri.parse(val);
          _error = null;
        } catch (_) {
          _error = 'Invalid URL format';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.service.isProdLocked;

    return TextField(
      controller: widget.controller,
      enabled: !locked,
      onChanged: _validate,
      decoration: InputDecoration(
        labelText: 'Custom API URL',
        hintText: 'https://api.example.com',
        prefixIcon: const Icon(Icons.link, size: 20),
        suffixIcon: _error == null && widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => widget.onSubmit(widget.controller.text),
              )
            : null,
        errorText: _error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onSubmitted: _error == null ? widget.onSubmit : null,
    );
  }
}

class _ConfigSearchField extends StatelessWidget {
  final Function(String) onSearch;

  const _ConfigSearchField({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onSearch,
      decoration: InputDecoration(
        hintText: 'Search keys or values...',
        prefixIcon: const Icon(Icons.search, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onCopyAll;
  final VoidCallback onReset;

  const _ActionButtons({required this.onCopyAll, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onCopyAll,
          icon: const Icon(Icons.copy_all, size: 18),
          label: const Text('Copy All Config'),
        ),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reset Everything'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ],
    );
  }
}

Color _envColor(Env env) => switch (env.name) {
      'dev' => Colors.blue,
      'staging' => Colors.purple,
      'prod' => Colors.red,
      _ => Colors.teal,
    };

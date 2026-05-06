import 'package:flutter/material.dart';

import '../env_config_service.dart';
import '../env_model.dart';
import '../envified_exception.dart';

/// A self-contained debug panel widget for inspecting and modifying the active
/// environment configuration at runtime.
///
/// [EnvDebugPanel] can be used standalone — embedded anywhere in your widget
/// tree — or it can be presented by [EnvifiedOverlay] via a floating button
/// and bottom sheet.
///
/// ## Features
///
/// - Displays the active [Env] with a lock indicator when prod-locked.
/// - [SegmentedButton] for switching between [Env] values.
/// - Read-only label showing the `BASE_URL` from the current `.env*` file.
/// - Text field for overriding the base URL at runtime.
/// - "Clear override" button to restore the `.env*` value.
/// - Expandable key-value table of all entries in [EnvConfig.values].
/// - Reset button to call [EnvConfigService.reset].
/// - Optional [onApply] callback for "Apply & Restart" flows.
///
/// ## Usage
///
/// ```dart
/// EnvDebugPanel(
///   service: EnvConfigService.instance,
///   onApply: () => /* restart logic */,
/// )
/// ```
///
/// @see EnvifiedOverlay
/// @see EnvConfigService
class EnvDebugPanel extends StatefulWidget {
  /// The [EnvConfigService] instance this panel reads from and writes to.
  final EnvConfigService service;

  /// Optional callback invoked when the user taps "Apply & Restart".
  ///
  /// If `null`, the button is not shown.
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
  String? _errorMessage;

  EnvConfigService get _svc => widget.service;

  @override
  void initState() {
    super.initState();
    _svc.current.addListener(_onConfigChanged);
    _syncUrlController();
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

  Future<void> _switchEnv(Env env) async {
    try {
      await _svc.switchTo(env);
      if (mounted) setState(() => _errorMessage = null);
    } on EnvifiedLockException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
  }

  Future<void> _applyUrlOverride() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    try {
      await _svc.setBaseUrl(url);
      if (mounted) setState(() => _errorMessage = null);
    } on EnvifiedLockException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
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
    if (mounted) setState(() => _errorMessage = null);
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            _buildHeader(config, locked, lockColor, cs),

            const SizedBox(height: 16),

            // ── Env switcher ──────────────────────────────────────────────
            _buildEnvSwitcher(config, locked, cs),

            const SizedBox(height: 20),

            // ── BASE_URL (from .env file) ─────────────────────────────────
            _buildEnvBaseUrlLabel(config, cs),

            const SizedBox(height: 16),

            // ── URL override ──────────────────────────────────────────────
            _buildUrlOverrideField(config, locked),

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
            const SizedBox(height: 8),

            // ── Action buttons ────────────────────────────────────────────
            _buildActionRow(),
          ],
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
            // ignore: deprecated_member_use
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
            // ignore: deprecated_member_use
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: Env.values.map((e) {
          final isSelected = config.env == e;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.label),
                  if (e == Env.prod && !_svc.allowProdSwitch)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock, size: 12),
                    ),
                ],
              ),
              selected: isSelected,
              onSelected: locked ? null : (_) => _switchEnv(e),
              // ignore: deprecated_member_use
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

  Widget _buildEnvBaseUrlLabel(EnvConfig config, ColorScheme cs) {
    final fileUrl = config.values['BASE_URL'] ?? '(not set)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BASE_URL from .env file',
          style: TextStyle(
            fontSize: 11,
            // ignore: deprecated_member_use
            color: cs.onSurface.withOpacity(0.55),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          fileUrl,
          style: TextStyle(
            fontSize: 13,
            // ignore: deprecated_member_use
            color: cs.onSurface.withOpacity(0.8),
            fontFamily: 'monospace',
          ),
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
                  // ignore: deprecated_member_use
                  color: cs.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'All values (${config.values.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    // ignore: deprecated_member_use
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_kvExpanded)
          Container(
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: cs.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: config.values.entries.map((entry) {
                return _buildKvRow(entry.key, entry.value, cs);
              }).toList(),
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
    switch (env) {
      case Env.dev:
        return Colors.blue.shade600;
      case Env.staging:
        return Colors.orange.shade700;
      case Env.prod:
        return Colors.red.shade600;
      case Env.custom:
        return Colors.purple.shade600;
    }
  }
}

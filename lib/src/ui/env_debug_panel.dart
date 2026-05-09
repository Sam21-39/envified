import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/env.dart';
import '../models/env_config.dart';
import '../models/audit_entry.dart';
import '../service/env_config_service.dart';
import 'audit_log_viewer.dart';

/// A premium debug panel for environment management.
class EnvDebugPanel extends StatefulWidget {
  final VoidCallback? onRestart;

  const EnvDebugPanel({super.key, this.onRestart});

  @override
  State<EnvDebugPanel> createState() => _EnvDebugPanelState();
}

class _EnvDebugPanelState extends State<EnvDebugPanel> {
  final _urlController = TextEditingController();
  bool _auditExpanded = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = EnvConfigService.instance.current.value.baseUrl;
    EnvConfigService.instance.current.addListener(_onEnvChanged);
  }

  void _onEnvChanged() {
    if (!mounted) return;
    final newUrl = EnvConfigService.instance.current.value.baseUrl;
    if (_urlController.text != newUrl) {
      setState(() {
        _urlController.text = newUrl;
      });
    }
  }

  @override
  void dispose() {
    EnvConfigService.instance.current.removeListener(_onEnvChanged);
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: EnvConfigService.instance.current,
      builder: (context, config, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                title: 'Active Environment',
                child: ValueListenableBuilder<List<Env>>(
                  valueListenable:
                      EnvConfigService.instance.availableEnvironments,
                  builder: (context, envs, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: envs.map((env) {
                        final isActive = config.env == env;
                        final isLocked = EnvConfigService.instance.isProdLocked;
                        return ChoiceChip(
                          label: Text(env.label),
                          selected: isActive,
                          onSelected: (selected) {
                            if (!selected || isActive) return;
                            if (isLocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot switch while Production is locked.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            EnvConfigService.instance.switchTo(env);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const Divider(height: 32),
              _buildSection(
                title: 'API Endpoint',
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.example.com',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () {
                            if (EnvConfigService.instance.isProdLocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot override URL while Production is locked.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                            EnvConfigService.instance
                                .setBaseUrl(_urlController.text);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (config.isBaseUrlOverridden)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '⚡ Custom URL active',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 32),
              _buildSection(
                title: 'Configuration',
                child: Column(
                  children: config.values.entries.map((e) {
                    final isSensitive =
                        EnvConfigService.instance.isSensitive(e.key);
                    return _ConfigRow(
                      name: e.key,
                      value: e.value,
                      isSensitive: isSensitive,
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 32),
              ExpansionTile(
                title: const Text('Activity History',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                initiallyExpanded: _auditExpanded,
                onExpansionChanged: (val) =>
                    setState(() => _auditExpanded = val),
                children: [
                  ValueListenableBuilder<List<AuditEntry>>(
                    valueListenable: EnvConfigService.instance.auditLog,
                    builder: (context, entries, _) {
                      return AuditLogViewer(entries: entries.reversed.toList());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (EnvConfigService.instance.restartNeeded.value)
                ElevatedButton.icon(
                  onPressed: () {
                    EnvConfigService.instance.markAsApplied();
                    widget.onRestart?.call();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart to Apply Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ConfigRow extends StatefulWidget {
  final String name;
  final String value;
  final bool isSensitive;

  const _ConfigRow({
    required this.name,
    required this.value,
    required this.isSensitive,
  });

  @override
  State<_ConfigRow> createState() => _ConfigRowState();
}

class _ConfigRowState extends State<_ConfigRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  widget.isSensitive && !_revealed
                      ? '••••••••••••••••'
                      : widget.value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSensitive)
            IconButton(
              icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility,
                  size: 18),
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Value copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../env_config_service.dart';
import '../env_model.dart';

class EnvDebugPanel extends StatefulWidget {
  final EnvConfigService service;
  final VoidCallback? onApply;

  const EnvDebugPanel({
    super.key,
    required this.service,
    this.onApply,
  });

  @override
  State<EnvDebugPanel> createState() => _EnvDebugPanelState();
}

class _EnvDebugPanelState extends State<EnvDebugPanel> {
  late TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl =
        TextEditingController(text: widget.service.current.value.baseUrl);
    widget.service.current.addListener(_syncTextField);
  }

  @override
  void dispose() {
    widget.service.current.removeListener(_syncTextField);
    _urlCtrl.dispose();
    super.dispose();
  }

  void _syncTextField() {
    final url = widget.service.current.value.baseUrl;
    if (_urlCtrl.text != url) _urlCtrl.text = url;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: widget.service.current,
      builder: (context, config, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/cog-8-tooth.svg',
                        package: 'envified',
                        colorFilter: const ColorFilter.mode(
                            Colors.green, BlendMode.srcIn),
                        width: 24,
                        height: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Environment Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/x-mark.svg',
                        package: 'envified',
                        colorFilter: ColorFilter.mode(
                            Theme.of(context).iconTheme.color ?? Colors.black,
                            BlendMode.srcIn),
                        width: 24,
                        height: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SegmentedButton<Env>(
                  style: ButtonStyle(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  segments: [Env.dev, Env.staging, Env.prod]
                      .map((e) => ButtonSegment(
                            value: e,
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(e.name.toUpperCase()),
                            ),
                          ))
                      .toList(),
                  selected: {config.env == Env.custom ? Env.dev : config.env},
                  onSelectionChanged: (selection) =>
                      widget.service.switchTo(selection.first),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'Custom Base URL',
                    hintText: 'https://...',
                    filled: true,
                    fillColor: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/check-circle.svg',
                        package: 'envified',
                        colorFilter: const ColorFilter.mode(
                            Colors.blueAccent, BlendMode.srcIn),
                        width: 24,
                        height: 24,
                      ),
                      onPressed: () =>
                          widget.service.setCustomUrl(_urlCtrl.text.trim()),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (v) => widget.service.setCustomUrl(v.trim()),
                ),
                const SizedBox(height: 12),
                Text(
                  'ACTIVE URL: ${config.baseUrl}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          await widget.service.reset();
                          _urlCtrl.text = widget.service.current.value.baseUrl;
                        },
                        child: const Text('Reset Defaults'),
                      ),
                    ),
                    if (widget.onApply != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onApply!();
                          },
                          child: const Text('Apply & Restart'),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

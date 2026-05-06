import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:envified/envified.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise envified before runApp. This loads all .env* asset files,
  // restores the previously selected environment from storage, and sets up
  // the production lock.
  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    persistSelection: true,
    allowProdSwitch: false, // prod is locked by default
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'envified Example',
      debugShowCheckedModeBanner: false,
      // Use builder to inject the debug panel across all routes.
      builder: (context, child) => EnvifiedOverlay(
        service: EnvConfigService.instance,
        gate: const EnvGate(pin: '1234'),
        trigger: const EnvTrigger.tap(count: 2),
        enabled: kDebugMode, // remove the panel in release builds
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final EnvConfigService service = EnvConfigService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('envified Example'),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<EnvConfig>(
        valueListenable: service.current,
        builder: (context, config, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Active env badge ─────────────────────────────────────
                const _SectionTitle('Active Environment'),
                const SizedBox(height: 8),
                _EnvBadge(env: config.env),

                const SizedBox(height: 24),

                // ── Base URL ─────────────────────────────────────────────
                const _SectionTitle('Base URL'),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Current',
                  value: config.baseUrl,
                  highlight: config.isBaseUrlOverridden,
                ),
                if (config.isBaseUrlOverridden)
                  _InfoRow(
                    label: 'From .env',
                    value: config.values['BASE_URL'] ?? '(not set)',
                  ),

                const SizedBox(height: 24),

                // ── Values ───────────────────────────────────────────────
                _SectionTitle('All env values (${config.values.length})'),
                const SizedBox(height: 8),
                ...config.values.entries.map(
                  (e) => _InfoRow(label: e.key, value: e.value),
                ),

                const SizedBox(height: 24),

                // ── Typed Getters ──────────────────────────────────────────
                const _SectionTitle('Typed Getters (Safe Parsing)'),
                const SizedBox(height: 8),
                _InfoRow(label: 'getBool("DEBUG")', value: service.getBool('DEBUG').toString()),
                _InfoRow(label: 'getInt("PORT")', value: service.getInt('PORT').toString()),
                _InfoRow(label: 'getDouble("VERSION")', value: service.getDouble('VERSION').toString()),
                _InfoRow(label: 'getUri("BASE_URL")', value: service.getUri('BASE_URL')?.toString() ?? 'null'),
                _InfoRow(label: 'getList("SCOPES")', value: service.getList('SCOPES').join(', ')),

                const SizedBox(height: 24),

                // ── Audit Log ──────────────────────────────────────────────
                const _SectionTitle('Audit Log (Action History)'),
                const SizedBox(height: 8),
                ValueListenableBuilder<List<AuditEntry>>(
                  valueListenable: service.auditLog,
                  builder: (context, log, _) {
                    if (log.isEmpty) {
                      return const Text('No history yet.', style: TextStyle(color: Colors.blueGrey));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: log.length,
                      itemBuilder: (context, index) {
                        final entry = log[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '[${entry.timestamp.toIso8601String().substring(11, 19)}] ${entry.action.name}: ${entry.details}',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.blueGrey),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Quick switch buttons ──────────────────────────────────
                const _SectionTitle('Quick Switch'),
                const SizedBox(height: 12),
                _EnvSwitcher(service: service),

                const SizedBox(height: 32),

                // ── Tip ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                  child: const Text(
                    '💡 Double-tap anywhere to open the debug panel.\n'
                    '🔐 PIN is 1234 — or tap 🌿 in the bottom-right corner.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.blueGrey.shade400,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
    );
  }
}

class _EnvBadge extends StatelessWidget {
  final Env env;
  const _EnvBadge({required this.env});

  Color _color() {
    switch (env) {
      case Env.dev:
        return Colors.blue.shade400;
      case Env.staging:
        return Colors.orange.shade400;
      case Env.prod:
        return Colors.red.shade400;
      case Env.custom:
        return Colors.purple.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: _color().withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _color(), width: 1.5),
      ),
      child: Text(
        env.label,
        style: TextStyle(
          color: _color(),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Colors.blueGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: highlight ? Colors.amber.shade400 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvSwitcher extends StatelessWidget {
  final EnvConfigService service;
  const _EnvSwitcher({required this.service});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: service.current,
      builder: (context, config, _) {
        final bool locked = service.isProdLocked;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Env.values.map((env) {
            final bool isActive = config.env == env;
            return Tooltip(
              message: locked && env != Env.prod ? 'Locked in production' : '',
              child: FilledButton(
                onPressed: (locked && env != Env.prod)
                    ? null
                    : () async {
                        try {
                          await service.switchTo(env);
                        } on EnvifiedLockException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: isActive ? null : Colors.blueGrey.shade800,
                ),
                child: Text(env.label),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

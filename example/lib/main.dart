import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:envified/envified.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize the singleton service.
  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    sensitiveKeys: ['SECRET_TOKEN', 'API_PASSWORD'],
  );

  runApp(const EnvifiedDemoApp());
}

class EnvifiedDemoApp extends StatefulWidget {
  const EnvifiedDemoApp({super.key});

  @override
  State<EnvifiedDemoApp> createState() => _EnvifiedDemoAppState();
}

class _EnvifiedDemoAppState extends State<EnvifiedDemoApp> {
  Key _appKey = UniqueKey();

  void _handleRestart() {
    // 2. Clear the restart flag.
    EnvConfigService.instance.acknowledgeRestart();
    setState(() {
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey,
      title: 'Envified v3.0.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      // 3. Wrap with the overlay.
      builder: (context, child) => EnvifiedOverlay(
        enabled: kDebugMode,
        gate: EnvGate(pin: '0000'),
        trigger: const EnvTrigger.tap(count: 7),
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: EnvConfigService.instance.current,
      builder: (context, config, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Envified v3.0.0'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    config.env.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _InfoCard(
                    title: 'Current Environment',
                    value: config.env.label,
                    icon: Icons.layers,
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Base URL',
                    value: config.baseUrl,
                    icon: Icons.link,
                    isOverridden: config.isBaseUrlOverridden,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'CONFIGURATION VALUES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...config.values.entries.map((e) => _ConfigTile(
                        name: e.key,
                        value: e.value,
                      )),
                ],
              ),
              const EnvStatusBadge(),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isOverridden;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isOverridden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOverridden ? Colors.orange.shade50 : Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isOverridden ? Colors.orange.shade700 : Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final String name;
  final String value;

  const _ConfigTile({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final isSensitive = EnvConfigService.instance.isSensitive(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  isSensitive ? '••••••••' : value,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (isSensitive)
            const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}

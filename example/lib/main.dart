import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:envified/envified.dart';

// 1. Define your custom shake detector or use a package like shake.
class MyShakeDetector implements EnvShakeDetector {
  @override
  void start(double threshold, VoidCallback onShake) {
    // Implement your shake logic here or use a package
    debugPrint('Shake listening started with threshold: $threshold');
  }

  @override
  void stop() {
    debugPrint('Shake listening stopped.');
  }
}

void main() async {
  // Ensure Flutter is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Envified.
  // This loads the active environment and discovers available .env.* files.
  await EnvConfigService.instance.init(
    defaultEnv: Env.dev,
    // Production lock: Only allow switching environments in debug mode.
    allowProdSwitch: kDebugMode,
    // Auto-discover .env.* files from assets.
    autoDiscover: true,
    // Sensitive keys will be blurred in the UI.
    sensitiveKeys: ['API_KEY', 'AUTH_TOKEN', 'JWT_SECRET'],
    // Define which environments should be treated as production (security locked).
    productionEnvs: [Env.prod, Env.dynamic("production")],
  );

  runApp(const EnvifiedLuxuryApp());
}

class EnvifiedLuxuryApp extends StatefulWidget {
  const EnvifiedLuxuryApp({super.key});

  @override
  State<EnvifiedLuxuryApp> createState() => _EnvifiedLuxuryAppState();
}

class _EnvifiedLuxuryAppState extends State<EnvifiedLuxuryApp> {
  Key _appKey = UniqueKey();

  void _restart() {
    setState(() {
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey,
      title: 'Envified Luxury',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
      ),
      // 3. Wrap with the EnvifiedOverlay.
      // We provide a PIN-protected gate and a Shake trigger.
      builder: (context, child) => EnvifiedOverlay(
        enabled: true,
        gate: EnvGate(pin: '8888'),
        trigger: EnvTrigger.shake(
          detector: MyShakeDetector(),
          threshold: 15.0,
        ),
        onRestart: _restart,
        showFab: true,
        // NEW: Toggle display of .env keys in the debug panel.
        showEnvKeys: true,
        // NEW: Toggle display of current environment badge.
        isShowEnvLabel: true,
        child: child!,
      ),
      home: const LuxuryHome(),
    );
  }
}

class LuxuryHome extends StatelessWidget {
  const LuxuryHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EnvConfig>(
      valueListenable: EnvConfigService.instance.current,
      builder: (context, config, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  Color(0xFF1E1E2E),
                  Color(0xFF0F0F1A),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      _buildAppBar(config),
                      SliverPadding(
                        padding: const EdgeInsets.all(24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildHeroCard(config),
                            const SizedBox(height: 32),
                            _buildSectionHeader('Connection Details'),
                            const SizedBox(height: 16),
                            _buildInfoTile(
                              'API ENDPOINT',
                              config.baseUrl,
                              Icons.api_rounded,
                              isOverridden: config.isBaseUrlOverridden,
                            ),
                            const SizedBox(height: 32),
                            _buildSectionHeader('Security Configuration'),
                            const SizedBox(height: 16),
                            ...config.values.entries
                                .map((e) => _buildSecretTile(e.key, e.value)),
                            const SizedBox(
                                height: 100), // Space for status badge
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const EnvStatusBadge(
                    margin: EdgeInsets.fromLTRB(0, 24, 24, 0),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(EnvConfig config) {
    return const SliverAppBar(
      backgroundColor: Colors.transparent,
      floating: true,
      title: Text(
        'ENVIFIED LUXURY',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          color: Colors.white70,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeroCard(EnvConfig config) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6200EE).withValues(alpha: 0.8),
            const Color(0xFFBB86FC).withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6200EE).withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              config.env.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Active Configuration',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last loaded at ${config.loadedAt.hour}:${config.loadedAt.minute}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white.withValues(alpha: 0.4),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon,
      {bool isOverridden = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon,
                color: isOverridden ? Colors.orangeAccent : Colors.white60,
                size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            if (isOverridden)
              const Icon(Icons.bolt_rounded,
                  color: Colors.orangeAccent, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretTile(String name, String value) {
    final isSensitive = EnvConfigService.instance.isSensitive(name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: isSensitive ? Colors.redAccent : Colors.tealAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  isSensitive ? '••••••••••••••••' : value,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          if (isSensitive)
            Icon(Icons.lock_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:envified/envified.dart';
import 'package:http/http.dart' as http;

void main() async {
  // 1. Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize the EnvConfigService before runApp
  // This loads the default .env files and checks for persisted overrides.
  await EnvConfigService.instance.init(
    defaultEnv: Env.staging,
    allowProdSwitch: false, // 🔒 Lock production by default
    verifyIntegrity: false,
    onAfterSwitch: (config) {
      debugPrint('Environment changed: ${config.env.name}');
    },
  );

  runApp(const EnvifiedDemoApp());
}

class EnvifiedDemoApp extends StatefulWidget {
  const EnvifiedDemoApp({super.key});

  @override
  State<EnvifiedDemoApp> createState() => _EnvifiedDemoAppState();
}

class _EnvifiedDemoAppState extends State<EnvifiedDemoApp> {
  // Use a UniqueKey to trigger a full widget tree rebuild during "Restart Now"
  Key _appKey = UniqueKey();

  void _handleRestart() {
    // 4. Reset the restartNeeded flag once the app acknowledges the restart
    EnvConfigService.instance.acknowledgeRestart();

    setState(() {
      _appKey = UniqueKey();
    });
    debugPrint('App tree re-initialized via Envified restart handler.');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey,
      title: 'Envified-Demo',
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
        // HIDE the package-provided label because this example app
        // renders its own manual EnvStatusBadge in LuxuryHome.
        isShowEnvLabel: false,
        child: child!,
      ),
      home: const LoginGate(),
    );
  }
}

class LoginGate extends StatefulWidget {
  const LoginGate({super.key});

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  bool _isLoggedIn = false;

  void _login() {
    setState(() => _isLoggedIn = true);
  }

  void _logout() {
    setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return HomePage(onLogout: _logout);
    }
    return LoginPage(onLogin: _login);
  }
}

class LoginPage extends StatelessWidget {
  final VoidCallback onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final config = EnvConfigService.instance.current.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDark ? [Colors.teal.shade900, Colors.black] : [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.teal.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🌿', style: TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      config.values['APP_TITLE'] ?? 'Envified-Demo',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Environment: ${config.env.label}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: onLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'API endpoint: ${config.baseUrl}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

  Widget _buildDynamicItem(dynamic item) {
    // Detect content type based on keys
    if (item.containsKey('completed')) {
      return _buildTodoItem(item);
    } else if (item.containsKey('email')) {
      return _buildUserItem(item);
    } else if (item.containsKey('thumbnailUrl')) {
      return _buildPhotoItem(item);
    }

    return ListTile(title: Text(item.toString()));
  }

  Widget _buildTodoItem(dynamic item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: Colors.teal.shade50,
        child: Text('${item['id']}',
            style:
                TextStyle(color: Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      title: Text(
        item['title'],
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(icon, color: isOverridden ? Colors.orangeAccent : Colors.white60, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            if (isOverridden) const Icon(Icons.bolt_rounded, color: Colors.orangeAccent, size: 16),
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
    );
  }

  Widget _buildUserItem(dynamic item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade50,
        child: const Icon(Icons.person, color: Colors.blue),
      ),
      title: Text(
        item['name'],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            Icon(Icons.lock_rounded, size: 14, color: Colors.white.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

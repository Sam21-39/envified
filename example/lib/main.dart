import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:envified/envified.dart';
import 'package:http/http.dart' as http;

void main() async {
  // 1. Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize the EnvConfigService before runApp
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

class MyShakeDetector implements EnvTriggerDetector {
  @override
  void start(double threshold, VoidCallback onShake) {
    debugPrint('Shake listening started with threshold: $threshold');
  }

  @override
  void stop() {
    debugPrint('Shake listening stopped');
  }
}

class EnvifiedDemoApp extends StatefulWidget {
  const EnvifiedDemoApp({super.key});

  @override
  State<EnvifiedDemoApp> createState() => _EnvifiedDemoAppState();
}

class _EnvifiedDemoAppState extends State<EnvifiedDemoApp> {
  Key _appKey = UniqueKey();

  void _restart() {
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
      builder: (context, child) => EnvifiedOverlay(
        service: EnvConfigService.instance,
        enabled: true,
        gate: const EnvGate(pin: '8888'),
        trigger: EnvTrigger.shake(
          detector: MyShakeDetector(),
          threshold: 15.0,
        ),
        onRestart: _restart,
        showFab: true,
        showEnvKeys: true,
        isShowEnvLabel: true,
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
            colors: isDark
                ? [Colors.teal.shade900, Colors.black]
                : [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              margin: const EdgeInsets.all(24),
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                        child: const Text('Sign In',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
}

class HomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const HomePage({super.key, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = _fetchData();
  }

  Future<List<dynamic>> _fetchData() async {
    final baseUrl = EnvConfigService.instance.current.value.baseUrl;
    if (baseUrl.isEmpty) return [];

    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.take(10).toList();
        }
        return [];
      } else {
        throw Exception('Server responded with ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = EnvConfigService.instance.current.value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config.values['APP_TITLE'] ?? 'Home'),
            Text(
              '${config.env.label} • ${config.baseUrl}',
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              (snapshot.hasData && snapshot.data!.isEmpty)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No data or error occurred'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _data = _fetchData()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: _buildDynamicItem(item),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDynamicItem(dynamic item) {
    if (item is! Map) return ListTile(title: Text(item.toString()));

    if (item.containsKey('completed')) {
      return _buildTodoItem(item);
    } else if (item.containsKey('email')) {
      return _buildUserItem(item);
    } else if (item.containsKey('thumbnailUrl')) {
      return _buildPhotoItem(item);
    }

    return ListTile(title: Text(item.toString()));
  }

  Widget _buildTodoItem(Map<dynamic, dynamic> item) {
    final bool completed = item['completed'] == true;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.teal.shade50,
        child: Text('${item['id']}',
            style: TextStyle(color: Colors.teal.shade700, fontSize: 12)),
      ),
      title: Text(item['title'] ?? ''),
      subtitle: Text(completed ? 'Completed' : 'Pending',
          style: TextStyle(
              color: completed ? Colors.green : Colors.orange, fontSize: 11)),
    );
  }

  Widget _buildUserItem(Map<dynamic, dynamic> item) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(item['name'] ?? ''),
      subtitle: Text(item['email'] ?? ''),
    );
  }

  Widget _buildPhotoItem(Map<dynamic, dynamic> item) {
    return ListTile(
      leading: Image.network(item['thumbnailUrl'],
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image)),
      title: Text(item['title'] ?? ''),
    );
  }
}

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
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      // 3. Wrap MaterialApp.builder with EnvifiedOverlay
      // This ensures the debug panel is available across all routes.
      builder: (context, child) => EnvifiedOverlay(
        service: EnvConfigService.instance,
        enabled: true, // Force enabled for this demo app
        onRestart: _handleRestart,
        gate: const EnvGate(pin: '1234'), // Secure with a PIN
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

    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> fullList = jsonDecode(response.body);
        return fullList.take(10).toList(); // Only show first 10
      } else {
        throw Exception('Server responded with ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
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
            Text(config.values['APP_TITLE'] ?? 'Envified-Demo'),
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
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load data: ${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _data = _fetchData()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: _buildDynamicItem(item),
              );
            },
          );
        },
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
            style: TextStyle(
                color: Colors.teal.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
      title: Text(
        item['title'],
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(
              item['completed'] ? Icons.check_circle : Icons.pending_actions,
              size: 14,
              color: item['completed'] ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              item['completed'] ? 'Completed' : 'Pending',
              style: TextStyle(
                color: item['completed']
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
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
          Text(item['email'], style: const TextStyle(fontSize: 12)),
          Text(
            item['company']?['name'] ?? '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
      trailing: const Icon(Icons.business_outlined, size: 18),
    );
  }

  Widget _buildPhotoItem(dynamic item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item['thumbnailUrl'],
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 48,
            height: 48,
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported, size: 20),
          ),
        ),
      ),
      title: Text(
        item['title'],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle:
          const Text('Environment: Production', style: TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.photo_library_outlined, size: 18),
    );
  }
}

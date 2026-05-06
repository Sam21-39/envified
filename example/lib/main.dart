import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:envified/envified.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfigService.instance.init(
    urls: {
      Env.dev: 'https://jsonplaceholder.typicode.com',
      Env.staging: 'https://dummyjson.com',
      Env.prod: 'https://reqres.in/api',
    },
    defaultEnv: Env.dev,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return EnvifiedScope(
      service: EnvConfigService.instance,
      builder: (context, config) {
        return MaterialApp(
          navigatorKey: navKey,
          title: 'Envified UI Example',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ThemeMode.system,
          // 1. Simply add the overlay builder to your MaterialApp
          builder: (context, child) {
            return EnvifiedOverlay(
              service: EnvConfigService.instance,
              navigatorKey: navKey,
              // The overlay will automatically hide if config.env == Env.prod
              child: child!,
            );
          },
          home: const MyHomePage(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _apiResult = 'No data fetched yet.';
  bool _isLoading = false;

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _apiResult = 'Fetching...';
    });

    try {
      final config = EnvConfigService.instance.current.value;
      // Using different endpoints based on the fake APIs configured
      final String endpoint;
      if (config.baseUrl.contains('jsonplaceholder')) {
        endpoint = '/users/1';
      } else if (config.baseUrl.contains('dummyjson')) {
        endpoint = '/users/1';
      } else {
        endpoint = '/users/2'; // reqres
      }

      final uri = Uri.parse('${config.baseUrl}$endpoint');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _apiResult =
              'Success!\n\n${const JsonEncoder.withIndent('  ').convert(data)}';
        });
      } else {
        setState(() {
          _apiResult = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _apiResult = 'Exception: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Access the current config effortlessly anywhere in your app
    final config = EnvifiedScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envified UI Overlay'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FlutterLogo(size: 64),
              const SizedBox(height: 16),
              const Text(
                'Simulated API Fetcher',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Change environments using the floating bug icon. Then press the button below to fetch data from the active environment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Current Config:\n${config.env.name.toUpperCase()} - ${config.baseUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchData,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download),
                label: const Text('Fetch Data'),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black26
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _apiResult,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

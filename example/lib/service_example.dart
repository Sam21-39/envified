import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:envified/envified.dart';

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

  runApp(const ServiceExampleApp());
}

class ServiceExampleApp extends StatelessWidget {
  const ServiceExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap your app with EnvifiedScope to automatically rebuild when the environment changes.
    return EnvifiedScope(
      service: EnvConfigService.instance,
      builder: (context, config) {
        return MaterialApp(
          title: 'Direct Service Example',
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
          home: const ServiceExampleHome(),
        );
      },
    );
  }
}

class ServiceExampleHome extends StatefulWidget {
  const ServiceExampleHome({super.key});

  @override
  State<ServiceExampleHome> createState() => _ServiceExampleHomeState();
}

class _ServiceExampleHomeState extends State<ServiceExampleHome> {
  String _apiResult = 'No data fetched yet.';
  bool _isLoading = false;

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _apiResult = 'Fetching...';
    });

    try {
      final config = EnvConfigService.instance.current.value;
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
    final config = EnvifiedScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Direct Service Integration')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FlutterLogo(size: 64),
              const SizedBox(height: 24),
              Text('Current Env: ${config.env.name.toUpperCase()}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Base URL: ${config.baseUrl}',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
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
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _apiResult,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () =>
                    EnvConfigService.instance.switchTo(Env.staging),
                child: const Text('Switch to Staging Programmatically'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => EnvConfigService.instance.switchTo(Env.dev),
                child: const Text('Switch to Dev Programmatically'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:envified/envified.dart';

// ---------------------------------------------------------------------------
// SECURE DOTENV ALTERNATIVE DEMO
//
// TWO approaches shown here:
//
// APPROACH A - Asset-based (non-sensitive config only):
//   .env.dev.json / .env.staging.json / .env.prod.json are bundled as Flutter
//   assets and loaded at runtime. These can be extracted from the APK, so
//   only use them for non-sensitive config (feature flags, log levels, etc).
//
// APPROACH B - Compile-time secrets (sensitive values):
//   Injected via --dart-define-from-file at build time. Baked into the binary,
//   cannot be extracted as a file. Use for API keys, DSNs, tokens, etc.
//
//   flutter run --dart-define=API_KEY=your-secret --dart-define=APP_NAME=MyApp
// ---------------------------------------------------------------------------

// Approach B: compile-time secrets (String.fromEnvironment)
const _apiKey = String.fromEnvironment('API_KEY', defaultValue: 'demo-key');
const _appName =
    String.fromEnvironment('APP_NAME', defaultValue: 'Envified Demo');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Approach A: load per-env config directly from .env.*.json asset files
  final devVars = await EnvFileReader.fromJsonAsset('assets/.env.dev.json');
  final stagingVars =
      await EnvFileReader.fromJsonAsset('assets/.env.staging.json');
  final prodVars = await EnvFileReader.fromJsonAsset('assets/.env.prod.json');

  await EnvConfigService.instance.init(
    urls: {
      Env.dev: 'https://jsonplaceholder.typicode.com',
      Env.staging: 'https://dummyjson.com',
      Env.prod: 'https://reqres.in/api',
    },
    defaultEnv: Env.dev,

    // Approach B: global compile-time secrets (all envs)
    vars: {
      'API_KEY': _apiKey,
      'APP_NAME': _appName,
    },

    // Approach A: per-env non-sensitive config from asset files
    // These are merged on top of global vars; per-env values take priority.
    // BASE_URL is always auto-injected and kept in sync automatically.
    varsByEnv: {
      Env.dev: devVars,
      Env.staging: stagingVars,
      Env.prod: prodVars,
    },
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
          title: EnvConfigService.instance.get('APP_NAME'),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ThemeMode.system,
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
  final _customUrlCtrl = TextEditingController();

  @override
  void dispose() {
    _customUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _apiResult = 'Fetching...';
    });

    try {
      // BASE_URL is always auto-injected into vars - use either way:
      final baseUrl = EnvConfigService.instance.get('BASE_URL');
      final endpoint = baseUrl.contains('jsonplaceholder')
          ? '/users/1'
          : baseUrl.contains('dummyjson')
              ? '/users/1'
              : '/users/2';

      final response = await http.get(Uri.parse('$baseUrl$endpoint'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _apiResult =
              'Success!\n\n${const JsonEncoder.withIndent('  ').convert(data)}';
        });
      } else {
        setState(() => _apiResult = 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _apiResult = 'Exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = EnvifiedScope.of(context);
    final service = EnvConfigService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(service.get('APP_NAME')),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _envColor(config.env).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _envColor(config.env)),
            ),
            child: Text(
              config.env.name.toUpperCase(),
              style: TextStyle(
                color: _envColor(config.env),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FlutterLogo(size: 64),
            const SizedBox(height: 24),

            // Active config
            _SectionCard(
              title: 'Active Configuration',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row('Environment', config.env.name.toUpperCase()),
                  _Row('Base URL', config.baseUrl),
                  _Row('API Key', service.maybeGet('API_KEY') ?? '(not set)'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // All resolved vars (including BASE_URL auto-injected)
            _SectionCard(
              title: 'Resolved Vars (from .env.*.json)',
              subtitle:
                  'BASE_URL is always auto-synced. Per-env values override global.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: config.vars.entries
                    .map((e) => _Row(e.key, e.value))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Env switcher
            _SectionCard(
              title: 'Switch Environment',
              subtitle: 'Loads matching .env.*.json vars automatically',
              child: Wrap(
                spacing: 8,
                children: [Env.dev, Env.staging, Env.prod].map((env) {
                  final isActive = config.env == env;
                  return FilledButton.tonal(
                    style: isActive
                        ? FilledButton.styleFrom(
                            backgroundColor: _envColor(env),
                            foregroundColor: Colors.white,
                          )
                        : null,
                    onPressed: () => service.switchTo(env),
                    child: Text(env.name.toUpperCase()),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Custom URL - BASE_URL var auto-syncs
            _SectionCard(
              title: 'Custom URL Override',
              subtitle: 'BASE_URL var stays in sync automatically',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customUrlCtrl,
                      decoration: const InputDecoration(
                        hintText: 'https://my-local-server.com/api',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final url = _customUrlCtrl.text.trim();
                      if (url.isNotEmpty) service.setCustomUrl(url);
                    },
                    child: const Text('Set'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // API fetch demo
            _SectionCard(
              title: 'Simulated API Fetcher',
              subtitle: 'Uses BASE_URL from resolved vars',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchData,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download_rounded),
                    label: const Text('Fetch from Active Env'),
                  ),
                  if (_apiResult != 'No data fetched yet.') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black26
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _apiResult,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _envColor(Env env) => switch (env) {
        Env.dev => Colors.blue,
        Env.staging => Colors.orange,
        Env.prod => Colors.green,
        Env.custom => Colors.purple,
      };
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:',
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

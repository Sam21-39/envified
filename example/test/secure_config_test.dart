import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:envified_example/core/config/app_config.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    Object? iOptions,
    Object? aOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async {
    _data.clear();
  }
}

class FakeAssetBundle extends AssetBundle {
  final Map<String, String> _assets = {};

  void register(String key, String content) {
    _assets[key] = content;
  }

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin' || key == 'AssetManifest.bin.gz') {
      return _generateManifestBinary();
    }
    if (key == 'AssetManifest.json') {
      return _generateManifestJson();
    }

    final content = _assets[key];
    if (content == null) {
      throw FlutterError('Asset not found: $key');
    }
    return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final content = _assets[key];
    if (content == null) {
      if (key == 'AssetManifest.json') {
        final data = _generateManifestJson();
        return utf8.decode(data.buffer.asUint8List());
      }
      throw FlutterError('Asset not found: $key');
    }
    return content;
  }

  ByteData _generateManifestBinary() {
    final manifest = <String, List<Map<String, dynamic>>>{};
    for (final key in _assets.keys) {
      manifest[key] = [
        {'asset': key}
      ];
    }
    return const StandardMessageCodec().encodeMessage(manifest)!;
  }

  ByteData _generateManifestJson() {
    final manifest = <String, List<String>>{};
    for (final key in _assets.keys) {
      manifest[key] = [key];
    }
    final String json = jsonEncode(manifest);
    return ByteData.view(Uint8List.fromList(utf8.encode(json)).buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterSecureStorage fakeSecureStorage;
  late EnvStorage envStorage;
  late FakeAssetBundle bundle;

  setUp(() {
    EnvConfigService.instance.resetForTesting();
    fakeSecureStorage = FakeFlutterSecureStorage();
    envStorage = EnvStorage(storage: fakeSecureStorage, channel: EnvifiedChannel());
    bundle = FakeAssetBundle();

    bundle.register(
      '.env.dev',
      'ENV_NAME=Development\nBASE_URL=https://api.dev.envified.com\nFEATURE_CHAT_ENABLED=true\nEXPERIMENTAL_UI=true\n',
    );
    bundle.register(
      '.env.staging',
      'ENV_NAME=Staging\nBASE_URL=https://api.staging.envified.com\nFEATURE_CHAT_ENABLED=true\nEXPERIMENTAL_UI=false\n',
    );
  });

  group('Unified AppConfig Facade & Secrets Lookup Tests (Integrated)', () {
    test('AppConfig init loads dynamic configurations and validates secrets',
        () async {
      await AppConfig.init(
        Env.dev,
        bundle: bundle,
        storage: envStorage,
      );

      expect(AppConfig.environment, Env.dev);
      expect(AppConfig.environmentName, 'Dev');
      expect(AppConfig.baseUrl, 'https://api.dev.envified.com');
      expect(AppConfig.isFeatureEnabled('FEATURE_CHAT_ENABLED'), true);
    });

    test('AppConfig accessor retrieves assets and delegates to secrets',
        () async {
      await AppConfig.init(
        Env.dev,
        bundle: bundle,
        storage: envStorage,
      );

      // Accessing standard configurations (comes from assets)
      expect(AppConfig.get('ENV_NAME'), 'Development');
      expect(AppConfig.get('BASE_URL'), 'https://api.dev.envified.com');

      // Accessing compile-time obfuscated secrets (delegated fallback to AppSecrets)
      expect(AppConfig.get('ENCRYPTION_KEY'), isNotEmpty);
      expect(AppConfig.get('BASIC_AUTH_PASSWORD'), isNotEmpty);
      expect(AppConfig.get('APP_AUTH_KEY'), isNotEmpty);
      expect(AppConfig.get('API_SECRET'), isNotEmpty);

      expect(AppConfig.encryptionKey, isNotEmpty);
      expect(AppConfig.basicAuthPassword, isNotEmpty);
      expect(AppConfig.appAuthKey, isNotEmpty);
      expect(AppConfig.apiSecret, isNotEmpty);
    });
  });
}

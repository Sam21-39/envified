import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A robust [AssetBundle] for testing that supports on-the-fly asset registration
/// and automatic [AssetManifest] generation.
class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, String> _assets = {};

  void register(String key, String content) {
    _assets[key] = content;
  }

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin' || key == 'AssetManifest.json') {
      return _generateManifest(key == 'AssetManifest.bin');
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
      throw FlutterError('Asset not found: $key');
    }
    return content;
  }

  ByteData _generateManifest(bool binary) {
    final manifest = <String, List<Map<String, dynamic>>>{};
    for (final key in _assets.keys) {
      manifest[key] = [
        {'asset': key}
      ];
    }

    if (binary) {
      final ByteData data = const StandardMessageCodec().encodeMessage(manifest)!;
      return data;
    } else {
      final String json = jsonEncode(manifest);
      return ByteData.view(Uint8List.fromList(utf8.encode(json)).buffer);
    }
  }
}

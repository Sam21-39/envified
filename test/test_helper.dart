import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A simple fake implementation of [FlutterSecureStorage] for testing.
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

/// A robust [AssetBundle] for testing that supports on-the-fly asset registration
/// and automatic [AssetManifest] generation.
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

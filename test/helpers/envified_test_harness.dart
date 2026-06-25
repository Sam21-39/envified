import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:envified/src/channel/envified_channel.dart';

/// An in-memory [EnvifiedChannel] stub for unit tests.
///
/// Intercepts all method-channel calls and stores state in memory so tests
/// run without a platform or native layer.
///
/// ```dart
/// late EnvifiedTestHarness harness;
///
/// setUp(() {
///   harness = EnvifiedTestHarness();
/// });
///
/// tearDown(() => harness.reset());
/// ```
class EnvifiedTestHarness {
  final Map<String, Map<String, String>> _secrets = {};
  final Map<String, String> _configs = {};
  final List<String> _auditLog = [];
  String _securityLevel = 'software';

  late final EnvifiedChannel channel;

  EnvifiedTestHarness() {
    const mc = MethodChannel('in.appamania.envified/channel');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mc, _handleCall);
    channel = EnvifiedChannel(channel: mc);
  }

  /// Override the reported security level (default: `"software"`).
  void setSecurityLevel(String level) => _securityLevel = level;

  Future<Object?> _handleCall(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    switch (call.method) {
      case 'initialize':
        return {'success': true, 'securityLevel': _securityLevel};

      case 'getDeviceSecurityLevel':
        return {'level': _securityLevel};

      case 'keyExists':
        return {'exists': true};

      case 'encrypt':
        final pt = args['plaintext'] as Uint8List;
        final iv = args['iv'] as Uint8List? ?? Uint8List(12);
        final ct = Uint8List.fromList(pt.map((b) => b ^ 0xFF).toList());
        return {'ciphertext': ct, 'iv': iv};

      case 'decrypt':
        final ct = args['ciphertext'] as Uint8List;
        final pt = Uint8List.fromList(ct.map((b) => b ^ 0xFF).toList());
        return {'plaintext': pt};

      case 'storeSecret':
        final env = args['env'] as String? ?? 'default';
        final keyId = args['keyId'] as String? ?? '';
        final ct = args['ciphertext'] as Uint8List?;
        final iv = args['iv'] as Uint8List?;
        _secrets.putIfAbsent(env, () => {});
        _secrets[env]!['ct_$keyId'] = base64.encode(ct ?? Uint8List(0));
        _secrets[env]!['iv_$keyId'] = base64.encode(iv ?? Uint8List(12));
        return {'success': true};

      case 'retrieveSecret':
        final env = args['env'] as String? ?? 'default';
        final keyId = args['keyId'] as String? ?? '';
        final store = _secrets[env];
        if (store == null || !store.containsKey('ct_$keyId')) {
          throw PlatformException(
            code: 'ENVIFIED_KEY_NOT_FOUND',
            message: 'Secret $keyId not found',
          );
        }
        return {
          'ciphertext': Uint8List.fromList(base64.decode(store['ct_$keyId']!)),
          'iv': Uint8List.fromList(base64.decode(store['iv_$keyId'] ?? '')),
        };

      case 'deleteSecret':
        final env = args['env'] as String? ?? 'default';
        final keyId = args['keyId'] as String? ?? '';
        _secrets[env]?.remove('ct_$keyId');
        _secrets[env]?.remove('iv_$keyId');
        return {'success': true};

      case 'deleteAllSecrets':
        final env = args['env'] as String? ?? 'default';
        final count =
            _secrets[env]?.keys.where((k) => k.startsWith('ct_')).length ?? 0;
        _secrets.remove(env);
        return {'deletedCount': count};

      case 'rotateKey':
        return {'migratedCount': 0};

      case 'persistConfig':
        final env = args['env'] as String? ?? 'default';
        _configs[env] = args['configJson'] as String? ?? '';
        return {'success': true};

      case 'loadConfig':
        final env = args['env'] as String? ?? 'default';
        return {'configJson': _configs[env]};

      case 'clearConfig':
        _configs.clear();
        return {'success': true};

      case 'appendAuditEntry':
        _auditLog.add(args['entryJson'] as String? ?? '');
        if (_auditLog.length > 50) _auditLog.removeAt(0);
        return {'success': true};

      case 'loadAuditLog':
        return {'entries': List<String>.from(_auditLog)};

      default:
        throw PlatformException(code: 'UNIMPLEMENTED', message: call.method);
    }
  }

  /// All audit entries stored so far.
  List<String> get auditEntries => List.unmodifiable(_auditLog);

  /// Clears all in-memory state.
  void reset() {
    _secrets.clear();
    _configs.clear();
    _auditLog.clear();
  }
}

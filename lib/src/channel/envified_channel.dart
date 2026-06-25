import 'package:flutter/services.dart';

import '../models/envified_exception.dart';

/// Thin async wrapper over the native method channel `in.appamania.envified/channel`.
///
/// All methods translate Dart-typed arguments to/from the platform codec and
/// re-throw [PlatformException] as typed [EnvifiedException] subclasses.
/// No business logic lives here — this is pure I/O translation.
class EnvifiedChannel {
  EnvifiedChannel({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('in.appamania.envified/channel');

  final MethodChannel _channel;

  // ── Key management ─────────────────────────────────────────────────────────

  /// Provisions an AES-256-GCM key in hardware for [env] if one does not exist.
  /// Returns the security level: `"strongbox"`, `"tee"`, `"secure_enclave"`, or `"software"`.
  Future<String> initialize({required String env}) async {
    final result =
        await _invoke<Map<Object?, Object?>>('initialize', {'env': env});
    return result['securityLevel'] as String? ?? 'software';
  }

  /// Returns the device security level without provisioning a key.
  Future<String> getDeviceSecurityLevel() async {
    final result =
        await _invoke<Map<Object?, Object?>>('getDeviceSecurityLevel', {});
    return result['level'] as String? ?? 'software';
  }

  /// Returns whether a Keystore/Keychain key exists for [alias].
  Future<bool> keyExists(String alias) async {
    final result =
        await _invoke<Map<Object?, Object?>>('keyExists', {'alias': alias});
    return result['exists'] as bool? ?? false;
  }

  // ── Encrypt / Decrypt ──────────────────────────────────────────────────────

  /// Encrypts [plaintext] under the [env] key using the provided [iv] (12 bytes).
  /// If [iv] is null, the native side generates one.
  ///
  /// Returns `{ciphertext, iv}`.
  Future<({Uint8List ciphertext, Uint8List iv})> encrypt({
    required Uint8List plaintext,
    required String env,
    Uint8List? iv,
  }) async {
    final args = <String, Object?>{
      'plaintext': plaintext,
      'env': env,
      if (iv != null) 'iv': iv,
    };
    final result = await _invoke<Map<Object?, Object?>>('encrypt', args);
    return (
      ciphertext: _toUint8List(result['ciphertext']),
      iv: _toUint8List(result['iv']),
    );
  }

  /// Decrypts [ciphertext] (with appended GCM tag) for [env].
  ///
  /// Throws [EnvifiedTamperException] if the GCM tag fails.
  Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required Uint8List iv,
    required String env,
    String keyId = 'default',
  }) async {
    final result = await _invoke<Map<Object?, Object?>>('decrypt', {
      'ciphertext': ciphertext,
      'iv': iv,
      'env': env,
      'keyId': keyId,
    });
    return _toUint8List(result['plaintext']);
  }

  // ── Secret storage ─────────────────────────────────────────────────────────

  /// Stores an encrypted blob under [keyId] for [env].
  Future<void> storeSecret({
    required String keyId,
    required Uint8List ciphertext,
    required Uint8List iv,
    required String env,
  }) async {
    await _invoke<Map<Object?, Object?>>('storeSecret', {
      'keyId': keyId,
      'ciphertext': ciphertext,
      'iv': iv,
      'env': env,
    });
  }

  /// Retrieves `{ciphertext, iv}` for [keyId]/[env].
  ///
  /// Returns null if the secret does not exist.
  Future<({Uint8List ciphertext, Uint8List iv})?> retrieveSecret({
    required String keyId,
    required String env,
  }) async {
    try {
      final result = await _invoke<Map<Object?, Object?>>('retrieveSecret', {
        'keyId': keyId,
        'env': env,
      });
      return (
        ciphertext: _toUint8List(result['ciphertext']),
        iv: _toUint8List(result['iv']),
      );
    } on EnvifiedNativeException catch (e) {
      if (e.code == 'ENVIFIED_KEY_NOT_FOUND') return null;
      rethrow;
    }
  }

  /// Deletes the secret stored under [keyId]/[env].
  Future<void> deleteSecret(
      {required String keyId, required String env}) async {
    await _invoke<Map<Object?, Object?>>('deleteSecret', {
      'keyId': keyId,
      'env': env,
    });
  }

  /// Deletes all secrets for [env]. Returns the number deleted.
  Future<int> deleteAllSecrets({required String env}) async {
    final result =
        await _invoke<Map<Object?, Object?>>('deleteAllSecrets', {'env': env});
    return result['deletedCount'] as int? ?? 0;
  }

  // ── Key rotation ───────────────────────────────────────────────────────────

  /// Re-encrypts all secrets for [env] under a new master key.
  ///
  /// Returns the number of secrets successfully migrated.
  Future<int> rotateKey({required String env}) async {
    final result =
        await _invoke<Map<Object?, Object?>>('rotateKey', {'env': env});
    return result['migratedCount'] as int? ?? 0;
  }

  // ── Config persistence ─────────────────────────────────────────────────────

  /// Persists the active [EnvConfig] as JSON for [env].
  Future<void> persistConfig(
      {required String configJson, required String env}) async {
    await _invoke<Map<Object?, Object?>>('persistConfig', {
      'configJson': configJson,
      'env': env,
    });
  }

  /// Loads the previously persisted config JSON. Returns null if none exists.
  Future<String?> loadConfig({required String env}) async {
    final result =
        await _invoke<Map<Object?, Object?>>('loadConfig', {'env': env});
    return result['configJson'] as String?;
  }

  /// Clears all persisted config entries.
  Future<void> clearConfig() async {
    await _invoke<Map<Object?, Object?>>('clearConfig', {});
  }

  // ── Audit log ──────────────────────────────────────────────────────────────

  /// Appends a JSON-encoded audit entry.
  Future<void> appendAuditEntry({required String entryJson}) async {
    await _invoke<Map<Object?, Object?>>(
        'appendAuditEntry', {'entryJson': entryJson});
  }

  /// Returns all persisted audit entries as JSON strings, oldest first.
  Future<List<String>> loadAuditLog() async {
    final result = await _invoke<Map<Object?, Object?>>('loadAuditLog', {});
    final entries = result['entries'];
    if (entries is List) return entries.cast<String>();
    return const [];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<T> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      final dynamic result = await _channel.invokeMethod<T>(method, args);
      if (result is T) return result;
      throw StateError(
          'Unexpected return type from $method: ${result.runtimeType}');
    } on PlatformException catch (e) {
      throw EnvifiedNativeException(
        code: e.code,
        message: e.message ?? 'Native error in $method',
      );
    }
  }

  static Uint8List _toUint8List(Object? value) {
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(value.cast<int>());
    throw StateError('Expected binary data, got ${value.runtimeType}');
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../channel/envified_channel.dart';

/// An opaque reference to a Tier-2 secret held in native secure storage.
///
/// The plaintext is *never* stored in a Dart field — it is decrypted
/// transiently inside [resolve] and the caller is responsible for using the
/// value immediately and not persisting it.
///
/// ```dart
/// final handle = SecretHandle(keyId: 'API_SECRET', env: 'prod');
/// // Access the value only within the callback scope:
/// final result = await handle.resolve(channel, (plaintext) async {
///   return await httpClient.post(url, headers: {'Authorization': plaintext});
/// });
/// ```
@immutable
class SecretHandle {
  final String keyId;
  final String env;

  const SecretHandle({required this.keyId, required this.env});

  /// Decrypts the secret and calls [action] with the plaintext.
  ///
  /// The plaintext [String] is constructed transiently and is not stored
  /// anywhere after [action] returns. Returns whatever [action] returns.
  Future<T> resolve<T>(
    EnvifiedChannel channel,
    Future<T> Function(String plaintext) action,
  ) async {
    final stored = await channel.retrieveSecret(keyId: keyId, env: env);
    if (stored == null) {
      throw StateError('SecretHandle: key "$keyId" not found for env "$env"');
    }
    final plainBytes = await channel.decrypt(
      ciphertext: stored.ciphertext,
      iv: stored.iv,
      env: env,
      keyId: keyId,
    );
    // Decode transiently — do not store in a variable that outlives this scope.
    return action(utf8.decode(plainBytes));
  }

  @override
  bool operator ==(Object other) =>
      other is SecretHandle && other.keyId == keyId && other.env == env;

  @override
  int get hashCode => Object.hash(keyId, env);

  @override
  String toString() => 'SecretHandle(keyId: $keyId, env: $env)';
}

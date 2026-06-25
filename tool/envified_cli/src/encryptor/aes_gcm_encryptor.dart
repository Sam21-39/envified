import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// CLI-side AES-256-GCM encryptor.
///
/// Keys are derived from a master key string via HKDF-SHA256.
/// The master key is read from the `ENVIFIED_MASTER_KEY` environment
/// variable (never written to disk in the project root).
///
/// Master key resolution order:
///   1. `ENVIFIED_MASTER_KEY` process env var.
///   2. `~/.envified_key` file (user home directory).
///   3. Interactive prompt (if [allowPrompt] is true).
class AesGcmEncryptor {
  static const int _keyBytes = 32; // AES-256
  static const int _ivBytes = 12; // GCM nonce

  final Uint8List _masterKey;

  AesGcmEncryptor._(this._masterKey);

  /// Resolves the master key and returns an encryptor instance.
  ///
  /// Throws [StateError] if no key is found and [allowPrompt] is false.
  factory AesGcmEncryptor.fromEnvironment({bool allowPrompt = false}) {
    final key = _resolveMasterKey(allowPrompt: allowPrompt);
    return AesGcmEncryptor._(key);
  }

  /// Encrypts [plaintext] with a per-env derived key.
  ///
  /// Returns [EncryptedPayload] containing base64-encoded ciphertext and IV.
  EncryptedPayload encrypt(String plaintext, {required String envName}) {
    final derivedKey = _deriveKey(envName);
    final iv = _randomBytes(_ivBytes);
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(derivedKey), 128, iv, Uint8List(0)),
      );

    final ciphertext = Uint8List(cipher.getOutputSize(plaintextBytes.length));
    var offset = cipher.processBytes(
        plaintextBytes, 0, plaintextBytes.length, ciphertext, 0);
    cipher.doFinal(ciphertext, offset);

    return EncryptedPayload(
      ciphertext: base64.encode(ciphertext),
      iv: base64.encode(iv),
      envName: envName,
    );
  }

  /// Decrypts an [EncryptedPayload].
  String decrypt(EncryptedPayload payload) {
    final derivedKey = _deriveKey(payload.envName);
    final iv = base64.decode(payload.iv);
    final ciphertext = Uint8List.fromList(base64.decode(payload.ciphertext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(derivedKey), 128, iv, Uint8List(0)),
      );

    final plaintext = Uint8List(cipher.getOutputSize(ciphertext.length));
    var offset =
        cipher.processBytes(ciphertext, 0, ciphertext.length, plaintext, 0);
    cipher.doFinal(plaintext, offset);

    return utf8.decode(plaintext);
  }

  // ── Key derivation ────────────────────────────────────────────────────────

  /// HKDF-SHA256 derives a 32-byte per-environment key from the master key.
  Uint8List _deriveKey(String envName) {
    final info = Uint8List.fromList(utf8.encode('envified:$envName'));
    final salt = Uint8List.fromList(utf8.encode('envified-v4'));
    return _hkdf(ikm: _masterKey, salt: salt, info: info, length: _keyBytes);
  }

  static Uint8List _hkdf({
    required Uint8List ikm,
    required Uint8List salt,
    required Uint8List info,
    required int length,
  }) {
    // Extract
    final prk = Hmac(sha256, salt).convert(ikm).bytes as Uint8List;
    // Expand
    final result = <int>[];
    var prev = Uint8List(0);
    var counter = 1;
    while (result.length < length) {
      final input = [...prev, ...info, counter++];
      prev = Hmac(sha256, prk).convert(input).bytes as Uint8List;
      result.addAll(prev);
    }
    return Uint8List.fromList(result.sublist(0, length));
  }

  // ── Master key resolution ─────────────────────────────────────────────────

  static Uint8List _resolveMasterKey({required bool allowPrompt}) {
    // 1. Process env var.
    final envKey = _envVarKey();
    if (envKey != null) return envKey;

    // 2. ~/.envified_key file.
    final fileKey = _homeFileKey();
    if (fileKey != null) return fileKey;

    // 3. Interactive prompt.
    if (allowPrompt) {
      stdout.write('Enter ENVIFIED_MASTER_KEY: ');
      final input = stdin.readLineSync() ?? '';
      if (input.isNotEmpty) return _stretchKey(input);
    }

    throw StateError(
      'ENVIFIED_MASTER_KEY not found. Set the environment variable, '
      'create ~/.envified_key, or run envified setup.',
    );
  }

  static Uint8List? _envVarKey() {
    final val = Platform.environment['ENVIFIED_MASTER_KEY'];
    if (val == null || val.isEmpty) return null;
    return _stretchKey(val);
  }

  static Uint8List? _homeFileKey() {
    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) return null;
      final file = File('$home/.envified_key');
      if (!file.existsSync()) return null;
      final val = file.readAsStringSync().trim();
      if (val.isEmpty) return null;
      return _stretchKey(val);
    } catch (_) {
      return null;
    }
  }

  /// SHA-256 stretches an arbitrary-length string to 32 bytes.
  static Uint8List _stretchKey(String key) =>
      Uint8List.fromList(sha256.convert(utf8.encode(key)).bytes);

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}

/// The result of encrypting a single value.
class EncryptedPayload {
  /// Base64-encoded AES-256-GCM ciphertext (with appended GCM tag).
  final String ciphertext;

  /// Base64-encoded 12-byte IV (nonce).
  final String iv;

  /// The environment name used for key derivation.
  final String envName;

  const EncryptedPayload({
    required this.ciphertext,
    required this.iv,
    required this.envName,
  });

  Map<String, String> toJson() => {
        'ciphertext': ciphertext,
        'iv': iv,
        'envName': envName,
      };

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) =>
      EncryptedPayload(
        ciphertext: json['ciphertext'] as String,
        iv: json['iv'] as String,
        envName: json['envName'] as String,
      );
}

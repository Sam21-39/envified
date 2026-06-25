import Foundation
import CryptoKit

/// AES-256-GCM encrypt/decrypt using CryptoKit.
///
/// The GCM combined ciphertext includes the authentication tag appended by CryptoKit.
/// Callers supply a 12-byte nonce; we do NOT generate it here.
internal enum EnvifiedCrypto {

    /// Encrypts [plaintext] with the Keychain key for [alias] and [nonce].
    ///
    /// - Returns: ciphertext with appended GCM tag (as produced by CryptoKit.AES.GCM).
    static func encrypt(plaintext: Data, alias: String, nonce: Data) throws -> Data {
        guard let key = try EnvifiedKeychain.loadKey(alias: alias) else {
            throw CryptoError.keyNotFound(alias)
        }
        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: gcmNonce)
        // CryptoKit's combined representation = nonce (12) + ciphertext + tag (16).
        // We strip the leading nonce so the Dart side only stores ciphertext+tag.
        let combined = sealed.combined!
        return combined.dropFirst(12) // drop nonce prefix
    }

    /// Decrypts [ciphertext] (ciphertext+tag without the nonce prefix) using the key for [alias].
    ///
    /// Throws [CryptoError.decryptFail] if the GCM tag is invalid.
    static func decrypt(ciphertext: Data, alias: String, nonce: Data) throws -> Data {
        guard let key = try EnvifiedKeychain.loadKey(alias: alias) else {
            throw CryptoError.keyNotFound(alias)
        }
        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        // Reconstruct the combined representation expected by CryptoKit.
        let combined = nonce + ciphertext
        let box = try AES.GCM.SealedBox(combined: combined)
        do {
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CryptoError.decryptFail
        }
    }

    enum CryptoError: Error {
        case keyNotFound(String)
        case decryptFail
    }
}

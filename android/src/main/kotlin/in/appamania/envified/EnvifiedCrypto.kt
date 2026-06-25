package `in`.appamania.envified

import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec

/**
 * AES-256-GCM encrypt/decrypt using keys held in [EnvifiedKeystore].
 *
 * The GCM authentication tag (16 bytes) is appended to the ciphertext.
 * Callers supply a 12-byte IV; we do NOT generate it here so that the
 * Dart side controls nonce derivation.
 */
internal object EnvifiedCrypto {

    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val TAG_LEN_BITS = 128

    /**
     * Encrypts [plaintext] using the Keystore key at [alias] with [iv] (12 bytes).
     *
     * @return ciphertext with GCM tag appended (ciphertext.length = plaintext.length + 16).
     */
    fun encrypt(plaintext: ByteArray, alias: String, iv: ByteArray): ByteArray {
        val key = EnvifiedKeystore.getKey(alias)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        val spec = GCMParameterSpec(TAG_LEN_BITS, iv)
        cipher.init(Cipher.ENCRYPT_MODE, key, spec)
        return cipher.doFinal(plaintext)
    }

    /**
     * Decrypts [ciphertext] (with appended GCM tag) using the Keystore key at [alias].
     *
     * Throws [javax.crypto.AEADBadTagException] if the tag fails — i.e., data was tampered.
     */
    fun decrypt(ciphertext: ByteArray, alias: String, iv: ByteArray): ByteArray {
        val key = EnvifiedKeystore.getKey(alias)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        val spec = GCMParameterSpec(TAG_LEN_BITS, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(ciphertext)
    }
}

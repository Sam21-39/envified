package `in`.appamania.envified

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore

/**
 * Manages AES-256-GCM keys in the Android Keystore.
 *
 * Prefers StrongBox-backed keys on API 28+ devices; silently falls back to
 * TEE-backed keys on devices that lack StrongBox.
 */
internal object EnvifiedKeystore {

    private const val PROVIDER = "AndroidKeyStore"

    /**
     * Generates an AES-256-GCM key in the Keystore under [alias], or no-ops
     * if the key already exists.
     *
     * @return "strongbox" if backed by StrongBox, "tee" otherwise.
     */
    fun generateKey(alias: String): String {
        if (keyExists(alias)) return getSecurityLevel(alias)

        val purposes = KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        val specBuilder = KeyGenParameterSpec.Builder(alias, purposes)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(false) // we supply our own IV

        // Attempt StrongBox on supported API levels.
        var strongBox = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                specBuilder.setIsStrongBoxBacked(true)
                strongBox = true
            } catch (_: Throwable) {
                // StrongBox not available; fall through to TEE.
                strongBox = false
            }
        }

        val spec = specBuilder.build()
        val generator = javax.crypto.KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, PROVIDER
        )
        try {
            generator.init(spec)
            generator.generateKey()
        } catch (e: Exception) {
            if (strongBox) {
                // StrongBox generation failed at runtime — retry without it.
                val fallbackSpec = KeyGenParameterSpec.Builder(alias, purposes)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setRandomizedEncryptionRequired(false)
                    .build()
                val fallbackGen = javax.crypto.KeyGenerator.getInstance(
                    KeyProperties.KEY_ALGORITHM_AES, PROVIDER
                )
                fallbackGen.init(fallbackSpec)
                fallbackGen.generateKey()
                return "tee"
            }
            throw e
        }

        return if (strongBox) "strongbox" else "tee"
    }

    /** Returns true if a key with [alias] exists in the Keystore. */
    fun keyExists(alias: String): Boolean {
        val ks = KeyStore.getInstance(PROVIDER).apply { load(null) }
        return ks.containsAlias(alias)
    }

    /** Deletes the key with [alias] from the Keystore. */
    fun deleteKey(alias: String): Boolean {
        val ks = KeyStore.getInstance(PROVIDER).apply { load(null) }
        if (!ks.containsAlias(alias)) return false
        ks.deleteEntry(alias)
        return true
    }

    /** Retrieves the AES SecretKey for [alias]. Throws if not found. */
    fun getKey(alias: String): javax.crypto.SecretKey {
        val ks = KeyStore.getInstance(PROVIDER).apply { load(null) }
        val entry = ks.getEntry(alias, null) as? KeyStore.SecretKeyEntry
            ?: throw IllegalStateException("Key '$alias' not found in Keystore")
        return entry.secretKey
    }

    /** Returns "strongbox" or "tee" for an existing key (best-effort). */
    private fun getSecurityLevel(alias: String): String {
        // We can't query StrongBox status on existing keys cheaply; return "tee" conservatively.
        return "tee"
    }
}

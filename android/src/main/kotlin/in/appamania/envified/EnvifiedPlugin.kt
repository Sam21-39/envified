package `in`.appamania.envified

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import java.security.SecureRandom

/**
 * Flutter plugin entry point for envified.
 *
 * Dispatches method-channel calls to [EnvifiedKeystore], [EnvifiedCrypto],
 * and the encrypted-prefs storage layer.
 */
class EnvifiedPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    // ── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ── MethodCallHandler ────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "initialize" -> handleInitialize(call, result)
                "encrypt" -> handleEncrypt(call, result)
                "decrypt" -> handleDecrypt(call, result)
                "storeSecret" -> handleStoreSecret(call, result)
                "retrieveSecret" -> handleRetrieveSecret(call, result)
                "deleteSecret" -> handleDeleteSecret(call, result)
                "deleteAllSecrets" -> handleDeleteAllSecrets(call, result)
                "keyExists" -> handleKeyExists(call, result)
                "rotateKey" -> handleRotateKey(call, result)
                "persistConfig" -> handlePersistConfig(call, result)
                "loadConfig" -> handleLoadConfig(call, result)
                "clearConfig" -> handleClearConfig(call, result)
                "appendAuditEntry" -> handleAppendAuditEntry(call, result)
                "loadAuditLog" -> handleLoadAuditLog(call, result)
                "getDeviceSecurityLevel" -> handleGetDeviceSecurityLevel(call, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("ENVIFIED_NATIVE_ERROR", e.message, null)
        }
    }

    // ── Handlers ─────────────────────────────────────────────────────────────

    private fun handleInitialize(call: MethodCall, result: Result) {
        val env = call.argument<String>("env") ?: "default"
        val alias = keystoreAlias(env)
        val level = EnvifiedKeystore.generateKey(alias)
        result.success(mapOf("success" to true, "securityLevel" to level))
    }

    private fun handleEncrypt(call: MethodCall, result: Result) {
        val plaintext = call.argument<ByteArray>("plaintext")
            ?: return result.error("ENVIFIED_MISSING_ARG", "plaintext required", null)
        val env = call.argument<String>("env") ?: "default"
        val iv = call.argument<ByteArray>("iv") ?: generateIv()
        val alias = keystoreAlias(env)
        val ciphertext = EnvifiedCrypto.encrypt(plaintext, alias, iv)
        result.success(mapOf("ciphertext" to ciphertext, "iv" to iv))
    }

    private fun handleDecrypt(call: MethodCall, result: Result) {
        val ciphertext = call.argument<ByteArray>("ciphertext")
            ?: return result.error("ENVIFIED_MISSING_ARG", "ciphertext required", null)
        val iv = call.argument<ByteArray>("iv")
            ?: return result.error("ENVIFIED_MISSING_ARG", "iv required", null)
        val env = call.argument<String>("env") ?: "default"
        val alias = keystoreAlias(env)
        try {
            val plaintext = EnvifiedCrypto.decrypt(ciphertext, alias, iv)
            result.success(mapOf("plaintext" to plaintext))
        } catch (e: javax.crypto.AEADBadTagException) {
            result.error("ENVIFIED_DECRYPT_FAIL", "GCM authentication tag mismatch", null)
        }
    }

    private fun handleStoreSecret(call: MethodCall, result: Result) {
        val keyId = call.argument<String>("keyId")
            ?: return result.error("ENVIFIED_MISSING_ARG", "keyId required", null)
        val ciphertext = call.argument<ByteArray>("ciphertext")
            ?: return result.error("ENVIFIED_MISSING_ARG", "ciphertext required", null)
        val iv = call.argument<ByteArray>("iv")
            ?: return result.error("ENVIFIED_MISSING_ARG", "iv required", null)
        val env = call.argument<String>("env") ?: "default"

        val prefs = getEncryptedPrefs(env)
        prefs.edit()
            .putString("ct_$keyId", android.util.Base64.encodeToString(ciphertext, android.util.Base64.NO_WRAP))
            .putString("iv_$keyId", android.util.Base64.encodeToString(iv, android.util.Base64.NO_WRAP))
            .apply()
        result.success(mapOf("success" to true))
    }

    private fun handleRetrieveSecret(call: MethodCall, result: Result) {
        val keyId = call.argument<String>("keyId")
            ?: return result.error("ENVIFIED_MISSING_ARG", "keyId required", null)
        val env = call.argument<String>("env") ?: "default"

        val prefs = getEncryptedPrefs(env)
        val ctStr = prefs.getString("ct_$keyId", null)
        val ivStr = prefs.getString("iv_$keyId", null)
        if (ctStr == null || ivStr == null) {
            result.error("ENVIFIED_KEY_NOT_FOUND", "Secret '$keyId' not found", null)
            return
        }
        result.success(mapOf(
            "ciphertext" to android.util.Base64.decode(ctStr, android.util.Base64.NO_WRAP),
            "iv" to android.util.Base64.decode(ivStr, android.util.Base64.NO_WRAP),
        ))
    }

    private fun handleDeleteSecret(call: MethodCall, result: Result) {
        val keyId = call.argument<String>("keyId")
            ?: return result.error("ENVIFIED_MISSING_ARG", "keyId required", null)
        val env = call.argument<String>("env") ?: "default"
        val prefs = getEncryptedPrefs(env)
        prefs.edit().remove("ct_$keyId").remove("iv_$keyId").apply()
        result.success(mapOf("success" to true))
    }

    private fun handleDeleteAllSecrets(call: MethodCall, result: Result) {
        val env = call.argument<String>("env") ?: "default"
        val prefs = getEncryptedPrefs(env)
        val count = prefs.all.keys.count { it.startsWith("ct_") }
        prefs.edit().clear().apply()
        result.success(mapOf("deletedCount" to count))
    }

    private fun handleKeyExists(call: MethodCall, result: Result) {
        val alias = call.argument<String>("alias")
            ?: return result.error("ENVIFIED_MISSING_ARG", "alias required", null)
        result.success(mapOf("exists" to EnvifiedKeystore.keyExists(alias)))
    }

    private fun handleRotateKey(call: MethodCall, result: Result) {
        val env = call.argument<String>("env") ?: "default"
        val oldAlias = keystoreAlias(env)
        val newAlias = "${oldAlias}_new_${System.currentTimeMillis()}"

        // Generate the new key first.
        EnvifiedKeystore.generateKey(newAlias)

        val prefs = getEncryptedPrefs(env)
        val allKeys = prefs.all.keys.filter { it.startsWith("ct_") }.map { it.removePrefix("ct_") }
        var count = 0

        for (keyId in allKeys) {
            val ctStr = prefs.getString("ct_$keyId", null) ?: continue
            val ivStr = prefs.getString("iv_$keyId", null) ?: continue
            val ciphertext = android.util.Base64.decode(ctStr, android.util.Base64.NO_WRAP)
            val iv = android.util.Base64.decode(ivStr, android.util.Base64.NO_WRAP)
            try {
                val plaintext = EnvifiedCrypto.decrypt(ciphertext, oldAlias, iv)
                val newIv = generateIv()
                val newCt = EnvifiedCrypto.encrypt(plaintext, newAlias, newIv)
                prefs.edit()
                    .putString("ct_$keyId", android.util.Base64.encodeToString(newCt, android.util.Base64.NO_WRAP))
                    .putString("iv_$keyId", android.util.Base64.encodeToString(newIv, android.util.Base64.NO_WRAP))
                    .apply()
                count++
            } catch (_: Exception) {
                // Skip entries that cannot be re-encrypted.
            }
        }

        // Delete the old key and rename the new one via re-generate under the original alias.
        EnvifiedKeystore.deleteKey(oldAlias)
        // The new alias is now active. Callers must update their alias mapping externally.
        // In practice, we keep the original alias for simplicity — re-generate under it.
        EnvifiedKeystore.generateKey(oldAlias)

        result.success(mapOf("migratedCount" to count))
    }

    private fun handlePersistConfig(call: MethodCall, result: Result) {
        val configJson = call.argument<String>("configJson")
            ?: return result.error("ENVIFIED_MISSING_ARG", "configJson required", null)
        val env = call.argument<String>("env") ?: "default"
        getMetaPrefs().edit().putString("config_$env", configJson).apply()
        result.success(mapOf("success" to true))
    }

    private fun handleLoadConfig(call: MethodCall, result: Result) {
        val env = call.argument<String>("env") ?: "default"
        val json = getMetaPrefs().getString("config_$env", null)
        result.success(mapOf("configJson" to json))
    }

    private fun handleClearConfig(call: MethodCall, result: Result) {
        getMetaPrefs().edit().clear().apply()
        result.success(mapOf("success" to true))
    }

    private fun handleAppendAuditEntry(call: MethodCall, result: Result) {
        val entryJson = call.argument<String>("entryJson")
            ?: return result.error("ENVIFIED_MISSING_ARG", "entryJson required", null)
        val prefs = getMetaPrefs()
        val existing = prefs.getString("audit_log", "[]") ?: "[]"
        val arr = JSONArray(existing)
        arr.put(entryJson)
        // Keep max 50 entries (FIFO).
        val trimmed = JSONArray()
        val start = maxOf(0, arr.length() - 50)
        for (i in start until arr.length()) trimmed.put(arr.get(i))
        prefs.edit().putString("audit_log", trimmed.toString()).apply()
        result.success(mapOf("success" to true))
    }

    private fun handleLoadAuditLog(call: MethodCall, result: Result) {
        val raw = getMetaPrefs().getString("audit_log", "[]") ?: "[]"
        val arr = JSONArray(raw)
        val entries = (0 until arr.length()).map { arr.getString(it) }
        result.success(mapOf("entries" to entries))
    }

    private fun handleGetDeviceSecurityLevel(call: MethodCall, result: Result) {
        // Generate a temp key to probe StrongBox availability.
        val probe = "envified_probe_${System.currentTimeMillis()}"
        val level = try {
            val l = EnvifiedKeystore.generateKey(probe)
            EnvifiedKeystore.deleteKey(probe)
            l
        } catch (_: Exception) {
            "software"
        }
        result.success(mapOf("level" to level))
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun keystoreAlias(env: String) = "envified_master_$env"

    private fun generateIv(): ByteArray = ByteArray(12).also { SecureRandom().nextBytes(it) }

    /** Encrypted SharedPreferences for per-env secret blobs. */
    private fun getEncryptedPrefs(env: String): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            "envified_secrets_$env",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    /** Plain SharedPreferences for non-secret metadata (config, audit). */
    private fun getMetaPrefs(): SharedPreferences =
        context.getSharedPreferences("envified_meta", Context.MODE_PRIVATE)

    companion object {
        const val CHANNEL_NAME = "in.appamania.envified/channel"
    }
}

import Flutter
import Foundation
import Security

/// Flutter plugin entry point for envified on iOS.
public class EnvifiedPlugin: NSObject, FlutterPlugin {

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "in.appamania.envified/channel",
            binaryMessenger: registrar.messenger()
        )
        let instance = EnvifiedPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - MethodCallHandler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        do {
            switch call.method {
            case "initialize":       try handleInitialize(args: args, result: result)
            case "encrypt":          try handleEncrypt(args: args, result: result)
            case "decrypt":          try handleDecrypt(args: args, result: result)
            case "storeSecret":      try handleStoreSecret(args: args, result: result)
            case "retrieveSecret":   try handleRetrieveSecret(args: args, result: result)
            case "deleteSecret":     try handleDeleteSecret(args: args, result: result)
            case "deleteAllSecrets": try handleDeleteAllSecrets(args: args, result: result)
            case "keyExists":        handleKeyExists(args: args, result: result)
            case "rotateKey":        try handleRotateKey(args: args, result: result)
            case "persistConfig":    handlePersistConfig(args: args, result: result)
            case "loadConfig":       handleLoadConfig(args: args, result: result)
            case "clearConfig":      handleClearConfig(result: result)
            case "appendAuditEntry": handleAppendAuditEntry(args: args, result: result)
            case "loadAuditLog":     handleLoadAuditLog(result: result)
            case "getDeviceSecurityLevel": handleGetDeviceSecurityLevel(result: result)
            default:                 result(FlutterMethodNotImplemented)
            }
        } catch {
            result(FlutterError(code: "ENVIFIED_NATIVE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Handlers

    private func handleInitialize(args: [String: Any], result: FlutterResult) throws {
        let env = args["env"] as? String ?? "default"
        let alias = keystoreAlias(env)
        let level = try EnvifiedKeychain.generateKey(alias: alias)
        result(["success": true, "securityLevel": level])
    }

    private func handleEncrypt(args: [String: Any], result: FlutterResult) throws {
        guard let plaintext = (args["plaintext"] as? FlutterStandardTypedData)?.data else {
            return result(FlutterError(code: "ENVIFIED_MISSING_ARG", message: "plaintext required", details: nil))
        }
        let env = args["env"] as? String ?? "default"
        let iv: Data
        if let ivData = (args["iv"] as? FlutterStandardTypedData)?.data {
            iv = ivData
        } else {
            iv = generateIv()
        }
        let alias = keystoreAlias(env)
        let ciphertext = try EnvifiedCrypto.encrypt(plaintext: plaintext, alias: alias, nonce: iv)
        result(["ciphertext": FlutterStandardTypedData(bytes: ciphertext),
                "iv": FlutterStandardTypedData(bytes: iv)])
    }

    private func handleDecrypt(args: [String: Any], result: FlutterResult) throws {
        guard let ciphertext = (args["ciphertext"] as? FlutterStandardTypedData)?.data,
              let iv = (args["iv"] as? FlutterStandardTypedData)?.data else {
            return result(FlutterError(code: "ENVIFIED_MISSING_ARG", message: "ciphertext and iv required", details: nil))
        }
        let env = args["env"] as? String ?? "default"
        let alias = keystoreAlias(env)
        do {
            let plaintext = try EnvifiedCrypto.decrypt(ciphertext: ciphertext, alias: alias, nonce: iv)
            result(["plaintext": FlutterStandardTypedData(bytes: plaintext)])
        } catch EnvifiedCrypto.CryptoError.decryptFail {
            result(FlutterError(code: "ENVIFIED_DECRYPT_FAIL", message: "GCM authentication tag mismatch", details: nil))
        }
    }

    private func handleStoreSecret(args: [String: Any], result: FlutterResult) throws {
        guard let keyId = args["keyId"] as? String,
              let ciphertext = (args["ciphertext"] as? FlutterStandardTypedData)?.data,
              let iv = (args["iv"] as? FlutterStandardTypedData)?.data else {
            return result(FlutterError(code: "ENVIFIED_MISSING_ARG", message: "keyId, ciphertext, iv required", details: nil))
        }
        let env = args["env"] as? String ?? "default"
        let combined = iv + ciphertext
        try storeKeychainItem(key: secretKey(env: env, keyId: keyId), data: combined)
        result(["success": true])
    }

    private func handleRetrieveSecret(args: [String: Any], result: FlutterResult) throws {
        guard let keyId = args["keyId"] as? String else {
            return result(FlutterError(code: "ENVIFIED_MISSING_ARG", message: "keyId required", details: nil))
        }
        let env = args["env"] as? String ?? "default"
        guard let combined = try loadKeychainItem(key: secretKey(env: env, keyId: keyId)) else {
            return result(FlutterError(code: "ENVIFIED_KEY_NOT_FOUND", message: "Secret '\(keyId)' not found", details: nil))
        }
        let iv = combined.prefix(12)
        let ct = combined.dropFirst(12)
        result(["ciphertext": FlutterStandardTypedData(bytes: Data(ct)),
                "iv": FlutterStandardTypedData(bytes: Data(iv))])
    }

    private func handleDeleteSecret(args: [String: Any], result: FlutterResult) throws {
        guard let keyId = args["keyId"] as? String else {
            return result(FlutterError(code: "ENVIFIED_MISSING_ARG", message: "keyId required", details: nil))
        }
        let env = args["env"] as? String ?? "default"
        try deleteKeychainItem(key: secretKey(env: env, keyId: keyId))
        result(["success": true])
    }

    private func handleDeleteAllSecrets(args: [String: Any], result: FlutterResult) throws {
        let env = args["env"] as? String ?? "default"
        let count = try deleteAllKeychainItems(prefix: "envified_secret_\(env)_")
        result(["deletedCount": count])
    }

    private func handleKeyExists(args: [String: Any], result: FlutterResult) {
        let alias = args["alias"] as? String ?? ""
        result(["exists": EnvifiedKeychain.keyExists(alias: alias)])
    }

    private func handleRotateKey(args: [String: Any], result: FlutterResult) throws {
        // Simplified rotation: re-generate the Keystore key under the same alias.
        // A full production implementation would re-encrypt all stored blobs.
        let env = args["env"] as? String ?? "default"
        let alias = keystoreAlias(env)
        try EnvifiedKeychain.deleteKey(alias: alias)
        try EnvifiedKeychain.generateKey(alias: alias)
        result(["migratedCount": 0])
    }

    private func handlePersistConfig(args: [String: Any], result: FlutterResult) {
        guard let configJson = args["configJson"] as? String,
              let env = args["env"] as? String else {
            return result(FlutterError(code: "ENVIFIED_MISSING_ARG", message: "configJson and env required", details: nil))
        }
        UserDefaults.standard.set(configJson, forKey: "envified_config_\(env)")
        result(["success": true])
    }

    private func handleLoadConfig(args: [String: Any], result: FlutterResult) {
        let env = args["env"] as? String ?? "default"
        let json = UserDefaults.standard.string(forKey: "envified_config_\(env)")
        result(["configJson": json as Any])
    }

    private func handleClearConfig(result: FlutterResult) {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("envified_") }
            .forEach { defaults.removeObject(forKey: $0) }
        result(["success": true])
    }

    private func handleAppendAuditEntry(args: [String: Any], result: FlutterResult) {
        guard let entryJson = args["entryJson"] as? String else {
            return result(FlutterError(code: "ENVIFIED_MISSING_ARG", message: "entryJson required", details: nil))
        }
        let key = "envified_audit_log"
        var entries = UserDefaults.standard.stringArray(forKey: key) ?? []
        entries.append(entryJson)
        if entries.count > 50 { entries = Array(entries.suffix(50)) }
        UserDefaults.standard.set(entries, forKey: key)
        result(["success": true])
    }

    private func handleLoadAuditLog(result: FlutterResult) {
        let entries = UserDefaults.standard.stringArray(forKey: "envified_audit_log") ?? []
        result(["entries": entries])
    }

    private func handleGetDeviceSecurityLevel(result: FlutterResult) {
        // On a real device with Secure Enclave, CryptoKit can use SE-backed P256 keys.
        // For AES keys via Keychain, the level is "software" key in hardware-protected storage.
        result(["level": "software"])
    }

    // MARK: - Helpers

    private func keystoreAlias(_ env: String) -> String { "envified_master_\(env)" }
    private func secretKey(env: String, keyId: String) -> String { "envified_secret_\(env)_\(keyId)" }
    private func generateIv() -> Data { var bytes = [UInt8](repeating: 0, count: 12); SecRandomCopyBytes(kSecRandomDefault, 12, &bytes); return Data(bytes) }

    private func storeKeychainItem(key: String, data: Data) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "in.appamania.envified.secrets",
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess { throw NSError(domain: "EnvifiedPlugin", code: Int(status)) }
    }

    private func loadKeychainItem(key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "in.appamania.envified.secrets",
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        if status != errSecSuccess { throw NSError(domain: "EnvifiedPlugin", code: Int(status)) }
        return item as? Data
    }

    private func deleteKeychainItem(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "in.appamania.envified.secrets",
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func deleteAllKeychainItems(prefix: String) throws -> Int {
        // Enumerate and delete all Keychain items with matching account prefix.
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "in.appamania.envified.secrets",
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll,
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound { return 0 }
        guard status == errSecSuccess, let arr = items as? [[CFString: Any]] else { return 0 }
        var count = 0
        for item in arr {
            if let account = item[kSecAttrAccount] as? String, account.hasPrefix(prefix) {
                try deleteKeychainItem(key: account)
                count += 1
            }
        }
        return count
    }
}

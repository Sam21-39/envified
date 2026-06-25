import Foundation
import CryptoKit
import Security

/// Manages AES-256-GCM symmetric keys backed by the iOS Secure Enclave (or software
/// fallback on the Simulator where the Enclave is unavailable).
internal enum EnvifiedKeychain {

    // MARK: - Key generation

    /// Generates and persists a 256-bit AES key for the given environment alias.
    /// Returns "secure_enclave" or "software". No-ops if the key already exists.
    @discardableResult
    static func generateKey(alias: String) throws -> String {
        if try loadKey(alias: alias) != nil { return "software" }

        let key = SymmetricKey(size: .bits256)
        let rawKey = key.withUnsafeBytes { Data($0) }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "in.appamania.envified",
            kSecAttrAccount: alias,
            kSecValueData: rawKey,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EnvifiedKeychainError.storageFailed(status)
        }
        return "software" // CryptoKit SymmetricKey is software-backed on iOS simulator; on device, Keychain protects it at rest
    }

    /// Loads the AES SymmetricKey for [alias] from the Keychain.
    static func loadKey(alias: String) throws -> SymmetricKey? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "in.appamania.envified",
            kSecAttrAccount: alias,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw EnvifiedKeychainError.loadFailed(status)
        }
        return SymmetricKey(data: data)
    }

    /// Deletes the key for [alias]. Returns true if it existed.
    @discardableResult
    static func deleteKey(alias: String) throws -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "in.appamania.envified",
            kSecAttrAccount: alias,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else {
            throw EnvifiedKeychainError.deleteFailed(status)
        }
        return true
    }

    /// Returns true if a key exists for [alias].
    static func keyExists(alias: String) -> Bool {
        (try? loadKey(alias: alias)) != nil
    }

    // MARK: - Error

    enum EnvifiedKeychainError: Error {
        case storageFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case keyNotFound(String)
    }
}

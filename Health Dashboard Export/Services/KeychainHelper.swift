//
//  KeychainHelper.swift
//  Health Dashboard Export
//
//  Created by Mike Neuwirth on 2/25/26.
//

import Foundation
import Security

protocol KeychainStoring {
    func save(key: String, value: String) throws
    func load(key: String) throws -> String?
    func delete(key: String) throws
    func exists(key: String) -> Bool
}

/// Secure storage for API keys using iOS Keychain Services
/// Keys are stored device-specific (no iCloud sync)
class KeychainHelper: KeychainStoring {
    static let shared = KeychainHelper()
    
    private let service = "com.healthexport.apikey"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Save a value to the Keychain
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The string value to store
    /// - Throws: KeychainError if save fails
    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Delete existing item if present
        try? delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly // Device-specific, no iCloud sync
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
        
        print("✓ Saved '\(key)' to Keychain")
    }
    
    /// Load a value from the Keychain
    /// - Parameter key: The key to retrieve
    /// - Returns: The stored string value, or nil if not found
    /// - Throws: KeychainError if load fails
    func load(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return value
    }
    
    /// Delete a value from the Keychain
    /// - Parameter key: The key to delete
    /// - Throws: KeychainError if delete fails
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // errSecItemNotFound is not an error for delete
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
        
        print("✓ Deleted '\(key)' from Keychain")
    }
    
    /// Check if a key exists in the Keychain
    /// - Parameter key: The key to check
    /// - Returns: true if the key exists, false otherwise
    func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case invalidData
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Failed to encode/decode Keychain data"
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .loadFailed(let status):
            return "Failed to load from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}

import Foundation
import CryptoKit

class EncryptionManager {
    static let shared = EncryptionManager()
    
    private let keychainService = "com.uluer.Whispr.encryption"
    private let keychainAccount = "folderEncryptionKey"
    
    private init() {}
    
    // Get or create encryption key from Keychain
    private func getEncryptionKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            if let data = result as? Data {
                return SymmetricKey(data: data)
            }
        }
        
        // Create new key if not found
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData
        ]
        
        SecItemDelete(query as CFDictionary)
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard addStatus == errSecSuccess else {
            throw EncryptionError.keychainError
        }
        
        return newKey
    }
    
    // Encrypt ClipboardItem data
    func encryptItem(_ item: ClipboardItem) throws -> Data {
        let encoder = JSONEncoder()
        let itemData = try encoder.encode(item)
        
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.seal(itemData, using: key)
        
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return encryptedData
    }
    
    // Decrypt ClipboardItem data
    func decryptItem(_ encryptedData: Data) throws -> ClipboardItem {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        let decoder = JSONDecoder()
        return try decoder.decode(ClipboardItem.self, from: decryptedData)
    }
    
    // Encrypt array of ClipboardItems
    func encryptItems(_ items: [ClipboardItem]) throws -> Data {
        let encoder = JSONEncoder()
        let itemsData = try encoder.encode(items)
        
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.seal(itemsData, using: key)
        
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return encryptedData
    }
    
    // Decrypt array of ClipboardItems
    func decryptItems(_ encryptedData: Data) throws -> [ClipboardItem] {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        let decoder = JSONDecoder()
        return try decoder.decode([ClipboardItem].self, from: decryptedData)
    }
}

enum EncryptionError: Error {
    case keychainError
    case encryptionFailed
    case decryptionFailed
    case invalidData
}

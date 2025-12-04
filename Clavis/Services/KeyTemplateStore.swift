//
//  KeyTemplateStore.swift
//  Clavis
//
//  Created on 12/26/25.
//

import Foundation
import Security

/// Service for securely storing and retrieving KeyTemplate data in the Keychain.
class KeyTemplateStore {
    static let shared = KeyTemplateStore()
    
    private let serviceName = "com.clavis.keytemplates"
    
    private init() {}
    
    /// Saves a KeyTemplate to the Keychain.
    /// - Parameter template: The template to save
    /// - Returns: True if save succeeded
    func save(_ template: KeyTemplate) -> Bool {
        guard let data = encodeTemplate(template) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: template.id.uuidString,
            kSecValueData as String: data
        ]
        
        // Delete existing item if present
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Loads a KeyTemplate from the Keychain by ID.
    /// - Parameter id: The template ID
    /// - Returns: The template if found, nil otherwise
    func load(id: UUID) -> KeyTemplate? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let template = decodeTemplate(data) else {
            return nil
        }
        
        return template
    }
    
    /// Loads all KeyTemplates from the Keychain.
    /// - Returns: Array of all stored templates
    func loadAll() -> [KeyTemplate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        var templates: [KeyTemplate] = []
        for item in items {
            guard let data = item[kSecValueData as String] as? Data,
                  let template = decodeTemplate(data) else {
                continue
            }
            templates.append(template)
        }
        
        return templates
    }
    
    /// Deletes a KeyTemplate from the Keychain.
    /// - Parameter id: The template ID to delete
    /// - Returns: True if deletion succeeded
    func delete(id: UUID) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: id.uuidString
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Encodes a KeyTemplate to Data for Keychain storage.
    private func encodeTemplate(_ template: KeyTemplate) -> Data? {
        // Convert feature vectors to a serializable format
        let encoder = JSONEncoder()
        do {
            return try encoder.encode(template)
        } catch {
            print("Failed to encode template: \(error)")
            return nil
        }
    }
    
    /// Decodes a KeyTemplate from Data.
    private func decodeTemplate(_ data: Data) -> KeyTemplate? {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(KeyTemplate.self, from: data)
        } catch {
            print("Failed to decode template: \(error)")
            return nil
        }
    }
}


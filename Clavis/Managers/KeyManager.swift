//
//  KeyManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages all keys (physical objects) that can be used across modes.
/// Keys can be assigned as main keys or temporary keys for different modes.
/// Implements responsibilities from SPEC §5.1 KeyManager (refactored for per-mode keys).
class KeyManager: ObservableObject {
    /// All enrolled keys, indexed by key ID.
    @Published private(set) var keys: [UUID: Key] = [:]
    
    init() {
        // TODO: Load all keys from secure storage (Keychain) on init
    }
    
    /// Gets a key by ID.
    func getKey(_ keyId: UUID) -> Key? {
        keys[keyId]
    }
    
    /// Gets all keys.
    var allKeys: [Key] {
        Array(keys.values)
    }
    
    /// Enrolls a new key from multiple camera images.
    /// - Parameters:
    ///   - images: Array of images captured from different angles during enrollment
    ///   - name: Optional user-friendly name for the key
    /// - Returns: The enrolled Key
    func enrollKey(from images: [Data], name: String? = nil) async throws -> Key {
        // TODO: Extract feature vectors from images using Vision/CoreML
        // TODO: Validate images (brightness, blur, distinctiveness)
        // TODO: Store feature vectors securely in Keychain
        // TODO: Store enrollment date
        
        let featureVectors = images.map { _ in
            KeyFeatureVector(data: []) // Placeholder - will be replaced with actual feature extraction
        }
        
        let template = KeyTemplate(featureVectors: featureVectors)
        let key = Key(template: template, name: name)
        keys[key.id] = key
        
        // TODO: Persist key to secure storage
        return key
    }
    
    /// Verifies a scan against a specific key.
    /// - Parameters:
    ///   - keyId: The ID of the key to verify against
    ///   - scanImage: Image data from current camera frame
    /// - Returns: KeyScanResult indicating match status and confidence
    func verifyKeyScan(_ keyId: UUID, scanImage: Data) async -> KeyScanResult {
        guard keys[keyId] != nil else {
            return .noMatch(errorReason: .unknown)
        }
        
        // TODO: Extract feature vector from scanImage using Vision/CoreML
        // TODO: Get the key using keys[keyId] and compare against stored feature vectors in key.template
        // TODO: Calculate similarity score and apply threshold to determine match
        // TODO: Check for blur, low light, etc. and return appropriate error reasons
        
        // Placeholder implementation
        return .noMatch(confidenceScore: 0.0, errorReason: .unknown)
    }
    
    /// Updates a key's name.
    func updateKeyName(_ keyId: UUID, name: String?) {
        guard var key = keys[keyId] else { return }
        key.name = name
        keys[keyId] = key
        // TODO: Persist key to secure storage
    }
    
    /// Removes a key.
    /// Note: This does not remove the key from modes that reference it.
    /// The caller should handle cleaning up mode references first.
    func removeKey(_ keyId: UUID) {
        keys.removeValue(forKey: keyId)
        // TODO: Delete key template from secure storage (Keychain)
    }
    
    /// Checks if a key exists.
    func hasKey(_ keyId: UUID) -> Bool {
        keys[keyId] != nil
    }
}

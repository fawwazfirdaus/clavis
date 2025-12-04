//
//  Mode.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation

/// Represents a user-defined mode (e.g., Work Mode, Sleep Mode, Study Mode).
/// Implements data structures from SPEC §5.2 ModeManager.
struct Mode: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    /// Reference to this mode's main key (required, mode-specific).
    var mainKeyId: UUID
    /// References to this mode's temporary keys (optional, multiple allowed).
    /// The same key can be used as a temporary key for multiple modes.
    var temporaryKeyIds: [UUID]
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        mainKeyId: UUID,
        temporaryKeyIds: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.mainKeyId = mainKeyId
        self.temporaryKeyIds = temporaryKeyIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    mutating func updateName(_ newName: String) {
        self.name = newName
        self.updatedAt = Date()
    }
    
    mutating func setMainKey(_ keyId: UUID) {
        self.mainKeyId = keyId
        self.updatedAt = Date()
    }
    
    mutating func addTemporaryKey(_ keyId: UUID) {
        if !temporaryKeyIds.contains(keyId) {
            temporaryKeyIds.append(keyId)
            self.updatedAt = Date()
        }
    }
    
    mutating func removeTemporaryKey(_ keyId: UUID) {
        temporaryKeyIds.removeAll { $0 == keyId }
        self.updatedAt = Date()
    }
    
    func hasTemporaryKey(_ keyId: UUID) -> Bool {
        temporaryKeyIds.contains(keyId)
    }
}



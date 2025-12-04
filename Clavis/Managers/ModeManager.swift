//
//  ModeManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages multiple modes and their configurations.
/// Implements responsibilities from SPEC §5.2 ModeManager.
class ModeManager: ObservableObject {
    @Published private(set) var modes: [Mode] = []
    @Published private(set) var activeModeId: UUID?
    
    init() {
        // TODO: Load modes from UserDefaults/persistent storage on init
        // TODO: Load active mode ID from UserDefaults on init
    }
    
    /// The currently active mode, if any.
    var activeMode: Mode? {
        guard let activeModeId = activeModeId else { return nil }
        return modes.first { $0.id == activeModeId }
    }
    
    /// Adds a new mode.
    func addMode(_ mode: Mode) {
        modes.append(mode)
        // If this is the first mode, make it active
        if activeModeId == nil {
            activeModeId = mode.id
        }
        // TODO: Persist modes to UserDefaults/persistent storage
    }
    
    /// Creates and adds a new mode with the given name.
    /// - Parameters:
    ///   - name: The name of the mode
    ///   - mainKeyId: The main key ID for this mode (required)
    ///   - temporaryKeyIds: Optional array of temporary key IDs for this mode
    func createMode(name: String, mainKeyId: UUID, temporaryKeyIds: [UUID] = []) -> Mode {
        let mode = Mode(name: name, mainKeyId: mainKeyId, temporaryKeyIds: temporaryKeyIds)
        addMode(mode)
        return mode
    }
    
    /// Sets the main key ID for a specific mode.
    func setMainKey(for modeId: UUID, mainKeyId: UUID) {
        guard let index = modes.firstIndex(where: { $0.id == modeId }) else {
            return
        }
        modes[index].setMainKey(mainKeyId)
        // TODO: Persist modes to UserDefaults/persistent storage
    }
    
    /// Adds a temporary key to a specific mode.
    func addTemporaryKey(to modeId: UUID, keyId: UUID) {
        guard let index = modes.firstIndex(where: { $0.id == modeId }) else {
            return
        }
        modes[index].addTemporaryKey(keyId)
        // TODO: Persist modes to UserDefaults/persistent storage
    }
    
    /// Removes a temporary key from a specific mode.
    func removeTemporaryKey(from modeId: UUID, keyId: UUID) {
        guard let index = modes.firstIndex(where: { $0.id == modeId }) else {
            return
        }
        modes[index].removeTemporaryKey(keyId)
        // TODO: Persist modes to UserDefaults/persistent storage
    }
    
    /// Updates an existing mode.
    func updateMode(_ mode: Mode) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else {
            return
        }
        var updatedMode = mode
        updatedMode.updatedAt = Date()
        modes[index] = updatedMode
        // TODO: Persist modes to UserDefaults/persistent storage
    }
    
    /// Removes a mode.
    func removeMode(_ modeId: UUID) {
        modes.removeAll { $0.id == modeId }
        // If the removed mode was active, switch to first available mode or nil
        if activeModeId == modeId {
            activeModeId = modes.first?.id
        }
        // TODO: Persist modes to UserDefaults/persistent storage
        // TODO: Clean up associated app profile and temporary key for this mode
    }
    
    /// Sets the active mode.
    /// Note: If a mode is locked, the caller should handle updating lock state/Focus Mode accordingly.
    func setActiveMode(_ modeId: UUID) {
        guard modes.contains(where: { $0.id == modeId }) else {
            return
        }
        activeModeId = modeId
        // TODO: Persist active mode ID to UserDefaults
        // TODO: If mode is currently locked, notify LockStateManager to handle mode switch
    }
    
    /// Gets a mode by ID.
    func getMode(_ modeId: UUID) -> Mode? {
        modes.first { $0.id == modeId }
    }
}


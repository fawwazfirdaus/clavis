//
//  TemporaryKeyManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages temporary key usage tracking for each mode.
/// Tracks which temporary keys have been used per lock cycle per mode.
/// Implements responsibilities from SPEC §5.5 TemporaryKeyManager (refactored for multiple temporary keys).
class TemporaryKeyManager: ObservableObject {
    /// Maps (modeId, keyId) to whether that temporary key has been used in current lock cycle
    @Published private(set) var temporaryKeyUsage: [ModeKeyPair: Bool] = [:]
    
    init() {
        // TODO: Load temporary key usage state from UserDefaults on init
    }
    
    /// Checks if a temporary key has been used in current lock cycle for a mode.
    func isTemporaryKeyUsed(modeId: UUID, keyId: UUID) -> Bool {
        temporaryKeyUsage[ModeKeyPair(modeId: modeId, keyId: keyId)] ?? false
    }
    
    /// Marks a temporary key as used for a mode (one-time use per lock cycle).
    func markTemporaryKeyUsed(modeId: UUID, keyId: UUID) {
        temporaryKeyUsage[ModeKeyPair(modeId: modeId, keyId: keyId)] = true
        // TODO: Persist usage state to UserDefaults
    }
    
    /// Resets temporary key usage for a mode (called when mode is unlocked).
    func resetTemporaryKeyUsage(for modeId: UUID) {
        temporaryKeyUsage = temporaryKeyUsage.filter { $0.key.modeId != modeId }
        // TODO: Persist usage state to UserDefaults
    }
    
    /// Resets usage for a specific temporary key in a mode.
    func resetTemporaryKeyUsage(modeId: UUID, keyId: UUID) {
        temporaryKeyUsage.removeValue(forKey: ModeKeyPair(modeId: modeId, keyId: keyId))
        // TODO: Persist usage state to UserDefaults
    }
}

/// Represents a pair of mode ID and key ID for tracking temporary key usage.
struct ModeKeyPair: Hashable, Codable {
    let modeId: UUID
    let keyId: UUID
}

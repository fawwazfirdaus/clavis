//
//  LockState.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation

/// Represents the current lock state for the active mode.
/// Implements data structures from SPEC §5.3 LockStateManager.
struct LockState: Codable {
    var isLocked: Bool
    var lockedModeId: UUID?
    var lockedAt: Date?
    var unlockedAt: Date?
    var temporaryUnlockState: TemporaryUnlockState
    
    init(
        isLocked: Bool = false,
        lockedModeId: UUID? = nil,
        lockedAt: Date? = nil,
        unlockedAt: Date? = nil,
        temporaryUnlockState: TemporaryUnlockState = .unused
    ) {
        self.isLocked = isLocked
        self.lockedModeId = lockedModeId
        self.lockedAt = lockedAt
        self.unlockedAt = unlockedAt
        self.temporaryUnlockState = temporaryUnlockState
    }
    
    mutating func lock(modeId: UUID) {
        self.isLocked = true
        self.lockedModeId = modeId
        self.lockedAt = Date()
        self.unlockedAt = nil
        self.temporaryUnlockState = .unused
    }
    
    mutating func unlock() {
        self.isLocked = false
        self.unlockedAt = Date()
        self.lockedModeId = nil
        self.lockedAt = nil
        self.temporaryUnlockState = .unused
    }
    
    mutating func activateTemporaryUnlock(expiresAt: Date) {
        guard isLocked else { return }
        self.temporaryUnlockState = .active(expiresAt: expiresAt)
    }
    
    mutating func deactivateTemporaryUnlock() {
        guard case .active = temporaryUnlockState else { return }
        self.temporaryUnlockState = .used
    }
}

/// State of temporary unlock for a locked mode.
enum TemporaryUnlockState: Codable, Equatable {
    case unused
    case active(expiresAt: Date)
    case used
    
    var isActive: Bool {
        if case .active(let expiresAt) = self {
            return expiresAt > Date()
        }
        return false
    }
}



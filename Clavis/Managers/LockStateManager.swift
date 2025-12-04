//
//  LockStateManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine

/// Maintains the lock state for the currently active mode.
/// Implements responsibilities from SPEC §5.3 LockStateManager.
class LockStateManager: ObservableObject {
    @Published private(set) var currentLockState: LockState = LockState()
    
    private let modeManager: ModeManager
    private let keyManager: KeyManager
    private let temporaryKeyManager: TemporaryKeyManager
    private let appsProfileManager: AppsProfileManager
    
    init(
        modeManager: ModeManager,
        keyManager: KeyManager,
        temporaryKeyManager: TemporaryKeyManager,
        appsProfileManager: AppsProfileManager
    ) {
        self.modeManager = modeManager
        self.keyManager = keyManager
        self.temporaryKeyManager = temporaryKeyManager
        self.appsProfileManager = appsProfileManager
        
        // TODO: Load lock state from UserDefaults on init
    }
    
    /// Whether the current active mode is locked.
    var isLocked: Bool {
        currentLockState.isLocked
    }
    
    /// The mode ID that is currently locked, if any.
    var lockedModeId: UUID? {
        currentLockState.lockedModeId
    }
    
    /// Locks the active mode after verifying the mode's main key.
    /// - Parameter scanImage: Image data from camera scan of main key
    /// - Returns: Success result or error
    func lock(using scanImage: Data) async throws {
        guard let activeMode = modeManager.activeMode else {
            throw LockError.noActiveMode
        }
        
        guard keyManager.hasKey(activeMode.mainKeyId) else {
            throw LockError.noMainKeyEnrolled
        }
        
        // Verify main key scan against the mode's main key
        let scanResult = await keyManager.verifyKeyScan(activeMode.mainKeyId, scanImage: scanImage)
        guard scanResult.isMatch else {
            throw LockError.keyVerificationFailed(scanResult.errorReason ?? .noMatch)
        }
        
        // Lock the mode
        currentLockState.lock(modeId: activeMode.id)
        
        // Get app profile for this mode
        let appProfile = appsProfileManager.getAppProfile(for: activeMode.id)
        
        // TODO: Trigger Focus Mode ON with apps from appProfile
        // TODO: Use Shortcuts integration or Focus activation APIs
        // TODO: Apply blocked categories and app identifiers from appProfile
        
        // Reset temporary key usage for this mode
        temporaryKeyManager.resetTemporaryKeyUsage(for: activeMode.id)
        
        // TODO: Persist lock state to UserDefaults
    }
    
    /// Unlocks the current locked mode after verifying the mode's main key.
    /// - Parameter scanImage: Image data from camera scan of main key
    /// - Returns: Success result or error
    func unlock(using scanImage: Data) async throws {
        guard currentLockState.isLocked else {
            throw LockError.notLocked
        }
        
        guard let lockedModeId = currentLockState.lockedModeId,
              let lockedMode = modeManager.getMode(lockedModeId) else {
            throw LockError.invalidLockState
        }
        
        guard keyManager.hasKey(lockedMode.mainKeyId) else {
            throw LockError.noMainKeyEnrolled
        }
        
        // Verify main key scan against the mode's main key
        let scanResult = await keyManager.verifyKeyScan(lockedMode.mainKeyId, scanImage: scanImage)
        guard scanResult.isMatch else {
            throw LockError.keyVerificationFailed(scanResult.errorReason ?? .noMatch)
        }
        
        // Unlock the mode
        currentLockState.unlock()
        
        // TODO: Trigger Focus Mode OFF
        // TODO: Use Shortcuts integration or Focus deactivation APIs
        
        // Reset temporary key usage for the unlocked mode
        temporaryKeyManager.resetTemporaryKeyUsage(for: lockedModeId)
        
        // TODO: Persist lock state to UserDefaults
    }
    
    /// Temporarily unlocks specific apps for the locked mode using a temporary key.
    /// - Parameters:
    ///   - scanImage: Image data from camera scan of temporary key
    ///   - duration: Duration in seconds for temporary unlock
    /// - Returns: Success result or error
    func temporaryUnlock(using scanImage: Data, duration: TimeInterval = 300) async throws {
        guard currentLockState.isLocked else {
            throw LockError.notLocked
        }
        
        guard let lockedModeId = currentLockState.lockedModeId,
              let lockedMode = modeManager.getMode(lockedModeId) else {
            throw LockError.invalidLockState
        }
        
        // Check if mode has temporary keys enrolled
        guard !lockedMode.temporaryKeyIds.isEmpty else {
            throw LockError.noTemporaryKeyEnrolled
        }
        
        // Try to match the scan against any of the mode's temporary keys
        var matchedKeyId: UUID?
        var bestResult: KeyScanResult?
        
        for tempKeyId in lockedMode.temporaryKeyIds {
            // Skip if this temporary key has already been used in this lock cycle
            if temporaryKeyManager.isTemporaryKeyUsed(modeId: lockedModeId, keyId: tempKeyId) {
                continue
            }
            
            // Verify against this temporary key
            let scanResult = await keyManager.verifyKeyScan(tempKeyId, scanImage: scanImage)
            if scanResult.isMatch {
                matchedKeyId = tempKeyId
                bestResult = scanResult
                break
            }
            // Keep track of best result for error reporting
            if bestResult == nil || scanResult.confidenceScore > (bestResult?.confidenceScore ?? 0) {
                bestResult = scanResult
            }
        }
        
        guard let keyId = matchedKeyId else {
            throw LockError.keyVerificationFailed(bestResult?.errorReason ?? .noMatch)
        }
        
        // Check if this key was already used (shouldn't happen due to check above, but double-check)
        if temporaryKeyManager.isTemporaryKeyUsed(modeId: lockedModeId, keyId: keyId) {
            throw LockError.temporaryKeyAlreadyUsed
        }
        
        // Activate temporary unlock
        let expiresAt = Date().addingTimeInterval(duration)
        currentLockState.activateTemporaryUnlock(expiresAt: expiresAt)
        temporaryKeyManager.markTemporaryKeyUsed(modeId: lockedModeId, keyId: keyId)
        
        // Get app profile for this mode
        let appProfile = appsProfileManager.getAppProfile(for: lockedModeId)
        
        // TODO: Temporarily allow access to apps in temporaryUnlockableAppIdentifiers
        // TODO: Use Focus Mode configuration or Shortcuts to allow specific apps
        
        // TODO: Persist temporary unlock state to UserDefaults
        // TODO: Set up timer to automatically deactivate temporary unlock when expiresAt is reached
    }
    
    /// Handles switching modes while locked (updates Focus Mode configuration).
    func handleModeSwitch() {
        guard currentLockState.isLocked, let lockedModeId = currentLockState.lockedModeId else {
            return
        }
        
        // TODO: Update Focus Mode to reflect new mode's app configuration
        // TODO: Get app profile for lockedModeId and update Focus Mode restrictions
    }
}

/// Errors that can occur during lock/unlock operations.
enum LockError: LocalizedError {
    case noActiveMode
    case noMainKeyEnrolled
    case noTemporaryKeyEnrolled
    case keyVerificationFailed(KeyErrorReason)
    case notLocked
    case invalidLockState
    case temporaryKeyAlreadyUsed
    
    var errorDescription: String? {
        switch self {
        case .noActiveMode:
            return "No active mode selected"
        case .noMainKeyEnrolled:
            return "Main key has not been enrolled"
        case .noTemporaryKeyEnrolled:
            return "No temporary key enrolled for this mode"
        case .keyVerificationFailed(let reason):
            return "Key verification failed: \(reason.rawValue)"
        case .notLocked:
            return "Mode is not currently locked"
        case .invalidLockState:
            return "Invalid lock state"
        case .temporaryKeyAlreadyUsed:
            return "Temporary key has already been used in this lock cycle"
        }
    }
}



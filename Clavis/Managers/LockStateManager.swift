//
//  LockStateManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine
import ARKit

/// Maintains the lock state for the currently active mode.
/// Implements responsibilities from SPEC §5.3 LockStateManager.
class LockStateManager: ObservableObject {
    @Published private(set) var currentLockState: LockState = LockState()
    
    private let modeManager: ModeManager
    private let keyManager: KeyManager
    private let temporaryKeyManager: TemporaryKeyManager
    private let appsProfileManager: AppsProfileManager
    
    // Continuous verification
    private var verificationCancellable: AnyCancellable?
    private var lockVerificationActive = false
    private var unlockVerificationActive = false
    private var temporaryUnlockVerificationActive = false
    
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
    
    // MARK: - Continuous Lock Flow
    
    /// Starts continuous verification for locking the active mode.
    /// Call `processLockFrame` for each frame until match is found.
    /// - Returns: Publisher that emits when lock succeeds or fails
    func startLockVerification() -> AnyPublisher<Result<Void, LockError>, Never> {
        guard let activeMode = modeManager.activeMode else {
            return Just(.failure(.noActiveMode)).eraseToAnyPublisher()
        }
        
        guard keyManager.hasKey(activeMode.mainKeyId) else {
            return Just(.failure(.noMainKeyEnrolled)).eraseToAnyPublisher()
        }
        
        lockVerificationActive = true
        let subject = PassthroughSubject<Result<Void, LockError>, Never>()
        
        verificationCancellable = keyManager.startVerification(for: activeMode.mainKeyId)
            .sink { [weak self] scanResult in
                guard let self = self, self.lockVerificationActive else { return }
                
                if scanResult.isMatch {
                    // Lock the mode
                    self.currentLockState.lock(modeId: activeMode.id)
                    
                    // Get app profile for this mode
                    let _ = self.appsProfileManager.getAppProfile(for: activeMode.id)
                    
                    // TODO: Trigger Focus Mode ON with apps from appProfile
                    // TODO: Use Shortcuts integration or Focus activation APIs
                    // TODO: Apply blocked categories and app identifiers from appProfile
                    
                    // Reset temporary key usage for this mode
                    self.temporaryKeyManager.resetTemporaryKeyUsage(for: activeMode.id)
                    
                    // TODO: Persist lock state to UserDefaults
                    
                    self.lockVerificationActive = false
                    self.keyManager.stopVerification()
                    subject.send(.success(()))
                    subject.send(completion: .finished)
                }
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Processes a frame during lock verification.
    /// - Parameters:
    ///   - frame: The ARFrame to process
    ///   - roi: Optional region of interest
    func processLockFrame(frame: ARFrame, roi: CGRect? = nil) async {
        guard lockVerificationActive else { return }
        await keyManager.processVerificationFrame(frame: frame, roi: roi)
    }
    
    /// Stops lock verification.
    func stopLockVerification() {
        lockVerificationActive = false
        keyManager.stopVerification()
        verificationCancellable?.cancel()
    }
    
    // MARK: - Legacy Lock API
    
    /// Locks the active mode after verifying the mode's main key (legacy API).
    /// - Parameter scanImage: Image data from camera scan of main key
    /// - Returns: Success result or error
    func lock(using scanImage: Data) async throws {
        throw NSError(domain: "LockStateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use continuous lock verification API instead"])
    }
    
    // MARK: - Continuous Unlock Flow
    
    /// Starts continuous verification for unlocking the current locked mode.
    /// Call `processUnlockFrame` for each frame until match is found.
    /// - Returns: Publisher that emits when unlock succeeds or fails
    func startUnlockVerification() -> AnyPublisher<Result<Void, LockError>, Never> {
        guard currentLockState.isLocked else {
            return Just(.failure(.notLocked)).eraseToAnyPublisher()
        }
        
        guard let lockedModeId = currentLockState.lockedModeId,
              let lockedMode = modeManager.getMode(lockedModeId) else {
            return Just(.failure(.invalidLockState)).eraseToAnyPublisher()
        }
        
        guard keyManager.hasKey(lockedMode.mainKeyId) else {
            return Just(.failure(.noMainKeyEnrolled)).eraseToAnyPublisher()
        }
        
        unlockVerificationActive = true
        let subject = PassthroughSubject<Result<Void, LockError>, Never>()
        
        verificationCancellable = keyManager.startVerification(for: lockedMode.mainKeyId)
            .sink { [weak self] scanResult in
                guard let self = self, self.unlockVerificationActive else { return }
                
                if scanResult.isMatch {
                    // Unlock the mode
                    self.currentLockState.unlock()
                    
                    // TODO: Trigger Focus Mode OFF
                    // TODO: Use Shortcuts integration or Focus deactivation APIs
                    
                    // Reset temporary key usage for the unlocked mode
                    self.temporaryKeyManager.resetTemporaryKeyUsage(for: lockedModeId)
                    
                    // TODO: Persist lock state to UserDefaults
                    
                    self.unlockVerificationActive = false
                    self.keyManager.stopVerification()
                    subject.send(.success(()))
                    subject.send(completion: .finished)
                }
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Processes a frame during unlock verification.
    /// - Parameters:
    ///   - frame: The ARFrame to process
    ///   - roi: Optional region of interest
    func processUnlockFrame(frame: ARFrame, roi: CGRect? = nil) async {
        guard unlockVerificationActive else { return }
        await keyManager.processVerificationFrame(frame: frame, roi: roi)
    }
    
    /// Stops unlock verification.
    func stopUnlockVerification() {
        unlockVerificationActive = false
        keyManager.stopVerification()
        verificationCancellable?.cancel()
    }
    
    // MARK: - Legacy Unlock API
    
    /// Unlocks the current locked mode after verifying the mode's main key (legacy API).
    /// - Parameter scanImage: Image data from camera scan of main key
    /// - Returns: Success result or error
    func unlock(using scanImage: Data) async throws {
        throw NSError(domain: "LockStateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use continuous unlock verification API instead"])
    }
    
    // MARK: - Continuous Temporary Unlock Flow
    
    /// Starts continuous verification for temporary unlock using any of the mode's temporary keys.
    /// Call `processTemporaryUnlockFrame` for each frame until match is found.
    /// - Parameter duration: Duration in seconds for temporary unlock
    /// - Returns: Publisher that emits when temporary unlock succeeds or fails
    func startTemporaryUnlockVerification(duration: TimeInterval = 300) -> AnyPublisher<Result<Void, LockError>, Never> {
        guard currentLockState.isLocked else {
            return Just(.failure(.notLocked)).eraseToAnyPublisher()
        }
        
        guard let lockedModeId = currentLockState.lockedModeId,
              let lockedMode = modeManager.getMode(lockedModeId) else {
            return Just(.failure(.invalidLockState)).eraseToAnyPublisher()
        }
        
        // Check if mode has temporary keys enrolled
        guard !lockedMode.temporaryKeyIds.isEmpty else {
            return Just(.failure(.noTemporaryKeyEnrolled)).eraseToAnyPublisher()
        }
        
        temporaryUnlockVerificationActive = true
        let subject = PassthroughSubject<Result<Void, LockError>, Never>()
        
        // Try verification against all unused temporary keys
        // For simplicity, we'll verify against the first unused key
        // In a more sophisticated implementation, we could try multiple keys in parallel
        let unusedKeys = lockedMode.temporaryKeyIds.filter { keyId in
            !temporaryKeyManager.isTemporaryKeyUsed(modeId: lockedModeId, keyId: keyId)
        }
        
        let _ = lockedModeId  // Used in closure below
        
        guard let firstUnusedKeyId = unusedKeys.first else {
            return Just(.failure(.temporaryKeyAlreadyUsed)).eraseToAnyPublisher()
        }
        
        verificationCancellable = keyManager.startVerification(for: firstUnusedKeyId)
            .sink { [weak self] scanResult in
                guard let self = self, self.temporaryUnlockVerificationActive else { return }
                
                if scanResult.isMatch {
                    // Check if key was already used (race condition check)
                    if self.temporaryKeyManager.isTemporaryKeyUsed(modeId: lockedModeId, keyId: firstUnusedKeyId) {
                        self.temporaryUnlockVerificationActive = false
                        self.keyManager.stopVerification()
                        subject.send(.failure(.temporaryKeyAlreadyUsed))
                        subject.send(completion: .finished)
                        return
                    }
                    
                    // Activate temporary unlock
                    let expiresAt = Date().addingTimeInterval(duration)
                    self.currentLockState.activateTemporaryUnlock(expiresAt: expiresAt)
                    self.temporaryKeyManager.markTemporaryKeyUsed(modeId: lockedModeId, keyId: firstUnusedKeyId)
                    
                    // Get app profile for this mode
                    let _ = self.appsProfileManager.getAppProfile(for: lockedModeId)
                    
                    // TODO: Temporarily allow access to apps in temporaryUnlockableAppIdentifiers
                    // TODO: Use Focus Mode configuration or Shortcuts to allow specific apps
                    
                    // TODO: Persist temporary unlock state to UserDefaults
                    // TODO: Set up timer to automatically deactivate temporary unlock when expiresAt is reached
                    
                    self.temporaryUnlockVerificationActive = false
                    self.keyManager.stopVerification()
                    subject.send(.success(()))
                    subject.send(completion: .finished)
                }
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Processes a frame during temporary unlock verification.
    /// - Parameters:
    ///   - frame: The ARFrame to process
    ///   - roi: Optional region of interest
    func processTemporaryUnlockFrame(frame: ARFrame, roi: CGRect? = nil) async {
        guard temporaryUnlockVerificationActive else { return }
        await keyManager.processVerificationFrame(frame: frame, roi: roi)
    }
    
    /// Stops temporary unlock verification.
    func stopTemporaryUnlockVerification() {
        temporaryUnlockVerificationActive = false
        keyManager.stopVerification()
        verificationCancellable?.cancel()
    }
    
    // MARK: - Legacy Temporary Unlock API
    
    /// Temporarily unlocks specific apps for the locked mode using a temporary key (legacy API).
    /// - Parameters:
    ///   - scanImage: Image data from camera scan of temporary key
    ///   - duration: Duration in seconds for temporary unlock
    /// - Returns: Success result or error
    func temporaryUnlock(using scanImage: Data, duration: TimeInterval = 300) async throws {
        throw NSError(domain: "LockStateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use continuous temporary unlock verification API instead"])
    }
    
    /// Handles switching modes while locked (updates Focus Mode configuration).
    func handleModeSwitch() {
        guard currentLockState.isLocked, currentLockState.lockedModeId != nil else {
            return
        }
        
        // TODO: Update Focus Mode to reflect new mode's app configuration
        // TODO: Get app profile for locked mode and update Focus Mode restrictions
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



//
//  KeyManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine
import ARKit

/// Manages all keys (physical objects) that can be used across modes.
/// Now uses ARKit for 3D object scanning and recognition.
class KeyManager: ObservableObject {
    /// All enrolled keys, indexed by key ID.
    @Published private(set) var keys: [UUID: Key] = [:]
    
    // Enrollment state
    @Published var enrollmentProgress: Double = 0.0
    @Published var enrollmentQualityMessage: String?
    @Published var enrollmentWaitingForObjectSelection = true
    private var enrollmentFeatures: [[Float]] = []  // 3D feature vectors
    private var enrollmentSessionActive = false
    private let minEnrollmentFrames = 8
    private let maxEnrollmentFrames = 12
    
    // Verification state
    private var verificationKeyId: UUID?
    private var verificationSmoother: TemporalSmoother?
    private let verificationSubject = PassthroughSubject<KeyScanResult, Never>()
    
    // Services
    private let featureExtractor = Feature3DExtractor.shared
    private let matcher3D = Matcher3D.shared
    private let templateStore = KeyTemplateStore.shared
    
    init() {
        loadAllKeys()
    }
    
    /// Loads all keys from secure storage.
    private func loadAllKeys() {
        let templates = templateStore.loadAll()
        for template in templates {
            let key = Key(template: template, name: nil, createdAt: template.enrolledDate)
            keys[key.id] = key
        }
    }
    
    /// Gets a key by ID.
    func getKey(_ keyId: UUID) -> Key? {
        keys[keyId]
    }
    
    /// Gets all keys.
    var allKeys: [Key] {
        Array(keys.values)
    }
    
    // MARK: - Continuous Enrollment
    
    /// Starts an enrollment session for a new key.
    /// - Parameters:
    ///   - name: Optional user-friendly name for the key
    ///   - initialROI: Optional initial region of interest (normalized 0-1) to focus on
    func startEnrollmentSession(name: String? = nil, initialROI: CGRect? = nil) {
        enrollmentSessionActive = true
        enrollmentFeatures.removeAll()
        enrollmentProgress = 0.0
        enrollmentQualityMessage = nil
        
        if let roi = initialROI {
            print("🔑 [KeyManager] Starting enrollment with ROI: \(roi)")
            enrollmentWaitingForObjectSelection = false
            DispatchQueue.main.async {
                self.enrollmentQualityMessage = "Object selected! Move it slowly through different angles"
            }
        } else {
            print("🔑 [KeyManager] Starting enrollment - waiting for object selection")
            enrollmentWaitingForObjectSelection = true
            DispatchQueue.main.async {
                self.enrollmentQualityMessage = "Tap on the object you want to enroll"
            }
        }
    }
    
    /// Processes an AR frame during enrollment.
    /// - Parameters:
    ///   - frame: The ARFrame to process
    ///   - roi: Optional region of interest (normalized coordinates)
    /// - Returns: True if frame was accepted and added to template
    func processEnrollmentFrame(frame: ARFrame, roi: CGRect? = nil) async -> Bool {
        guard enrollmentSessionActive else {
            print("⚠️ [KeyManager] Enrollment session not active")
            return false
        }
        
        // CRITICAL: Don't process frames until an object is selected
        if enrollmentWaitingForObjectSelection {
            if let roi = roi {
                // User just selected an object
                print("🎯 [KeyManager] Object selected! Starting enrollment from ROI: \(roi)")
                enrollmentWaitingForObjectSelection = false
                DispatchQueue.main.async {
                    self.enrollmentQualityMessage = "Object selected! Move it slowly through different angles"
                }
            } else {
                // Still waiting for object selection
                DispatchQueue.main.async {
                    self.enrollmentQualityMessage = "Tap on the object you want to enroll"
                }
                return false
            }
        }
        
        print("🔑 [KeyManager] Processing enrollment frame \(enrollmentFeatures.count + 1)...")
        
        // Check ARKit tracking state
        let trackingState = frame.camera.trackingState
        switch trackingState {
        case .notAvailable:
            DispatchQueue.main.async {
                self.enrollmentQualityMessage = "ARKit tracking not available. Move device slowly"
            }
            return false
        case .limited(let reason):
            let message = trackingStateMessage(reason: reason)
            DispatchQueue.main.async {
                self.enrollmentQualityMessage = message
            }
            // Continue anyway, but warn user
        case .normal:
            // Good tracking
            break
        @unknown default:
            break
        }
        
        // Get point cloud from ARFrame
        // Note: rawFeaturePoints provides sparse feature points from ARKit's world tracking
        // On LiDAR devices, this is more dense; on regular devices, it's sparser but still usable
        // ROI filtering can be added later if needed - currently ROI is used for user guidance
        let pointCloud = frame.rawFeaturePoints?.points.map { $0 } ?? []
        
        // Validate point cloud quality
        guard !pointCloud.isEmpty else {
        DispatchQueue.main.async {
                self.enrollmentQualityMessage = "No points detected. Move closer or improve lighting"
            }
            return false
        }
        
        // Check point cloud size (rough estimate of object size)
        let (minBounds, maxBounds) = computeBoundingBox(points: pointCloud)
        let dimensions = maxBounds - minBounds
        let volume = dimensions.x * dimensions.y * dimensions.z
        
        // Validate object size (too small = too far, too large = too close)
        if volume < 0.001 {  // Very small volume
            DispatchQueue.main.async {
                self.enrollmentQualityMessage = "Object too far. Move closer"
            }
            return false
        } else if volume > 1.0 {  // Very large volume
            DispatchQueue.main.async {
                self.enrollmentQualityMessage = "Object too close. Move farther away"
            }
            return false
        }
        
        // Extract 3D features from point cloud
        guard let features = featureExtractor.extractFeatures(pointCloud: pointCloud, roi: roi) else {
            print("❌ [KeyManager] Failed to extract 3D features")
            DispatchQueue.main.async {
                self.enrollmentQualityMessage = "Failed to extract features. Try again"
            }
            return false
        }
        
        // Add features to enrollment collection
        enrollmentFeatures.append(features)
        print("✅ [KeyManager] Added 3D features. Total: \(enrollmentFeatures.count)/\(maxEnrollmentFrames)")
        
        // Update progress
        let progress = min(1.0, Double(enrollmentFeatures.count) / Double(maxEnrollmentFrames))
        DispatchQueue.main.async {
            self.enrollmentProgress = progress
            if progress >= 0.8 {
                self.enrollmentQualityMessage = "Almost done! Capture a few more angles"
            } else {
                self.enrollmentQualityMessage = "Good! Continue moving the object slowly"
            }
        }
        
        return true
    }
    
    /// Completes enrollment and creates the key.
    /// - Parameter name: Optional user-friendly name for the key
    /// - Returns: The enrolled Key, or nil if enrollment failed
    func completeEnrollment(name: String? = nil) -> Key? {
        guard enrollmentSessionActive else { return nil }
        guard enrollmentFeatures.count >= minEnrollmentFrames else {
            print("❌ [KeyManager] Not enough frames: \(enrollmentFeatures.count) < \(minEnrollmentFrames)")
            return nil
        }
        
        enrollmentSessionActive = false
        
        // Create template with 3D features
        let template = KeyTemplate(features: enrollmentFeatures)
        
        // Persist template
        guard templateStore.save(template) else {
            print("❌ [KeyManager] Failed to save template to Keychain")
            return nil
        }
        
        // Create key
        let key = Key(template: template, name: name, createdAt: template.enrolledDate)
        keys[key.id] = key
        
        print("✅ [KeyManager] Enrollment completed! Created key: \(key.id.uuidString.prefix(8))")
        
        // Reset enrollment state
        enrollmentFeatures.removeAll()
        enrollmentProgress = 0.0
        enrollmentQualityMessage = nil
        enrollmentWaitingForObjectSelection = true
        
        return key
    }
    
    /// Stops enrollment session without creating a key.
    func stopEnrollmentSession() {
        enrollmentSessionActive = false
        enrollmentFeatures.removeAll()
        enrollmentProgress = 0.0
        enrollmentQualityMessage = nil
        enrollmentWaitingForObjectSelection = true
    }
    
    /// Publisher for enrollment progress (0.0 to 1.0).
    var onEnrollmentProgress: AnyPublisher<Double, Never> {
        $enrollmentProgress.eraseToAnyPublisher()
    }
    
    // MARK: - Continuous Verification
    
    /// Starts verification for a specific key.
    /// Returns a publisher that emits KeyScanResult for each processed frame.
    /// - Parameters:
    ///   - keyId: The ID of the key to verify against
    ///   - initialROI: Optional initial region of interest
    /// - Returns: Publisher of KeyScanResult
    func startVerification(for keyId: UUID, initialROI: CGRect? = nil) -> AnyPublisher<KeyScanResult, Never> {
        guard keys[keyId] != nil else {
            return Just(.noMatch(errorReason: .unknown)).eraseToAnyPublisher()
        }
        
        verificationKeyId = keyId
        verificationSmoother = TemporalSmoother(windowSize: 3)
        matcher3D.resetTemporalSmoother()
        
        print("🔑 [KeyManager] Starting verification for key: \(keyId.uuidString.prefix(8))")
        
        return verificationSubject.eraseToAnyPublisher()
    }
    
    /// Processes an AR frame during verification.
    /// - Parameters:
    ///   - frame: The ARFrame to process
    ///   - roi: Optional region of interest (normalized coordinates)
    func processVerificationFrame(frame: ARFrame, roi: CGRect? = nil) async {
        guard let keyId = verificationKeyId,
              let key = keys[keyId],
              let smoother = verificationSmoother else {
            print("⚠️ [KeyManager] Verification not active or key not found")
            return
        }
        
        print("🔑 [KeyManager] Processing verification frame for key: \(keyId.uuidString.prefix(8))...")
        
        // Check ARKit tracking state
        let trackingState = frame.camera.trackingState
        switch trackingState {
        case .notAvailable:
            verificationSubject.send(.noMatch(confidenceScore: 0.0, errorReason: .unknown))
            return
        case .limited:
            // Continue but tracking is limited
            break
        case .normal:
            // Good tracking
            break
        @unknown default:
            break
        }
        
        // Get point cloud
        let pointCloud = frame.rawFeaturePoints?.points.map { $0 } ?? []
        
        guard !pointCloud.isEmpty else {
            print("⚠️ [KeyManager] No points detected")
            verificationSubject.send(.noMatch(confidenceScore: 0.0, errorReason: .tooFar))
            return
        }
        
        // Extract 3D features
        guard let features = featureExtractor.extractFeatures(pointCloud: pointCloud, roi: roi) else {
            print("❌ [KeyManager] Failed to extract 3D features")
            verificationSubject.send(.noMatch(confidenceScore: 0.0, errorReason: .unknown))
            return
        }
        
        // Match against template
        let template = key.template.embeddings
        print("🔑 [KeyManager] Comparing against template with \(template.count) feature vectors...")
        let bestScore = matcher3D.bestMatchScore(features: features, template: template)
        let isMatch = matcher3D.isMatch(bestScore)
        
        print("🔑 [KeyManager] Best similarity score: \(String(format: "%.4f", bestScore)), threshold: \(matcher3D.threshold), match: \(isMatch)")
        
        // Apply temporal smoothing
        let smoothedMatch = smoother.addFrame(score: bestScore, isMatch: isMatch)
        print("🔑 [KeyManager] Temporal smoothing: \(smoothedMatch) (window: \(smoother.recentMatches.count))")
        
        // Send result
        if smoothedMatch {
            print("✅✅✅ [KeyManager] MATCH CONFIRMED! Score: \(String(format: "%.4f", bestScore))")
            verificationSubject.send(.match(confidenceScore: Double(bestScore)))
        } else {
            print("⏳ [KeyManager] No match yet (score: \(String(format: "%.4f", bestScore)))")
            verificationSubject.send(.noMatch(confidenceScore: Double(bestScore), errorReason: isMatch ? nil : .noMatch))
        }
    }
    
    /// Stops verification.
    func stopVerification() {
        verificationKeyId = nil
        verificationSmoother?.reset()
        verificationSmoother = nil
        matcher3D.resetTemporalSmoother()
    }
    
    // MARK: - Key Management
    
    /// Updates a key's name.
    func updateKeyName(_ keyId: UUID, name: String?) {
        guard var key = keys[keyId] else { return }
        key.name = name
        keys[keyId] = key
    }
    
    /// Removes a key.
    /// Note: This does not remove the key from modes that reference it.
    /// The caller should handle cleaning up mode references first.
    func removeKey(_ keyId: UUID) {
        keys.removeValue(forKey: keyId)
        _ = templateStore.delete(id: keyId)
    }
    
    /// Checks if a key exists.
    func hasKey(_ keyId: UUID) -> Bool {
        keys[keyId] != nil
    }
    
    // MARK: - Helpers
    
    private func computeBoundingBox(points: [simd_float3]) -> (min: simd_float3, max: simd_float3) {
        guard let first = points.first else {
            return (simd_float3(0, 0, 0), simd_float3(0, 0, 0))
        }
        
        var minBounds = first
        var maxBounds = first
        
        for point in points {
            minBounds = simd_min(minBounds, point)
            maxBounds = simd_max(maxBounds, point)
        }
        
        return (minBounds, maxBounds)
    }
    
    private func trackingStateMessage(reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .initializing:
            return "Initializing AR tracking..."
        case .relocalizing:
            return "Relocalizing... Move device slowly"
        case .excessiveMotion:
            return "Too much motion. Hold device still"
        case .insufficientFeatures:
            return "Not enough features. Improve lighting or move closer"
        @unknown default:
            return "Tracking limited"
        }
    }
}

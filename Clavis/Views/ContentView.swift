//
//  ContentView.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import SwiftUI
import Combine
import ARKit
import UIKit

struct ContentView: View {
    // Managers
    @StateObject private var keyManager = KeyManager()
    
    // ARKit Session
    @StateObject private var arSession = ARKitSession()
    
    // Test state
    @State private var testMode: TestMode = .idle
    @State private var enrolledKeyId: UUID?
    @State private var verificationConfidence: Double = 0.0
    @State private var verificationQualityMessage: String?
    @State private var verificationResult: String?
    @State private var isMatch: Bool = false
    @State private var selectedROI: CGRect? = nil
    @State private var showROIInstructions = false
    
    // Frame processing
    @State private var frameProcessingTask: Task<Void, Never>?
    @State private var verificationCancellable: AnyCancellable?
    
    enum TestMode {
        case idle
        case enrolling
        case verifying
    }
    
    var body: some View {
        ZStack {
            // ARKit view
            if arSession.isAuthorized {
                ARScanningView(
                    arSession: arSession,
                    onFrame: { frame in
                        // Frame processing handled in startFrameProcessing
                    },
                    onROISelected: { roi in
                        print("🎬 [ContentView] ROI selected: \(roi)")
                        arSession.setROI(roi)
                        selectedROI = roi
                        showROIInstructions = false
                    },
                    progress: $keyManager.enrollmentProgress,
                    confidenceScore: $verificationConfidence,
                    qualityMessage: Binding(
                        get: { testMode == .enrolling ? keyManager.enrollmentQualityMessage : verificationQualityMessage },
                        set: { _ in }
                    ),
                    isMatch: $isMatch,
                    trackedROI: $selectedROI
                )
                .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 20) {
                            Image(systemName: "arkit")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("ARKit Not Available")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Clavis requires ARKit support to scan 3D objects. ARKit is available on iOS 11+ devices.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
            }
            
            // Controls overlay
        VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Status display
                    if let keyId = enrolledKeyId, let key = keyManager.getKey(keyId) {
                        Text("Enrolled: \(key.name ?? "Unnamed Key")")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    if let result = verificationResult {
                        Text(result)
                            .font(.headline)
                            .foregroundColor(isMatch ? .green : .red)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    // Instructions and progress indicator
                    if testMode == .enrolling {
                        VStack(spacing: 8) {
                            if showROIInstructions || selectedROI == nil {
                                Text("Tap on the object you want to enroll")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.bottom, 4)
                            }
                            
                            ProgressView(value: keyManager.enrollmentProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            Text("\(Int(keyManager.enrollmentProgress * 100))% - Move object slowly through different angles")
                                .font(.caption)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            if let message = keyManager.enrollmentQualityMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            if selectedROI != nil {
                                Text("✓ Object selected - tracking active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                    
                    // Confidence display
                    if testMode == .verifying {
                        VStack(spacing: 4) {
                            if showROIInstructions || selectedROI == nil {
                                Text("Tap on the object to verify, or wait for auto-detection")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.bottom, 4)
                            }
                            
                            Text("Confidence: \(Int(verificationConfidence * 100))%")
                                .font(.headline)
                                .foregroundColor(verificationConfidence >= 0.90 ? .green : .yellow)
                            if verificationConfidence >= 0.90 {
                                Text("MATCH!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            if let message = verificationQualityMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            if selectedROI != nil {
                                Text("✓ Object selected - tracking active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        if testMode == .idle {
                            Button(action: startEnrollment) {
                                Label("Enroll Key", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(!arSession.isAuthorized)
                            
                            if enrolledKeyId != nil {
                                Button(action: startVerification) {
                                    Label("Verify Key", systemImage: "checkmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                        } else {
                            Button(action: stopCurrentOperation) {
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            if testMode == .enrolling {
                                Button(action: completeEnrollment) {
                                    Label("Complete", systemImage: "checkmark")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(keyManager.enrollmentProgress >= 0.8 ? Color.green : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .disabled(keyManager.enrollmentProgress < 0.8)
                            }
                        }
                    }
                    .padding(.horizontal)
        }
        .padding()
            }
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func setupCamera() {
        // ARKit authorization is checked automatically
        // Session will start when enrollment/verification begins
    }
    
    private func startEnrollment() {
        print("🎬 [ContentView] Starting enrollment...")
        testMode = .enrolling
        keyManager.enrollmentProgress = 0.0
        keyManager.enrollmentQualityMessage = nil
        verificationResult = nil
        isMatch = false
        selectedROI = nil
        showROIInstructions = true
        
        // Start enrollment session (will use ROI if user taps)
        keyManager.startEnrollmentSession(name: "Test Key", initialROI: nil)
        print("🎬 [ContentView] Enrollment session started - waiting for ROI selection")
        
        arSession.start(mode: .enrollment)
        print("🎬 [ContentView] ARKit session started in enrollment mode")
        
        // Start frame processing
        startFrameProcessing()
        print("🎬 [ContentView] Frame processing started")
    }
    
    private func completeEnrollment() {
        if let key = keyManager.completeEnrollment(name: "Test Key") {
            enrolledKeyId = key.id
            testMode = .idle
            stopFrameProcessing()
            arSession.stop()
            verificationResult = "Key enrolled successfully! ID: \(key.id.uuidString.prefix(8))"
        } else {
            verificationResult = "Enrollment failed - need at least 8 quality frames"
        }
    }
    
    private func startVerification() {
        guard let keyId = enrolledKeyId else {
            print("❌ [ContentView] No enrolled key to verify")
            return
        }
        
        print("🎬 [ContentView] Starting verification for key: \(keyId.uuidString.prefix(8))...")
        testMode = .verifying
        verificationConfidence = 0.0
        verificationQualityMessage = nil
        verificationResult = nil
        isMatch = false
        selectedROI = nil
        showROIInstructions = true
        
        arSession.start(mode: .verification)
        print("🎬 [ContentView] ARKit session started in verification mode")
        
        // Start verification publisher (will use ROI if user taps, or auto-detect)
        verificationCancellable = keyManager.startVerification(for: keyId, initialROI: nil)
            .sink { result in
                print("📡 [ContentView] Verification result received: match=\(result.isMatch), confidence=\(String(format: "%.4f", result.confidenceScore))")
                DispatchQueue.main.async {
                    verificationConfidence = result.confidenceScore
                    verificationQualityMessage = result.errorReason?.rawValue
                    
                    if result.isMatch {
                        isMatch = true
                        verificationResult = "MATCH! Confidence: \(Int(result.confidenceScore * 100))%"
                        print("✅✅✅ [ContentView] MATCH CONFIRMED IN UI!")
                        showROIInstructions = false
                    } else {
                        isMatch = false
                        if result.confidenceScore > 0 {
                            verificationResult = "No match. Confidence: \(Int(result.confidenceScore * 100))%"
                        }
                    }
                }
            }
        
        print("🎬 [ContentView] Verification publisher subscribed")
        
        // Start frame processing
        startFrameProcessing()
        print("🎬 [ContentView] Frame processing started")
    }
    
    private func stopCurrentOperation() {
        switch testMode {
        case .enrolling:
            keyManager.stopEnrollmentSession()
        case .verifying:
            keyManager.stopVerification()
            verificationCancellable?.cancel()
        case .idle:
            break
        }
        
        testMode = .idle
        stopFrameProcessing()
        arSession.stop()
    }
    
    private func startFrameProcessing() {
        stopFrameProcessing()
        
        print("🎬 [ContentView] Starting AR frame processing task...")
        frameProcessingTask = Task {
            var frameCount = 0
            
            // Set up frame handler - this will be called by ARKitSession delegate
            arSession.onFrame = { [weak keyManager] frame in
                frameCount += 1
                if frameCount % 10 == 0 { // Log every 10th frame
                    print("🎬 [ContentView] Processing AR frame #\(frameCount)")
                }
                
                Task { @MainActor [testMode, selectedROI, arSession, keyManager] in
                    guard let keyManager = keyManager else { return }
                    
                    // Get current state
                    let roi = arSession.selectedROI
                    let effectiveROI = selectedROI ?? roi
                    
                    switch testMode {
                    case .enrolling:
                        let accepted = await keyManager.processEnrollmentFrame(frame: frame, roi: effectiveROI)
                        if accepted {
                            print("✅ [ContentView] Enrollment frame accepted")
                            // Once we have ROI, hide instructions
                            if effectiveROI != nil {
                                showROIInstructions = false
                            }
                        }
                        
                    case .verifying:
                        await keyManager.processVerificationFrame(frame: frame, roi: effectiveROI)
                        // Once we have ROI, hide instructions
                        if effectiveROI != nil {
                            showROIInstructions = false
                        }
                        
                    case .idle:
                        break
                    }
                }
            }
        }
    }
    
    private func stopFrameProcessing() {
        frameProcessingTask?.cancel()
        frameProcessingTask = nil
    }
    
    private func cleanup() {
        stopFrameProcessing()
        verificationCancellable?.cancel()
        arSession.stop()
    }
}

#Preview {
    ContentView()
}

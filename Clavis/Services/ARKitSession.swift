//
//  ARKitSession.swift
//  Clavis
//
//  Created on 12/26/25.
//

import Foundation
import ARKit
import Combine
import CoreVideo

/// Manages ARKit session for 3D object scanning with depth and point cloud extraction.
class ARKitSession: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isRunning = false
    @Published var currentFrame: ARFrame?
    @Published var selectedROI: CGRect?  // Normalized coordinates (0-1)
    
    let arSession = ARSession()
    private let sessionQueue = DispatchQueue(label: "com.clavis.arkit.session", qos: .userInitiated)
    
    // Frame throttling
    private var lastFrameTime: Date?
    private let enrollmentFrameInterval: TimeInterval = 1.0 / 5.0  // 5 FPS for enrollment
    private let verificationFrameInterval: TimeInterval = 1.0 / 10.0  // 10 FPS for verification
    private var currentFrameInterval: TimeInterval = 1.0 / 10.0
    
    // Frame handler
    var onFrame: ((ARFrame) -> Void)?
    
    // Configuration mode
    enum ConfigurationMode {
        case enrollment  // Object scanning mode for detailed capture
        case verification  // World tracking mode for fast verification
    }
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        arSession.delegate = self
        checkAuthorization()
    }
    
    private func checkAuthorization() {
        // ARKit doesn't require explicit camera permission (uses camera automatically)
        // But we should check if ARKit is supported and camera is available
        let isSupported = ARWorldTrackingConfiguration.isSupported
        
        // Note: rawFeaturePoints is available on all ARKit-supported devices
        // On devices with LiDAR (iPhone 12 Pro+, iPad Pro 2020+), point clouds are denser
        // On regular devices, point clouds are sparser but still usable
        
        DispatchQueue.main.async {
            self.isAuthorized = isSupported
        }
    }
    
    /// Starts the AR session with the specified configuration mode.
    /// - Parameter mode: Enrollment (object scanning) or verification (world tracking)
    func start(mode: ConfigurationMode = .verification) {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isRunning else {
                print("📷 [ARKitSession] Already running or self is nil")
                return
            }
            
            let configuration: ARConfiguration
            
            switch mode {
            case .enrollment:
                // Use object scanning configuration for detailed capture
                if ARObjectScanningConfiguration.isSupported {
                    let objectConfig = ARObjectScanningConfiguration()
                    objectConfig.planeDetection = [.horizontal, .vertical]
                    configuration = objectConfig
                    print("📷 [ARKitSession] Starting in enrollment mode (Object Scanning)")
                } else {
                    // Fallback to world tracking if object scanning not supported
                    let worldConfig = ARWorldTrackingConfiguration()
                    worldConfig.planeDetection = [.horizontal, .vertical]
                    worldConfig.environmentTexturing = .automatic
                    configuration = worldConfig
                    print("📷 [ARKitSession] Starting in enrollment mode (World Tracking - fallback)")
                }
                self.currentFrameInterval = self.enrollmentFrameInterval
                
            case .verification:
                // Use world tracking for fast verification
                let worldConfig = ARWorldTrackingConfiguration()
                worldConfig.planeDetection = [.horizontal, .vertical]
                configuration = worldConfig
                self.currentFrameInterval = self.verificationFrameInterval
                print("📷 [ARKitSession] Starting in verification mode (World Tracking)")
            }
            
            // Enable scene reconstruction if available (only for world tracking config)
            if let worldConfig = configuration as? ARWorldTrackingConfiguration,
               ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                worldConfig.sceneReconstruction = .mesh
                print("📷 [ARKitSession] Scene reconstruction enabled")
            }
            
            self.arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            print("📷 [ARKitSession] AR session started")
            
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }
    
    /// Stops the AR session.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.arSession.pause()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    /// Sets the region of interest (normalized coordinates 0-1).
    /// - Parameter roi: Normalized CGRect, or nil to use full frame
    func setROI(_ roi: CGRect?) {
        DispatchQueue.main.async {
            self.selectedROI = roi
        }
    }
    
    /// Converts a point in view coordinates to normalized ROI coordinates.
    /// - Parameters:
    ///   - point: Point in view coordinates
    ///   - viewSize: Size of the view
    /// - Returns: Normalized CGRect centered at point (or nil if invalid)
    func roiFromTap(at point: CGPoint, in viewSize: CGSize) -> CGRect? {
        // Create a small ROI around the tap point (e.g., 20% of screen)
        let roiSize: CGFloat = 0.2
        let normalizedX = point.x / viewSize.width
        let normalizedY = point.y / viewSize.height
        
        let roi = CGRect(
            x: max(0, min(1 - roiSize, normalizedX - roiSize / 2)),
            y: max(0, min(1 - roiSize, normalizedY - roiSize / 2)),
            width: roiSize,
            height: roiSize
        )
        
        return roi
    }
    
    /// Gets depth data from the current frame if available.
    /// - Returns: CVPixelBuffer containing depth data, or nil if unavailable
    func getDepthData() -> CVPixelBuffer? {
        return currentFrame?.capturedDepthData?.depthDataMap
    }
    
    /// Gets point cloud from the current frame.
    /// - Returns: Array of 3D points (simd_float3) in world space
    func getPointCloud() -> [simd_float3] {
        guard let frame = currentFrame else { return [] }
        
        // Get raw feature points from ARKit
        let featurePoints = frame.rawFeaturePoints?.points ?? []
        return featurePoints.map { $0 }
    }
    
    /// Gets point cloud within ROI if specified.
    /// - Parameters:
    ///   - interfaceOrientation: Current interface orientation (defaults to .portrait)
    /// - Returns: Array of 3D points within the ROI
    func getPointCloudInROI(interfaceOrientation: UIInterfaceOrientation = .portrait) -> [simd_float3] {
        guard let roi = selectedROI, let frame = currentFrame else {
            return getPointCloud()
        }
        
        // Project 3D points to 2D screen space and filter by ROI
        let camera = frame.camera
        let imageResolution = frame.camera.imageResolution
        
        let featurePoints = frame.rawFeaturePoints?.points ?? []
        var filteredPoints: [simd_float3] = []
        
        for point in featurePoints {
            // Project 3D point to 2D using actual interface orientation
            let viewMatrix = camera.viewMatrix(for: interfaceOrientation)
            let projectionMatrix = camera.projectionMatrix(for: interfaceOrientation, viewportSize: imageResolution, zNear: 0.001, zFar: 1000)
            
            // Transform point to view space
            let viewPoint = viewMatrix * simd_float4(point, 1.0)
            let clipPoint = projectionMatrix * viewPoint
            
            // Normalize to NDC
            let ndcX = clipPoint.x / clipPoint.w
            let ndcY = clipPoint.y / clipPoint.w
            
            // Convert to normalized screen coordinates (0-1)
            let screenX = (ndcX + 1.0) / 2.0
            let screenY = (1.0 - ndcY) / 2.0  // Flip Y
            
            // Check if point is within ROI
            if roi.contains(CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))) {
                filteredPoints.append(point)
            }
        }
        
        // Return filtered points, or all points if filtering resulted in empty set
        // (this prevents issues when ROI is too small or points are sparse)
        return filteredPoints.isEmpty ? getPointCloud() : filteredPoints
    }
}

// MARK: - ARSessionDelegate

extension ARKitSession: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Throttle frame updates
        let now = Date()
        if let lastTime = lastFrameTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < currentFrameInterval {
                return
            }
        }
        lastFrameTime = now
        
        DispatchQueue.main.async {
            self.currentFrame = frame
        }
        
        // Notify frame handler on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(frame)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ [ARKitSession] AR session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ [ARKitSession] AR session interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("✅ [ARKitSession] AR session interruption ended")
        // Optionally restart the session
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        switch state {
        case .normal:
            print("✅ [ARKitSession] Tracking state: normal")
        case .notAvailable:
            print("⚠️ [ARKitSession] Tracking state: not available")
        case .limited(let reason):
            print("⚠️ [ARKitSession] Tracking state: limited - \(reason)")
        @unknown default:
            print("⚠️ [ARKitSession] Tracking state: unknown")
        }
    }
}


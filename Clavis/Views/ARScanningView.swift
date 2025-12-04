//
//  ARScanningView.swift
//  Clavis
//
//  Created on 12/26/25.
//

import SwiftUI
import ARKit
import RealityKit

/// SwiftUI view wrapper for ARKit scanning with overlays and ROI selection.
struct ARScanningView: UIViewControllerRepresentable {
    @ObservedObject var arSession: ARKitSession
    let onFrame: (ARFrame) -> Void
    let onROISelected: ((CGRect) -> Void)?
    
    // UI state
    @Binding var progress: Double  // 0.0 to 1.0
    @Binding var confidenceScore: Double  // 0.0 to 1.0
    @Binding var qualityMessage: String?
    @Binding var isMatch: Bool
    @Binding var trackedROI: CGRect?  // Current tracked object bounding box (normalized)
    
    func makeUIViewController(context: Context) -> ARScanningViewController {
        let controller = ARScanningViewController()
        controller.arSession = arSession
        controller.onFrame = onFrame
        controller.onROISelected = onROISelected
        controller.progressBinding = $progress
        controller.confidenceScoreBinding = $confidenceScore
        controller.qualityMessageBinding = $qualityMessage
        controller.isMatchBinding = $isMatch
        controller.trackedROIBinding = $trackedROI
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARScanningViewController, context: Context) {
        // Update bindings
        uiViewController.updateProgress(progress)
        uiViewController.updateConfidence(confidenceScore)
        uiViewController.updateQuality(qualityMessage)
        uiViewController.updateMatch(isMatch)
        uiViewController.updateTrackedROI(trackedROI)
    }
}

/// UIKit view controller that manages ARKit view and overlays.
class ARScanningViewController: UIViewController {
    var arSession: ARKitSession!
    var onFrame: ((ARFrame) -> Void)?
    var onROISelected: ((CGRect) -> Void)?
    
    var progressBinding: Binding<Double>?
    var confidenceScoreBinding: Binding<Double>?
    var qualityMessageBinding: Binding<String?>?
    var isMatchBinding: Binding<Bool>?
    var trackedROIBinding: Binding<CGRect?>?
    
    private var arView: ARView?
    private var overlayView: ARScanningOverlayView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupOverlay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // AR session will be started by parent
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSession.stop()
    }
    
    private func setupARView() {
        let arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.session = arSession.arSession
        view.addSubview(arView)
        self.arView = arView
        
        // Note: Frame handler is set by ContentView in startFrameProcessing()
        // We just pass frames through when they arrive
    }
    
    private func setupOverlay() {
        let overlay = ARScanningOverlayView()
        overlay.progress = progressBinding?.wrappedValue ?? 0
        overlay.confidenceScore = confidenceScoreBinding?.wrappedValue ?? 0
        overlay.qualityMessage = qualityMessageBinding?.wrappedValue
        overlay.isMatch = isMatchBinding?.wrappedValue ?? false
        overlay.trackedROI = trackedROIBinding?.wrappedValue
        overlay.onTap = { [weak self] point in
            guard let self = self else { return }
            let viewSize = self.view.bounds.size
            if let roi = self.arSession.roiFromTap(at: point, in: viewSize) {
                self.arSession.setROI(roi)
                self.onROISelected?(roi)
            }
        }
        view.addSubview(overlay)
        overlayView = overlay
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)
        overlayView?.handleTap(at: point)
    }
    
    func updateProgress(_ value: Double) {
        overlayView?.progress = value
    }
    
    func updateConfidence(_ value: Double) {
        overlayView?.confidenceScore = value
    }
    
    func updateQuality(_ message: String?) {
        overlayView?.qualityMessage = message
    }
    
    func updateMatch(_ value: Bool) {
        overlayView?.isMatch = value
    }
    
    func updateTrackedROI(_ roi: CGRect?) {
        overlayView?.trackedROI = roi
    }
}

/// Overlay view showing progress, confidence, and ROI indicator for AR scanning.
class ARScanningOverlayView: UIView {
    var progress: Double = 0 {
        didSet { updateProgress() }
    }
    var confidenceScore: Double = 0 {
        didSet { updateConfidence() }
    }
    var qualityMessage: String? {
        didSet { updateQuality() }
    }
    var isMatch: Bool = false {
        didSet { updateMatch() }
    }
    var trackedROI: CGRect? = nil {
        didSet { updateROI() }
    }
    
    var onTap: ((CGPoint) -> Void)?
    
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let confidenceLabel = UILabel()
    private let qualityLabel = UILabel()
    private let matchIndicator = UIView()
    private let roiBox = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        
        // Progress bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = .systemBlue
        progressBar.trackTintColor = .systemGray
        addSubview(progressBar)
        
        // Confidence label
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        confidenceLabel.textColor = .white
        confidenceLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        confidenceLabel.textAlignment = .center
        addSubview(confidenceLabel)
        
        // Quality message label
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        qualityLabel.textColor = .yellow
        qualityLabel.font = .systemFont(ofSize: 14)
        qualityLabel.textAlignment = .center
        qualityLabel.numberOfLines = 0
        addSubview(qualityLabel)
        
        // Match indicator
        matchIndicator.translatesAutoresizingMaskIntoConstraints = false
        matchIndicator.backgroundColor = .systemGreen
        matchIndicator.layer.cornerRadius = 30
        matchIndicator.isHidden = true
        addSubview(matchIndicator)
        
        // ROI box (for tracked object visualization)
        roiBox.translatesAutoresizingMaskIntoConstraints = false
        roiBox.layer.borderColor = UIColor.systemGreen.cgColor
        roiBox.layer.borderWidth = 3
        roiBox.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        roiBox.isHidden = true
        addSubview(roiBox)
        
        NSLayoutConstraint.activate([
            progressBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            confidenceLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 20),
            confidenceLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            qualityLabel.topAnchor.constraint(equalTo: confidenceLabel.bottomAnchor, constant: 10),
            qualityLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            qualityLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            matchIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            matchIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            matchIndicator.widthAnchor.constraint(equalToConstant: 60),
            matchIndicator.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func updateProgress() {
        progressBar.setProgress(Float(progress), animated: true)
    }
    
    private func updateConfidence() {
        let percentage = Int(confidenceScore * 100)
        confidenceLabel.text = "Confidence: \(percentage)%"
        confidenceLabel.textColor = confidenceScore >= 0.85 ? .systemGreen : .systemYellow
    }
    
    private func updateQuality() {
        qualityLabel.text = qualityMessage
        qualityLabel.isHidden = qualityMessage == nil
    }
    
    private func updateMatch() {
        matchIndicator.isHidden = !isMatch
        if isMatch {
            // Animate match indicator
            UIView.animate(withDuration: 0.3) {
                self.matchIndicator.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            } completion: { _ in
                UIView.animate(withDuration: 0.3) {
                    self.matchIndicator.transform = .identity
                }
            }
        }
    }
    
    private func updateROI() {
        guard let roi = trackedROI else {
            roiBox.isHidden = true
            return
        }
        
        roiBox.isHidden = false
        // Convert normalized ROI to view coordinates
        let viewWidth = bounds.width
        let viewHeight = bounds.height
        
        let x = roi.origin.x * viewWidth
        let y = roi.origin.y * viewHeight
        let width = roi.width * viewWidth
        let height = roi.height * viewHeight
        
        roiBox.frame = CGRect(x: x, y: y, width: width, height: height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateROI()  // Update ROI position when view layout changes
    }
    
    func handleTap(at point: CGPoint) {
        onTap?(point)
    }
}


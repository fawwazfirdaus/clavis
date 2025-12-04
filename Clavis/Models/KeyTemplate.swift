//
//  KeyTemplate.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation

/// Represents stored key feature data for a physical object.
/// Now uses 3D features extracted from ARKit point clouds.
struct KeyTemplate: Codable, Identifiable {
    let id: UUID
    let enrolledDate: Date
    /// 3D feature vectors extracted from ARKit point clouds during enrollment.
    /// Each vector represents 3D geometric, spatial, and surface features.
    let featureVectors: [KeyFeatureVector]
    
    init(id: UUID = UUID(), enrolledDate: Date = Date(), featureVectors: [KeyFeatureVector]) {
        self.id = id
        self.enrolledDate = enrolledDate
        self.featureVectors = featureVectors
    }
    
    /// Convenience initializer from array of Float arrays (3D feature vectors).
    init(id: UUID = UUID(), enrolledDate: Date = Date(), features: [[Float]]) {
        self.id = id
        self.enrolledDate = enrolledDate
        self.featureVectors = features.map { KeyFeatureVector(data: $0) }
    }
    
    /// Converts feature vectors to array of Float arrays for matching.
    var embeddings: [[Float]] {
        featureVectors.map { $0.data }
    }
}

/// Represents a single 3D feature vector extracted from an ARKit point cloud.
struct KeyFeatureVector: Codable {
    /// 3D feature vector data containing geometric, spatial, surface, and statistical features.
    /// Extracted from point clouds using Feature3DExtractor.
    let data: [Float]
    
    init(data: [Float]) {
        self.data = data
    }
}

/// Result of a key verification scan attempt.
struct KeyScanResult {
    let isMatch: Bool
    let confidenceScore: Double
    let errorReason: KeyErrorReason?
    
    init(isMatch: Bool, confidenceScore: Double = 0.0, errorReason: KeyErrorReason? = nil) {
        self.isMatch = isMatch
        self.confidenceScore = confidenceScore
        self.errorReason = errorReason
    }
    
    static func match(confidenceScore: Double) -> KeyScanResult {
        KeyScanResult(isMatch: true, confidenceScore: confidenceScore)
    }
    
    static func noMatch(confidenceScore: Double = 0.0, errorReason: KeyErrorReason? = nil) -> KeyScanResult {
        KeyScanResult(isMatch: false, confidenceScore: confidenceScore, errorReason: errorReason)
    }
}

/// Reasons why a key scan might fail verification.
enum KeyErrorReason: String, Codable {
    case blurryImage
    case lowLight
    case lowTexture
    case tooFar
    case tooClose
    case noMatch
    case unknown
}



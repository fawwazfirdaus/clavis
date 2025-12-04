//
//  KeyTemplate.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation

/// Represents stored key feature data for a physical object.
/// Implements data structures from SPEC §7 Computer Vision Design.
struct KeyTemplate: Codable, Identifiable {
    let id: UUID
    let enrolledDate: Date
    /// Feature vectors extracted from enrollment images.
    /// Stored as abstract data - actual Vision/CoreML integration will be added later.
    let featureVectors: [KeyFeatureVector]
    
    init(id: UUID = UUID(), enrolledDate: Date = Date(), featureVectors: [KeyFeatureVector]) {
        self.id = id
        self.enrolledDate = enrolledDate
        self.featureVectors = featureVectors
    }
}

/// Represents a single feature vector extracted from an enrollment image.
struct KeyFeatureVector: Codable {
    /// Placeholder for feature vector data - will be replaced with actual Vision/CoreML embeddings.
    /// For now, this is a simple abstraction that can store Float arrays.
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



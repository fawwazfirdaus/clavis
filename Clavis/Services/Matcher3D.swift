//
//  Matcher3D.swift
//  Clavis
//
//  Created on 12/26/25.
//

import Foundation

/// Matches 3D feature vectors using similarity metrics.
/// Compares extracted 3D features against stored templates.
class Matcher3D {
    static let shared = Matcher3D()
    
    private let similarityThreshold: Float = 0.85  // Tunable threshold for 3D matching
    private let smoother: TemporalSmoother
    
    init(windowSize: Int = 3) {
        self.smoother = TemporalSmoother(windowSize: windowSize)
    }
    
    /// Computes the best match score between a feature vector and a template.
    /// - Parameters:
    ///   - features: Current 3D feature vector
    ///   - template: Template containing multiple feature vectors from enrollment
    /// - Returns: Best similarity score (0.0 to 1.0)
    func bestMatchScore(features: [Float], template: [[Float]]) -> Float {
        guard !template.isEmpty else {
            print("⚠️ [Matcher3D] Empty template")
            return 0.0
        }
        
        var bestScore: Float = 0.0
        var scoreRange: (min: Float, max: Float) = (1.0, 0.0)
        
        print("🔍 [Matcher3D] Comparing against template with \(template.count) feature vectors...")
        
        for (index, templateFeatures) in template.enumerated() {
            // Ensure feature vectors have same length
            guard features.count == templateFeatures.count else {
                print("⚠️ [Matcher3D] Feature vector length mismatch: \(features.count) vs \(templateFeatures.count)")
                continue
            }
            
            // Compute cosine similarity
            let score = cosineSimilarity(features, templateFeatures)
            
            if index == 0 {
                scoreRange = (score, score)
            } else {
                scoreRange.min = min(scoreRange.min, score)
                scoreRange.max = max(scoreRange.max, score)
            }
            
            if score > bestScore {
                bestScore = score
            }
        }
        
        print("📊 [Matcher3D] Best score: \(String(format: "%.4f", bestScore)), range: [\(String(format: "%.4f", scoreRange.min)), \(String(format: "%.4f", scoreRange.max))]")
        
        return bestScore
    }
    
    /// Checks if a similarity score indicates a match.
    /// - Parameter score: Similarity score (0.0 to 1.0)
    /// - Returns: True if score exceeds threshold
    func isMatch(_ score: Float) -> Bool {
        return score >= similarityThreshold
    }
    
    /// Applies temporal smoothing to reduce false positives.
    /// - Parameter currentMatch: Whether current frame is a match
    /// - Returns: True if smoothed result indicates match
    func checkTemporalMatch(currentMatch: Bool) -> Bool {
        return smoother.addFrame(score: currentMatch ? 1.0 : 0.0, isMatch: currentMatch)
    }
    
    /// Resets the temporal smoother (call when starting new verification session).
    func resetTemporalSmoother() {
        smoother.reset()
    }
    
    /// Computes cosine similarity between two feature vectors.
    /// - Parameters:
    ///   - a: First feature vector
    ///   - b: Second feature vector
    /// - Returns: Cosine similarity (0.0 to 1.0)
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else {
            return 0.0
        }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0.001 else {
            return 0.0
        }
        
        let similarity = dotProduct / denominator
        
        // Normalize from [-1, 1] to [0, 1] for easier thresholding
        return (similarity + 1.0) / 2.0
    }
    
    /// Computes L2 (Euclidean) distance between two feature vectors.
    /// - Parameters:
    ///   - a: First feature vector
    ///   - b: Second feature vector
    /// - Returns: L2 distance (lower is more similar)
    func l2Distance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else {
            return Float.infinity
        }
        
        var sumSquaredDiffs: Float = 0.0
        for i in 0..<a.count {
            let diff = a[i] - b[i]
            sumSquaredDiffs += diff * diff
        }
        
        return sqrt(sumSquaredDiffs)
    }
    
    /// Threshold for matching (readable for debugging).
    var threshold: Float {
        similarityThreshold
    }
}


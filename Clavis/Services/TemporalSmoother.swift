//
//  TemporalSmoother.swift
//  Clavis
//
//  Created on 12/26/25.
//

import Foundation

/// Applies temporal smoothing to reduce false positives in verification.
/// Requires consecutive matching frames before confirming a match.
class TemporalSmoother {
    private let windowSize: Int
    private var recentScores: [Float] = []
    var recentMatches: [Bool] = []  // Made internal for logging
    
    init(windowSize: Int = 3) {
        self.windowSize = windowSize
    }
    
    /// Adds a frame's score and match status, returns smoothed match result.
    /// - Parameters:
    ///   - score: Similarity score (0.0 to 1.0)
    ///   - isMatch: Whether this frame is a match
    /// - Returns: True if smoothed result indicates match (consecutive matches in window)
    func addFrame(score: Float, isMatch: Bool) -> Bool {
        recentScores.append(score)
        recentMatches.append(isMatch)
        
        // Keep only recent frames
        if recentScores.count > windowSize {
            recentScores.removeFirst()
            recentMatches.removeFirst()
        }
        
        // Check if we have enough consecutive matches
        guard recentMatches.count >= windowSize else {
            return false
        }
        
        // Check if all recent frames are matches
        let allMatch = recentMatches.suffix(windowSize).allSatisfy { $0 }
        
        if allMatch {
            print("✅ [TemporalSmoother] Match confirmed after \(windowSize) consecutive frames")
        }
        
        return allMatch
    }
    
    /// Resets the smoother (call when starting new verification session).
    func reset() {
        recentScores.removeAll()
        recentMatches.removeAll()
    }
}


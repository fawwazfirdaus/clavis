//
//  OnboardingManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine

/// Tracks which onboarding steps have been completed.
/// Implements responsibilities from SPEC §5.6 OnboardingManager.
class OnboardingManager: ObservableObject {
    @Published private(set) var progress: OnboardingProgress
    
    init(progress: OnboardingProgress = OnboardingProgress()) {
        self.progress = progress
        // TODO: Load onboarding progress from UserDefaults on init
    }
    
    /// Whether onboarding has been completed.
    var isOnboardingComplete: Bool {
        progress.isComplete
    }
    
    /// Whether a specific step has been completed.
    func isStepComplete(_ step: OnboardingStep) -> Bool {
        progress.completedSteps.contains(step)
    }
    
    /// Marks a step as complete.
    func markStepComplete(_ step: OnboardingStep) {
        progress.markStepComplete(step)
        // TODO: Persist onboarding progress to UserDefaults
    }
    
    /// Resets onboarding progress (for testing or re-onboarding).
    func resetOnboarding() {
        progress.reset()
        // TODO: Clear onboarding progress from UserDefaults
    }
}



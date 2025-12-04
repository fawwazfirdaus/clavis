//
//  OnboardingProgress.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation

/// Tracks which onboarding steps have been completed.
/// Implements data structures from SPEC §5.6 OnboardingManager.
struct OnboardingProgress: Codable {
    var completedSteps: Set<OnboardingStep>
    
    init(completedSteps: Set<OnboardingStep> = []) {
        self.completedSteps = completedSteps
    }
    
    var isComplete: Bool {
        OnboardingStep.allRequiredSteps.isSubset(of: completedSteps)
    }
    
    mutating func markStepComplete(_ step: OnboardingStep) {
        completedSteps.insert(step)
    }
    
    mutating func reset() {
        completedSteps.removeAll()
    }
}

/// Steps in the onboarding flow.
/// Implements steps from SPEC §6.1 Onboarding Flow.
enum OnboardingStep: String, Codable, CaseIterable {
    case welcome = "welcome"
    case mainKeyEnrollment = "mainKeyEnrollment"
    case createFirstMode = "createFirstMode"
    case configureAppsForFirstMode = "configureAppsForFirstMode"
    case configureFocusMode = "configureFocusMode"
    case temporaryKeyEnrollment = "temporaryKeyEnrollment"
    case complete = "complete"
    
    static var allRequiredSteps: Set<OnboardingStep> {
        [.welcome, .mainKeyEnrollment, .createFirstMode, .configureAppsForFirstMode, .configureFocusMode, .complete]
    }
}



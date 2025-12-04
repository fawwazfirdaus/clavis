//
//  AppsProfileManager.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages which apps/categories are blocked for each mode during Locked Mode.
/// Implements responsibilities from SPEC §5.4 AppsProfileManager.
class AppsProfileManager: ObservableObject {
    /// Maps mode ID to its app profile
    @Published private(set) var appProfiles: [UUID: AppProfile] = [:]
    
    init() {
        // TODO: Load app profiles from UserDefaults/persistent storage on init
    }
    
    /// Gets the app profile for a specific mode.
    func getAppProfile(for modeId: UUID) -> AppProfile? {
        appProfiles[modeId]
    }
    
    /// Gets or creates the app profile for a specific mode.
    func getOrCreateAppProfile(for modeId: UUID) -> AppProfile {
        if let existing = appProfiles[modeId] {
            return existing
        }
        let newProfile = AppProfile(modeId: modeId)
        appProfiles[modeId] = newProfile
        // TODO: Persist app profile to UserDefaults/persistent storage
        return newProfile
    }
    
    /// Updates the app profile for a specific mode.
    func updateAppProfile(_ profile: AppProfile) {
        var updatedProfile = profile
        updatedProfile.updatedAt = Date()
        appProfiles[profile.modeId] = updatedProfile
        // TODO: Persist app profile to UserDefaults/persistent storage
    }
    
    /// Sets blocked categories for a mode.
    func setBlockedCategories(_ categories: Set<AppCategory>, for modeId: UUID) {
        var profile = getOrCreateAppProfile(for: modeId)
        profile.blockedCategories = categories
        updateAppProfile(profile)
    }
    
    /// Sets blocked app identifiers for a mode.
    func setBlockedAppIdentifiers(_ identifiers: Set<String>, for modeId: UUID) {
        var profile = getOrCreateAppProfile(for: modeId)
        profile.blockedAppIdentifiers = identifiers
        updateAppProfile(profile)
    }
    
    /// Sets temporary unlockable app identifiers for a mode.
    func setTemporaryUnlockableAppIdentifiers(_ identifiers: Set<String>, for modeId: UUID) {
        var profile = getOrCreateAppProfile(for: modeId)
        profile.temporaryUnlockableAppIdentifiers = identifiers
        updateAppProfile(profile)
    }
    
    /// Removes the app profile for a specific mode.
    func removeAppProfile(for modeId: UUID) {
        appProfiles.removeValue(forKey: modeId)
        // TODO: Remove app profile from UserDefaults/persistent storage
    }
}



//
//  AppProfile.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation

/// Represents which apps/categories are blocked for a specific mode.
/// Implements data structures from SPEC §5.4 AppsProfileManager.
struct AppProfile: Codable, Identifiable {
    let id: UUID
    let modeId: UUID
    var blockedCategories: Set<AppCategory>
    var blockedAppIdentifiers: Set<String>
    var temporaryUnlockableAppIdentifiers: Set<String>
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        modeId: UUID,
        blockedCategories: Set<AppCategory> = [],
        blockedAppIdentifiers: Set<String> = [],
        temporaryUnlockableAppIdentifiers: Set<String> = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.modeId = modeId
        self.blockedCategories = blockedCategories
        self.blockedAppIdentifiers = blockedAppIdentifiers
        self.temporaryUnlockableAppIdentifiers = temporaryUnlockableAppIdentifiers
        self.updatedAt = updatedAt
    }
}

/// Categories of apps that can be blocked.
enum AppCategory: String, Codable, CaseIterable {
    case social = "Social"
    case video = "Video"
    case games = "Games"
    case entertainment = "Entertainment"
    case news = "News"
    case shopping = "Shopping"
    case other = "Other"
}



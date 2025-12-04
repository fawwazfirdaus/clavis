//
//  Key.swift
//  Clavis
//
//  Created by Fawwaz Firdaus on 11/26/25.
//

import Foundation

/// Represents a physical key object that can be used across multiple modes.
/// A key wraps a KeyTemplate (feature vectors) and can be assigned as a main key
/// or temporary key for one or more modes.
struct Key: Codable, Identifiable {
    let id: UUID
    let template: KeyTemplate
    /// Optional user-friendly name for the key (e.g., "My Toy", "Blue Mug")
    var name: String?
    var createdAt: Date
    
    init(id: UUID = UUID(), template: KeyTemplate, name: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.template = template
        self.name = name
        self.createdAt = createdAt
    }
}


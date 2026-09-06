//
//  WorldClockCity.swift
//  All-In-One-Clock (Shared)
//
//  A city shown in the world clock. Stays local to the watch, but the model is
//  shared so the iPhone companion can display the same list.
//

import Foundation

/// A named location backed by a time-zone identifier (e.g. "America/New_York").
struct WorldClockCity: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var timeZoneIdentifier: String

    init(id: UUID = UUID(), name: String, timeZoneIdentifier: String) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// The resolved time zone, or `nil` if the identifier is unknown on this device.
    var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }
}

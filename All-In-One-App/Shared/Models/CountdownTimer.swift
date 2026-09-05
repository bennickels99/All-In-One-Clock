//
//  CountdownTimer.swift
//  All-In-One-Clock (Shared)
//
//  A countdown timer request. Shared across the iPhone app, watch app, and widget.
//

import Foundation

/// A countdown timer that runs for `duration` seconds from when it is started.
struct CountdownTimer: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var label: String
    var duration: TimeInterval
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String = "",
        duration: TimeInterval,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.duration = duration
        self.createdAt = createdAt
    }
}

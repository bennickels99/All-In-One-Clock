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
    var soundName: String?  // nil = system default; otherwise a bundled .caf filename

    init(
        id: UUID = UUID(),
        label: String = "",
        duration: TimeInterval,
        createdAt: Date = Date(),
        soundName: String? = nil
    ) {
        self.id = id
        self.label = label
        self.duration = duration
        self.createdAt = createdAt
        self.soundName = soundName
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, label, duration, createdAt, soundName
    }

    // Custom decoder so existing saved timers without soundName still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,         forKey: .id)
        label     = try c.decode(String.self,       forKey: .label)
        duration  = try c.decode(TimeInterval.self, forKey: .duration)
        createdAt = try c.decode(Date.self,         forKey: .createdAt)
        soundName = try c.decodeIfPresent(String.self, forKey: .soundName)
    }
}

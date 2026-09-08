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
    var soundName: String?        // nil = system default; otherwise a bundled .caf filename
    var stages: [TimeInterval]?   // nil = simple timer; populated = multi-stage, durations in order
    var currentStageIndex: Int    // 0-based; always 0 for simple timers

    init(
        id: UUID = UUID(),
        label: String = "",
        duration: TimeInterval,
        createdAt: Date = Date(),
        soundName: String? = nil,
        stages: [TimeInterval]? = nil,
        currentStageIndex: Int = 0
    ) {
        self.id = id
        self.label = label
        self.duration = duration
        self.createdAt = createdAt
        self.soundName = soundName
        self.stages = stages
        self.currentStageIndex = currentStageIndex
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, label, duration, createdAt, soundName, stages, currentStageIndex
    }

    // Custom decoder so existing saved timers without new fields still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(UUID.self,              forKey: .id)
        label             = try c.decode(String.self,            forKey: .label)
        duration          = try c.decode(TimeInterval.self,      forKey: .duration)
        createdAt         = try c.decode(Date.self,              forKey: .createdAt)
        soundName         = try c.decodeIfPresent(String.self,            forKey: .soundName)
        stages            = try c.decodeIfPresent([TimeInterval].self,    forKey: .stages)
        currentStageIndex = try c.decodeIfPresent(Int.self,               forKey: .currentStageIndex) ?? 0
    }
}

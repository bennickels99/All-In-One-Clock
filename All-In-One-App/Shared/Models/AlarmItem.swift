//
//  AlarmItem.swift
//  All-In-One-Clock (Shared)
//
//  A user-scheduled alarm. Shared across the iPhone app, watch app, and widget
//  so all three can describe the same alarm with one Codable value.
//

import Foundation

/// A one-time or weekly-repeating alarm.
///
/// `weekdays` uses `Calendar` weekday numbering (1 = Sunday ... 7 = Saturday).
/// An empty set means the alarm fires once at the next occurrence of `hour:minute`.
struct AlarmItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>
    var label: String
    var isEnabled: Bool
    var snoozeDuration: Int  // minutes

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        weekdays: Set<Int> = [],
        label: String = "",
        isEnabled: Bool = true,
        snoozeDuration: Int = 8
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.label = label
        self.isEnabled = isEnabled
        self.snoozeDuration = snoozeDuration
    }

    /// Whether the alarm repeats on a weekly cadence.
    var repeats: Bool { !weekdays.isEmpty }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, hour, minute, weekdays, label, isEnabled, snoozeDuration
    }

    // Custom decoder so existing saved alarms without snoozeDuration still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,     forKey: .id)
        hour           = try c.decode(Int.self,      forKey: .hour)
        minute         = try c.decode(Int.self,      forKey: .minute)
        weekdays       = try c.decode(Set<Int>.self, forKey: .weekdays)
        label          = try c.decode(String.self,   forKey: .label)
        isEnabled      = try c.decode(Bool.self,     forKey: .isEnabled)
        snoozeDuration = try c.decodeIfPresent(Int.self, forKey: .snoozeDuration) ?? 8
    }
}

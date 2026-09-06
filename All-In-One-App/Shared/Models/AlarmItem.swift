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

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        weekdays: Set<Int> = [],
        label: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.label = label
        self.isEnabled = isEnabled
    }

    /// Whether the alarm repeats on a weekly cadence.
    var repeats: Bool { !weekdays.isEmpty }
}

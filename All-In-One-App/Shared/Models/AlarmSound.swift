//
//  AlarmSound.swift
//  All-In-One-Clock (Shared)
//
//  Catalog of selectable alarm sounds. iOS uses the filename to resolve
//  AlertConfiguration.AlertSound.named(_:); Watch uses it only to store
//  the selection in AlarmItem/CountdownTimer for the phone to act on.
//

import Foundation

struct AlarmSound: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    /// Filename in the iOS app bundle. `nil` means use the system default sound.
    let filename: String?

    static let `default`        = AlarmSound(id: "default",             displayName: "Default",          filename: nil)
    static let classicAlarm     = AlarmSound(id: "ClassicAlarmClock",   displayName: "Classic Alarm",    filename: "ClassicAlarmClock.caf")
    static let classicDigital   = AlarmSound(id: "ClassicAlarmDigital", displayName: "Classic Digital",  filename: "ClassicAlarmDigital.caf")
    static let dadsAlarm        = AlarmSound(id: "DadsAlarmClock",      displayName: "Dad's Alarm",      filename: "DadsAlarmClock.caf")

    static let all: [AlarmSound] = [.default, .classicAlarm, .classicDigital, .dadsAlarm]
}

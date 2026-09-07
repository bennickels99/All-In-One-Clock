//
//  SnoozeAlarmIntent.swift
//  All-In-One-Clock
//

import AlarmKit
import AppIntents

struct SnoozeAlarmIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource { "Snooze Alarm" }

    @Parameter(title: "Alarm ID")
    var alarmID: String

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        // Duration was set at schedule time via Alarm.CountdownDuration.postAlert.
        // countdown(id:) takes no duration parameter.
        try? AlarmManager.shared.countdown(id: id)
        return .result()
    }
}

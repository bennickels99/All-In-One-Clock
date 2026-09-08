//
//  AppIntent.swift
//  ClockWidgetExtension
//
//  Live Activity intents for timer pause/resume/cancel controls.
//  These run inside the widget extension process, which has direct access
//  to AlarmManager, so no IPC to the host app is needed.
//

import AppIntents
import AlarmKit

struct PauseTimerIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource { "Pause Timer" }
    @Parameter(title: "Timer ID") var timerID: String

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }
        try? AlarmManager.shared.pause(id: id)
        return .result()
    }
}

struct ResumeTimerIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource { "Resume Timer" }
    @Parameter(title: "Timer ID") var timerID: String

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }
        try? AlarmManager.shared.resume(id: id)
        return .result()
    }
}

struct CancelTimerIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource { "Cancel Timer" }
    @Parameter(title: "Timer ID") var timerID: String

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }
        try? AlarmManager.shared.stop(id: id)
        return .result()
    }
}

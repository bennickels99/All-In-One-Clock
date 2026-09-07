//
//  AlarmKitCoordinator.swift
//  All-In-One-Clock
//
//  Source of truth for alarms and timers on the iPhone. Schedules via AlarmKit,
//  observes alarmUpdates to keep the list current, and mirrors state to the
//  watch via WatchConnectivity (wired up fully in Phase 4).
//
//  Simulator note: AlarmKit scheduling and the alert UI work on simulator, but
//  the Live Activity XPC calls (countdown/paused presentations, snooze countdown)
//  crash Springboard. ClockAlarmMetadata uses #if targetEnvironment(simulator) to
//  strip those presentations out, and the alarmUpdates loop is skipped on simulator
//  since the AlarmKit daemon doesn't run there.
//

import ActivityKit
import AlarmKit
import SwiftUI

@MainActor
@Observable
final class AlarmKitCoordinator {

    // MARK: - Published state

    var alarms: [AlarmItem] = []
    var timers: [CountdownTimer] = []
    var cities: [WorldClockCity] = []
    var authorizationState: AlarmManager.AuthorizationState = .notDetermined

    // MARK: - Init / persistence keys

    private enum Keys {
        static let alarms = "coordinator.alarms"
        static let timers = "coordinator.timers"
        static let cities = "coordinator.cities"
    }

    init() {
        loadState()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            authorizationState = try await AlarmManager.shared.requestAuthorization()
        } catch {
            // Authorization errors are non-fatal; state stays .notDetermined
        }
    }

    func observeAuthorizationUpdates() async {
        for await state in AlarmManager.shared.authorizationUpdates {
            authorizationState = state
        }
    }

    // MARK: - Schedule

    func scheduleAlarm(_ alarm: AlarmItem) async throws {
        if authorizationState == .notDetermined { await requestAuthorization() }
        guard authorizationState == .authorized else {
            throw alarmPermissionError()
        }
        let attrs = ClockAlarmMetadata.attributes(label: alarm.label, kind: .alarm)
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.weekdays.isEmpty
            ? .never
            : .weekly(localeWeekdays(from: alarm.weekdays))
        let schedule = Alarm.Schedule.relative(Alarm.Schedule.Relative(time: time, repeats: recurrence))
        let snoozeIntent = SnoozeAlarmIntent()
        snoozeIntent.alarmID = alarm.id.uuidString
        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: TimeInterval(alarm.snoozeDuration * 60)
            ),
            schedule: schedule,
            attributes: attrs,
            secondaryIntent: snoozeIntent,
            sound: alarmSound(from: alarm.soundName)
        )
        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: config)

        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        saveState()
        pushStateToWatch()
    }

    func scheduleTimer(_ timer: CountdownTimer) async throws {
        if authorizationState == .notDetermined { await requestAuthorization() }
        guard authorizationState == .authorized else {
            throw alarmPermissionError()
        }
        let attrs = ClockAlarmMetadata.attributes(label: timer.label, kind: .timer)
        let config = AlarmManager.AlarmConfiguration.timer(
            duration: timer.duration,
            attributes: attrs,
            sound: alarmSound(from: timer.soundName)
        )
        _ = try await AlarmManager.shared.schedule(id: timer.id, configuration: config)

        if let index = timers.firstIndex(where: { $0.id == timer.id }) {
            timers[index] = timer
        } else {
            timers.append(timer)
        }
        saveState()
        pushStateToWatch()
    }

    // MARK: - Cancel

    func cancel(id: UUID) throws {
        alarms.removeAll { $0.id == id }
        timers.removeAll { $0.id == id }
        saveState()
        pushStateToWatch()
        try? AlarmManager.shared.stop(id: id)
    }

    // MARK: - Toggle alarm enabled

    func setEnabled(_ enabled: Bool, for alarm: AlarmItem) async throws {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        var updated = alarm
        updated.isEnabled = enabled
        if enabled {
            try await scheduleAlarm(updated)
        } else {
            try? AlarmManager.shared.stop(id: alarm.id)
            alarms[index] = updated
            saveState()
            pushStateToWatch()
        }
    }

    // MARK: - World clock (local)

    func addCity(_ city: WorldClockCity) {
        cities.append(city)
        saveState()
    }

    func removeCity(at offsets: IndexSet) {
        cities.remove(atOffsets: offsets)
        saveState()
    }

    // MARK: - Observe AlarmKit updates

    func startObserving() async {
        authorizationState = AlarmManager.shared.authorizationState
#if targetEnvironment(simulator)
        // The AlarmKit daemon doesn't run on simulator so alarmUpdates never
        // produces values; skipping avoids a suspended task holding the .task modifier.
        return
#else
        for await activeAlarms in AlarmManager.shared.alarmUpdates {
            let activeIDs = Set(activeAlarms.map(\.id))
            // Fired one-shots are removed from AlarmKit — remove timers, mark alarms disabled.
            timers.removeAll { !activeIDs.contains($0.id) }
            for index in alarms.indices {
                if alarms[index].isEnabled && !alarms[index].repeats && !activeIDs.contains(alarms[index].id) {
                    alarms[index].isEnabled = false
                }
            }
            saveState()
            pushStateToWatch()
        }
#endif
    }

    // MARK: - Watch sync

    func pushStateToWatch() {
        let state = ClockState(alarms: alarms, timers: timers)
        ConnectivityManager.shared.updateContext(.stateSync(state))
    }

    // MARK: - Sound helper

    private func alarmSound(from soundName: String?) -> AlertConfiguration.AlertSound {
        return .named(soundName ?? AlarmSound.classicAlarm.filename)
    }

    // MARK: - Weekday conversion (Calendar 1=Sun…7=Sat → Locale.Weekday)

    private func localeWeekdays(from calendarWeekdays: Set<Int>) -> [Locale.Weekday] {
        let map: [Int: Locale.Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        return calendarWeekdays.sorted().compactMap { map[$0] }
    }

    // MARK: - Helpers

    private func alarmPermissionError() -> NSError {
        let message = authorizationState == .denied
            ? "Alarm permission was denied. Go to Settings > All-In-One Clock to enable it."
            : "Alarm permission is required. Please authorize in Settings."
        return NSError(domain: "com.allinone.clock", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: message])
    }

    // MARK: - Persistence

    private func saveState() {
        let encoder = JSONEncoder()
        UserDefaults.standard.set(try? encoder.encode(alarms), forKey: Keys.alarms)
        UserDefaults.standard.set(try? encoder.encode(timers), forKey: Keys.timers)
        UserDefaults.standard.set(try? encoder.encode(cities), forKey: Keys.cities)
    }

    private func loadState() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: Keys.alarms) {
            alarms = (try? decoder.decode([AlarmItem].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: Keys.timers) {
            timers = (try? decoder.decode([CountdownTimer].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: Keys.cities) {
            cities = (try? decoder.decode([WorldClockCity].self, from: data)) ?? []
        }
    }
}

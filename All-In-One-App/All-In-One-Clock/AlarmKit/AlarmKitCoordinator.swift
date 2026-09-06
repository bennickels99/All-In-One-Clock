//
//  AlarmKitCoordinator.swift
//  All-In-One-Clock
//
//  Source of truth for alarms and timers on the iPhone. Schedules via AlarmKit,
//  observes alarmUpdates to keep the list current, and mirrors state to the
//  watch via WatchConnectivity (wired up fully in Phase 4).
//

import AlarmKit
import WatchConnectivity
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

    // MARK: - Schedule

    func scheduleAlarm(_ alarm: AlarmItem) async throws {
        let attrs = ClockAlarmMetadata.attributes(label: alarm.label, kind: .alarm)
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.weekdays.isEmpty
            ? .never
            : .weekly(localeWeekdays(from: alarm.weekdays))
        let schedule = Alarm.Schedule.relative(Alarm.Schedule.Relative(time: time, repeats: recurrence))
        let config = AlarmManager.AlarmConfiguration.alarm(schedule: schedule, attributes: attrs)
        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: config)

        if !alarms.contains(where: { $0.id == alarm.id }) {
            alarms.append(alarm)
        }
        saveState()
        pushStateToWatch()
    }

    func scheduleTimer(_ timer: CountdownTimer) async throws {
        let attrs = ClockAlarmMetadata.attributes(label: timer.label, kind: .timer)
        let config = AlarmManager.AlarmConfiguration.timer(duration: timer.duration, attributes: attrs)
        _ = try await AlarmManager.shared.schedule(id: timer.id, configuration: config)

        if !timers.contains(where: { $0.id == timer.id }) {
            timers.append(timer)
        }
        saveState()
        pushStateToWatch()
    }

    // MARK: - Cancel

    func cancel(id: UUID) throws {
        try AlarmManager.shared.stop(id: id)
        alarms.removeAll { $0.id == id }
        timers.removeAll { $0.id == id }
        saveState()
        pushStateToWatch()
    }

    // MARK: - Toggle alarm enabled

    func setEnabled(_ enabled: Bool, for alarm: AlarmItem) async throws {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        var updated = alarm
        updated.isEnabled = enabled
        if enabled {
            try await scheduleAlarm(updated)
        } else {
            // Stop first — only update the array if AlarmKit accepts it, so the
            // UI never shows "disabled" for an alarm that is still active.
            try AlarmManager.shared.stop(id: alarm.id)
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
        for await activeAlarms in AlarmManager.shared.alarmUpdates {
            let activeIDs = Set(activeAlarms.map(\.id))
            // Remove fired one-shot timers
            timers.removeAll { !activeIDs.contains($0.id) }
            // Remove fired one-shot alarms (repeating stay scheduled)
            alarms.removeAll { !$0.repeats && !activeIDs.contains($0.id) }
            saveState()
            pushStateToWatch()
        }
    }

    // MARK: - Watch sync (Phase 4 will route through ConnectivityManager)

    func pushStateToWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        // isPaired / isWatchAppInstalled are only reliable after the session is
        // activated. Before Phase 4 wires ConnectivityManager, the session is
        // inactive and these properties return false — so this guard safely
        // no-ops rather than pushing stale/empty context. Phase 4 activation
        // makes the push live.
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }
        let state = ClockState(alarms: alarms, timers: timers)
        guard let payload = try? ClockMessage.stateSync(state).encodedPayload() else { return }
        try? session.updateApplicationContext(payload)
    }

    // MARK: - Weekday conversion (Calendar 1=Sun…7=Sat → Locale.Weekday)

    private func localeWeekdays(from calendarWeekdays: Set<Int>) -> [Locale.Weekday] {
        let map: [Int: Locale.Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        return calendarWeekdays.sorted().compactMap { map[$0] }
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

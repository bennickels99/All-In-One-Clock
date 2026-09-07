//
//  AlarmKitCoordinator.swift
//  All-In-One-Clock
//
//  Source of truth for alarms and timers on the iPhone. On a physical device,
//  schedules via AlarmKit and observes alarmUpdates. On simulator, falls back
//  to UNUserNotificationCenter because AlarmKit's Springboard XPC communication
//  is not available in the simulator and causes Springboard to crash at fire time.
//

import ActivityKit
import AlarmKit
import SwiftUI
import UserNotifications

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
#if targetEnvironment(simulator)
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authorizationState = granted ? .authorized : .denied
        } catch {
            // stay .notDetermined
        }
#else
        do {
            authorizationState = try await AlarmManager.shared.requestAuthorization()
        } catch {
            // Authorization errors are non-fatal; state stays .notDetermined
        }
#endif
    }

    func observeAuthorizationUpdates() async {
#if targetEnvironment(simulator)
        // No AlarmKit authorization stream on simulator; nothing to observe.
#else
        for await state in AlarmManager.shared.authorizationUpdates {
            authorizationState = state
        }
#endif
    }

    // MARK: - Schedule

    func scheduleAlarm(_ alarm: AlarmItem) async throws {
        if authorizationState == .notDetermined { await requestAuthorization() }
        guard authorizationState == .authorized else {
            throw alarmPermissionError()
        }

#if targetEnvironment(simulator)
        try await scheduleAlarmNotification(alarm)
#else
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
#endif

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

#if targetEnvironment(simulator)
        try await scheduleTimerNotification(timer)
#else
        let attrs = ClockAlarmMetadata.attributes(label: timer.label, kind: .timer)
        let config = AlarmManager.AlarmConfiguration.timer(
            duration: timer.duration,
            attributes: attrs,
            sound: alarmSound(from: timer.soundName)
        )
        _ = try await AlarmManager.shared.schedule(id: timer.id, configuration: config)
#endif

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
#if targetEnvironment(simulator)
        removePendingNotifications(for: id)
#else
        try? AlarmManager.shared.stop(id: id)
#endif
    }

    // MARK: - Toggle alarm enabled

    func setEnabled(_ enabled: Bool, for alarm: AlarmItem) async throws {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        var updated = alarm
        updated.isEnabled = enabled
        if enabled {
            try await scheduleAlarm(updated)
        } else {
#if targetEnvironment(simulator)
            removePendingNotifications(for: alarm.id)
#else
            try? AlarmManager.shared.stop(id: alarm.id)
#endif
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
#if targetEnvironment(simulator)
        // AlarmKit daemon not available on simulator — check UNUserNotificationCenter
        // auth state so the UI reflects correct permission status.
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationState = .authorized
        case .denied:
            authorizationState = .denied
        default:
            break
        }
#else
        authorizationState = AlarmManager.shared.authorizationState
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

    // MARK: - Simulator: UNUserNotificationCenter fallback

#if targetEnvironment(simulator)
    private func scheduleAlarmNotification(_ alarm: AlarmItem) async throws {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "Your alarm is going off"
        content.sound = .defaultCritical
        let center = UNUserNotificationCenter.current()
        var comps = DateComponents()
        comps.hour = alarm.hour
        comps.minute = alarm.minute
        if alarm.weekdays.isEmpty {
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            try await center.add(request)
        } else {
            for weekday in alarm.weekdays {
                var dayComps = comps
                dayComps.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: dayComps, repeats: true)
                let id = "\(alarm.id.uuidString)-\(weekday)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try await center.add(request)
            }
        }
    }

    private func scheduleTimerNotification(_ timer: CountdownTimer) async throws {
        let content = UNMutableNotificationContent()
        content.title = timer.label.isEmpty ? "Timer" : timer.label
        content.body = "Your timer has finished"
        content.sound = .defaultCritical
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timer.duration, repeats: false)
        let request = UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    private func removePendingNotifications(for id: UUID) {
        let ids = [id.uuidString] + (1...7).map { "\(id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
#endif

    // MARK: - Sound helper (device only)

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

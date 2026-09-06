import UserNotifications
import Foundation

/// Routes alarm/timer create and cancel requests from the watch to the phone.
///
/// When the phone is reachable the message goes immediately via sendMessage.
/// When it is not reachable, ConnectivityManager queues it via transferUserInfo
/// (guaranteed delivery) AND we schedule a local UNNotification as a fallback
/// so the user gets alerted even if the phone never comes online in time.
/// Fallback notifications are cancelled as soon as the phone confirms receipt
/// via a .stateSync message.
@MainActor
final class WatchAlarmBridge {
    static let shared = WatchAlarmBridge()
    private init() {}

    // MARK: - Schedule

    func scheduleAlarm(_ alarm: AlarmItem, store: ClockStore) async {
        // Optimistic update so the UI responds immediately
        store.alarms.removeAll { $0.id == alarm.id }
        store.alarms.append(alarm)
        // Snapshot reachability once so send() and the fallback decision use the
        // same state — avoids a TOCTOU where reachability changes between the two.
        let reachable = ConnectivityManager.shared.isReachable
        ConnectivityManager.shared.send(.scheduleAlarm(alarm))
        if !reachable {
            await scheduleFallback(for: alarm)
        }
    }

    func scheduleTimer(_ timer: CountdownTimer, store: ClockStore) async {
        store.timers.removeAll { $0.id == timer.id }
        store.timers.append(timer)
        let reachable = ConnectivityManager.shared.isReachable
        ConnectivityManager.shared.send(.scheduleTimer(timer))
        if !reachable {
            await scheduleFallback(for: timer)
        }
    }

    // MARK: - Cancel

    func cancel(id: UUID, store: ClockStore) {
        store.alarms.removeAll { $0.id == id }
        store.timers.removeAll { $0.id == id }
        ConnectivityManager.shared.send(.cancel(id))
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    // MARK: - Reconciliation

    /// Called on every .stateSync from the phone. Cancels local fallback
    /// notifications for any item now confirmed managed by AlarmKit.
    func reconcile(with state: ClockState) {
        let confirmedIDs = (state.alarms.map(\.id) + state.timers.map(\.id))
            .map(\.uuidString)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: confirmedIDs)
    }

    // MARK: - Local notification fallbacks

    private func scheduleFallback(for alarm: AlarmItem) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "Your alarm is going off."
        content.sound = .defaultCritical

        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: alarm.repeats
        )
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func scheduleFallback(for timer: CountdownTimer) async {
        guard timer.duration > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = timer.label.isEmpty ? "Timer" : timer.label
        content.body = "Your timer has ended."
        content.sound = .defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timer.duration,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: timer.id.uuidString,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

import Foundation

/// Formats an elapsed time interval as a stopwatch display string.
/// Shows centiseconds when under 1 hour: "m:ss.cs" (e.g. "1:23.45")
/// Shows full hours when ≥1h: "h:mm:ss" (e.g. "1:02:03")
func formatElapsed(_ elapsed: TimeInterval) -> String {
    let total = Int(elapsed)
    let centis = Int((elapsed - Double(total)) * 100)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%d:%02d.%02d", m, s, centis)
}

/// Formats a duration as a compact "h:mm:ss" or "m:ss" string (no centiseconds).
func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

/// Returns a short human-readable label for the next scheduled alarm, e.g. "7:00 AM".
/// Returns "None" when there are no enabled alarms.
func nextAlarmLabel(from alarms: [AlarmItem]) -> String {
    let enabled = alarms.filter(\.isEnabled)
    guard !enabled.isEmpty else { return "None" }

    let cal = Calendar.current
    let now = Date()
    let todayComps = cal.dateComponents([.weekday, .hour, .minute], from: now)
    let todayWeekday = todayComps.weekday ?? 1
    let nowMinutes = (todayComps.hour ?? 0) * 60 + (todayComps.minute ?? 0)

    var soonestMinutes = Int.max
    var soonestAlarm: AlarmItem?

    for alarm in enabled {
        let alarmMinutes = alarm.hour * 60 + alarm.minute
        let minutesUntil: Int
        if alarm.weekdays.isEmpty {
            // One-shot: fires today if time hasn't passed, else tomorrow
            minutesUntil = alarmMinutes > nowMinutes
                ? alarmMinutes - nowMinutes
                : 1440 - nowMinutes + alarmMinutes
        } else {
            // Find the soonest upcoming occurrence across all matching weekdays.
            // Scanning 0..<8 ensures we always find at least one hit (the same
            // weekday one week from today at worst). We break on the first day
            // with a future candidate; if today's occurrence already passed we
            // record next week's occurrence and keep scanning for an earlier day
            // later this week.
            var best = Int.max
            for dayOffset in 0..<8 {
                let weekday = ((todayWeekday - 1 + dayOffset) % 7) + 1
                guard alarm.weekdays.contains(weekday) else { continue }
                let candidate = dayOffset * 1440 + alarmMinutes - nowMinutes
                if candidate > 0 {
                    best = min(best, candidate)
                    break // dayOffsets are ascending; this is the earliest future hit
                }
                // Today's occurrence already passed — next occurrence is 7 days away.
                best = min(best, candidate + 7 * 1440)
                // Don't break: a later day this week might be sooner than next week.
            }
            minutesUntil = best
        }
        if minutesUntil < soonestMinutes {
            soonestMinutes = minutesUntil
            soonestAlarm = alarm
        }
    }

    guard let alarm = soonestAlarm else { return "None" }
    let ampm = alarm.hour < 12 ? "AM" : "PM"
    let h = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
    return String(format: "%d:%02d %@", h, alarm.minute, ampm)
}

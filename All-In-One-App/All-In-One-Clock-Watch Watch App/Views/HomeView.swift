import SwiftUI

struct HomeView: View {
    @Environment(ClockStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: StopwatchView()) {
                    HomeRow(
                        icon: "stopwatch",
                        color: .orange,
                        title: "Stopwatch",
                        badge: stopwatchBadge
                    )
                }
                NavigationLink(destination: TimerListView()) {
                    HomeRow(
                        icon: "timer",
                        color: .yellow,
                        title: "Timers",
                        badge: timerBadge
                    )
                }
                NavigationLink(destination: AlarmListView()) {
                    HomeRow(
                        icon: "alarm",
                        color: .red,
                        title: "Alarms",
                        badge: alarmBadge
                    )
                }
                NavigationLink(destination: WorldClockView()) {
                    HomeRow(
                        icon: "globe",
                        color: .blue,
                        title: "World Clock",
                        badge: store.cities.isEmpty ? "" : "\(store.cities.count)"
                    )
                }
            }
            .navigationTitle("Clock")
        }
    }

    // MARK: - Badges

    private var stopwatchBadge: String {
        switch store.stopwatch.phase {
        case .idle: return ""
        case .running: return "Running"
        case .paused: return formatElapsed(store.stopwatch.elapsed(at: .now))
        }
    }

    private var timerBadge: String {
        guard !store.timers.isEmpty else { return "" }
        return store.timers.count == 1 ? "1 active" : "\(store.timers.count) active"
    }

    private var alarmBadge: String {
        nextAlarmLabel(from: store.alarms)
    }
}

private struct HomeRow: View {
    let icon: String
    let color: Color
    let title: String
    let badge: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if !badge.isEmpty {
                    Text(badge)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

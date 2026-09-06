import SwiftUI

struct HomeView: View {
    @Environment(ClockStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                // Stopwatch row needs live updates while running.
                NavigationLink(destination: StopwatchView()) {
                    StopwatchTile()
                }

                NavigationLink(destination: TimerListView()) {
                    FeatureTileRow(
                        icon: "timer",
                        color: .yellow,
                        title: "Timers",
                        badge: timerBadge
                    )
                }

                NavigationLink(destination: AlarmListView()) {
                    FeatureTileRow(
                        icon: "alarm",
                        color: .red,
                        title: "Alarms",
                        badge: alarmBadge
                    )
                }

                NavigationLink(destination: WorldClockView()) {
                    FeatureTileRow(
                        icon: "globe",
                        color: .blue,
                        title: "World Clock",
                        badge: store.cities.isEmpty ? "" : "\(store.cities.count)"
                    )
                }

                // Phone connectivity indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.isPhoneReachable ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(store.isPhoneReachable ? "iPhone connected" : "iPhone unreachable")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .padding(.top, 2)
            }
            .navigationTitle("Clock")
        }
    }

    // MARK: - Badges

    private var timerBadge: String {
        guard !store.timers.isEmpty else { return "" }
        return store.timers.count == 1 ? "1 active" : "\(store.timers.count) active"
    }

    private var alarmBadge: String {
        nextAlarmLabel(from: store.alarms)
    }
}

// MARK: - Stopwatch tile (live elapsed via TimelineView)

private struct StopwatchTile: View {
    @Environment(ClockStore.self) private var store

    var body: some View {
        // Animation schedule keeps centiseconds live while running.
        // When idle/paused, elapsed() is constant so frames are visual no-ops.
        TimelineView(.animation) { context in
            FeatureTileRow(
                icon: "stopwatch",
                color: .orange,
                title: "Stopwatch",
                badge: stopwatchBadge(at: context.date)
            )
        }
    }

    private func stopwatchBadge(at now: Date) -> String {
        switch store.stopwatch.phase {
        case .idle: return ""
        case .running, .paused: return formatElapsed(store.stopwatch.elapsed(at: now))
        }
    }
}

// MARK: - Shared tile row

private struct FeatureTileRow: View {
    let icon: String
    let color: Color
    let title: String
    let badge: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                if !badge.isEmpty {
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

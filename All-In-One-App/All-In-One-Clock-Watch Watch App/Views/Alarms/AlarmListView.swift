import SwiftUI

struct AlarmListView: View {
    @Environment(ClockStore.self) private var store
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(store.alarms) { alarm in
                AlarmRow(alarm: alarm)
            }
            .onDelete { offsets in
                for index in offsets {
                    WatchAlarmBridge.shared.cancel(id: store.alarms[index].id, store: store)
                }
            }

            Button {
                showingAdd = true
            } label: {
                Label("Add Alarm", systemImage: "plus")
            }
        }
        .navigationTitle("Alarms")
        .sheet(isPresented: $showingAdd) {
            AddAlarmView()
        }
    }
}

private struct AlarmRow: View {
    let alarm: AlarmItem

    private var timeLabel: String {
        let ampm = alarm.hour < 12 ? "AM" : "PM"
        let h = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
        return String(format: "%d:%02d %@", h, alarm.minute, ampm)
    }

    private var repeatLabel: String {
        guard !alarm.weekdays.isEmpty else { return "Once" }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return alarm.weekdays.sorted()
            .compactMap { $0 >= 1 && $0 <= 7 ? names[$0 - 1] : nil }
            .joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeLabel)
                .font(.headline)
            if !alarm.label.isEmpty {
                Text(alarm.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(repeatLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

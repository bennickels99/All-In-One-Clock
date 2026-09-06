import SwiftUI

struct AddAlarmView: View {
    @Environment(ClockStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var hour = Calendar.current.component(.hour, from: .now)
    @State private var minute = Calendar.current.component(.minute, from: .now)
    @State private var selectedWeekdays: Set<Int> = []
    @State private var label = ""
    @State private var isScheduling = false

    private let weekdayAbbreviations = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    HStack(spacing: 0) {
                        Picker("Hour", selection: $hour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Text(":")
                            .font(.title2.bold())

                        Picker("Minute", selection: $minute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 80)
                }

                Section("Repeat") {
                    // Weekday 1=Sun…7=Sat
                    HStack(spacing: 3) {
                        ForEach(1...7, id: \.self) { day in
                            let selected = selectedWeekdays.contains(day)
                            Button(weekdayAbbreviations[day - 1]) {
                                if selected { selectedWeekdays.remove(day) }
                                else { selectedWeekdays.insert(day) }
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                            .tint(selected ? .orange : .secondary)
                            .font(.system(size: 11, weight: .semibold))
                        }
                    }
                }

                Section {
                    TextField("Label (optional)", text: $label)
                }

                Button("Add Alarm") {
                    guard !isScheduling else { return }
                    isScheduling = true
                    let alarm = AlarmItem(
                        hour: hour,
                        minute: minute,
                        weekdays: selectedWeekdays,
                        label: label
                    )
                    Task {
                        await WatchAlarmBridge.shared.scheduleAlarm(alarm, store: store)
                        dismiss()
                    }
                }
                .disabled(isScheduling)
            }
            .navigationTitle("New Alarm")
        }
    }
}

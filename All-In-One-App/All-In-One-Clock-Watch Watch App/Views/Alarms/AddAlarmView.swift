import SwiftUI

struct AddAlarmView: View {
    @Environment(ClockStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var hour = Calendar.current.component(.hour, from: .now)
    @State private var minute = Calendar.current.component(.minute, from: .now)
    @State private var label = ""
    @State private var repeatPreset: RepeatPreset = .never
    @State private var customWeekdays: Set<Int> = []
    @State private var snoozeDuration = 8
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
                    Picker("Preset", selection: $repeatPreset) {
                        ForEach(RepeatPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }

                    if repeatPreset == .custom {
                        HStack(spacing: 3) {
                            ForEach(1...7, id: \.self) { day in
                                let selected = customWeekdays.contains(day)
                                Button(weekdayAbbreviations[day - 1]) {
                                    if selected { customWeekdays.remove(day) }
                                    else { customWeekdays.insert(day) }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.bordered)
                                .tint(selected ? .orange : .secondary)
                                .font(.system(size: 11, weight: .semibold))
                            }
                        }
                    }
                }

                Section("Snooze") {
                    Picker("Duration", selection: $snoozeDuration) {
                        Text("5 min").tag(5)
                        Text("8 min").tag(8)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("20 min").tag(20)
                    }
                }

                Section {
                    TextField("Label (optional)", text: $label)
                }

                Button("Add Alarm") {
                    guard !isScheduling else { return }
                    isScheduling = true
                    let weekdays = repeatPreset.resolvedWeekdays ?? customWeekdays
                    let alarm = AlarmItem(
                        hour: hour,
                        minute: minute,
                        weekdays: weekdays,
                        label: label,
                        snoozeDuration: snoozeDuration
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

private enum RepeatPreset: String, CaseIterable, Identifiable {
    case never, weekdays, weekends, custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .never:    return "Never"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .custom:   return "Custom"
        }
    }
    var resolvedWeekdays: Set<Int>? {
        switch self {
        case .never:    return []
        case .weekdays: return [2, 3, 4, 5, 6]  // Mon–Fri
        case .weekends: return [1, 7]            // Sun, Sat
        case .custom:   return nil
        }
    }
}

import SwiftUI

struct AddAlarmView: View {
    @Environment(ClockStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existingAlarm: AlarmItem?

    @State private var hour: Int
    @State private var minute: Int
    @State private var label: String
    @State private var repeatPreset: RepeatPreset
    @State private var customWeekdays: Set<Int>
    @State private var snoozeDuration: Int
    @State private var selectedSound: AlarmSound
    @State private var isScheduling = false

    private let weekdayAbbreviations = ["S", "M", "T", "W", "T", "F", "S"]

    init(existingAlarm: AlarmItem? = nil) {
        self.existingAlarm = existingAlarm
        if let alarm = existingAlarm {
            _hour           = State(initialValue: alarm.hour)
            _minute         = State(initialValue: alarm.minute)
            _label          = State(initialValue: alarm.label)
            _snoozeDuration = State(initialValue: alarm.snoozeDuration)
            let preset      = RepeatPreset.from(weekdays: alarm.weekdays)
            _repeatPreset   = State(initialValue: preset)
            _customWeekdays = State(initialValue: preset == .custom ? alarm.weekdays : [])
            let sound       = AlarmSound.all.first { $0.filename == alarm.soundName } ?? .classicAlarm
            _selectedSound  = State(initialValue: sound)
        } else {
            _hour           = State(initialValue: Calendar.current.component(.hour, from: .now))
            _minute         = State(initialValue: Calendar.current.component(.minute, from: .now))
            _label          = State(initialValue: "")
            _repeatPreset   = State(initialValue: .never)
            _customWeekdays = State(initialValue: [])
            _snoozeDuration = State(initialValue: 8)
            _selectedSound  = State(initialValue: .classicAlarm)
        }
    }

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
                        ForEach(1...20, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                }

                Section("Sound") {
                    Picker("Sound", selection: $selectedSound) {
                        ForEach(AlarmSound.all) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                }

                Section {
                    TextField("Label (optional)", text: $label)
                }

                Button(existingAlarm == nil ? "Add Alarm" : "Save Alarm") {
                    guard !isScheduling else { return }
                    isScheduling = true
                    let weekdays = repeatPreset.resolvedWeekdays ?? customWeekdays
                    let alarm = AlarmItem(
                        id: existingAlarm?.id ?? UUID(),
                        hour: hour,
                        minute: minute,
                        weekdays: weekdays,
                        label: label,
                        snoozeDuration: snoozeDuration,
                        soundName: selectedSound.filename
                    )
                    Task {
                        await WatchAlarmBridge.shared.scheduleAlarm(alarm, store: store)
                        dismiss()
                    }
                }
                .disabled(isScheduling)
            }
            .navigationTitle(existingAlarm == nil ? "New Alarm" : "Edit Alarm")
        }
    }
}

private enum RepeatPreset: String, CaseIterable, Identifiable {
    case never, daily, weekdays, weekends, custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .never:    return "Never"
        case .daily:    return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .custom:   return "Custom"
        }
    }
    var resolvedWeekdays: Set<Int>? {
        switch self {
        case .never:    return []
        case .daily:    return [1, 2, 3, 4, 5, 6, 7]
        case .weekdays: return [2, 3, 4, 5, 6]  // Mon–Fri
        case .weekends: return [1, 7]            // Sun, Sat
        case .custom:   return nil
        }
    }
    static func from(weekdays: Set<Int>) -> RepeatPreset {
        if weekdays.isEmpty            { return .never }
        if weekdays == [1,2,3,4,5,6,7] { return .daily }
        if weekdays == [2,3,4,5,6]     { return .weekdays }
        if weekdays == [1,7]           { return .weekends }
        return .custom
    }
}

//
//  AlarmsView.swift
//  All-In-One-Clock
//

import AlarmKit
import SwiftUI

// MARK: - Repeat Preset

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
    // nil means user controls the day set; non-nil values are fixed presets.
    var resolvedWeekdays: Set<Int>? {
        switch self {
        case .never:    return []
        case .weekdays: return [2, 3, 4, 5, 6]  // Mon–Fri
        case .weekends: return [1, 7]            // Sun, Sat
        case .custom:   return nil
        }
    }
}

// MARK: - Alarms List

struct AlarmsView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL
    @State private var showingAdd = false
    @State private var showingAuthAlert = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(coordinator.alarms) { alarm in
                    AlarmRow(alarm: alarm)
                }
                .onDelete { offsets in
                    let ids = offsets.map { coordinator.alarms[$0].id }
                    for id in ids { try? coordinator.cancel(id: id) }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await checkAuthThenAdd() }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddAlarmView()
            }
            .overlay {
                if coordinator.alarms.isEmpty {
                    ContentUnavailableView("No Alarms", systemImage: "alarm",
                                          description: Text("Tap + to add an alarm."))
                }
            }
            .alert("Alarm Permission Required", isPresented: $showingAuthAlert) {
                Button("Open Settings") {
                    if let url = URL(string: "app-settings:") { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All-In-One Clock needs permission to schedule alarms. Enable it in Settings.")
            }
        }
    }

    private func checkAuthThenAdd() async {
        if coordinator.authorizationState == .notDetermined {
            await coordinator.requestAuthorization()
        }
        if coordinator.authorizationState == .authorized {
            showingAdd = true
        } else {
            showingAuthAlert = true
        }
    }
}

// MARK: - Alarm Row

private struct AlarmRow: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    let alarm: AlarmItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(timeString)
                    .font(.title2.monospacedDigit())
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if alarm.repeats {
                    Text(weekdaySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !alarm.isEnabled {
                    Text("Elapsed")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { enabled in
                    Task { try? await coordinator.setEnabled(enabled, for: alarm) }
                }
            ))
            .labelsHidden()
        }
        .opacity(alarm.isEnabled ? 1 : 0.65)
    }

    private var timeString: String {
        var comps = DateComponents()
        comps.hour = alarm.hour
        comps.minute = alarm.minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }

    private var weekdaySummary: String {
        switch alarm.weekdays {
        case [2, 3, 4, 5, 6]: return "Weekdays"
        case [1, 7]:           return "Weekends"
        default:
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return alarm.weekdays.sorted().compactMap { idx in
                idx >= 1 && idx <= 7 ? names[idx - 1] : nil
            }.joined(separator: " ")
        }
    }
}

// MARK: - Add Alarm Sheet

struct AddAlarmView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var hour = Calendar.current.component(.hour, from: Date())
    @State private var minute = Calendar.current.component(.minute, from: Date())
    @State private var label = ""
    @State private var repeatPreset: RepeatPreset = .never
    @State private var customWeekdays: Set<Int> = []
    @State private var snoozeDuration = 8
    @State private var selectedSound: AlarmSound = .default
    @State private var isScheduling = false
    @State private var errorMessage: String?

    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    HStack {
                        Picker("Hour", selection: $hour) {
                            ForEach(0..<24, id: \.self) { h in
                                let ampm = h < 12 ? "AM" : "PM"
                                let display = h % 12 == 0 ? 12 : h % 12
                                Text("\(display) \(ampm)").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Minute", selection: $minute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 120)
                }

                Section("Label") {
                    TextField("Optional", text: $label)
                }

                Section("Repeat") {
                    Picker("Preset", selection: $repeatPreset) {
                        ForEach(RepeatPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    if repeatPreset == .custom {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                let selected = customWeekdays.contains(day)
                                Button(weekdayNames[day - 1]) {
                                    if selected { customWeekdays.remove(day) }
                                    else { customWeekdays.insert(day) }
                                }
                                .buttonStyle(.bordered)
                                .tint(selected ? .orange : .secondary)
                                .font(.caption)
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
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }

                Section("Sound") {
                    Picker("Sound", selection: $selectedSound) {
                        ForEach(AlarmSound.all) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { scheduleAlarm() }
                        .disabled(isScheduling)
                }
            }
        }
    }

    private func scheduleAlarm() {
        isScheduling = true
        let weekdays = repeatPreset.resolvedWeekdays ?? customWeekdays
        let alarm = AlarmItem(
            hour: hour,
            minute: minute,
            weekdays: weekdays,
            label: label,
            snoozeDuration: snoozeDuration,
            soundName: selectedSound.filename
        )
        Task {
            do {
                try await coordinator.scheduleAlarm(alarm)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isScheduling = false
            }
        }
    }
}

//
//  AlarmsView.swift
//  All-In-One-Clock
//

import SwiftUI

struct AlarmsView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @State private var showingAdd = false
    @State private var errorMessage: String?

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
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddAlarmView()
            }
            .overlay {
                if coordinator.alarms.isEmpty {
                    ContentUnavailableView("No Alarms", systemImage: "alarm", description: Text("Tap + to add an alarm."))
                }
            }
        }
    }
}

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
    }

    private var timeString: String {
        let h = alarm.hour, m = alarm.minute
        let ampm = h < 12 ? "AM" : "PM"
        let displayHour = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", displayHour, m, ampm)
    }

    private var weekdaySummary: String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return alarm.weekdays.sorted().compactMap { idx in
            idx >= 1 && idx <= 7 ? names[idx - 1] : nil
        }.joined(separator: " ")
    }
}

// MARK: - Add Alarm Sheet

struct AddAlarmView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var hour = Calendar.current.component(.hour, from: Date())
    @State private var minute = Calendar.current.component(.minute, from: Date())
    @State private var label = ""
    @State private var selectedWeekdays: Set<Int> = []
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
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            let selected = selectedWeekdays.contains(day)
                            Button(weekdayNames[day - 1]) {
                                if selected { selectedWeekdays.remove(day) }
                                else { selectedWeekdays.insert(day) }
                            }
                            .buttonStyle(.bordered)
                            .tint(selected ? .orange : .secondary)
                            .font(.caption)
                        }
                    }
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
        let alarm = AlarmItem(hour: hour, minute: minute, weekdays: selectedWeekdays, label: label)
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

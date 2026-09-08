//
//  TimersView.swift
//  All-In-One-Clock
//

import AlarmKit
import SwiftUI

// MARK: - Timers List

struct TimersView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL
    @State private var showingAdd = false
    @State private var editingTimer: CountdownTimer?
    @State private var showingAuthAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Quick-start preset chips
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([60, 300, 600, 1200], id: \.self) { secs in
                                Button(presetLabel(secs)) {
                                    Task { await schedulePreset(TimeInterval(secs)) }
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowSeparator(.hidden)
                }

                ForEach(coordinator.timers) { timer in
                    TimerRow(timer: timer) {
                        editingTimer = timer
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { coordinator.timers[$0].id }
                    for id in ids { try? coordinator.cancel(id: id) }
                }
            }
            .navigationTitle("Timers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await checkAuthThenAdd() }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddTimerView()
            }
            .sheet(item: $editingTimer) { timer in
                AddTimerView(existingTimer: timer)
            }
            .alert("Alarm Permission Required", isPresented: $showingAuthAlert) {
                Button("Open Settings") {
                    if let url = URL(string: "app-settings:") { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All-In-One Clock needs permission to schedule timers. Enable it in Settings.")
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

    private func schedulePreset(_ duration: TimeInterval) async {
        if coordinator.authorizationState == .notDetermined {
            await coordinator.requestAuthorization()
        }
        guard coordinator.authorizationState == .authorized else {
            showingAuthAlert = true
            return
        }
        let timer = CountdownTimer(duration: duration, soundName: AlarmSound.classicAlarm.filename)
        try? await coordinator.scheduleTimer(timer)
    }

    private func presetLabel(_ seconds: Int) -> String {
        seconds < 3600 ? "\(seconds / 60)m" : "\(seconds / 3600)h"
    }
}

// MARK: - Timer Row

private struct TimerRow: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    let timer: CountdownTimer
    let onEdit: () -> Void

    private var activeFireDate: Date {
        let activeDuration = timer.stages?[timer.currentStageIndex] ?? timer.duration
        return timer.createdAt.addingTimeInterval(activeDuration)
    }

    private var totalDuration: TimeInterval {
        timer.stages.map { $0.reduce(0, +) } ?? timer.duration
    }

    var body: some View {
        HStack {
            // Content area — tap to edit
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        if activeFireDate > .now {
                            Text(timerInterval: Date.now...activeFireDate, countsDown: true)
                        } else {
                            Text(formatDuration(totalDuration))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.title3.monospacedDigit())

                    if !timer.label.isEmpty {
                        Text(timer.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let stages = timer.stages, stages.count > 1 {
                        Text("Stage \(timer.currentStageIndex + 1) of \(stages.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Restart button
            Button {
                Task { await restartTimer() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)

            // Cancel button
            Button(role: .destructive) {
                try? coordinator.cancel(id: timer.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func restartTimer() async {
        try? coordinator.cancel(id: timer.id)
        let fresh = CountdownTimer(
            label: timer.label,
            duration: timer.duration,
            soundName: timer.soundName,
            stages: timer.stages,
            currentStageIndex: 0
        )
        try? await coordinator.scheduleTimer(fresh)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Add / Edit Timer Sheet

struct AddTimerView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    let existingTimer: CountdownTimer?

    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var label: String
    @State private var selectedSound: AlarmSound
    @State private var isMultiStage: Bool
    @State private var stageDurations: [TimeInterval]
    @State private var isScheduling = false
    @State private var errorMessage: String?

    init(existingTimer: CountdownTimer? = nil) {
        self.existingTimer = existingTimer
        if let t = existingTimer {
            let total = Int(t.duration)
            _hours         = State(initialValue: total / 3600)
            _minutes       = State(initialValue: total % 3600 / 60)
            _seconds       = State(initialValue: total % 60)
            _label         = State(initialValue: t.label)
            _selectedSound = State(initialValue: AlarmSound.all.first { $0.filename == t.soundName } ?? .classicAlarm)
            let stages     = t.stages ?? []
            _isMultiStage  = State(initialValue: !stages.isEmpty)
            _stageDurations = State(initialValue: stages.isEmpty ? [300, 300] : stages)
        } else {
            _hours         = State(initialValue: 0)
            _minutes       = State(initialValue: 1)
            _seconds       = State(initialValue: 0)
            _label         = State(initialValue: "")
            _selectedSound = State(initialValue: .classicAlarm)
            _isMultiStage  = State(initialValue: false)
            _stageDurations = State(initialValue: [300, 300])
        }
    }

    private var simpleDuration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private var canStart: Bool {
        if isMultiStage { return stageDurations.count >= 2 }
        return simpleDuration > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Multi-stage", isOn: $isMultiStage)
                }

                if isMultiStage {
                    Section("Stages") {
                        Stepper("Stages: \(stageDurations.count)",
                                onIncrement: {
                                    if stageDurations.count < 10 { stageDurations.append(300) }
                                },
                                onDecrement: {
                                    if stageDurations.count > 2 { stageDurations.removeLast() }
                                })
                    }
                    ForEach(stageDurations.indices, id: \.self) { index in
                        Section("Stage \(index + 1)") {
                            StageDurationPicker(duration: $stageDurations[index])
                        }
                    }
                } else {
                    Section("Duration") {
                        HStack {
                            Picker("Hours", selection: $hours) {
                                ForEach(0..<24, id: \.self) { Text("\($0)h").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $minutes) {
                                ForEach(0..<60, id: \.self) { Text(String(format: "%02dm", $0)).tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Seconds", selection: $seconds) {
                                ForEach(0..<60, id: \.self) { Text(String(format: "%02ds", $0)).tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 120)
                    }
                }

                Section("Label") {
                    TextField("Optional", text: $label)
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
            .navigationTitle(existingTimer == nil ? "New Timer" : "Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTimer == nil ? "Start" : "Save") { scheduleTimer() }
                        .disabled(isScheduling || !canStart)
                }
            }
        }
    }

    private func scheduleTimer() {
        isScheduling = true
        let timerToSchedule: CountdownTimer
        if isMultiStage && stageDurations.count >= 2 {
            timerToSchedule = CountdownTimer(
                id: existingTimer?.id ?? UUID(),
                label: label,
                duration: stageDurations[0],
                soundName: selectedSound.filename,
                stages: stageDurations,
                currentStageIndex: 0
            )
        } else {
            timerToSchedule = CountdownTimer(
                id: existingTimer?.id ?? UUID(),
                label: label,
                duration: simpleDuration,
                soundName: selectedSound.filename
            )
        }
        Task {
            do {
                try await coordinator.scheduleTimer(timerToSchedule)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isScheduling = false
            }
        }
    }
}

// MARK: - Stage Duration Picker

/// H:M:S wheel pickers backed by a single TimeInterval binding.
private struct StageDurationPicker: View {
    @Binding var duration: TimeInterval

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { Int(duration) / 3600 },
            set: { newH in
                let cur = Int(duration)
                let remainder = cur % 3600
                duration = TimeInterval(newH * 3600 + remainder)
            }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { Int(duration) % 3600 / 60 },
            set: { newM in
                let cur = Int(duration)
                let h = cur / 3600
                let s = cur % 60
                duration = TimeInterval(h * 3600 + newM * 60 + s)
            }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: { Int(duration) % 60 },
            set: { newS in
                let cur = Int(duration)
                let h = cur / 3600
                let m = cur % 3600 / 60
                duration = TimeInterval(h * 3600 + m * 60 + newS)
            }
        )
    }

    var body: some View {
        HStack {
            Picker("Hours", selection: hoursBinding) {
                ForEach(0..<24, id: \.self) { Text("\($0)h").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Minutes", selection: minutesBinding) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02dm", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Seconds", selection: secondsBinding) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02ds", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
}

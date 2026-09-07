//
//  TimersView.swift
//  All-In-One-Clock
//

import AlarmKit
import SwiftUI

struct TimersView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL
    @State private var showingAdd = false
    @State private var showingAuthAlert = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(coordinator.timers) { timer in
                    TimerRow(timer: timer)
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
            .overlay {
                if coordinator.timers.isEmpty {
                    ContentUnavailableView("No Timers", systemImage: "timer", description: Text("Tap + to add a timer."))
                }
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
}

private struct TimerRow: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    let timer: CountdownTimer

    private var fireDate: Date { timer.createdAt.addingTimeInterval(timer.duration) }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Group {
                    if fireDate > .now {
                        Text(timerInterval: Date.now...fireDate, countsDown: true)
                    } else {
                        Text("Finished")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.title3.monospacedDigit())
                if !timer.label.isEmpty {
                    Text(timer.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive) {
                try? coordinator.cancel(id: timer.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Add Timer Sheet

struct AddTimerView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var label = ""
    @State private var isScheduling = false
    @State private var errorMessage: String?

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Label") {
                    TextField("Optional", text: $label)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { scheduleTimer() }
                        .disabled(isScheduling || duration <= 0)
                }
            }
        }
    }

    private func scheduleTimer() {
        isScheduling = true
        let timer = CountdownTimer(label: label, duration: duration)
        Task {
            do {
                try await coordinator.scheduleTimer(timer)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isScheduling = false
            }
        }
    }
}

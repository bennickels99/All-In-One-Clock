//
//  TimersView.swift
//  All-In-One-Clock
//

import SwiftUI

struct TimersView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(coordinator.timers) { timer in
                    TimerRow(timer: timer)
                }
                .onDelete { offsets in
                    for index in offsets {
                        try? coordinator.cancel(id: coordinator.timers[index].id)
                    }
                }
            }
            .navigationTitle("Timers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
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
        }
    }
}

private struct TimerRow: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    let timer: CountdownTimer

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(durationString(timer.duration))
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

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
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

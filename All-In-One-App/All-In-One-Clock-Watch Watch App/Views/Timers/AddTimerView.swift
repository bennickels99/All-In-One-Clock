import SwiftUI

struct AddTimerView: View {
    @Environment(ClockStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var label = ""

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    HStack(spacing: 0) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<24, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60, id: \.self) { Text("\($0)m").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        Picker("Seconds", selection: $seconds) {
                            ForEach(0..<60, id: \.self) { Text("\($0)s").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 80)
                }
                Section {
                    TextField("Label (optional)", text: $label)
                }
                Button("Start Timer") {
                    Task {
                        let timer = CountdownTimer(label: label, duration: duration)
                        await WatchAlarmBridge.shared.scheduleTimer(timer, store: store)
                        dismiss()
                    }
                }
                .disabled(duration <= 0)
            }
            .navigationTitle("New Timer")
        }
    }
}

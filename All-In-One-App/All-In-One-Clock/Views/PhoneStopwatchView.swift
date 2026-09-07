//
//  PhoneStopwatchView.swift
//  All-In-One-Clock
//

import SwiftUI

struct PhoneStopwatchView: View {
    @State private var startDate: Date?
    @State private var offset: TimeInterval = 0
    @State private var laps: [TimeInterval] = []

    private var isRunning: Bool { startDate != nil }
    private var hasStarted: Bool { isRunning || offset > 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineView(.animation(minimumInterval: 0.05, paused: !isRunning)) { context in
                    Text(formatElapsed(currentElapsed(at: context.date)))
                        .font(.system(size: 80, weight: .thin, design: .monospaced))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                }

                HStack(spacing: 48) {
                    Button((!hasStarted || isRunning) ? "Lap" : "Reset") {
                        if isRunning { lap() } else { reset() }
                    }
                    .buttonStyle(CircleButtonStyle(tint: .secondary))
                    .disabled(!hasStarted)

                    Button(isRunning ? "Stop" : "Start") {
                        if isRunning { stop() } else { start() }
                    }
                    .buttonStyle(CircleButtonStyle(tint: isRunning ? .red : .green))
                }
                .padding(.bottom, 32)

                if !laps.isEmpty {
                    Divider()
                    List {
                        ForEach(laps.indices.reversed(), id: \.self) { i in
                            HStack {
                                Text("Lap \(i + 1)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatElapsed(lapDuration(at: i)))
                                    .font(.body.monospacedDigit())
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Stopwatch")
        }
    }

    private func currentElapsed(at date: Date) -> TimeInterval {
        guard let start = startDate else { return offset }
        return offset + date.timeIntervalSince(start)
    }

    private func lapDuration(at index: Int) -> TimeInterval {
        let prev = index > 0 ? laps[index - 1] : 0
        return laps[index] - prev
    }

    private func start() { startDate = .now }

    private func stop() {
        offset = currentElapsed(at: .now)
        startDate = nil
    }

    private func lap() { laps.append(currentElapsed(at: .now)) }

    private func reset() {
        startDate = nil
        offset = 0
        laps = []
    }

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        let total = Int(elapsed)
        let centis = Int((elapsed - Double(total)) * 100)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d.%02d", m, s, centis)
    }
}

private struct CircleButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(width: 80, height: 80)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

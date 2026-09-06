import SwiftUI

struct StopwatchView: View {
    @Environment(ClockStore.self) private var store

    var body: some View {
        // Animation schedule drives centisecond updates. When paused/idle elapsed()
        // returns a constant so repeated renders are visual no-ops.
        TimelineView(.animation) { context in
            let elapsed = store.stopwatch.elapsed(at: context.date)
            ScrollView {
                VStack(spacing: 10) {
                    Text(formatElapsed(elapsed))
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.top, 4)

                    HStack(spacing: 10) {
                        if store.stopwatch.isRunning {
                            Button("Lap") { store.lapStopwatch() }
                                .buttonStyle(.bordered)
                                .tint(.gray)
                            Button("Pause") { store.pauseStopwatch() }
                                .buttonStyle(.bordered)
                                .tint(.yellow)
                        } else if store.stopwatch.hasStarted {
                            Button("Reset") { store.resetStopwatch() }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            Button("Resume") { store.startStopwatch() }
                                .buttonStyle(.bordered)
                                .tint(.green)
                        } else {
                            Button("Start") { store.startStopwatch() }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                        }
                    }

                    if !store.stopwatch.laps.isEmpty {
                        Divider()
                        ForEach(store.stopwatch.laps.indices.reversed(), id: \.self) { i in
                            HStack {
                                Text("Lap \(i + 1)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatElapsed(store.stopwatch.laps[i]))
                                    .monospacedDigit()
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Stopwatch")
        .navigationBarTitleDisplayMode(.inline)
    }
}

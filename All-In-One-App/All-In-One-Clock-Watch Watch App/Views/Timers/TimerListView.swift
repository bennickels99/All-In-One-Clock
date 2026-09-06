import SwiftUI

struct TimerListView: View {
    @Environment(ClockStore.self) private var store
    @State private var showingAdd = false

    var body: some View {
        List {
            if store.timers.isEmpty {
                Label("No timers", systemImage: "timer")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.timers) { timer in
                    TimerRow(timer: timer)
                }
                .onDelete { offsets in
                    let ids = offsets.map { store.timers[$0].id }
                    for id in ids {
                        WatchAlarmBridge.shared.cancel(id: id, store: store)
                    }
                }
            }

            Button {
                showingAdd = true
            } label: {
                Label("Add Timer", systemImage: "plus")
            }
        }
        .navigationTitle("Timers")
        .sheet(isPresented: $showingAdd) {
            AddTimerView()
        }
    }
}

private struct TimerRow: View {
    let timer: CountdownTimer

    private var fireDate: Date {
        timer.createdAt.addingTimeInterval(timer.duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !timer.label.isEmpty {
                Text(timer.label)
                    .font(.headline)
                    .lineLimit(1)
            }
            Group {
                if fireDate > .now {
                    Text(timerInterval: Date.now...fireDate, countsDown: true)
                } else {
                    Text("Finished")
                        .foregroundStyle(.red)
                }
            }
            .font(.system(.body, design: .monospaced))
        }
    }
}

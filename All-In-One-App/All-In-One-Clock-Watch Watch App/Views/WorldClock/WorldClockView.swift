import SwiftUI

struct WorldClockView: View {
    @Environment(ClockStore.self) private var store
    @State private var showingAdd = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                if store.cities.isEmpty {
                    Label("No cities", systemImage: "globe")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(store.cities) { city in
                        CityRow(city: city, now: context.date)
                    }
                    .onDelete { store.removeCity(at: $0) }
                }

                Button {
                    showingAdd = true
                } label: {
                    Label("Add City", systemImage: "plus")
                }
            }
            .navigationTitle("World Clock")
        }
        .sheet(isPresented: $showingAdd) {
            AddCityView()
        }
    }
}

private struct CityRow: View {
    let city: WorldClockCity
    let now: Date

    var body: some View {
        HStack {
            Text(city.name)
                .font(.body)
                .lineLimit(1)
            Spacer()
            Group {
                if let tz = city.timeZone {
                    // Respects the device's 12h/24h setting; no DateFormatter alloc.
                    Text(now, format: .dateTime.hour().minute())
                        .environment(\.timeZone, tz)
                } else {
                    Text("--:--")
                }
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }
}

import SwiftUI

struct WorldClockView: View {
    @Environment(ClockStore.self) private var store
    @State private var showingAdd = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                ForEach(store.cities) { city in
                    CityRow(city: city, now: context.date)
                }
                .onDelete { store.removeCity(at: $0) }

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

    private var localTime: String {
        guard let tz = city.timeZone else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = tz
        return formatter.string(from: now)
    }

    var body: some View {
        HStack {
            Text(city.name)
                .font(.body)
                .lineLimit(1)
            Spacer()
            Text(localTime)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

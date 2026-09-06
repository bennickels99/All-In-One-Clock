//
//  PhoneWorldClockView.swift
//  All-In-One-Clock
//

import SwiftUI

struct PhoneWorldClockView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                List {
                    ForEach(coordinator.cities) { city in
                        CityRow(city: city, now: context.date)
                    }
                    .onDelete(perform: coordinator.removeCity)
                }
            }
            .navigationTitle("World Clock")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCityView()
            }
            .overlay {
                if coordinator.cities.isEmpty {
                    ContentUnavailableView("No Cities", systemImage: "globe", description: Text("Tap + to add a city."))
                }
            }
        }
    }
}

private struct CityRow: View {
    let city: WorldClockCity
    let now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(city.name)
                    .font(.headline)
                if let tz = city.timeZone {
                    Text(tz.abbreviation(for: now) ?? tz.identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let tz = city.timeZone {
                Text(now, format: .dateTime.hour().minute())
                    .environment(\.timeZone, tz)
                    .font(.title3.monospacedDigit())
            }
        }
    }
}

// MARK: - Add City Sheet

struct AddCityView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filteredZones: [TimeZone] {
        let all = TimeZone.knownTimeZoneIdentifiers.compactMap { TimeZone(identifier: $0) }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.identifier.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List(filteredZones, id: \.identifier) { tz in
                Button {
                    let city = WorldClockCity(
                        name: tz.identifier.components(separatedBy: "/").last ?? tz.identifier,
                        timeZoneIdentifier: tz.identifier
                    )
                    coordinator.addCity(city)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(tz.identifier.components(separatedBy: "/").last ?? tz.identifier)
                            .foregroundStyle(.primary)
                        Text(tz.identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add City")
            .searchable(text: $searchText, prompt: "Search time zones")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

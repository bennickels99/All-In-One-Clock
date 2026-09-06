import SwiftUI

struct AddCityView: View {
    @Environment(ClockStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredIdentifiers: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredIdentifiers, id: \.self) { identifier in
                Button {
                    let name = identifier.split(separator: "/").last.map(String.init) ?? identifier
                    store.addCity(WorldClockCity(name: name, timeZoneIdentifier: identifier))
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(identifier.split(separator: "/").last.map(String.init) ?? identifier)
                            .font(.body)
                        Text(identifier)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search")
            .navigationTitle("Add City")
        }
    }
}

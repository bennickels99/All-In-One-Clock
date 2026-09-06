import SwiftUI

@MainActor
@Observable
final class ClockStore {

    // Synced from phone via .stateSync
    var alarms: [AlarmItem] = []
    var timers: [CountdownTimer] = []

    // Local watch-side state
    var cities: [WorldClockCity] = []
    var stopwatch = StopwatchState()
    var isPhoneReachable = false

    private enum Keys {
        static let cities = "watch.cities"
        static let stopwatch = "watch.stopwatch"
    }

    init() {
        loadCities()
        loadStopwatch()
    }

    // MARK: - State sync (from phone)

    func handleStateSync(_ state: ClockState) {
        alarms = state.alarms
        timers = state.timers
    }

    // MARK: - Stopwatch (local)

    func startStopwatch() {
        stopwatch.start()
        saveStopwatch()
    }

    func pauseStopwatch() {
        stopwatch.pause()
        saveStopwatch()
    }

    func lapStopwatch() {
        stopwatch.lap()
        saveStopwatch()
    }

    func resetStopwatch() {
        stopwatch.reset()
        saveStopwatch()
    }

    // MARK: - World Clock (local)

    func addCity(_ city: WorldClockCity) {
        cities.append(city)
        saveCities()
    }

    func removeCity(at offsets: IndexSet) {
        cities.remove(atOffsets: offsets)
        saveCities()
    }

    // MARK: - Persistence

    private func saveCities() {
        UserDefaults.standard.set(try? JSONEncoder().encode(cities), forKey: Keys.cities)
    }

    private func loadCities() {
        guard let data = UserDefaults.standard.data(forKey: Keys.cities) else { return }
        cities = (try? JSONDecoder().decode([WorldClockCity].self, from: data)) ?? []
    }

    private func saveStopwatch() {
        UserDefaults.standard.set(try? JSONEncoder().encode(stopwatch), forKey: Keys.stopwatch)
    }

    private func loadStopwatch() {
        guard let data = UserDefaults.standard.data(forKey: Keys.stopwatch) else { return }
        stopwatch = (try? JSONDecoder().decode(StopwatchState.self, from: data)) ?? StopwatchState()
    }
}

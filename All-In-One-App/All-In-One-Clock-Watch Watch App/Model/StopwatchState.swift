import Foundation

struct StopwatchState: Codable {
    enum Phase: Codable { case idle, running, paused }

    private(set) var startDate: Date?
    private(set) var elapsedBeforePause: TimeInterval = 0
    private(set) var laps: [TimeInterval] = []
    private(set) var phase: Phase = .idle

    var isRunning: Bool { phase == .running }
    var hasStarted: Bool { phase != .idle }

    func elapsed(at now: Date) -> TimeInterval {
        switch phase {
        case .idle: return 0
        case .paused: return elapsedBeforePause
        case .running:
            guard let start = startDate else { return elapsedBeforePause }
            return elapsedBeforePause + now.timeIntervalSince(start)
        }
    }

    mutating func start(at now: Date = .now) {
        startDate = now
        phase = .running
    }

    mutating func pause(at now: Date = .now) {
        elapsedBeforePause = elapsed(at: now)
        startDate = nil
        phase = .paused
    }

    mutating func lap(at now: Date = .now) {
        laps.append(elapsed(at: now))
    }

    mutating func reset() {
        startDate = nil
        elapsedBeforePause = 0
        laps = []
        phase = .idle
    }
}

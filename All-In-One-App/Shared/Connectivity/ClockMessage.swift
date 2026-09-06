//
//  ClockMessage.swift
//  All-In-One-Clock (Shared)
//
//  The wire format exchanged between the watch and iPhone over WatchConnectivity.
//  Both sides encode/decode the same Codable DTOs so requests and state stay in sync.
//

import Foundation

/// A snapshot of the alarm/timer lists that the iPhone owns (AlarmKit is the
/// source of truth) and mirrors to the watch.
struct ClockState: Codable, Hashable, Sendable {
    var alarms: [AlarmItem]
    var timers: [CountdownTimer]

    init(alarms: [AlarmItem] = [], timers: [CountdownTimer] = []) {
        self.alarms = alarms
        self.timers = timers
    }
}

/// A single message passed between devices.
///
/// - `scheduleAlarm` / `scheduleTimer`: watch → phone requests to schedule via AlarmKit.
/// - `cancel`: watch → phone request to cancel an alarm/timer by shared UUID.
/// - `stateSync`: phone → watch broadcast of the authoritative alarm/timer lists.
enum ClockMessage: Codable, Hashable, Sendable {
    case scheduleAlarm(AlarmItem)
    case scheduleTimer(CountdownTimer)
    case cancel(UUID)
    case stateSync(ClockState)
}

extension ClockMessage {
    /// The dictionary key under which the encoded message travels inside a
    /// WatchConnectivity payload (`sendMessage` / `transferUserInfo` / context).
    static let payloadKey = "clockMessage"

    /// Encodes the message into a `[String: Any]` payload suitable for
    /// `WCSession`. WatchConnectivity only accepts property-list types, so the
    /// message is carried as JSON `Data`.
    func encodedPayload() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return [ClockMessage.payloadKey: data]
    }

    /// Reconstructs a message from a received WatchConnectivity payload.
    /// Returns `nil` if the payload does not contain a clock message.
    /// Marked nonisolated because this is pure JSON decoding on a Sendable value
    /// type — it is safe to call from any actor, including WCSession's background queue.
    nonisolated init?(payload: [String: Any]) {
        guard let data = payload[ClockMessage.payloadKey] as? Data,
              let message = try? JSONDecoder().decode(ClockMessage.self, from: data) else {
            return nil
        }
        self = message
    }
}

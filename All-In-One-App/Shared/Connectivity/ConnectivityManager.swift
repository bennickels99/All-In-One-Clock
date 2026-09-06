//
//  ConnectivityManager.swift
//  All-In-One-Clock (Shared — iOS app + Watch app)
//
//  WCSession wrapper used by both sides of the app.
//  • iOS: activate on launch, handle watch requests, push state via updateContext.
//  • Watch: activate on launch, send requests, receive .stateSync updates.
//
//  The file-level #if canImport guard ensures this compiles to nothing inside the
//  widget extension, which has no use for WatchConnectivity.
//

#if canImport(WatchConnectivity)
import WatchConnectivity
import Foundation

final class ConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = ConnectivityManager()

    // Incoming messages are always dispatched to this handler on the MainActor.
    var messageHandler: ((ClockMessage) -> Void)?
    // Called on the MainActor when WCSession reachability changes.
    var reachabilityHandler: ((Bool) -> Void)?

    var isReachable: Bool {
        WCSession.isSupported()
            && WCSession.default.activationState == .activated
            && WCSession.default.isReachable
    }

    private override init() { super.init() }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Outbound

    /// Sends a message immediately when the counterpart is reachable;
    /// queues it via transferUserInfo (guaranteed delivery) otherwise so no
    /// request is lost when the watch and phone aren't connected.
    func send(_ message: ClockMessage) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              let payload = try? message.encodedPayload() else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// Pushes latest-state via updateApplicationContext (last-value-wins, no
    /// queuing). Used by the phone to broadcast alarm/timer lists to the watch.
    func updateContext(_ message: ClockMessage) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              let payload = try? message.encodedPayload() else { return }
#if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
#endif
        try? session.updateApplicationContext(payload)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
#if os(watchOS)
        // On cold start the phone may have pushed state while the watch was
        // suspended. Read receivedApplicationContext so the watch doesn't show
        // empty lists until the next live push.
        if !session.receivedApplicationContext.isEmpty {
            route(session.receivedApplicationContext)
        }
        // Seed the initial reachability indicator; sessionReachabilityDidChange
        // is only called on subsequent changes, not on activation.
        Task { @MainActor [weak self] in
            self?.reachabilityHandler?(session.isReachable)
        }
#endif
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate when the user switches Apple Watches.
        session.activate()
    }
#endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.reachabilityHandler?(session.isReachable)
        }
    }

    // MARK: - Inbound routing

    nonisolated private func route(_ payload: [String: Any]) {
        // Extract Sendable Data on the WCSession queue; decode ClockMessage on
        // the MainActor where its Decodable conformance is isolated.
        guard let data = payload[ClockMessage.payloadKey] as? Data else { return }
        Task { @MainActor [weak self] in
            guard let message = try? JSONDecoder().decode(ClockMessage.self, from: data) else { return }
            self?.messageHandler?(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        route(message)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        route(message)
        replyHandler([:])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        route(userInfo)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        route(applicationContext)
    }
}
#endif

//
//  All_In_One_ClockApp.swift
//  All-In-One-Clock
//

import SwiftUI
import AlarmKit

@main
struct All_In_One_ClockApp: App {
    @State private var coordinator = AlarmKitCoordinator()

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(coordinator)
                .task {
                    // Activate WatchConnectivity and route incoming watch
                    // requests (scheduleAlarm/Timer/cancel) to the coordinator.
                    ConnectivityManager.shared.activate()
                    ConnectivityManager.shared.messageHandler = { [coordinator] message in
                        switch message {
                        case .scheduleAlarm(let alarm):
                            Task { try? await coordinator.scheduleAlarm(alarm) }
                        case .scheduleTimer(let timer):
                            Task { try? await coordinator.scheduleTimer(timer) }
                        case .cancel(let id):
                            try? coordinator.cancel(id: id)
                        case .stateSync:
                            break // phone is the sender, never the receiver
                        }
                    }
                    await coordinator.requestAuthorization()
                    await coordinator.startObserving()
                }
        }
    }
}

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
                    await coordinator.requestAuthorization()
                    await coordinator.startObserving()
                }
        }
    }
}

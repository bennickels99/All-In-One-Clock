//
//  PhoneRootView.swift
//  All-In-One-Clock
//

import SwiftUI

struct PhoneRootView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator

    var body: some View {
        TabView {
            AlarmsView()
                .tabItem { Label("Alarms", systemImage: "alarm") }

            TimersView()
                .tabItem { Label("Timers", systemImage: "timer") }

            PhoneWorldClockView()
                .tabItem { Label("World Clock", systemImage: "globe") }
        }
    }
}

//
//  PhoneRootView.swift
//  All-In-One-Clock
//

import AlarmKit
import SwiftUI

struct PhoneRootView: View {
    @Environment(AlarmKitCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL

    var body: some View {
        TabView {
            PhoneStopwatchView()
                .tabItem { Label("Stopwatch", systemImage: "stopwatch") }

            AlarmsView()
                .tabItem { Label("Alarms", systemImage: "alarm") }

            TimersView()
                .tabItem { Label("Timers", systemImage: "timer") }

            PhoneWorldClockView()
                .tabItem { Label("World Clock", systemImage: "globe") }
        }
        .safeAreaInset(edge: .top) {
            if coordinator.authorizationState == .denied {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Alarm permission denied")
                        .font(.subheadline)
                    Spacer()
                    Button("Open Settings") {
                        if let url = URL(string: "app-settings:") {
                            openURL(url)
                        }
                    }
                    .font(.subheadline.bold())
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }
}

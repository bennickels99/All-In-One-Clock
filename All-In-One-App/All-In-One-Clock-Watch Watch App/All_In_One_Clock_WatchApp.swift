import SwiftUI
import UserNotifications

@main
struct All_In_One_Clock_Watch_Watch_AppApp: App {
    @State private var store = ClockStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .task {
                    ConnectivityManager.shared.activate()

                    ConnectivityManager.shared.messageHandler = { [store] message in
                        if case .stateSync(let state) = message {
                            store.handleStateSync(state)
                            WatchAlarmBridge.shared.reconcile(with: state)
                        }
                    }

                    ConnectivityManager.shared.reachabilityHandler = { [store] reachable in
                        store.isPhoneReachable = reachable
                    }

                    // Request authorization for local notification fallbacks when
                    // the phone is unreachable and cannot run AlarmKit immediately.
                    _ = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])
                }
        }
    }
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

All-In-One Clock — an Apple Watch app (watchOS 26.5) with an iPhone companion (iOS 26.5). Features: Stopwatch, Timer, Alarm, World Clock. Alarms and timers use **AlarmKit** (iOS-only, requires physical device to fully test), so the watch relays requests to the phone over WatchConnectivity. The watch handles Stopwatch and World Clock entirely locally.

## Building

Open `All-In-One-App/All-In-One-App.xcodeproj` in Xcode. Three targets:

- **All-In-One-Clock** — iOS companion app (scheme: `All-In-One-Clock`)
- **All-In-One-Clock-Watch Watch App** — watchOS app (scheme: `All-In-One-Clock-Watch Watch App`)
- **ClockWidgetExtension** — embedded widget/Live Activity (built as part of the iOS app)

Use `XcodeRefreshCodeIssuesInFile` for fast per-file diagnostics. Use `BuildProject` for a full compile. There are no test targets.

**Never edit `All-In-One-App.xcodeproj/project.pbxproj` directly while Xcode is open** — it will corrupt the project. Use Xcode's UI for any project-file changes (build settings, target membership, Info.plist keys).

## Architecture

### Target layout

```
Shared/                   → iOS + Watch + Widget
  Models/                 → AlarmItem, CountdownTimer, WorldClockCity (Codable, Sendable)
  AlarmKit/               → ClockAlarmMetadata (AlarmMetadata, iOS + Widget only in practice)
  Connectivity/           → ClockMessage (wire DTOs), ConnectivityManager (WCSession wrapper)

All-In-One-Clock/         → iOS app
  AlarmKit/AlarmKitCoordinator.swift  → source of truth; schedules via AlarmKit, observes alarmUpdates
  Views/                  → PhoneRootView (TabView), AlarmsView, TimersView, PhoneWorldClockView

All-In-One-Clock-Watch Watch App/
  Model/ClockStore.swift  → @MainActor @Observable; alarms/timers synced from phone, cities/stopwatch local
  Model/StopwatchState.swift → pure value-type date-math stopwatch
  Services/WatchAlarmBridge.swift → sends requests to phone; UNUserNotification fallback when unreachable
  Support/TimeFormatting.swift    → formatElapsed, formatDuration, nextAlarmLabel, formattedAlarmTime
  Views/                  → HomeView, Stopwatch, Timers, Alarms, WorldClock

ClockWidgetExtension/     → AlarmKit Live Activity (ClockWidgetExtensionLiveActivity.swift)
```

### Data flow

```
Watch (AddAlarmView) → WatchAlarmBridge.scheduleAlarm()
    → ConnectivityManager.send(.scheduleAlarm)    ← sendMessage if reachable
    → [phone unreachable] UNCalendarNotificationTrigger fallback (per weekday)
    ↓
iOS messageHandler → AlarmKitCoordinator.scheduleAlarm() → AlarmManager.shared.schedule()
    → alarmUpdates loop → pushStateToWatch() → updateApplicationContext(.stateSync)
    ↓
Watch ConnectivityManager.route() → ClockStore.handleStateSync() + WatchAlarmBridge.reconcile()
    → removes fallback notifications for items now managed by AlarmKit
```

### Concurrency model

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` are set on all targets. Every type is implicitly `@MainActor` unless explicitly opted out.

- WCSession delegate callbacks arrive on a background queue — all delegate methods must be `nonisolated`. Dispatch to MainActor with `Task { @MainActor [weak self] in … }`.
- `static let` constants accessed from `nonisolated` contexts must be marked `nonisolated static let`.
- `ClockMessage` decoding happens inside the `Task { @MainActor }` in `ConnectivityManager.route()`, not in the `nonisolated` delegate.

### WatchConnectivity patterns

- `sendMessage` — immediate delivery when both sides reachable.
- `transferUserInfo` — queued guaranteed delivery (used as fallback by `ConnectivityManager.send()`).
- `updateApplicationContext` — last-value-wins; phone uses this for `stateSync`.
- On watch cold start, `activationDidCompleteWith` reads `session.receivedApplicationContext` to load state cached while the watch was off.

### Fallback notification identifiers

Single-shot alarm: `alarm.id.uuidString`
Repeating alarm (per weekday): `"\(alarm.id.uuidString)-\(weekday)"` where weekday is Calendar weekday (1=Sun…7=Sat)
Timer: `timer.id.uuidString`

`WatchAlarmBridge.removeFallbackNotifications(for:)` cleans up both forms.

### AlarmKit notes

- `AlarmManager` is iOS-only; the Watch target never imports AlarmKit.
- `AlarmKitCoordinator.startObserving()` runs an infinite `for await` loop on `AlarmManager.shared.alarmUpdates`. It is the last statement in the app's `.task` — do not add code after it.
- `cancel(id:)` removes items from arrays before calling `AlarmManager.shared.stop()` (which may throw if the alarm already fired).
- `scheduleAlarm/scheduleTimer` upsert the local array (replace if existing, append if new) so re-enabling a toggled-off alarm correctly reflects `isEnabled = true`.

## Git workflow

Work on feature branches; open PRs into `main`. Commit after each major change. Current feature branch: `all-in-one-clock-build`.

# All-In-One Clock — Watch app + iPhone companion (AlarmKit)

## Context

Goal: a friendly all-in-one clock for the average Apple Watch user — **Stopwatch, Timer, Alarm,
World Clock** — with rounded icons, features usable **simultaneously**. The user wants an **iPhone
companion app** so alarms/timers use **AlarmKit** (real system alerts that override Silent Mode +
Live Activity countdowns). AlarmKit is iOS-only, so the watch relays requests to the phone.

### Confirmed decisions
- **iOS 26-only** (full AlarmKit, no availability branching). Watch = watchOS 26.
- **Both Alarms and Timers** go through AlarmKit on iPhone. **Stopwatch + World Clock stay local on
  the watch**, fully independent.
- **Offline fallback:** when the iPhone is unreachable, the watch schedules its own local
  notification so the alert still fires, then reconciles with AlarmKit on reconnect (dedupe by
  shared UUID). Independent of iOS version.
- **Full companion iPhone UI:** phone also views/manages alarms & timers and shows world clock,
  sharing model code with the watch.
- **Git workflow:** work on the `all-in-one-clock-build` feature branch; commit after each major
  change with descriptive messages; open PRs into `main` for review/merge.

### Data flow
Watch create/edit → **WatchConnectivity** → iPhone `AlarmKitCoordinator` → **AlarmManager.schedule**
→ AlarmKit fires and **auto-forwards the alert to the paired watch**. iPhone pushes the alarm/timer
list back via `updateApplicationContext` so both UIs stay in sync.

### Researched facts (Apple docs)
- AlarmKit **requires a Widget Extension** for countdown presentations or the system may dismiss
  alarms. Needs `NSAlarmKitUsageDescription` + `AlarmManager.shared.requestAuthorization()`.
- Configs: `AlarmConfiguration.timer(duration:attributes:…)`, `.alarm(schedule:attributes:…)`;
  `Alarm.Schedule.Relative` for one-time/weekly (`Locale.Weekday`); observe
  `AlarmManager.shared.alarmUpdates`.
- WatchConnectivity: `sendMessage` (immediate, both reachable) / `transferUserInfo` (queued,
  guaranteed) / `updateApplicationContext` (latest-state sync). Full testing needs **physical paired
  devices**.

---

## Project targets (set up in Xcode)

- ✅ **All-In-One-Clock** — iOS app, `nickels.All-In-One-Clock`, iOS 26.5, embeds watch + widget,
  depends on both.
- ✅ **All-In-One-Clock-Watch Watch App** — watchOS 26.5, `nickels.All-In-One-Clock.watchkitapp`,
  `WKCompanionAppBundleIdentifier = nickels.All-In-One-Clock` (correctly wired companion).
- ✅ **ClockWidgetExtension** — Widget Extension w/ Live Activity, embedded in All-In-One-Clock,
  folder `ClockWidgetExtension/`. Template files (`ClockWidgetExtensionLiveActivity.swift` etc.) to
  be repurposed for the AlarmKit `AlarmAttributes` Live Activity; default `AppIntent.swift` /
  `...Control.swift` can be trimmed.
- ✅ Old template targets deleted; Products clean (3 real outputs).
- ⬜ **iOS app Info settings:** `NSAlarmKitUsageDescription` + `NSSupportsLiveActivities = YES`.
- ⬜ **Shared code:** `Shared` group with target membership for iOS + Watch + Widget (or a local
  Swift package).

Folders: iOS app = `All-In-One-Clock/`, watch = `All-In-One-Clock-Watch Watch App/`, widget =
`ClockWidgetExtension/`.

---

## Source layout (to implement)

```
Shared/                          (membership: iOS + Watch + Widget)
  Models/AlarmItem.swift          Codable/Identifiable; hour,minute,weekdays,label,enabled
  Models/CountdownTimer.swift     id,label,duration,createdAt
  Models/WorldClockCity.swift
  AlarmKit/ClockAlarmMetadata.swift  AlarmMetadata conformer + AlarmAttributes/Presentation builder
  Connectivity/ClockMessage.swift  Codable DTOs: .scheduleAlarm/.scheduleTimer/.cancel/.stateSync
  Connectivity/ConnectivityManager.swift  WCSession wrapper (delegate, send/receive, encode DTOs)

<iOS app>/
  App.swift                       @main; AlarmKit + notif auth; activates WCSession
  AlarmKit/AlarmKitCoordinator.swift  models→AlarmConfiguration, schedule/cancel, observe alarmUpdates, push state to watch
  Views/PhoneRootView.swift, AlarmsView.swift, TimersView.swift, WorldClockView.swift

<Widget>/
  AlarmWidgetBundle.swift         @main WidgetBundle
  AlarmLiveActivity.swift         ActivityConfiguration for AlarmAttributes<ClockAlarmMetadata>

<Watch app>/
  App.swift                       inject store, activate WCSession, request notif auth
  ContentView → HomeView
  Model/ClockStore.swift          @MainActor @Observable: stopwatch + cities local; synced alarms/timers
  Model/StopwatchState.swift      date-math elapsed + laps
  Services/WatchAlarmBridge.swift  send requests to phone; local-notif fallback + reconciliation
  Views/HomeView.swift            List of rounded-icon rows + live status badges
  Views/Stopwatch/StopwatchView.swift
  Views/Timers/TimerListView.swift, AddTimerView.swift
  Views/Alarms/AlarmListView.swift, AddAlarmView.swift
  Views/WorldClock/WorldClockView.swift, AddCityView.swift
  Support/TimeFormatting.swift
```

### Key behaviors
- **AlarmKitCoordinator (iOS):** builds `AlarmAttributes` (tint + presentation with stop/pause
  buttons) + `ClockAlarmMetadata`; `.timer(duration:…)` for timers, `.alarm(schedule: .relative(…))`
  for alarms (weekly repeat via `Locale.Weekday`); `AlarmManager.shared.schedule(id:configuration:)`.
  Consumes `alarmUpdates`, mirrors resulting list to the watch via `updateApplicationContext`.
- **ConnectivityManager (shared):** `sendMessage` w/ reply when reachable (returns scheduled id);
  `transferUserInfo` when not (phone schedules on reconnect). Watch receives `.stateSync` to refresh
  `ClockStore` alarm/timer lists.
- **WatchAlarmBridge:** on create — phone reachable → send + await reply. Not reachable → schedule
  local `UNUserNotificationCenter` fallback AND queue `transferUserInfo`; cancel fallback when phone
  confirms via `.stateSync`.
- **Stopwatch/World Clock (watch):** date-math + `TimelineView` (`.animation` / `.everyMinute`),
  fully local, run concurrently with everything else.
- **Home badges:** running stopwatch, active timer count/next fire, next alarm, phone-reachability dot.
- **Styling:** home-menu `List` of rounded-corner icon tiles (rounded SF Symbols: `stopwatch`,
  `timer`, `alarm`, `globe`); capsule/rounded controls throughout.

---

## Implementation phases (build after each)

1. **Shared models + DTOs + `ClockAlarmMetadata`** → confirm they compile in all three targets.
2. **Widget**: `AlarmAttributes`-based Live Activity (countdown/alert/paused). Build.
3. **AlarmKitCoordinator** + iOS auth + scheduling for alarms/timers + iOS companion UI. Build.
4. **ConnectivityManager** both sides + `.stateSync`; wire watch create/edit → requests. Build.
5. **Watch features**: HomeView, Stopwatch, World Clock, Timer/Alarm list+add UIs, local-notif
   fallback + reconciliation. Build.
6. Polish rounded styling, badges, empty states.

---

## Verification

- **Compile loop:** `XcodeRefreshCodeIssuesInFile` per file; `BuildProject` (iOS + Watch schemes)
  after each phase.
- **Simulator (partial):** iOS app launches, AlarmKit auth prompt appears, a short timer/alarm
  schedules and shows a countdown via the widget; watch app renders, stopwatch + world clock work
  locally and concurrently.
- **Physical paired iPhone + Watch (required for full check):**
  - Create alarm/timer **on the watch** → appears in iPhone list → fires with alert forwarded to the
    watch (overrides Silent Mode).
  - Create **on the iPhone** → syncs to watch list.
  - **Offline:** phone away → create on watch → local-notification fallback fires; on reconnect the
    phone schedules via AlarmKit and the watch cancels its fallback (no double alert).
  - **Concurrency:** stopwatch + two AlarmKit timers + world clock all running; switching screens
    keeps them alive.
- **Persistence:** relaunch both apps → alarms/timers restored (AlarmKit = source of truth on phone;
  watch stopwatch restores via date math).

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

---

## Phase 7: Alarm History, Snooze, and Repeat Presets

### Context
Alarms currently vanish from the list after they fire (one-shots are deleted in `startObserving()`). There is no snooze, no per-alarm snooze duration, and the repeat UI shows raw day toggles with no preset shortcuts. This phase adds alarm history persistence, configurable snooze, and "Weekdays / Weekends / Custom" repeat presets across iOS and Watch.

### Files to modify

**`Shared/Models/AlarmItem.swift`**
Add `snoozeDuration: Int` (minutes, default 8). Because Codable conformance is synthesised, add explicit `CodingKeys` + hand-written `init(from:)` using `decodeIfPresent` with `?? 8` fallback for backward compat. Add `snoozeDuration` to the existing memberwise `init`.

**`All-In-One-Clock/AlarmKit/AlarmKitCoordinator.swift`** — two changes:
- *History*: in `startObserving()`, replace `alarms.removeAll { $0.isEnabled && !$0.repeats && !activeIDs.contains($0.id) }` with a loop that sets `alarms[i].isEnabled = false` for those entries instead of deleting them.
- *Snooze*: in `scheduleAlarm()`, replace `.alarm(schedule:attributes:)` with the full `AlarmManager.AlarmConfiguration.init(countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(alarm.snoozeDuration * 60)), schedule: schedule, attributes: attrs, secondaryIntent: snoozeIntent)`. `preAlert: nil` prevents the pre-fire Live Activity that caused error 0.

**New `All-In-One-Clock/SnoozeAlarmIntent.swift`** (iOS app target, via `XcodeWrite`):
```swift
struct SnoozeAlarmIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource { "Snooze Alarm" }
    @Parameter(title: "Alarm ID") var alarmID: String
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        try? AlarmManager.shared.countdown(id: id)   // no duration param; uses postAlert from schedule time
        return .result()
    }
}
```

**`All-In-One-Clock/Views/AlarmsView.swift`** — AddAlarmView:
- Add `Section("Snooze")` with a `.menu` Picker for 5/8/10/15/20 min (default 8).
- Replace flat weekday toggles with a `RepeatPreset` segmented picker (Never / Weekdays / Weekends / Custom); Custom shows individual day buttons. `RepeatPreset.resolvedWeekdays` returns `[]`, `{2,3,4,5,6}`, `{1,7}`, or `nil` (custom) respectively.
- Pass both `snoozeDuration` and resolved weekdays to `AlarmItem` init.
- Update `AlarmRow.weekdaySummary` to show "Weekdays"/"Weekends" shorthand; add "Elapsed" caption for `!alarm.isEnabled && !alarm.repeats`.

**`All-In-One-Clock-Watch Watch App/Views/Alarms/AddAlarmView.swift`**
Mirror iOS changes: same `RepeatPreset` enum, same `snoozeDuration` picker (watchOS default navigation-link style).

**`All-In-One-Clock-Watch Watch App/Views/Alarms/AlarmListView.swift`**
- Update `repeatLabel` with "Weekdays"/"Weekends" shorthand.
- Dim disabled rows with `.opacity(alarm.isEnabled ? 1 : 0.45)`.

### Risks
- **Error 0 regression**: `preAlert: nil` avoids the pre-fire Live Activity that caused error 0. `AlarmPresentation` for alarms retains alert-only (no countdown), so no Live Activity starts at schedule time.
- **Snooze Live Activity**: Without `AlarmPresentation.Countdown` in alarm attributes, the snooze countdown won't show a Dynamic Island countdown — alarm silently snoozes. Acceptable for v1.

### Verification
1. Build iOS app — no compile errors.
2. Schedule alarm 1–2 min out → fires → tap Snooze → re-fires after configured duration.
3. Alarm fires without snooze → stays in list with toggle OFF and "Elapsed" label.
4. Toggle back on → reschedules; swipe-delete → removes entirely.
5. "Weekdays" preset → `alarm.weekdays == {2,3,4,5,6}`; "Custom" Mon+Wed → correct days stored.
6. Watch shows disabled history entries dimmed; syncs correctly via stateSync.

---

## Phase 8: Timer Feature Expansion

### Context
The timer screen needs six improvements: quick-start presets at the top, an interactive Live Activity (pause/cancel controls on lock screen and expanded Dynamic Island), a better post-completion display, timer editing and instant-restart from the row, and a new multi-stage chaining mode where stages each show a full alert before the next begins.

---

### 1. Timer Presets

**Where:** Top of `TimersView`, above the list — a horizontal `ScrollView` of four tappable chips.

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack {
        ForEach([60, 300, 600, 1200], id: \.self) { secs in
            Button(presetLabel(secs)) { Task { await schedulePreset(secs) } }
                .buttonStyle(.bordered).tint(.orange)
        }
    }.padding(.horizontal)
}
```

`schedulePreset()` runs the same auth pre-check already used by the `+` button, then calls `coordinator.scheduleTimer(CountdownTimer(label: "", duration: TimeInterval(secs)))`.

---

### 2. Model: Add `itemID` to `ClockAlarmMetadata`

**File:** `Shared/AlarmKit/ClockAlarmMetadata.swift`

Add `var itemID: UUID` to `ClockAlarmMetadata` so the widget can pass the correct ID to action intents. Update `attributes(label:kind:itemID:)` and its two callers in `AlarmKitCoordinator.scheduleAlarm()` and `scheduleTimer()`.

---

### 3. Live Activity Action Intents

**File:** `ClockWidgetExtension/AppIntent.swift` (widget extension target only)

Replace the stub `ConfigurationAppIntent` with three timer-control intents:

```swift
struct PauseTimerIntent: AppIntent {
    @Parameter var timerID: String
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }
        try? AlarmManager.shared.pause(id: id); return .result()
    }
}
struct ResumeTimerIntent: AppIntent {
    @Parameter var timerID: String
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }
        try? AlarmManager.shared.resume(id: id); return .result()
    }
}
struct CancelTimerIntent: AppIntent {
    @Parameter var timerID: String
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }
        try? AlarmManager.shared.stop(id: id); return .result()
    }
}
```

AlarmKit state propagates to the app via the existing `alarmUpdates` loop — no additional wiring needed.

---

### 4. Live Activity Layout

**File:** `ClockWidgetExtension/ClockWidgetExtensionLiveActivity.swift`

#### Lock Screen (`AlarmLockScreenView`)
For timer kind, add pause/resume and cancel buttons to the right side:
```
[⏱]  Timer label          [⏸/▶]  [✕]
     0:45 remaining
```
Use `Button(intent:)` — pause/resume toggled by `context.state.mode` (`.countdown` → show pause, `.paused` → show resume), cancel always shown. Alarm kind keeps the current read-only layout.

#### Dynamic Island Expanded
Add `.trailing` region with the pause/resume button (timer only). Add a small cancel button alongside the countdown in `.bottom`:
```swift
DynamicIslandExpandedRegion(.trailing) { /* pause/resume button */ }
DynamicIslandExpandedRegion(.bottom) {
    HStack { AlarmCountdownView(state:); Spacer(); /* cancel button */ }
}
```

---

### 5. Post-Completion Display

**File:** `All-In-One-Clock/Views/TimersView.swift`

In `TimerRow`, replace `Text("Finished")` with the formatted original duration. Add a private helper:
```swift
private func formatDuration(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600, m = Int(t) % 3600 / 60, s = Int(t) % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                 : String(format: "%d:%02d", m, s)
}
```

---

### 6. Timer Row: Restart Button + Edit Sheet

**File:** `All-In-One-Clock/Views/TimersView.swift`

Each `TimerRow` has two tap targets:
- **Content area** (Button wrapping the VStack) → sets `editingTimer = timer` to open edit sheet
- **Restart icon** (trailing Button) → calls `restartTimer(timer)`: schedules a new `CountdownTimer` with a fresh UUID and `createdAt = .now` but same `duration`, `label`, `soundName`

`AddTimerView` gets `existingTimer: CountdownTimer?` and a custom `init` (same pattern as `AddAlarmView`). Pre-populate hours/minutes/seconds by decomposing `timer.duration`. Title = "Edit Timer"/"New Timer", confirm button = "Save"/"Start". Editing preserves the same `id` for upsert in the coordinator.

---

### 7. Multi-Stage Timers

#### Model — `Shared/Models/CountdownTimer.swift`
Add two backward-compat fields (use `decodeIfPresent` with defaults, same pattern already in this file):
```swift
var stages: [TimeInterval]?   // nil = simple; stage durations in order
var currentStageIndex: Int    // 0-based; always 0 for simple timers
```

#### Scheduling — `AlarmKitCoordinator.scheduleTimer()`
```swift
let activeDuration = timer.stages?[timer.currentStageIndex] ?? timer.duration
// label: if multi-stage, append "Stage N of M"
```

#### Auto-Advance — `AlarmKitCoordinator.startObserving()`
When a multi-stage timer disappears from `activeIDs`, advance rather than remove:
```swift
if let stages = timer.stages, timer.currentStageIndex + 1 < stages.count {
    var next = timer
    next.currentStageIndex += 1
    next.createdAt = .now
    Task { try? await scheduleTimer(next) }
} else {
    timers.removeAll { $0.id == timer.id }
}
```
> **Simulator note**: `alarmUpdates` is skipped on simulator (existing known limitation), so multi-stage auto-advance only works on device.

#### UI — `AddTimerView`
Below the duration picker, add:
- `Toggle("Multi-stage", isOn: $isMultiStage)`
- When on: `Stepper("Stages: \(stageCount)", value: $stageCount, in: 2...10)`
- A per-stage H:M:S picker row for each index (labelled "Stage 1", "Stage 2", …)
- State: `@State private var isMultiStage = false`, `@State private var stageCount = 2`, `@State private var stageDurations: [TimeInterval] = [300, 300]`
- `stageCount` changes resize `stageDurations` (pad with 300s or trim from end)

When scheduling: `CountdownTimer(label:, duration: stageDurations[0], soundName:, stages: stageDurations, currentStageIndex: 0)`.

---

### Files Modified

| File | Change |
|------|--------|
| `Shared/Models/CountdownTimer.swift` | Add `stages`, `currentStageIndex` with backward-compat Codable |
| `Shared/AlarmKit/ClockAlarmMetadata.swift` | Add `itemID: UUID` |
| `All-In-One-Clock/AlarmKit/AlarmKitCoordinator.swift` | Stage-aware `scheduleTimer`, auto-advance in `startObserving` |
| `ClockWidgetExtension/AppIntent.swift` | Replace stub with Pause/Resume/Cancel intents |
| `ClockWidgetExtension/ClockWidgetExtensionLiveActivity.swift` | Action buttons in lock screen + expanded Dynamic Island |
| `All-In-One-Clock/Views/TimersView.swift` | Presets row, restart button, edit sheet, duration display |

---

### Verification
1. Build — no errors
2. **Presets**: Tap "5 min" chip → timer starts counting down immediately
3. **Restart**: Tap ↺ on a finished timer → restarts with same duration
4. **Edit**: Tap content area → edit sheet opens pre-filled; change duration → Save → reschedules
5. **Post-completion**: Let a 1-min timer fire → row shows "1:00" not "Finished"
6. **Live Activity** (device): Long-press Dynamic Island → pause and cancel buttons visible; pause works; cancel removes timer
7. **Multi-stage** (device): Create 2-stage (1 min + 2 min) → stage 1 fires alert → dismiss → stage 2 immediately starts → stage 2 fires → timer removed

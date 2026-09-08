//
//  ClockWidgetExtensionLiveActivity.swift
//  ClockWidgetExtension
//
//  AlarmKit Live Activity widget. Renders countdown, alerting, and paused
//  presentations for alarms and timers scheduled via AlarmKit.
//  Timers show pause/resume and cancel buttons on the lock screen and
//  in the expanded Dynamic Island.
//

import AlarmKit
import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<ClockAlarmMetadata>.self) { context in
            AlarmLockScreenView(context: context)
                .activityBackgroundTint(ClockAlarmMetadata.tint.opacity(0.15))
                .activitySystemActionForegroundColor(ClockAlarmMetadata.tint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AlarmIconView(metadata: context.attributes.metadata)
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.center) {
                    AlarmTitleView(metadata: context.attributes.metadata)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let metadata = context.attributes.metadata, metadata.kind == .timer {
                        let id = metadata.itemID.uuidString
                        if isTimerPaused(context.state) {
                            Button(intent: makeResumeIntent(id: id)) {
                                Image(systemName: "play.fill")
                            }
                            .tint(ClockAlarmMetadata.tint)
                        } else {
                            Button(intent: makePauseIntent(id: id)) {
                                Image(systemName: "pause.fill")
                            }
                            .tint(ClockAlarmMetadata.tint)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        AlarmCountdownView(state: context.state)
                            .font(.subheadline)
                            .monospacedDigit()
                        Spacer()
                        if let metadata = context.attributes.metadata, metadata.kind == .timer {
                            Button(intent: makeCancelIntent(id: metadata.itemID.uuidString)) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                AlarmIconView(metadata: context.attributes.metadata)
            } compactTrailing: {
                AlarmCountdownView(state: context.state)
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                AlarmIconView(metadata: context.attributes.metadata)
            }
        }
    }
}

// MARK: - Lock screen / banner

private struct AlarmLockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<ClockAlarmMetadata>>

    private var metadata: ClockAlarmMetadata? { context.attributes.metadata }

    var body: some View {
        HStack(spacing: 12) {
            AlarmIconView(metadata: metadata)
                .font(.title2)
                .foregroundStyle(ClockAlarmMetadata.tint)

            VStack(alignment: .leading, spacing: 2) {
                AlarmTitleView(metadata: metadata)
                    .font(.headline)
                AlarmCountdownView(state: context.state)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let meta = metadata, meta.kind == .timer {
                let id = meta.itemID.uuidString
                if isTimerPaused(context.state) {
                    Button(intent: makeResumeIntent(id: id)) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                    }
                    .tint(ClockAlarmMetadata.tint)
                } else {
                    Button(intent: makePauseIntent(id: id)) {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                    }
                    .tint(ClockAlarmMetadata.tint)
                }
                Button(intent: makeCancelIntent(id: id)) {
                    Image(systemName: "xmark")
                        .font(.title3)
                }
                .tint(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Sub-views

private struct AlarmIconView: View {
    let metadata: ClockAlarmMetadata?

    var body: some View {
        Image(systemName: metadata?.kind == .timer ? "timer" : "alarm")
            .foregroundStyle(ClockAlarmMetadata.tint)
    }
}

private struct AlarmTitleView: View {
    let metadata: ClockAlarmMetadata?

    var body: some View {
        let label = metadata?.label ?? ""
        let fallback = metadata?.kind == .timer ? "Timer" : "Alarm"
        Text(label.isEmpty ? fallback : label)
    }
}

private struct AlarmCountdownView: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let c):
            Text(timerInterval: Date.now...c.fireDate, countsDown: true)
        case .alert:
            Text("Time's up!")
                .foregroundStyle(ClockAlarmMetadata.tint)
        case .paused(let p):
            let remaining = p.totalCountdownDuration - p.previouslyElapsedDuration
            Text(Duration.seconds(remaining), format: .time(pattern: .hourMinuteSecond))
                .foregroundStyle(.secondary)
        @unknown default:
            EmptyView()
        }
    }
}

// MARK: - Intent helpers (file-private)

private func isTimerPaused(_ state: AlarmPresentationState) -> Bool {
    if case .paused = state.mode { return true }
    return false
}

private func makePauseIntent(id: String) -> PauseTimerIntent {
    var i = PauseTimerIntent(); i.timerID = id; return i
}

private func makeResumeIntent(id: String) -> ResumeTimerIntent {
    var i = ResumeTimerIntent(); i.timerID = id; return i
}

private func makeCancelIntent(id: String) -> CancelTimerIntent {
    var i = CancelTimerIntent(); i.timerID = id; return i
}

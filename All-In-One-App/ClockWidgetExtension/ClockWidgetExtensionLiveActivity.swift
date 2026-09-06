//
//  ClockWidgetExtensionLiveActivity.swift
//  ClockWidgetExtension
//
//  AlarmKit Live Activity widget. Renders countdown, alerting, and paused
//  presentations for alarms and timers scheduled via AlarmKit.
//

import AlarmKit
import ActivityKit
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
                DynamicIslandExpandedRegion(.bottom) {
                    AlarmCountdownView(state: context.state)
                        .font(.subheadline)
                        .monospacedDigit()
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

    var body: some View {
        HStack(spacing: 14) {
            AlarmIconView(metadata: context.attributes.metadata)
                .font(.title2)
                .foregroundStyle(ClockAlarmMetadata.tint)

            VStack(alignment: .leading, spacing: 2) {
                AlarmTitleView(metadata: context.attributes.metadata)
                    .font(.headline)
                AlarmCountdownView(state: context.state)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()
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
            // Use hourMinuteSecond so durations over 59m59s show the hour component.
            Text(Duration.seconds(remaining), format: .time(pattern: .hourMinuteSecond))
                .foregroundStyle(.secondary)
        @unknown default:
            EmptyView()
        }
    }
}

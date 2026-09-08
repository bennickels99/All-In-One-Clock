//
//  ClockAlarmMetadata.swift
//  All-In-One-Clock (Shared — iPhone app + widget only)
//
//  AlarmKit is iOS-only, so this file is excluded from the watch target. It
//  defines the custom metadata attached to every AlarmKit alarm/timer and a
//  builder for the `AlarmAttributes` that drive the system alert + Live Activity.
//

import AlarmKit
import SwiftUI

/// Custom data carried alongside each AlarmKit alarm. AlarmKit encodes this into
/// the `AlarmAttributes` and hands it back to the widget extension when it renders
/// the countdown / alerting presentations.
struct ClockAlarmMetadata: AlarmMetadata {
    /// Distinguishes a countdown timer from a scheduled alarm for presentation.
    enum Kind: String, Codable, Hashable, Sendable {
        case alarm
        case timer
    }

    var label: String
    var kind: Kind
    /// The UUID of the originating AlarmItem or CountdownTimer — used by widget
    /// action intents (pause/resume/cancel) to identify the correct item.
    var itemID: UUID

    init(label: String, kind: Kind, itemID: UUID) {
        self.label = label
        self.kind = kind
        self.itemID = itemID
    }

    // MARK: - Codable (backward compat: itemID missing in older encoded instances)

    private enum CodingKeys: String, CodingKey { case label, kind, itemID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label  = try c.decode(String.self, forKey: .label)
        kind   = try c.decode(Kind.self,   forKey: .kind)
        itemID = try c.decodeIfPresent(UUID.self, forKey: .itemID) ?? UUID()
    }
}

extension ClockAlarmMetadata {
    /// The shared tint applied to the templated alarm UI.
    static let tint: Color = .orange

    /// Builds the `AlarmAttributes` for an alarm/timer: an alert presentation
    /// (system-provided stop button) plus countdown and paused presentations so
    /// the Live Activity can show a running / paused countdown.
    static func attributes(
        label: String,
        kind: Kind,
        itemID: UUID
    ) -> AlarmAttributes<ClockAlarmMetadata> {
        let title: LocalizedStringResource = label.isEmpty
            ? (kind == .timer ? "Timer" : "Alarm")
            : LocalizedStringResource(stringLiteral: label)

        // Timers count down from a duration so they need countdown + paused Live
        // Activity presentations. Scheduled alarms just fire at a fixed time —
        // including countdown here would cause AlarmKit to start a Live Activity
        // immediately on schedule (potentially hours early) and fail with error 0.
        let presentation: AlarmPresentation
        if kind == .timer {
            let alert = AlarmPresentation.Alert(title: title)
            let countdown = AlarmPresentation.Countdown(
                title: title,
                pauseButton: AlarmButton(
                    text: "Pause",
                    textColor: .white,
                    systemImageName: "pause.fill"
                )
            )
            let paused = AlarmPresentation.Paused(
                title: "Paused",
                resumeButton: AlarmButton(
                    text: "Resume",
                    textColor: .white,
                    systemImageName: "play.fill"
                )
            )
            presentation = AlarmPresentation(alert: alert, countdown: countdown, paused: paused)
        } else {
            // secondaryButton + .countdown behavior renders the Snooze button on the
            // alert screen. The snooze duration was set via Alarm.CountdownDuration.postAlert
            // at schedule time; .countdown tells the system to restart that countdown.
            let alert = AlarmPresentation.Alert(
                title: title,
                secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz"),
                secondaryButtonBehavior: .countdown
            )
            presentation = AlarmPresentation(alert: alert)
        }

        return AlarmAttributes(
            presentation: presentation,
            metadata: ClockAlarmMetadata(label: label, kind: kind, itemID: itemID),
            tintColor: tint
        )
    }
}

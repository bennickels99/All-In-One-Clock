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

    init(label: String, kind: Kind) {
        self.label = label
        self.kind = kind
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
        kind: Kind
    ) -> AlarmAttributes<ClockAlarmMetadata> {
        let title: LocalizedStringResource = label.isEmpty
            ? (kind == .timer ? "Timer" : "Alarm")
            : LocalizedStringResource(stringLiteral: label)

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

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: countdown,
            paused: paused
        )

        return AlarmAttributes(
            presentation: presentation,
            metadata: ClockAlarmMetadata(label: label, kind: kind),
            tintColor: tint
        )
    }
}

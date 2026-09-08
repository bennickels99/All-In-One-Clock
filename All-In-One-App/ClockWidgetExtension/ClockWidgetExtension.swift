//
//  ClockWidgetExtension.swift
//  ClockWidgetExtension
//
//  Placeholder home-screen widget (not yet implemented). The real widget
//  surface is the AlarmKit Live Activity in ClockWidgetExtensionLiveActivity.swift.
//

import WidgetKit
import SwiftUI

private struct ClockEntry: TimelineEntry { let date: Date }

private struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        completion(Timeline(entries: [ClockEntry(date: .now)], policy: .never))
    }
}

struct ClockWidgetExtension: Widget {
    let kind = "ClockWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { _ in
            EmptyView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

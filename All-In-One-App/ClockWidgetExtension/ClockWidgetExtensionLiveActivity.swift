//
//  ClockWidgetExtensionLiveActivity.swift
//  ClockWidgetExtension
//
//  Created by Ben Nickels on 9/5/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ClockWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ClockWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClockWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ClockWidgetExtensionAttributes {
    fileprivate static var preview: ClockWidgetExtensionAttributes {
        ClockWidgetExtensionAttributes(name: "World")
    }
}

extension ClockWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: ClockWidgetExtensionAttributes.ContentState {
        ClockWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ClockWidgetExtensionAttributes.ContentState {
         ClockWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ClockWidgetExtensionAttributes.preview) {
   ClockWidgetExtensionLiveActivity()
} contentStates: {
    ClockWidgetExtensionAttributes.ContentState.smiley
    ClockWidgetExtensionAttributes.ContentState.starEyes
}

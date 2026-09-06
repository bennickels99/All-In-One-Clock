//
//  ClockWidgetExtensionBundle.swift
//  ClockWidgetExtension
//

import WidgetKit
import SwiftUI

@main
struct ClockWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        ClockWidgetExtension()
        ClockWidgetExtensionControl()
        AlarmLiveActivity()
    }
}

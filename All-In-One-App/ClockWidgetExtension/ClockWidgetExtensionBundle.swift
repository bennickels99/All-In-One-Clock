//
//  ClockWidgetExtensionBundle.swift
//  ClockWidgetExtension
//
//  Created by Ben Nickels on 9/5/26.
//

import WidgetKit
import SwiftUI

@main
struct ClockWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        ClockWidgetExtension()
        ClockWidgetExtensionControl()
        ClockWidgetExtensionLiveActivity()
    }
}

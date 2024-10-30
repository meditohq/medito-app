//
//  StreakWidgetSmall.swift
//  MeditoWidgetExtension
//
//  Created by Luz Racca on 26/10/2024.
//

import SwiftUI
import WidgetKit

struct StreakWidgetSmall: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: MeditoWidgetKind.streakSmall,
            provider: MeditoTimelineProvider()
        ) { entry in
            StreakWidgetSmallView(entry: entry)
        }
        .configurationDisplayName("Medito")
        .description("Mindful streak count: one breath at a time.")
        .supportedFamilies([.systemSmall])
    }
}

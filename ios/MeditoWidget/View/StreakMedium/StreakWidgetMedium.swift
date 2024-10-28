import WidgetKit
import SwiftUI


struct StreakWidgetMedium: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: MeditoWidgetKind.streakMedium,
            provider: MeditoTimelineProvider()
        ) { entry in
            StreakWidgetMediumView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.systemMedium])
    }
}

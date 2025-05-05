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
        .configurationDisplayName("Medito")
        .description("Keep track of your journey with Medito on your home screen.")
        .supportedFamilies([.systemMedium])
    }
}

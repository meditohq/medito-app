import WidgetKit
import SwiftUI

@main
struct MeditoWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeditoStatsWidget()
    }
}

struct MeditoStatsWidget: Widget {
    let kind: String = "MeditoStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeditoTimelineProvider()) { entry in
            StreakWidgetSmall(entry: entry)
        }
        .configurationDisplayName("Meditation Stats")
        .description("View your meditation streak and progress")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
} 
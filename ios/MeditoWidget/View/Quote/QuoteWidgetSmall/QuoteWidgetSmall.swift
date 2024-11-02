import SwiftUI
import WidgetKit

struct QuoteWidgetSmall: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: MeditoWidgetKind.quoteSmall,
            provider: MeditoTimelineProvider()
        ) { entry in
            QuoteWidgetSmallView(entry: entry)
        }
        .configurationDisplayName("Medito")
        .description("Mindful streak count: one breath at a time.")
        .supportedFamilies([.systemSmall])
    }
}

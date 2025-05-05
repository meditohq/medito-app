import SwiftUI
import WidgetKit

struct QuoteWidgetMedium: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: MeditoWidgetKind.quoteMedium,
            provider: MeditoTimelineProvider()
        ) { entry in
            QuoteWidgetMediumView(entry: entry)
        }
        .configurationDisplayName("Medito")
        .description("Mindful streak count: one breath at a time.")
        .supportedFamilies([.systemMedium])
    }
}

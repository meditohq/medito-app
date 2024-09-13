import WidgetKit
import SwiftUI

enum MeditoWidgetConstants {
    static let widgetKind = "StreakWidget"
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: MeditoWidgetConstants.widgetKind,
            provider: Provider()
        ) { entry in
            if #available(iOS 17.0, *) {
                StreakWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                StreakWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StatsWidgetEntry(date: Date(), title: "8 days", subtitle: "Current streak")
    StatsWidgetEntry(date: Date(), title: "9 days", subtitle: "Current streak")
}

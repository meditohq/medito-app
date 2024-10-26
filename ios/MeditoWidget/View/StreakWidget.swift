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
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}


//#Preview(as: .systemSmall) {
//    StreakWidget()
//} timeline: {
//    StatsWidgetEntry(date: Date(), streakTitle: "Title", streakValue: 30, audioCompleted: [])
//    StatsWidgetEntry(date: Date(), streakTitle: "Title", streakValue: 30, audioCompleted: [])
//}

import SwiftUI
import WidgetKit

struct ConsistencyEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct ConsistencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConsistencyEntry {
        ConsistencyEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ConsistencyEntry) -> Void) {
        completion(ConsistencyEntry(date: Date(), data: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConsistencyEntry>) -> Void) {
        let entry = ConsistencyEntry(date: Date(), data: .load())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct ConsistencyWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family
    let entry: ConsistencyEntry

    private var effectiveDark: Bool {
        switch entry.data.themePreference {
        case "dark": return true
        case "light": return false
        default: return colorScheme == .dark
        }
    }

    private var colors: WidgetColors { effectiveDark ? .dark : .light }
    private var isMedium: Bool { family == .systemMedium }

    private var allActivityDates: Set<Date> {
        entry.data.meditationDates.union(entry.data.freezeDates)
    }

    private var hasActivityToday: Bool {
        allActivityDates.contains(
            logicalDayStart(Date(), offsetHours: entry.data.dayBoundaryOffsetHours)
        )
    }

    var body: some View {
        StatWidgetBody(
            value: "\(entry.data.consistencyScore)%",
            ringScore: entry.data.consistencyScore,
            doneToday: hasActivityToday,
            allActivityDates: allActivityDates,
            dayBoundaryOffsetHours: entry.data.dayBoundaryOffsetHours,
            colors: colors,
            isMedium: isMedium
        )
    }
}

struct ConsistencyWidget: Widget {
    let kind = "ConsistencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConsistencyProvider()) { entry in
            ConsistencyWidgetView(entry: entry)
                // Source params let DeepLinkService attribute the tap for analytics.
                .widgetURL(URL(string: "org.meditofoundation://medito/?source=home_widget&widget=consistency"))
        }
        .configurationDisplayName("Consistency")
        .description("See your meditation consistency percentage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

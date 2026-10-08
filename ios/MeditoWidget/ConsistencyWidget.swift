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
        let data = WidgetData.load()
        let now = Date()
        let entries = data.timelineDates(from: now).map { ConsistencyEntry(date: $0, data: data) }
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
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

    private var today: Date { entry.data.today(at: entry.date) }

    var body: some View {
        let score = entry.data.consistencyScore(at: entry.date)
        StatWidgetBody(
            value: "\(score)%",
            ringScore: score,
            doneToday: entry.data.allActivityDates.contains(today),
            allActivityDates: entry.data.allActivityDates,
            today: today,
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

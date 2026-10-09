import SwiftUI
import WidgetKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: Date(), data: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let data = WidgetData.load()
        let now = Date()
        let entries = data.timelineDates(from: now).map { StreakEntry(date: $0, data: data) }
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: StreakEntry

    private var isMedium: Bool { family == .systemMedium }

    private var today: Date { entry.data.today(at: entry.date) }

    var body: some View {
        let streak = entry.data.streak(at: entry.date)
        WidgetContextReader(themePreference: entry.data.themePreference) { colors, standBy in
            StatWidgetBody(
                value: "\(streak)",
                unit: streak == 1 ? entry.data.dayLabel : entry.data.daysLabel,
                doneToday: entry.data.allActivityDates.contains(today),
                allActivityDates: entry.data.allActivityDates,
                today: today,
                colors: colors,
                isMedium: isMedium
            )
            // Source params let DeepLinkService attribute the tap for analytics.
            .widgetURL(widgetTapURL("streak", placement: standBy ? "standby" : "home_screen"))
        }
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("See your current meditation streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

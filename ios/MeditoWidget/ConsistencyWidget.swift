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
        allActivityDates.contains(Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        VStack(spacing: isMedium ? 12 : 6) {
            HStack(spacing: 6) {
                Image(systemName: hasActivityToday ? "flame.fill" : "flame")
                    .foregroundStyle(hasActivityToday ? Color(hex: "917DF0") : colors.inactiveColor)
                    .font(.system(size: isMedium ? 26 : 20, weight: .bold))
                Text("\(entry.data.consistencyScore)")
                    .font(.system(size: isMedium ? 32 : 24, weight: .bold))
                    .foregroundStyle(colors.textColor)
                Text("%")
                    .font(.system(size: isMedium ? 18 : 14))
                    .foregroundStyle(colors.textColor)
            }
            CalendarStrip(allActivityDates: allActivityDates, colors: colors, circleSize: isMedium ? 28 : 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(12)
        .widgetBackground(color: colors.backgroundColor)
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

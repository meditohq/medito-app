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
        let entry = StreakEntry(date: Date(), data: .load())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct StreakWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family
    let entry: StreakEntry

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

    private var streakLabel: String {
        entry.data.streakCurrent == 1 ? entry.data.dayLabel : entry.data.daysLabel
    }

    var body: some View {
        VStack(spacing: isMedium ? 12 : 6) {
            HStack(spacing: 6) {
                Image(systemName: hasActivityToday ? "flame.fill" : "flame")
                    .foregroundStyle(hasActivityToday ? Color(hex: "917DF0") : colors.inactiveColor)
                    .font(.system(size: isMedium ? 26 : 20, weight: .bold))
                Text("\(entry.data.streakCurrent)")
                    .font(.system(size: isMedium ? 32 : 24, weight: .bold))
                    .foregroundStyle(colors.textColor)
                Text(streakLabel)
                    .font(.system(size: isMedium ? 18 : 14))
                    .foregroundStyle(colors.textColor)
            }
            CalendarStrip(allActivityDates: allActivityDates, colors: colors, circleSize: isMedium ? 28 : 20, dayBoundaryOffsetHours: entry.data.dayBoundaryOffsetHours)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(12)
        .widgetBackground(color: colors.backgroundColor)
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                // Source params let DeepLinkService attribute the tap for analytics.
                .widgetURL(URL(string: "org.meditofoundation://medito/?source=home_widget&widget=streak"))
        }
        .configurationDisplayName("Streak")
        .description("See your current meditation streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

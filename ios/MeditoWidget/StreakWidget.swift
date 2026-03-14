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
    let entry: StreakEntry

    private var effectiveDark: Bool {
        switch entry.data.themePreference {
        case "dark": return true
        case "light": return false
        default: return colorScheme == .dark
        }
    }

    private var colors: WidgetColors { effectiveDark ? .dark : .light }

    private var allActivityDates: Set<Date> {
        entry.data.meditationDates.union(entry.data.freezeDates)
    }

    private var hasActivityToday: Bool {
        allActivityDates.contains(Calendar.current.startOfDay(for: Date()))
    }

    private var streakLabel: String {
        entry.data.streakCurrent == 1 ? entry.data.dayLabel : entry.data.daysLabel
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: hasActivityToday ? "flame.fill" : "flame")
                    .foregroundStyle(hasActivityToday ? Color(hex: "917DF0") : colors.inactiveColor)
                    .font(.system(size: 20, weight: .bold))
                Text("\(entry.data.streakCurrent)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(colors.textColor)
                Text(streakLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(colors.textColor)
            }
            CalendarStrip(allActivityDates: allActivityDates, colors: colors)
        }
        .padding(12)
        .widgetBackground(color: colors.backgroundColor)
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

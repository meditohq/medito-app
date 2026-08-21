import Foundation
import SwiftUI

private let appGroupId = "group.org.medito.widget"

/// The user-perceived calendar day that contains [date], honouring the
/// day-boundary offset. Mirrors Dart's `dayOf` and the Android
/// StreakCalculator: shift the instant back by the offset, then take the
/// local start-of-day. MUST match those so the widget buckets days the same
/// way the in-app streak/calendar do — otherwise a session inside the offset
/// window (e.g. just after midnight with a "day starts at 3am" setting) gets
/// circled on a different day than the streak counts it.
func logicalDayStart(_ date: Date, offsetHours: Int) -> Date {
    let shifted = date.addingTimeInterval(-Double(offsetHours) * 3600)
    return Calendar.current.startOfDay(for: shifted)
}

struct WidgetData {
    let streakCurrent: Int
    let consistencyScore: Int
    let meditationDates: Set<Date>
    let freezeDates: Set<Date>
    let dayLabel: String
    let daysLabel: String
    let themePreference: String
    let dayBoundaryOffsetHours: Int

    static var placeholder: WidgetData {
        WidgetData(
            streakCurrent: 7,
            consistencyScore: 85,
            meditationDates: [Calendar.current.startOfDay(for: Date())],
            freezeDates: [],
            dayLabel: "day",
            daysLabel: "days",
            themePreference: "system",
            dayBoundaryOffsetHours: 0
        )
    }

    static func load() -> WidgetData {
        let defaults = UserDefaults(suiteName: appGroupId)
        let offsetHours = defaults?.integer(forKey: "day_boundary_offset_hours") ?? 0
        return WidgetData(
            streakCurrent: defaults?.integer(forKey: "streak_current") ?? 0,
            consistencyScore: defaults?.integer(forKey: "consistency_score") ?? 0,
            meditationDates: parseDates(
                from: defaults?.string(forKey: "meditation_dates") ?? "[]",
                offsetHours: offsetHours
            ),
            freezeDates: parseDates(
                from: defaults?.string(forKey: "freeze_dates") ?? "[]",
                offsetHours: offsetHours
            ),
            dayLabel: defaults?.string(forKey: "day_label") ?? "day",
            daysLabel: defaults?.string(forKey: "days_label") ?? "days",
            themePreference: defaults?.string(forKey: "theme_preference") ?? "system",
            dayBoundaryOffsetHours: offsetHours
        )
    }

    private static func parseDates(from json: String, offsetHours: Int) -> Set<Date> {
        guard
            let data = json.data(using: .utf8),
            let timestamps = try? JSONSerialization.jsonObject(with: data) as? [Double]
        else { return [] }

        return Set(timestamps.map {
            logicalDayStart(Date(timeIntervalSince1970: $0 / 1000), offsetHours: offsetHours)
        })
    }
}

struct WidgetColors {
    let backgroundColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let inactiveColor: Color

    static let dark = WidgetColors(
        backgroundColor: Color(hex: "121212"),
        textColor: Color(hex: "FFFFFF"),
        secondaryTextColor: Color(hex: "B3B3B3"),
        inactiveColor: Color(hex: "2C2C2C")
    )

    static let light = WidgetColors(
        backgroundColor: Color(hex: "F8F9FA"),
        textColor: Color(hex: "000000"),
        secondaryTextColor: Color(hex: "000000"),
        inactiveColor: Color(hex: "E5E7EB")
    )
}

struct CalendarStrip: View {
    let allActivityDates: Set<Date>
    let colors: WidgetColors
    var circleSize: CGFloat = 20
    var dayBoundaryOffsetHours: Int = 0

    private var last5Days: [Date] {
        let cal = Calendar.current
        // Logical "today" under the day-boundary offset, so the strip's day
        // keys match the offset-bucketed `allActivityDates`.
        let today = logicalDayStart(Date(), offsetHours: dayBoundaryOffsetHours)
        return (0 ..< 5).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(last5Days, id: \.self) { day in
                let active = allActivityDates.contains(day)
                VStack(spacing: 3) {
                    Text(dayLetter(for: day))
                        .font(.system(size: circleSize * 0.45))
                        .foregroundStyle(colors.secondaryTextColor)
                    ZStack {
                        Circle()
                            .fill(active ? Color(hex: "917DF0") : colors.inactiveColor)
                        if active {
                            Image(systemName: "checkmark")
                                .font(.system(size: circleSize * 0.38, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: circleSize, height: circleSize)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayLetter(for date: Date) -> String {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return "S"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        case 7: return "S"
        default: return ""
        }
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

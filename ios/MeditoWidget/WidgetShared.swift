import Foundation
import SwiftUI

private let appGroupId = "group.org.medito.widget"

struct WidgetData {
    let streakCurrent: Int
    let consistencyScore: Int
    let meditationDates: Set<Date>
    let freezeDates: Set<Date>
    let dayLabel: String
    let daysLabel: String
    let themePreference: String

    static var placeholder: WidgetData {
        WidgetData(
            streakCurrent: 7,
            consistencyScore: 85,
            meditationDates: [Calendar.current.startOfDay(for: Date())],
            freezeDates: [],
            dayLabel: "day",
            daysLabel: "days",
            themePreference: "system"
        )
    }

    static func load() -> WidgetData {
        let defaults = UserDefaults(suiteName: appGroupId)
        return WidgetData(
            streakCurrent: defaults?.integer(forKey: "streak_current") ?? 0,
            consistencyScore: defaults?.integer(forKey: "consistency_score") ?? 0,
            meditationDates: parseDates(from: defaults?.string(forKey: "meditation_dates") ?? "[]"),
            freezeDates: parseDates(from: defaults?.string(forKey: "freeze_dates") ?? "[]"),
            dayLabel: defaults?.string(forKey: "day_label") ?? "day",
            daysLabel: defaults?.string(forKey: "days_label") ?? "days",
            themePreference: defaults?.string(forKey: "theme_preference") ?? "system"
        )
    }

    private static func parseDates(from json: String) -> Set<Date> {
        guard
            let data = json.data(using: .utf8),
            let timestamps = try? JSONSerialization.jsonObject(with: data) as? [Double]
        else { return [] }

        return Set(timestamps.map {
            Calendar.current.startOfDay(for: Date(timeIntervalSince1970: $0 / 1000))
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

    private var last5Days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0 ..< 5).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(last5Days, id: \.self) { day in
                let active = allActivityDates.contains(day)
                VStack(spacing: 2) {
                    Text(dayLetter(for: day))
                        .font(.system(size: 9))
                        .foregroundStyle(colors.secondaryTextColor)
                    ZStack {
                        Circle()
                            .fill(active ? Color(hex: "917DF0") : colors.inactiveColor)
                        if active {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
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

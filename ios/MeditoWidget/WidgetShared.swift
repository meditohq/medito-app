import CoreText
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

/// The app's monochrome palette (lib/constants/colors/color_constants.dart): near-black page and
/// off-white text in dark mode, white page and near-black text in light mode. The accent is the
/// theme's inverted "primary" (light on dark, dark on light), with `onAccent` for glyphs on it.
struct WidgetColors {
    let backgroundColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let inactiveColor: Color
    let accent: Color
    let onAccent: Color

    static let dark = WidgetColors(
        backgroundColor: Color(hex: "1A1A1A"), // ebony
        textColor: Color(hex: "FFFFFF"),
        secondaryTextColor: Color(hex: "A1A1A1"), // graphite
        inactiveColor: Color(hex: "333333"), // charcoal
        accent: Color(hex: "E5E5E5"), // brandAccent (dark)
        onAccent: Color(hex: "171717") // onAccentDark
    )

    static let light = WidgetColors(
        backgroundColor: Color(hex: "FFFFFF"), // lightBackground
        textColor: Color(hex: "0A0A0A"), // lightOnSurface
        secondaryTextColor: Color(hex: "737373"), // lightSecondary
        inactiveColor: Color(hex: "E5E5E5"), // lightGrey
        accent: Color(hex: "171717"), // brandAccent (light)
        onAccent: Color(hex: "FAFAFA") // onAccentLight
    )
}

/// Google Sans, registered from the containing app's Flutter bundle so the extension shares the
/// app's font files instead of shipping a second copy (they're ~2 MB each). If they can't be
/// found, `Font.custom` quietly falls back to the system font.
enum WidgetFonts {
    enum Weight: String {
        case regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold"
    }

    static let register: Void = {
        // <App>.app/PlugIns/MeditoWidgetExtension.appex → <App>.app
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        let dir = appURL.appendingPathComponent(
            "Frameworks/App.framework/flutter_assets/assets/fonts/google-sans"
        )
        for weight in [Weight.regular, .medium, .semibold, .bold] {
            let url = dir.appendingPathComponent("GoogleSans-\(weight.rawValue).ttf")
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}

extension Font {
    /// Fixed size, like the `.system(size:)` it replaces: widgets have a fixed canvas.
    static func googleSans(_ size: CGFloat, _ weight: WidgetFonts.Weight = .regular) -> Font {
        _ = WidgetFonts.register
        return .custom("GoogleSans-\(weight.rawValue)", fixedSize: size)
    }
}

/// Localised one-letter weekday ("M", "T"…) for `date`.
func weekdayLetter(_ date: Date) -> String {
    let cal = Calendar.current
    return cal.veryShortStandaloneWeekdaySymbols[cal.component(.weekday, from: date) - 1]
}

/// The last five logical days as a row of discs, oldest first (small widget).
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
                    Text(weekdayLetter(day))
                        .font(.googleSans(12, .semibold))
                        .foregroundStyle(colors.secondaryTextColor)
                    ZStack {
                        Circle()
                            .fill(active ? colors.accent : colors.inactiveColor)
                        if active {
                            Image(systemName: "checkmark")
                                .font(.system(size: circleSize * 0.4, weight: .bold))
                                .foregroundStyle(colors.onAccent)
                        }
                    }
                    .frame(width: circleSize, height: circleSize)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// The last few weeks as a calendar: rows of seven days ending with today in the bottom-right
/// corner (like the small widget's strip, the weekday header follows the window rather than the
/// locale's week start, so the grid is always full). Practised days are filled; today is ringed
/// until it's done.
struct ActivityGrid: View {
    let allActivityDates: Set<Date>
    let colors: WidgetColors
    var weeks = 5
    var dotSize: CGFloat = 16
    var dayBoundaryOffsetHours: Int = 0

    private var today: Date { logicalDayStart(Date(), offsetHours: dayBoundaryOffsetHours) }

    /// `weeks` rows of seven days, the last one ending today.
    private var rows: [[Date]] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(7 * weeks - 1), to: today)!
        return (0 ..< weeks).map { w in
            (0 ..< 7).map { cal.date(byAdding: .day, value: w * 7 + $0, to: start)! }
        }
    }

    var body: some View {
        let rows = rows
        VStack(spacing: dotSize * 0.4) {
            HStack(spacing: dotSize * 0.5) {
                ForEach(rows[0], id: \.self) { day in
                    Text(weekdayLetter(day))
                        .font(.googleSans(11, .semibold))
                        .foregroundStyle(colors.secondaryTextColor)
                        .frame(width: dotSize)
                }
            }
            ForEach(rows, id: \.self) { week in
                HStack(spacing: dotSize * 0.5) {
                    ForEach(week, id: \.self) { day in
                        dot(for: day).frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dot(for day: Date) -> some View {
        if allActivityDates.contains(day) {
            Circle().fill(colors.accent)
        } else if day == today {
            Circle()
                .fill(colors.inactiveColor)
                .overlay(Circle().strokeBorder(colors.secondaryTextColor, lineWidth: 1.5))
        } else {
            Circle().fill(colors.inactiveColor)
        }
    }
}

/// The in-app consistency chip's ring: the score as an arc over a faint track.
struct ConsistencyRing: View {
    let score: Int
    let color: Color
    let colors: WidgetColors
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle().stroke(colors.textColor.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
    }
}

/// Shared body of the Streak and Consistency widgets. Mirrors the in-app streak chip: once today
/// is practised the icon lights up in the accent and the figure goes bold; before that both stay
/// quiet. The icon is a flame for the streak and, given a `ringScore`, the consistency ring.
///
/// Small: icon + figure over the last five days. Medium: the figure on the left, the last five
/// weeks as a calendar on the right.
struct StatWidgetBody: View {
    let value: String
    var unit: String = ""
    var ringScore: Int? = nil
    let doneToday: Bool
    let allActivityDates: Set<Date>
    let dayBoundaryOffsetHours: Int
    let colors: WidgetColors
    let isMedium: Bool

    private var iconColor: Color { doneToday ? colors.accent : colors.secondaryTextColor }

    @ViewBuilder
    private func icon(size: CGFloat) -> some View {
        if let ringScore {
            ConsistencyRing(score: ringScore, color: iconColor, colors: colors, size: size, lineWidth: size * 0.12)
        } else {
            Image(systemName: doneToday ? "flame.fill" : "flame")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var figure: some View {
        Text(value)
            .font(.googleSans(isMedium ? 52 : 28, doneToday ? .bold : .medium))
            .monospacedDigit()
            .foregroundStyle(colors.textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    var body: some View {
        Group {
            if isMedium {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        icon(size: 28)
                        Spacer(minLength: 8)
                        figure
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.googleSans(16, .medium))
                                .foregroundStyle(colors.secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                    ActivityGrid(
                        allActivityDates: allActivityDates,
                        colors: colors,
                        dayBoundaryOffsetHours: dayBoundaryOffsetHours
                    )
                }
            } else {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        icon(size: 20)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                        figure
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.googleSans(14, .medium))
                                .foregroundStyle(colors.secondaryTextColor)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    CalendarStrip(
                        allActivityDates: allActivityDates,
                        colors: colors,
                        dayBoundaryOffsetHours: dayBoundaryOffsetHours
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .widgetBackground(color: colors.backgroundColor)
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            // iOS 17's container background brings the system content margins; match them here.
            padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color)
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

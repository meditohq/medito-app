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
    let meditationDates: Set<Date>
    let freezeDates: Set<Date>
    let dayLabel: String
    let daysLabel: String
    let themePreference: String
    let dayBoundaryOffsetHours: Int
    /// The in-app streak chip's choice ("currentStreak" / "consistencyScore"), which the Lock
    /// Screen widget follows. Defaults to the consistency score, as the app does.
    var statDisplay: String = "consistencyScore"

    var showsStreak: Bool { statDisplay == "currentStreak" }

    var allActivityDates: Set<Date> { meditationDates.union(freezeDates) }

    func today(at now: Date) -> Date {
        logicalDayStart(now, offsetHours: dayBoundaryOffsetHours)
    }

    // The streak and score are recomputed here (like the Android widgets) rather than read from
    // the "streak_current" / "consistency_score" the app pushes, which only change when the app
    // runs: a missed day left the old streak showing until the next app open.
    func streak(at now: Date) -> Int {
        StatCalculator.streak(activityDays: allActivityDates, today: today(at: now))
    }

    func consistencyScore(at now: Date) -> Int {
        StatCalculator.consistencyScore(activityDays: allActivityDates, today: today(at: now))
    }

    /// Timeline entries for the stat widgets: now, and the moment the logical day rolls over, so
    /// the streak and the strip turn over on time without the app.
    func timelineDates(from now: Date) -> [Date] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today(at: now))!
        return [now, tomorrow.addingTimeInterval(Double(dayBoundaryOffsetHours) * 3600)]
    }

    /// Seven days running plus one earlier session: a 7-day streak at 67%.
    static var placeholder: WidgetData {
        let today = Calendar.current.startOfDay(for: Date())
        let days = [0, -1, -2, -3, -4, -5, -6, -11].map {
            Calendar.current.date(byAdding: .day, value: $0, to: today)!
        }
        return WidgetData(
            meditationDates: Set(days),
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
            dayBoundaryOffsetHours: offsetHours,
            statDisplay: defaults?.string(forKey: "stat_display") ?? "consistencyScore"
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
    /// Punch glyphs out of the accent disc instead of painting them in `onAccent`.
    var knockOutGlyphs = false

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

    /// Clear / tinted home screen and StandBy at night: the system keeps only each pixel's
    /// opacity, so every colour comes out the same and states must differ by alpha, with glyphs
    /// cut out of their discs.
    static let monochrome = WidgetColors(
        backgroundColor: Color(hex: "1A1A1A"),
        textColor: .white,
        secondaryTextColor: .white.opacity(0.6),
        inactiveColor: .white.opacity(0.25),
        accent: .white,
        onAccent: .black,
        knockOutGlyphs: true
    )

    /// The palette for the in-app theme choice ("dark" / "light" / "system").
    static func forTheme(_ themePreference: String, _ colorScheme: ColorScheme) -> WidgetColors {
        switch themePreference {
        case "dark": return .dark
        case "light": return .light
        default: return colorScheme == .dark ? .dark : .light
        }
    }
}

/// Resolves the palette and placement from the widget's environment and hands them to `content`.
///
/// Where the system strips the container background (StandBy) the content sits on black, so the
/// light palette's near-black text would vanish: the dark palette is used whatever the in-app
/// theme says. Where it doesn't render in full colour (clear / tinted home screen, StandBy at
/// night) the monochrome palette is used.
struct WidgetContextReader<Content: View>: View {
    let themePreference: String
    let content: (WidgetColors, _ standBy: Bool) -> Content

    init(themePreference: String, @ViewBuilder content: @escaping (WidgetColors, Bool) -> Content) {
        self.themePreference = themePreference
        self.content = content
    }

    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            BackgroundAwareReader(themePreference: themePreference, content: content)
        } else {
            ThemeReader(themePreference: themePreference, content: content)
        }
    }

    private struct ThemeReader: View {
        @Environment(\.colorScheme) var colorScheme
        let themePreference: String
        let content: (WidgetColors, Bool) -> Content

        var body: some View {
            content(WidgetColors.forTheme(themePreference, colorScheme), false)
        }
    }

    @available(iOSApplicationExtension 17.0, *)
    private struct BackgroundAwareReader: View {
        @Environment(\.colorScheme) var colorScheme
        @Environment(\.showsWidgetContainerBackground) var showsBackground
        @Environment(\.widgetRenderingMode) var renderingMode
        let themePreference: String
        let content: (WidgetColors, Bool) -> Content

        var body: some View {
            let colors: WidgetColors = renderingMode != .fullColor
                ? .monochrome
                : !showsBackground ? .dark : .forTheme(themePreference, colorScheme)
            content(
                colors,
                // A home-screen-size widget without its background is in StandBy (or, rarely, on
                // an iPad Lock Screen).
                !showsBackground
            )
        }
    }
}

/// A widget's tap deep link. `placement` lets DeepLinkService split taps by where the widget sits.
func widgetTapURL(_ widget: String, path: String = "medito/", placement: String = "home_screen") -> URL? {
    URL(string: "org.meditofoundation://\(path)?source=home_widget&widget=\(widget)&placement=\(placement)")
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
    /// The logical day (`logicalDayStart`) being shown, so the strip's day keys match the
    /// offset-bucketed `allActivityDates`.
    let today: Date
    var circleSize: CGFloat = 20

    private var last5Days: [Date] {
        let cal = Calendar.current
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
                                .onAccentGlyph(colors)
                        }
                    }
                    .compositingGroup()
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
    let today: Date
    var weeks = 5
    var dotSize: CGFloat = 16

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

/// The app's flame (assets/images/fire-flame.svg), as on Android: outlined until today is
/// practised, then lit — solid, with the inner flame cut out (widget_flame_filled.xml).
struct MeditoFlame: View {
    let lit: Bool
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            if lit {
                FlameShape.lit.fill(color, style: FillStyle(eoFill: true))
            } else {
                FlameShape.outline.stroke(
                    color,
                    style: StrokeStyle(lineWidth: size * 1.5 / 24, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: size, height: size)
    }
}

/// Closed cubic subpaths in the icon's 24×24 grid, each a flat x, y list: a start point, then
/// (control 1, control 2, end) triples.
private struct FlameShape: Shape {
    let subpaths: [[CGFloat]]

    static let outline = FlameShape(subpaths: [
        [8, 18, 8, 20.4148, 9.79086, 21, 12, 21, 15.7587, 21, 17, 18.5, 14.5, 13.5,
         11, 18, 10.5, 11, 11, 9, 9.5, 12, 8, 14.8177, 8, 18],
        [12, 21, 17.0495, 21, 20, 18.0956, 20, 13.125, 20, 8.15444, 12, 3, 12, 3,
         12, 3, 4, 8.15444, 4, 13.125, 4, 18.0956, 6.95054, 21, 12, 21],
    ])

    static let lit = FlameShape(subpaths: [
        [12, 21.75, 17.4, 21.75, 20.75, 18.6, 20.75, 13.125, 20.75, 7.75, 12, 2.1, 12, 2.1,
         12, 2.1, 3.25, 7.75, 3.25, 13.125, 3.25, 18.6, 6.6, 21.75, 12, 21.75],
        [8.75, 18, 8.75, 19.9, 10.2, 20.25, 12, 20.25, 15.1, 20.25, 16.1, 18.3, 14.35, 14.6,
         11, 18.2, 9.9, 12.6, 10.35, 11, 9.4, 13.1, 8.75, 15.4, 8.75, 18],
    ])

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        for subpath in subpaths {
            let p = stride(from: 0, to: subpath.count, by: 2).map {
                CGPoint(x: rect.minX + subpath[$0] * scale, y: rect.minY + subpath[$0 + 1] * scale)
            }
            path.move(to: p[0])
            for i in stride(from: 1, to: p.count, by: 3) {
                path.addCurve(to: p[i + 2], control1: p[i], control2: p[i + 1])
            }
            path.closeSubpath()
        }
        return path
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
    let today: Date
    let colors: WidgetColors
    let isMedium: Bool

    private var iconColor: Color { doneToday ? colors.accent : colors.secondaryTextColor }

    @ViewBuilder
    private func icon(size: CGFloat) -> some View {
        if let ringScore {
            ConsistencyRing(score: ringScore, color: iconColor, colors: colors, size: size, lineWidth: size * 0.12)
        } else {
            // The glyph fills 18 of its 24-unit box; scale up to sit level with the ring.
            MeditoFlame(lit: doneToday, color: iconColor, size: size * 4 / 3)
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

                    ActivityGrid(allActivityDates: allActivityDates, colors: colors, today: today)
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
                    CalendarStrip(allActivityDates: allActivityDates, colors: colors, today: today)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .widgetBackground(color: colors.backgroundColor)
    }
}

extension View {
    /// A glyph on an accent disc: painted in `onAccent`, or punched out of the disc for the
    /// monochrome palette (the disc needs `.compositingGroup()` so only it is cut).
    @ViewBuilder
    func onAccentGlyph(_ colors: WidgetColors) -> some View {
        if colors.knockOutGlyphs {
            foregroundStyle(.black).blendMode(.destinationOut)
        } else {
            foregroundStyle(colors.onAccent)
        }
    }

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

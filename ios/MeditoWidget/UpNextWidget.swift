import SwiftUI
import WidgetKit

private let appGroupId = "group.org.medito.widget"

struct UpNextEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let packTitle: String
    let trackId: String
    let completed: Int
    let total: Int
    let themePreference: String

    static var placeholder: UpNextEntry {
        UpNextEntry(
            date: Date(),
            title: "Introduction to Mindfulness",
            subtitle: "Breath awareness",
            packTitle: "Basics",
            trackId: "",
            completed: 2,
            total: 10,
            themePreference: "system"
        )
    }
}

struct UpNextProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpNextEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        completion(context.isPreview ? .placeholder : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        let entry = load()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> UpNextEntry {
        let d = UserDefaults(suiteName: appGroupId)
        return UpNextEntry(
            date: Date(),
            title: d?.string(forKey: "up_next_title") ?? "",
            subtitle: d?.string(forKey: "up_next_subtitle") ?? "",
            packTitle: d?.string(forKey: "up_next_pack_title") ?? "",
            trackId: d?.string(forKey: "up_next_track_id") ?? "",
            completed: d?.integer(forKey: "up_next_completed") ?? 0,
            total: d?.integer(forKey: "up_next_total") ?? 0,
            themePreference: d?.string(forKey: "theme_preference") ?? "system"
        )
    }
}

// MARK: - Shared sub-views

/// The app's play button: accent disc, rounded play glyph in `onAccent` (cut out when monochrome).
private struct PlayCircleView: View {
    let colors: WidgetColors
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(colors.accent)
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.36, weight: .bold))
                .onAccentGlyph(colors)
                .offset(x: size * 0.035)
        }
        .compositingGroup()
        .frame(width: size, height: size)
    }
}

/// Matches the app's Home hero: "Start here" before anything in the pack is
/// played, "Continue" after.
private func upNextLabel(_ entry: UpNextEntry) -> String {
    entry.completed == 0 ? "START HERE" : "CONTINUE"
}

private let emptyTitle = "Choose what's next"

/// "CONTINUE · Pack" in the hero eyebrow's voice: small, semibold, tracked, muted. Hidden once
/// the pack is finished.
private struct UpNextEyebrow: View {
    let entry: UpNextEntry
    let colors: WidgetColors
    var showPack = true

    var body: some View {
        if entry.title.isEmpty {
            // Pack finished: a quiet tick where the eyebrow sits.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(colors.secondaryTextColor)
        } else {
            Text(showPack && !entry.packTitle.isEmpty
                 ? "\(upNextLabel(entry)) · \(entry.packTitle)"
                 : upNextLabel(entry))
                .font(.googleSans(12, .semibold))
                .tracking(1)
                .foregroundStyle(colors.secondaryTextColor)
                .lineLimit(1)
        }
    }
}

/// Thin rounded pack-progress bar, as under the Home hero title, with a "3/10" count when there's
/// room for it.
private struct UpNextProgress: View {
    let entry: UpNextEntry
    let colors: WidgetColors
    var showCount = true

    private var fraction: Double { min(1, Double(entry.completed) / Double(max(entry.total, 1))) }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.textColor.opacity(0.15))
                    Capsule()
                        .fill(colors.accent)
                        .frame(width: fraction > 0 ? max(geo.size.height, geo.size.width * fraction) : 0)
                }
            }
            .frame(height: 4)
            if showCount {
                Text("\(entry.completed)/\(entry.total)")
                    .font(.googleSans(12, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(colors.secondaryTextColor)
            }
        }
    }
}

private func hasProgress(_ entry: UpNextEntry) -> Bool { !entry.title.isEmpty && entry.total > 0 }

// MARK: - Small layout (.systemSmall)
// Eyebrow and play button along the top, title and progress along the bottom.

private struct UpNextSmallView: View {
    let entry: UpNextEntry
    let colors: WidgetColors
    private var displayTitle: String { entry.title.isEmpty ? emptyTitle : entry.title }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                UpNextEyebrow(entry: entry, colors: colors, showPack: false)
                    .padding(.top, 2)
                Spacer(minLength: 4)
                PlayCircleView(colors: colors, size: 40)
            }

            Spacer(minLength: 6)

            Text(displayTitle)
                .font(.googleSans(17, .bold))
                .foregroundStyle(colors.textColor)
                .lineLimit(3)
                .lineSpacing(-1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasProgress(entry) {
                UpNextProgress(entry: entry, colors: colors, showCount: false)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(color: colors.backgroundColor)
    }
}

// MARK: - Medium layout (.systemMedium)
// Same arrangement with room for the pack, subtitle and a "3/10" count — mirrors Android WIDE_TALL.

private struct UpNextMediumView: View {
    let entry: UpNextEntry
    let colors: WidgetColors
    private var displayTitle: String { entry.title.isEmpty ? emptyTitle : entry.title }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                UpNextEyebrow(entry: entry, colors: colors)
                    .padding(.top, 2)
                Spacer(minLength: 0)
                PlayCircleView(colors: colors, size: 44)
            }

            Spacer(minLength: 4)

            Text(displayTitle)
                .font(.googleSans(22, .bold))
                .foregroundStyle(colors.textColor)
                .lineLimit(2)
                .lineSpacing(-1)

            if !entry.subtitle.isEmpty {
                Text(entry.subtitle)
                    .font(.googleSans(14, .medium))
                    .foregroundStyle(colors.secondaryTextColor)
                    .lineLimit(1)
                    .padding(.top, 2)
            }

            if hasProgress(entry) {
                UpNextProgress(entry: entry, colors: colors)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(color: colors.backgroundColor)
    }
}

// MARK: - Widget

struct UpNextWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: UpNextEntry

    // Source params let DeepLinkService attribute the tap to the home-screen
    // widget for analytics. Empty-state tap still gets a deep link so the
    // open is attributable; no path segments → app just opens.
    private func deepLinkURL(standBy: Bool) -> URL? {
        let placement = standBy ? "standby" : "home_screen"
        if entry.trackId.isEmpty {
            return widgetTapURL("up_next", placement: placement)
        }
        return widgetTapURL("up_next", path: "tracks/\(entry.trackId)", placement: placement)
    }

    var body: some View {
        WidgetContextReader(themePreference: entry.themePreference) { colors, standBy in
            Group {
                switch family {
                case .systemSmall:
                    UpNextSmallView(entry: entry, colors: colors)
                default:
                    UpNextMediumView(entry: entry, colors: colors)
                }
            }
            .widgetURL(deepLinkURL(standBy: standBy))
        }
    }
}

struct UpNextWidget: Widget {
    let kind = "UpNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpNextProvider()) { entry in
            UpNextWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Continue")
        .description("Pick up your pack where you left off.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

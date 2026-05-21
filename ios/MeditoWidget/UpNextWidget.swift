import SwiftUI
import WidgetKit

private let appGroupId = "group.org.medito.widget"
private let purple = Color(hex: "917DF0")

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

private struct PlayCircleView: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(purple)
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

private struct UpNextLabel: View {
    let packTitle: String
    let labelColor: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("UP NEXT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(labelColor)
            if !packTitle.isEmpty {
                Text("·")
                    .font(.system(size: 9))
                    .foregroundStyle(labelColor)
                Text(packTitle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(purple)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Small layout (.systemSmall)
// Play circle centred with title below — uncluttered, mirrors Android TINY.

private struct UpNextSmallView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: UpNextEntry

    private var isDark: Bool {
        switch entry.themePreference {
        case "dark": return true
        case "light": return false
        default: return colorScheme == .dark
        }
    }

    private var colors: WidgetColors { isDark ? .dark : .light }
    private var labelColor: Color { colors.textColor.opacity(0.4) }

    var body: some View {
        VStack(spacing: 0) {
            // "UP NEXT" label pinned to top-left
            HStack {
                Text("UP NEXT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(labelColor)
                Spacer()
            }

            Spacer()

            // Play circle + title centred
            VStack(spacing: 8) {
                PlayCircleView(size: 44)
                if !entry.title.isEmpty {
                    Text(entry.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.textColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding(12)
        .widgetBackground(color: colors.backgroundColor)
    }
}

// MARK: - Medium layout (.systemMedium)
// Two columns: text block on left, play button on right — mirrors Android WIDE.

private struct UpNextMediumView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: UpNextEntry

    private var isDark: Bool {
        switch entry.themePreference {
        case "dark": return true
        case "light": return false
        default: return colorScheme == .dark
        }
    }

    private var colors: WidgetColors { isDark ? .dark : .light }
    private var labelColor: Color { colors.textColor.opacity(0.4) }
    private var displayTitle: String { entry.title.isEmpty ? "No session up next" : entry.title }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                UpNextLabel(packTitle: entry.packTitle, labelColor: labelColor)

                Text(displayTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(colors.textColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: false)

                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(colors.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PlayCircleView(size: 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
    private var deepLinkURL: URL? {
        if entry.trackId.isEmpty {
            return URL(string: "org.meditofoundation://medito/?source=home_widget&widget=up_next")
        }
        return URL(string: "org.meditofoundation://tracks/\(entry.trackId)?source=home_widget&widget=up_next")
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                UpNextSmallView(entry: entry)
            default:
                UpNextMediumView(entry: entry)
            }
        }
        .widgetURL(deepLinkURL)
    }
}

struct UpNextWidget: Widget {
    let kind = "UpNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpNextProvider()) { entry in
            UpNextWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("See your next meditation session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

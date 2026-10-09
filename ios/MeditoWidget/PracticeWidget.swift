import SwiftUI
import WidgetKit

// Lock Screen widget (iOS 16+). Shows the streak or the consistency score, whichever the user
// picked for the in-app streak chip, so the Lock Screen matches Home. No Up Next here: a pack
// or track title on a screen anyone can see could be sensitive.

struct PracticeEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct PracticeProvider: TimelineProvider {
    func placeholder(in context: Context) -> PracticeEntry {
        PracticeEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PracticeEntry) -> Void) {
        completion(PracticeEntry(date: Date(), data: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PracticeEntry>) -> Void) {
        let data = WidgetData.load()
        let now = Date()
        let entries = data.timelineDates(from: now).map { PracticeEntry(date: $0, data: data) }
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}

/// Lock Screen widgets are drawn in a single tint chosen by the system, so everything here is
/// `.primary` at varying opacity rather than the app palette.
@available(iOSApplicationExtension 16.0, *)
struct PracticeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PracticeEntry

    private var data: WidgetData { entry.data }
    private var today: Date { data.today(at: entry.date) }
    private var doneToday: Bool { data.allActivityDates.contains(today) }
    private var streak: Int { data.streak(at: entry.date) }
    private var score: Int { data.consistencyScore(at: entry.date) }
    private var unit: String { streak == 1 ? data.dayLabel : data.daysLabel }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            default: inline
            }
        }
        .widgetURL(widgetTapURL(
            data.showsStreak ? "lock_streak" : "lock_consistency",
            placement: "lock_screen"
        ))
        .accessoryWidgetBackground()
    }

    // MARK: Circular: flame over the streak, or the score as a capacity ring.

    @ViewBuilder
    private var circular: some View {
        if data.showsStreak {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    MeditoFlame(lit: doneToday, color: .primary, size: 18)
                        .widgetAccentable()
                    Text("\(streak)")
                        .font(.googleSans(20, .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, 6)
            }
        } else {
            Gauge(value: Double(min(max(score, 0), 100)), in: 0 ... 100) {
                EmptyView()
            } currentValueLabel: {
                Text("\(score)%")
                    .font(.googleSans(15, .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        }
    }

    // MARK: Rectangular: the figure, then the last seven days.

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Group {
                    if data.showsStreak {
                        MeditoFlame(lit: doneToday, color: .primary, size: 16)
                    } else {
                        AccessoryRing(score: score, size: 14)
                    }
                }
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                .widgetAccentable()

                Text(data.showsStreak ? "\(streak)" : "\(score)%")
                    .font(.googleSans(20, .bold))
                    .monospacedDigit()
                if data.showsStreak {
                    Text(unit)
                        .font(.googleSans(14, .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                // Nothing else on the Lock Screen says which app this is.
                Image("MeditoLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 9)
                    .foregroundStyle(.secondary)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            AccessoryWeek(allActivityDates: data.allActivityDates, today: today)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Inline: one line of text above the clock (system font and SF Symbols only).

    @ViewBuilder
    private var inline: some View {
        if data.showsStreak {
            Label("\(streak) \(unit)", systemImage: doneToday ? "flame.fill" : "flame")
        } else {
            Label("\(score)%", systemImage: doneToday ? "checkmark.circle.fill" : "circle.dashed")
        }
    }
}

/// The last seven logical days, oldest first: weekday letters over dots that are filled once
/// practised; today is ringed until it is.
@available(iOSApplicationExtension 16.0, *)
private struct AccessoryWeek: View {
    let allActivityDates: Set<Date>
    let today: Date
    var dotSize: CGFloat = 11

    private var days: [Date] {
        let cal = Calendar.current
        return (0 ..< 7).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(weekdayLetter(day))
                        .font(.googleSans(10, .semibold))
                        .foregroundStyle(.secondary)
                    dot(for: day).frame(width: dotSize, height: dotSize)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dot(for day: Date) -> some View {
        if allActivityDates.contains(day) {
            Circle().fill(.primary).widgetAccentable()
        } else if day == today {
            Circle().strokeBorder(.primary, lineWidth: 1.5)
        } else {
            Circle().fill(.primary.opacity(0.25))
        }
    }
}

/// The consistency ring in the Lock Screen's single tint.
@available(iOSApplicationExtension 16.0, *)
private struct AccessoryRing: View {
    let score: Int
    let size: CGFloat

    var body: some View {
        let lineWidth = size * 0.14
        ZStack {
            Circle().stroke(.primary.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
    }
}

private extension View {
    /// iOS 17 requires every widget to declare a container background; on the Lock Screen it's
    /// clear (the circular streak draws its own `AccessoryWidgetBackground`).
    @ViewBuilder
    func accessoryWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}

struct PracticeWidget: Widget {
    let kind = "PracticeWidget"

    private var families: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, *) {
            return [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        }
        return []
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PracticeProvider()) { entry in
            if #available(iOSApplicationExtension 16.0, *) {
                PracticeWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Practice")
        .description("Your streak or consistency score, whichever you show on Home in Medito.")
        .supportedFamilies(families)
    }
}

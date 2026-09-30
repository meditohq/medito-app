import SwiftUI

enum Route: Hashable {
    case player(WatchTrack)
    case favorites
    case downloads
}

struct ContentView: View {
    @ObservedObject private var store = WatchStore.shared
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            // A ScrollView rather than a List so the cover can run up under
            // the clock, full-bleed like the phone's Home hero.
            GeometryReader { geo in
                let topInset = geo.safeAreaInsets.top
                let shortcutCount = store.hasSynced ? (store.daily == nil ? 2 : 3) : 1
                let shortcutWidth = (geo.size.width - 8 - CGFloat(shortcutCount - 1) * 8) / CGFloat(shortcutCount)
                ScrollView {
                    VStack(spacing: 8) {
                        if let upNext = store.upNext {
                            NavigationLink(value: Route.player(upNext.track)) {
                                // Stat pill top right over the cover, like the phone hero.
                                UpNextCard(upNext: upNext, stat: stat?.onImage(), topInset: topInset)
                            }
                            .buttonStyle(.plain)
                            .disabled(!upNext.canPlay)
                        } else {
                            Color.clear.frame(height: topInset)
                            if let stat {
                                stat
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }
                        }

                        if !store.hasSynced {
                            EmptyStateRow()
                        }
                        // Icon tiles, like the phone's Home shortcuts.
                        HStack(spacing: 8) {
                            if store.hasSynced {
                                if let daily = store.daily {
                                    ShortcutTile(title: "Daily", image: Image("Sun")) {
                                        path.append(.player(daily))
                                    }
                                    .frame(width: shortcutWidth)
                                }
                                ShortcutTile(title: "Favorites", image: Image("Star")) {
                                    path.append(.favorites)
                                }
                                .frame(width: shortcutWidth)
                            }
                            ShortcutTile(title: "Downloads", image: Image(systemName: "arrow.down.circle")) {
                                path.append(.downloads)
                            }
                            .frame(width: shortcutWidth)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.bottom, 8)
                }
                .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .player(let track): PlayerScreen(track: track)
                case .favorites: FavoritesScreen()
                case .downloads: WatchDownloadsScreen()
                }
            }
        }
        .tint(.white)
        .onChange(of: store.hasSynced) { synced in
            // Signed out on the phone: leave whatever that account had open.
            if !synced { path.removeAll() }
        }
    }

    /// Consistency score, unless the phone's Home would show the streak.
    private var stat: StatPill? {
        if store.showStreak {
            guard store.streak > 0 else { return nil }
            return StatPill(kind: .streak(store.streak))
        }
        guard let consistency = store.consistency else { return nil }
        return StatPill(kind: .consistency(consistency))
    }
}

/// The phone Home's stat pill: a ring filled to the consistency score and
/// "85%", or a flame and the streak length.
private struct StatPill: View {
    enum Kind { case consistency(Int), streak(Int) }
    let kind: Kind
    var isOnImage = false

    /// Smaller, on a dark backing so it reads over cover art.
    func onImage() -> StatPill { StatPill(kind: kind, isOnImage: true) }

    var body: some View {
        HStack(spacing: 6) {
            switch kind {
            case .consistency(let percent):
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: Double(percent) / 100)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: isOnImage ? 12 : 14, height: isOnImage ? 12 : 14)
                Text("\(percent)%")
            case .streak(let days):
                // The phone's own flame (assets/images/fire-flame.svg).
                Image("Flame")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isOnImage ? 14 : 16, height: isOnImage ? 14 : 16)
                Text("\(days)")
            }
        }
        .font(.system(size: isOnImage ? 13 : 15, weight: .semibold).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, isOnImage ? 9 : 12)
        .padding(.vertical, isOnImage ? 5 : 7)
        .background(Capsule().fill(isOnImage ? .black.opacity(0.55) : .white.opacity(0.14)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch kind {
        case .consistency(let percent): return "Consistency score: \(percent)%"
        case .streak(let days): return "\(days) day streak"
        }
    }
}

/// A phone Home shortcut: the app's own icon (assets/images, same set as the
/// phone) on a tile, label below.
private struct ShortcutTile: View {
    let title: String
    let image: Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity)
            }
        }
        // Each shortcut has its own full tile tap target.
        .buttonStyle(.plain)
    }
}

/// The phone's Home hero in miniature: pack cover full-bleed, a dark fade,
/// "CONTINUE · Pack" eyebrow, title, progress bar and a white play button.
private struct UpNextCard: View {
    let upNext: UpNext
    var stat: StatPill?
    /// Height of the clock area the cover runs up under.
    var topInset: CGFloat = 0

    var body: some View {
        // The cover is layered on a fixed-size base (not a ZStack child), so
        // its fill-scaling can't grow the card and push the text off it.
        Color.clear
            .frame(height: 124 + topInset)
            .overlay { CoverImage(url: upNext.coverUrl) }
            .overlay {
                // Dark enough under the eyebrow to read on busy cover art.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0.1),
                        .init(color: .black.opacity(0.6), location: 0.5),
                        .init(color: .black.opacity(0.9), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                // A light shade at the top so the clock reads over bright art.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.45), location: 0),
                        .init(color: .black.opacity(0), location: 0.3),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) { content }
            // Just below the clock, which sits top right.
            .overlay(alignment: .topTrailing) {
                stat?.padding(.top, topInset + 2).padding(.trailing, 8)
            }
            // Square edges, like the phone's full-bleed hero.
            .clipped()
            .accessibilityElement(children: .combine)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            ScrollingTitle(eyebrow)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.85))

            HStack(alignment: .center, spacing: 8) {
                ScrollingTitle(upNext.track.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white))
            }

            if upNext.total > 0 {
                HStack(spacing: 6) {
                    ProgressBar(value: Double(upNext.completed) / Double(upNext.total))
                    // Same as the phone hero: sessions completed.
                    Text("\(upNext.completed) of \(upNext.total)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    /// Same rule as the phone hero: "Start here" until something is played.
    private var eyebrow: String {
        let label = upNext.completed == 0 ? "START HERE" : "CONTINUE"
        return upNext.packTitle.isEmpty ? label : "\(label) · \(upNext.packTitle)"
    }
}

private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3))
                Capsule().fill(.white).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 3)
    }
}

private struct EmptyStateRow: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open Medito on your iPhone to get started.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
}

struct WatchDownloadsScreen: View {
    @ObservedObject private var store = WatchStore.shared

    var body: some View {
        List {
            if store.downloads.isEmpty {
                Text("Send sessions from Downloads in the Medito iPhone app to listen offline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.downloads, id: \.fileId) { track in
                NavigationLink(value: Route.player(track)) {
                    VStack(alignment: .leading) {
                        Text(track.title)
                        Text("\(track.guide) · \(track.minutes) min · Offline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Remove", role: .destructive) { store.removeDownload(track) }
                }
            }
        }
        .navigationTitle("Downloads")
    }
}

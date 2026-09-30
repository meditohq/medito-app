import SwiftUI

/// Favourites from the phone, filtered to tracks or packs. A pack plays its
/// next unfinished session (resolved on the phone, like Continue).
struct FavoritesScreen: View {
    private enum Filter { case tracks, packs }

    @ObservedObject private var store = WatchStore.shared
    @State private var filter: Filter?

    var body: some View {
        List {
            HStack(spacing: 6) {
                FilterChip(title: "Packs", isSelected: current == .packs) { filter = .packs }
                FilterChip(title: "Tracks", isSelected: current == .tracks) { filter = .tracks }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if items.isEmpty {
                Text(current == .tracks
                     ? "Favorite a track on your iPhone to see it here."
                     : "Favorite a pack on your iPhone to see it here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items, id: \.rowKey) { track in
                    NavigationLink(value: Route.player(track)) {
                        FavoriteRow(track: track)
                    }
                }
            }
        }
        .navigationTitle("Favorites")
    }

    /// Opens on packs (the first filter), unless there are only favourite tracks.
    private var current: Filter {
        if let filter { return filter }
        let hasTracks = store.favorites.contains { $0.packTitle.isEmpty }
        let hasPacks = store.favorites.contains { !$0.packTitle.isEmpty }
        return !hasPacks && hasTracks ? .tracks : .packs
    }

    private var items: [WatchTrack] {
        store.favorites.filter { current == .packs ? !$0.packTitle.isEmpty : $0.packTitle.isEmpty }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? Color.black : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.14))
                )
        }
        // Plain, so both chips in the one list row are tappable separately.
        .buttonStyle(.plain)
    }
}

private struct FavoriteRow: View {
    let track: WatchTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // A pack shows its name; the line below is the session it plays.
            ScrollingTitle(track.packTitle.isEmpty ? track.title : track.packTitle)
            ScrollingTitle(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        track.packTitle.isEmpty
            ? "\(track.minutes) min"
            : "\(track.title) · \(track.minutes) min"
    }
}

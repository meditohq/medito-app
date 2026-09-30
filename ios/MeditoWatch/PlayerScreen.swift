import SwiftUI

struct PlayerScreen: View {
    @StateObject private var player: WatchPlayer
    @Environment(\.dismiss) private var dismiss
    private let track: WatchTrack

    init(track: WatchTrack) {
        self.track = track
        _player = StateObject(wrappedValue: WatchPlayer(track: track))
    }

    var body: some View {
        VStack(spacing: 6) {
            ScrollingTitle(track.title, alignment: .center)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: player.progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: player.progress)
                centre
            }
            .padding(.horizontal, 18)

            Text(caption)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .focusable()
        .digitalCrownRotation($player.volume, from: 0, through: 1, sensitivity: .low)
        .task { await player.start() }
        .onDisappear { player.stop() }
    }

    @ViewBuilder private var centre: some View {
        switch player.phase {
        case .idle, .connecting:
            ProgressView()
        case .playing, .paused:
            Button(action: player.togglePlayPause) {
                Image(systemName: player.phase == .playing ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            .buttonStyle(.plain)
            .frame(width: 64, height: 64)
            .contentShape(Circle())
        case .finished:
            Button { dismiss() } label: {
                Image(systemName: "checkmark")
                    .font(.title.weight(.semibold))
            }
            .buttonStyle(.plain)
        case .failed:
            Image(systemName: "headphones")
                .font(.title2)
        }
    }

    private var caption: String {
        switch player.phase {
        case .finished: return "Well done"
        case .failed(let message): return message
        case .idle, .connecting: return "\(track.minutes) min"
        case .playing, .paused: return "-" + format(player.remaining)
        }
    }

    private func format(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}


/// Keeps short titles still and reveals long titles without shrinking the font.
struct ScrollingTitle: View {
    let text: String
    var alignment: Alignment = .leading
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    init(_ text: String, alignment: Alignment = .leading) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        // The hidden label supplies the font's height without expanding the row.
        Text(text)
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geometry in
                    let distance = max(0, textWidth - geometry.size.width)
                    Text(text)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                        .background {
                            GeometryReader { label in
                                Color.clear.preference(key: TitleWidthKey.self, value: label.size.width)
                            }
                        }
                        .offset(x: offset)
                        .frame(width: geometry.size.width, height: geometry.size.height,
                               alignment: distance > 0 ? .leading : alignment)
                        .task(id: ScrollConfiguration(text: text, distance: distance,
                                                     enabled: !reduceMotion && scenePhase == .active)) {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) { offset = 0 }
                            guard distance > 0, !reduceMotion, scenePhase == .active else { return }
                            let duration = Double(distance / 24)
                            do {
                                while !Task.isCancelled {
                                    try await Task.sleep(for: .seconds(1.5))
                                    withAnimation(.linear(duration: duration)) { offset = -distance }
                                    try await Task.sleep(for: .seconds(duration + 1.5))
                                    withAnimation(.linear(duration: duration)) { offset = 0 }
                                    try await Task.sleep(for: .seconds(duration))
                                }
                            } catch { /* Leaving the screen cancels scrolling. */ }
                        }
                }
                .clipped()
            }
            .onPreferenceChange(TitleWidthKey.self) { textWidth = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}

private struct ScrollConfiguration: Equatable {
    let text: String
    let distance: CGFloat
    let enabled: Bool
}

private struct TitleWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

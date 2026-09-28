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
            Text(track.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
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

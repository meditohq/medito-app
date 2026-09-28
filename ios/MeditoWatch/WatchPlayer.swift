import AVFoundation
import MediaPlayer
import WatchKit

/// Streams one session on the watch itself. watchOS only routes long-form
/// audio to Bluetooth headphones, so activating the session shows the system
/// route picker when none are connected.
@MainActor
final class WatchPlayer: ObservableObject {
    enum Phase: Equatable { case idle, connecting, playing, paused, finished, failed(String) }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var volume: Double = 1 { didSet { player?.volume = Float(volume) } }

    private let track: WatchTrack
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(track: WatchTrack) {
        self.track = track
        self.duration = Double(track.durationMs) / 1000
    }

    var progress: Double { duration > 0 ? min(elapsed / duration, 1) : 0 }
    var remaining: Double { max(duration - elapsed, 0) }

    func start() async {
        guard phase == .idle, let url = URL(string: track.audioUrl) else { return }
        phase = .connecting

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
            guard try await session.activate() else {
                phase = .failed("Connect headphones to listen")
                return
            }
        } catch {
            phase = .failed("Connect headphones to listen")
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = Float(volume)
        self.player = player

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.elapsed = time.seconds
                if let d = player.currentItem?.duration.seconds, d.isFinite, d > 0 {
                    self.duration = d
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }

        setUpRemoteCommands()
        player.play()
        phase = .playing
        updateNowPlaying()
    }

    func togglePlayPause() {
        guard let player else { return }
        switch phase {
        case .playing:
            player.pause()
            phase = .paused
        case .paused:
            player.play()
            phase = .playing
        default:
            return
        }
        updateNowPlaying()
    }


    func stop() {
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player = nil
        MPRemoteCommandCenter.shared().playCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().pauseCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func finish() {
        elapsed = duration
        phase = .finished
        WKInterfaceDevice.current().play(.success)
        WatchStore.shared.reportCompleted(track)
        stop()
    }

    private func setUpRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { if self?.phase == .paused { self?.togglePlayPause() } }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { if self?.phase == .playing { self?.togglePlayPause() } }
            return .success
        }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.guide,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: phase == .playing ? 1.0 : 0.0,
        ]
    }
}

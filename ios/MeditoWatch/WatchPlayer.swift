import AVFoundation
import MediaPlayer
import WatchKit

/// Streams one session on the watch itself.
///
/// Headphones first: long-form audio keeps playing with the wrist down, but
/// watchOS only routes it to Bluetooth (and, on Series 10 / Ultra 2 with
/// watchOS 11+, to the speaker if the user picked it). When that gets no
/// route, the player offers the watch speaker instead, kept alive with the
/// screen off by a mindfulness extended runtime session (up to an hour).
@MainActor
final class WatchPlayer: ObservableObject {
    enum Phase: Equatable {
        case idle, connecting, needsOutput, playing, paused, finished, failed(String)
    }

    /// A mindfulness session ends after an hour; leave room for loading and
    /// pauses. Longer sessions (mostly sleep) still need headphones.
    static let speakerMaxMs = 55 * 60 * 1000

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var volume: Double = 1 { didSet { player?.volume = Float(volume) } }

    private let track: WatchTrack
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var keepAlive: MindfulnessKeepAlive?

    init(track: WatchTrack) {
        self.track = track
        self.duration = Double(track.durationMs) / 1000
    }

    var progress: Double { duration > 0 ? min(elapsed / duration, 1) : 0 }
    var remaining: Double { max(duration - elapsed, 0) }

    func start() async {
        guard phase == .idle,
              let url = WatchStore.shared.localURL(track) ?? URL(string: track.audioUrl)
        else { return }
        phase = .connecting

        let session = AVAudioSession.sharedInstance()
        var activated = false
        do {
            try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
            activated = try await session.activate()
        } catch {
            activated = false
        }
        #if DEBUG
        // The simulator always has a route; launch with this to test the
        // no-headphones path.
        if ProcessInfo.processInfo.arguments.contains("-forceNoAudioRoute") {
            activated = false
        }
        #endif
        guard activated else {
            let speakerAllowed = track.durationMs <= Self.speakerMaxMs
            WatchStore.shared.reportAudio(
                speakerAllowed ? "no_route" : "no_route_too_long", track: track
            )
            phase = speakerAllowed ? .needsOutput : .failed("Connect headphones to listen")
            return
        }
        WatchStore.shared.reportAudio("long_form", track: track)
        play(url)
    }

    /// No headphones: play through the watch speaker. The mindfulness session
    /// is what keeps the app (and so the audio) running once the wrist drops.
    func playOnWatch() {
        guard phase == .needsOutput,
              let url = WatchStore.shared.localURL(track) ?? URL(string: track.audioUrl)
        else { return }
        phase = .connecting

        let keepAlive = MindfulnessKeepAlive { [weak self] reason in
            // e.g. Low Power Mode: playback continues while the screen is on.
            guard let self else { return }
            WatchStore.shared.reportAudio(
                "mindfulness_ended", track: self.track, detail: reason
            )
        }
        keepAlive.start()
        self.keepAlive = keepAlive

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, policy: .default)
            try session.setActive(true)
        } catch {
            WatchStore.shared.reportAudio(
                "speaker_failed", track: track, detail: error.localizedDescription
            )
            keepAlive.stop()
            self.keepAlive = nil
            phase = .failed("Couldn't play on this watch")
            return
        }
        WatchStore.shared.reportAudio("speaker", track: track)
        play(url)
    }

    private func play(_ url: URL) {
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
        keepAlive?.stop()
        keepAlive = nil
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

/// Holds a mindfulness `WKExtendedRuntimeSession` for speaker playback.
/// Needs `mindfulness` in the watch app's WKBackgroundModes.
private final class MindfulnessKeepAlive: NSObject, WKExtendedRuntimeSessionDelegate {
    private let session = WKExtendedRuntimeSession()
    private let onEnded: (String) -> Void
    private var stopping = false

    init(onEnded: @escaping (String) -> Void) {
        self.onEnded = onEnded
        super.init()
        session.delegate = self
    }

    func start() { session.start() }

    func stop() {
        stopping = true
        if session.state == .running || session.state == .scheduled {
            session.invalidate()
        }
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        guard !stopping else { return }
        let detail = error.map { "\(reason.rawValue): \($0.localizedDescription)" }
            ?? "\(reason.rawValue)"
        DispatchQueue.main.async { self.onEnded(detail) }
    }
}

import Foundation
import AVFoundation
import Flutter

public class AudioService: MeditoAudioServiceApi {
    lazy var flutterEngine: FlutterEngine? = {
        var flutterEngine: FlutterEngine? = FlutterEngine(
            name: "medito_flutter_engine",
            project: nil,
            allowHeadlessExecution: true
        )
        
        flutterEngine?.run()
        return flutterEngine
    }()
    
    private var backgroundMusicVolume: Float?
    private var backgroundSoundURI: String?
    private var audioTrack: Track?
    private let notificationCenter = NotificationCenter.default
    private var primaryPlayer: AVPlayer?
    private var backgroundPlayer: AVPlayer?
    private var isPrimaryPlayerPlaying: Bool { primaryPlayer?.rate != 0 && primaryPlayer?.error == nil }
    private var isBackgroundPlayerPlaying: Bool { backgroundPlayer?.rate != 0 && backgroundPlayer?.error == nil }
    private var currentPositionInSeconds: Int64 { Int64(primaryPlayer?.currentTime().seconds ?? -1) }
    private var currentDurationInSeconds: Double { primaryPlayer?.currentItem?.duration.seconds ?? -1 }
    
    private var playbackStateTimer: Timer?
    
    lazy var audioServiceCallback: MeditoAudioServiceCallbackApi? = {
        guard let binaryMessenger = flutterEngine?.binaryMessenger
         else {
            print("FlutterEngine is not running.")
            return nil
        }
     
         return MeditoAudioServiceCallbackApi(binaryMessenger: binaryMessenger)
    }()
    
    private var trackDuration: Int64 {
        if let duration = primaryPlayer?.currentItem?.duration {
            let durationSeconds = CMTimeGetSeconds(duration) * 1000 //TODO: check unit (Flutter uses Int in miliseconds)
            if durationSeconds.isFinite {
                return Int64(durationSeconds)
            } else {
                print("Duration is infinite or NaN")
            }
        }
        
        return -1
    }
    
    private var currentVolume: Int64 {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(true)
            let outputVolume = audioSession.outputVolume
            return Int64(outputVolume * 100)
            
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
        
        return -1
    }
    
    public init() {}
    
    deinit {
        invalidatePlaybackStateTimer()
        invalidatePlayer(&primaryPlayer)
        invalidatePlayer(&backgroundPlayer)
        stopObservingPlayers()
    }
    
    private func invalidatePlayer(_ player: inout AVPlayer?) {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
    
    private func startObservingPrimaryPlayer() {
        guard let player = primaryPlayer else {
            print("Trying to observe a player that wasn't initialized yet.")
            return
        }

        notificationCenter.addObserver(
            self,
            selector: #selector(primaryPlayerDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    private func startObservingBackgroundPlayer() {
        guard let player = backgroundPlayer else {
            print("Trying to observe a player that wasn't initialized yet.")
            return
        }
        
        notificationCenter.addObserver(
            self,
            selector: #selector(backgroundPlayerDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    private func stopObservingPlayers() {
        notificationCenter.removeObserver(self)
    }
    
    func playAudio(audioData: AudioData) throws -> Bool {
        self.audioTrack = audioData.track
        
        guard let url = URL(string: audioData.url) else {
            print("audioData.url is invalid")
            return false
        }
        
        primaryPlayer = AVPlayer(url: url)
        startObservingPrimaryPlayer()
        primaryPlayer?.play()
        
        startPlaybackStateTimer()
        
        guard let callback = audioServiceCallback else {
            print("yo FlutterEngine is not running.")
            return true
        }
        
        updatePlaybackState()
        
        return true
    }

    func playPauseAudio() throws {
        guard let player = primaryPlayer else { return }
        
        if isPrimaryPlayerPlaying {
            player.pause()
            updatePlaybackState()
        } else {
            player.play()
            updatePlaybackState()
        }
    }
    
    func stopAudio() throws {
        primaryPlayer?.pause()
        
        updatePlaybackState()
    }
    
    func setSpeed(speed: Double) throws {
        guard let player = primaryPlayer else { return }
        player.rate = Float(speed)
        
        updatePlaybackState(speed: speed)
    }
    
    func seekToPosition(position: Int64) throws {
        guard let player = primaryPlayer else { return }

        updatePlaybackState(position: position)
    }
    
    func skip10SecondsForward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentTime = player.currentTime()
        let targetTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: targetTime)
        
        updatePlaybackState(position: Int64(targetTime.seconds))
    }
    
    func skip10SecondsBackward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentTime = player.currentTime()
        let targetTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: targetTime)
        
        updatePlaybackState(position: Int64(targetTime.seconds))
    }
    
    func setBackgroundSound(uri: String?) throws {
        guard let uri = uri, let url = URL(string: uri) else {
            throw AudioServiceError.invalidURI
        }
        
        let backgroundPlayerItem = AVPlayerItem(url: url)
        backgroundPlayer = AVPlayer(playerItem: backgroundPlayerItem)
        backgroundPlayer?.play()
        
        startObservingBackgroundPlayer()
    }
    
    func setBackgroundSoundVolume(volume: Double) throws {
        guard let player = backgroundPlayer else {
            throw AudioServiceError.backgroundSoundNotSet
        }
        
        player.volume = Float(volume)
    }
    
    func stopBackgroundSound() throws {
        guard let player = backgroundPlayer else {
            throw AudioServiceError.backgroundSoundNotSet
        }
        
        player.pause()
        backgroundPlayer = nil
    }
    
    func playBackgroundSound() throws {
        guard let player = backgroundPlayer else {
            throw AudioServiceError.backgroundSoundNotSet
        }
        
        player.play()
    }
    
    
    @objc
    func primaryPlayerDidFinishPlaying(_ notification: Notification) {
        updatePlaybackState(isCompleted: true)
    }
    
    @objc
    func backgroundPlayerDidFinishPlaying(_ notification: Notification) {
        updatePlaybackState(isCompleted: true)
    }
}

// MARK: Playback State

extension AudioService {
    @objc 
    private func updatePlaybackState(
        isCompleted: Bool = false,
        position: Int64 = -1,
        speed: Double = 1
    ) {
        guard let track = audioTrack else {
            preconditionFailure("The audio track should exist by now, nil found instead.")
        }
        
//        let position = position == -1 ? currentPositionInSeconds : 0
        
        audioServiceCallback?.updatePlaybackState(state: PlaybackState(
            isPlaying: isPrimaryPlayerPlaying,
            isBuffering: false,
            isSeeking: false,
            isCompleted: isCompleted,
            position: 3000,
            duration: trackDuration,
            speed: Speed(speed: speed),
            volume: currentVolume,
            track: track,
            backgroundSound: nil
        )) { result in
            print("******************")
            print(result)
            print("isPlaying: \(self.isPrimaryPlayerPlaying)")
            print("isCompleted: \(isCompleted)")
            print("position: \(position)")
            print("duration: \(self.trackDuration)")
            print("speed: \(speed)")
            print("volume: \(self.currentVolume)")
            print("track: \(track)")
            print("******************")
        }
    }
    
    private func startPlaybackStateTimer() {
        playbackStateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updatePlaybackState), userInfo: nil, repeats: true)
    }
    
    private func invalidatePlaybackStateTimer() {
        playbackStateTimer?.invalidate()
        playbackStateTimer = nil
    }
}

import Foundation
import AVFoundation
import Flutter

public class AudioService: MeditoAudioServiceApi {
    lazy var flutterEngine: FlutterEngine? = {
        var flutterEngine: FlutterEngine? = FlutterEngine(
            name: "medito_flutter_engine", //TODO: this goes as an ENGINE_ID param
            project: nil,
            allowHeadlessExecution: true
        )
        
        flutterEngine?.run()
        return flutterEngine
    }()
    
//    private var notification: Notification TODO: add this logic
    private var backgroundMusicVolume: Float?
    private var backgroundSoundURI: String?
    
    private var audioData: AudioData?
    private var audioTrack: Track? { audioData?.track }
    private var audioURL: URL? {
        guard let urlString = audioData?.url else { return nil }
        
        return URL(string: urlString)
    }
    
    private lazy var primaryPlayer: AVPlayer? = {
        guard let url = audioURL else {
            print("audioData.url is invalid")
            return AVPlayer()
        }
        
        return AVPlayer(url: url)
    }()
    
    private lazy var backgroundPlayer: AVPlayer? = {
        guard let url = audioURL else {
            print("audioData.url is invalid")
            return nil
        }
        
        return AVPlayer(url: url)
    }()
    
    private var isPrimaryPlayerPlaying: Bool { primaryPlayer?.rate != 0 && primaryPlayer?.error == nil }
    private var isBackgroundPlayerPlaying: Bool { backgroundPlayer?.rate != 0 && backgroundPlayer?.error == nil }
    
    private var timer: Timer?
    
    lazy var audioServiceCallback: MeditoAudioServiceCallbackApi? = {
        guard let binaryMessenger = flutterEngine?.binaryMessenger
         else {
            print("FlutterEngine is not running.")
            return nil
        }
     
         return MeditoAudioServiceCallbackApi(binaryMessenger: binaryMessenger)
    }()
    
    public init() {}
    
    deinit {
        timer?.invalidate()
        timer = nil
        invalidatePlayer(&primaryPlayer)
        invalidatePlayer(&backgroundPlayer)
    }
    
    private func invalidatePlayer(_ player: inout AVPlayer?) {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
    
    func playAudio(audioData: AudioData) throws -> Bool {
        self.audioData = audioData
        
        primaryPlayer?.play()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updatePlaybackState), userInfo: nil, repeats: true)
        
        guard let callback = audioServiceCallback else {
            print("FlutterEngine is not running.")
            return true
        }
        
        self.updatePlaybackState()
        
        return true
    }

    func playPauseAudio() throws {
        guard let player = primaryPlayer else { return }
        
        if isPrimaryPlayerPlaying {
            player.pause()
            self.updatePlaybackState()
        } else {
            player.play()
            self.updatePlaybackState()
        }
    }
    
    func stopAudio() throws {
        primaryPlayer?.pause()
        
        self.updatePlaybackState()
    }
    
    func setSpeed(speed: Double) throws {
        guard let player = primaryPlayer else { return }
        player.rate = Float(speed)
        
        self.updatePlaybackState(speed: speed)
    }
    
    func seekToPosition(position: Int64) throws {
        guard let player = primaryPlayer else { return }
        
        let time = CMTime(seconds: Double(position) / 1000, preferredTimescale: 1)
        player.seek(to: time)
        
        self.updatePlaybackState(position: position)
    }
    
    func skip10SecondsForward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentTime = player.currentTime()
        let targetTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: targetTime)
        
        self.updatePlaybackState(position: Int64(targetTime.seconds))
    }
    
    func skip10SecondsBackward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentTime = player.currentTime()
        let targetTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: targetTime)
        
        self.updatePlaybackState(position: Int64(targetTime.seconds))
    }
    
    func setBackgroundSound(uri: String?) throws {
        guard let uri = uri, let url = URL(string: uri) else {
            throw AudioServiceError.invalidURI
        }
        
        let backgroundPlayerItem = AVPlayerItem(url: url)
        let backgroundPlayer = AVPlayer(playerItem: backgroundPlayerItem)
        backgroundPlayer.play()
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
}

// MARK: Playback State

extension AudioService {
    @objc 
    private func updatePlaybackState(
        isBuffering: Bool = false,
        isSeeking: Bool = false,
        isCompleted: Bool = false,
        position: Int64 = 0,
        duration: Int64 = 0,
        speed: Double = 1,
        volume: Int64 = 100 //TODO: current vol?
    ) {
        guard let track = audioTrack else {
            preconditionFailure("The audio track should exist by now, nil found instead.")
        }
        
        audioServiceCallback?.updatePlaybackState(state: PlaybackState(
            isPlaying: isPrimaryPlayerPlaying,
            isBuffering: isBuffering,
            isSeeking: isSeeking,
            isCompleted: isCompleted,
            position: position,
            duration: duration,
            speed: Speed(speed: speed),
            volume: volume,
            track: track,
            backgroundSound: nil
        )) { result in
            print(result)
        }
    }
}

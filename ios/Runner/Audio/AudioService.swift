import Foundation
import AVFoundation
import Flutter

public class AudioService: MeditoAudioServiceApi {
    var player: AVPlayer?
    var backgroundPlayer: AVPlayer?
    var isPlaying = false
    var track: Track?
    
    lazy var flutterEngine: FlutterEngine? = {
        var flutterEngine: FlutterEngine? = FlutterEngine(
            name: "medito_flutter_engine", //TODO: this goes as an ENGINE_ID param
            project: nil,
            allowHeadlessExecution: true
        )
        
        flutterEngine?.run()
        return flutterEngine
    }()
    
    lazy var audioServiceCallback: MeditoAudioServiceCallbackApi? = {
        guard let binaryMessenger = flutterEngine?.binaryMessenger
         else {
            print("FlutterEngine is not running.")
            return nil
        }
     
         return MeditoAudioServiceCallbackApi(binaryMessenger: binaryMessenger)
    }()
    
    func playAudio(audioData: AudioData) throws -> Bool {
        track = audioData.track
    
        guard let url = URL(string: audioData.url) else {
            preconditionFailure("audioData.url invalid")
        }
        
        // Initialize and play audio
        player = AVPlayer(url: url)
        player?.play()
        isPlaying = true
        
        guard let callback = audioServiceCallback else {
            print("FlutterEngine is not running.")
            return true
        }
        
        self.updatePlaybackState(track: track, isPlaying: true)
        
        return true
    }
    
    private func updatePlaybackState(
        track: Track?,
        isPlaying: Bool = false,
        isBuffering: Bool = false,
        isSeeking: Bool = false,
        isCompleted: Bool = false,
        position: Int64 = 0,
        duration: Int64 = 0,
        speed: Speed = Speed(speed: 1),
        volume: Int64 = 10, //TODO: current vol?
        backgroundSound: BackgroundSound? = nil
    ) {
        guard let track = track else {
            preconditionFailure("Track is missing")
        }
        
        audioServiceCallback?.updatePlaybackState(state: PlaybackState(
            isPlaying: isPlaying,
            isBuffering: isBuffering,
            isSeeking: isSeeking,
            isCompleted: isCompleted,
            position: position,
            duration: duration,
            speed: speed,
            volume: volume,
            track: track,
            backgroundSound: backgroundSound
        )) { result in
            print(result) //TODO: ?
        }
    }
    
    func playPauseAudio() throws {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            self.updatePlaybackState(track: track, isPlaying: false)
        } else {
            player.play()
            self.updatePlaybackState(track: track, isPlaying: true)
        }
        isPlaying.toggle()
    }
    
    func stopAudio() throws {
        player?.pause()
        player = nil
        isPlaying = false
        
        self.updatePlaybackState(track: track, isPlaying: false)
    }
    
    func setSpeed(speed: Double) throws {
        guard let player = player else { return }
        player.rate = Float(speed)
        
        self.updatePlaybackState(track: track, speed: Speed(speed: speed))
    }
    
    func seekToPosition(position: Int64) throws {
        guard let player = player else { return }
        let time = CMTime(seconds: Double(position) / 1000, preferredTimescale: 1)
        player.seek(to: time)
        
        self.updatePlaybackState(track: track, position: position)
    }
    
    func skip10SecondsForward() throws {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let targetTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: targetTime)
        
        self.updatePlaybackState(track: track, position: Int64(targetTime.seconds))
    }
    
    func skip10SecondsBackward() throws {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let targetTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: targetTime)
        
        self.updatePlaybackState(track: track, position: Int64(targetTime.seconds))
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

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
    
    private let notificationCenter = NotificationCenter.default
    private var playbackStateTimer: Timer?
    
    //Primary track
    private var primaryPlayer: AVPlayer?
    private var audioTrack: Track?
    private var isPrimaryPlayerPlaying: Bool { primaryPlayer?.rate != 0 && primaryPlayer?.error == nil }
    private var audioTrackDuration: Int64 { convertCMTimeIntoInt64(primaryPlayer?.currentItem?.duration) }
    
    //Background Sound
    private var backgroundPlayer: AVPlayer?
    private var backgroundSoundURI: String?
    private var isBackgroundPlayerPlaying: Bool { backgroundPlayer?.rate != 0 && backgroundPlayer?.error == nil }
    
    lazy var audioServiceCallback: MeditoAudioServiceCallbackApi? = {
        guard let binaryMessenger = flutterEngine?.binaryMessenger
         else {
            print("FlutterEngine is not running.")
            return nil
        }
     
         return MeditoAudioServiceCallbackApi(binaryMessenger: binaryMessenger)
    }()
    
    private var deviceVolume: Int64 {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(true)
            let outputVolume = audioSession.outputVolume
            let result = Int64(outputVolume * 100)
            return result
            
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
        updatePlaybackState()
        
        print("DEBUG: playAudio \(audioData)")
        
        return true
    }

    func playPauseAudio() {
        guard let player = primaryPlayer else { return }
        
        if isPrimaryPlayerPlaying {
            player.pause()
            updatePlaybackState()
            print("DEBUG: PAUSE")
        } else {
            player.play()
            updatePlaybackState()
            print("DEBUG: PLAY")
        }
    }
    
    func stopAudio() throws {
        primaryPlayer?.pause()
        backgroundPlayer?.pause()
        
        print("DEBUG: stopAudio")
        updatePlaybackState()
        invalidatePlaybackStateTimer()
    }
    
    func setSpeed(speed: Double) throws {
        print("DEBUG: setSpeed \(speed)")
        guard let player = primaryPlayer else { return }
        player.rate = Float(speed) //TODO: check this speed is in the correct format
        updatePlaybackState()
    }
    
    //Position comes in percentage seems like //TODO: check unit
    func seekToPosition(position: Int64) throws {
        print("DEBUG: seekToPosition \(position)") //TODO: finish this
        guard let player = primaryPlayer else { return }
        
        let targetPositionInMilis = ( position * audioTrackDuration / 100 )
        let targetPositionInSec = Double(targetPositionInMilis / 1000)
        
        let targetPosition = CMTime(seconds: targetPositionInSec, preferredTimescale: 1)
        player.seek(to: targetPosition)
        
        print("DEBUG: seekToPosition target position in sec: \(targetPosition)")
        print("DEBUG: seekToPosition target position in milis: \(targetPositionInMilis)")
        
        updatePlaybackState()
    }
    
    func skip10SecondsForward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentTime = player.currentTime()
        let targetTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        let targetInMilis = convertCMTimeIntoInt64(targetTime)
        player.seek(to: targetTime)
        
        print("DEBUG: skip10SecondsForward target time: \(targetInMilis)")
        updatePlaybackState()
    }
    
    func skip10SecondsBackward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentTime = player.currentTime()
        let targetTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        let targetInMilis = convertCMTimeIntoInt64(targetTime)
        player.seek(to: targetTime)
    
        print("DEBUG: skip10SecondsBackward target time: \(targetInMilis)")
        updatePlaybackState()
    }
    
    func setBackgroundSound(uri: String?) throws {
        guard let uri = uri, let url = URL(string: uri) else {
            throw AudioServiceError.invalidURI
        }
        
        backgroundSoundURI = uri
        
        let backgroundPlayerItem = AVPlayerItem(url: url)
        backgroundPlayer = AVPlayer(playerItem: backgroundPlayerItem)
        backgroundPlayer?.play()
        
        print("DEBUG: setBackgroundSound uri: \(uri)")
        startObservingBackgroundPlayer()
    }
    
    func setBackgroundSoundVolume(volume: Double) throws {
        guard let player = backgroundPlayer else {
            throw AudioServiceError.backgroundSoundNotSet
        }
        
        let result = Float(volume / 100)
        print("DEBUG: setBackgroundSoundVolume \(result)")
        player.volume = result
        //playPauseBackgroundAudio()
    }
    
    func stopBackgroundSound() throws {
        guard let player = backgroundPlayer else {
            throw AudioServiceError.backgroundSoundNotSet
        }
        
        player.pause()
        backgroundPlayer = nil
        print("DEBUG: stopBackgroundSound")
    }
    
    func playBackgroundSound() throws {
        guard let player = backgroundPlayer else {
            throw AudioServiceError.backgroundSoundNotSet
        }
        
        player.play()
        print("DEBUG: playBackgroundSound")
    }
    
    
    @objc
    func primaryPlayerDidFinishPlaying(_ notification: Notification) {
        updatePlaybackState(isCompleted: true)
        print("DEBUG: primaryPlayerDidFinishPlaying")
    }
    
    @objc
    func backgroundPlayerDidFinishPlaying(_ notification: Notification) {
        updatePlaybackState(isCompleted: true)
        print("DEBUG: backgroundPlayerDidFinishPlaying")
    }
}

// MARK: Playback State

extension AudioService {
    @objc 
    private func updatePlaybackState(isCompleted: Bool = false) {
        guard let track = audioTrack else {
            preconditionFailure("The audio track should exist by now, nil found instead.")
        }
        
        let isPlaying = self.isPrimaryPlayerPlaying
        let duration = audioTrackDuration
        let position = convertCMTimeIntoInt64(primaryPlayer?.currentTime())
        let speed = Speed(speed: Double(primaryPlayer?.rate ?? -1))
        let volume = self.deviceVolume
        let backgroundSound = BackgroundSound(uri: backgroundSoundURI, title: "title")
        
        audioServiceCallback?.updatePlaybackState(state: PlaybackState(
            isPlaying: isPlaying,
            isBuffering: false,
            isSeeking: false,
            isCompleted: isCompleted,
            position: position,
            duration: duration,
            speed: speed,
            volume: volume,
            track: track,
            backgroundSound: backgroundSound
        )) { result in
            print("******************")
            print(result)
            print("DEBUG: isPlaying: \(isPlaying)")
            print("DEBUG: isCompleted: \(isCompleted)")
            print("DEBUG: position: \(position)")
            print("DEBUG: duration: \(duration)")
            print("DEBUG: speed: \(speed)")
            print("DEBUG: volume: \(volume)")
            print("DEBUG: track: \(track)")
            print("DEBUG: backgroundSound: \(backgroundSound)")
            print("******************")
        }
    }
    
    private func startPlaybackStateTimer() {
        print("DEBUG: startPlaybackStateTimer")
        playbackStateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updatePlaybackState), userInfo: nil, repeats: true)
    }
    
    private func invalidatePlaybackStateTimer() {
        print("DEBUG: invalidatePlaybackStateTimer")
        playbackStateTimer?.invalidate()
        playbackStateTimer = nil
    }
}

// MARK: Helpers

extension AudioService {
    func convertCMTimeIntoInt64(_ cmTime: CMTime?) -> Int64 {
        guard let cmTime = cmTime else {
            print("DEBUG: cmTimeIsNil")
            return -1
        }
        
        let seconds = Double(cmTime.seconds)
        let duration = CMTimeMakeWithSeconds(seconds, preferredTimescale: Int32(NSEC_PER_SEC))
        let miliseconds = Int64(CMTimeGetSeconds(duration) * 1000) // Convert seconds back to milliseconds
        return miliseconds
    }
}

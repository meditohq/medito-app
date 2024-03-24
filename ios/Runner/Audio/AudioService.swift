import Foundation
import AVFoundation
import Flutter

public class AudioService: NSObject, MeditoAudioServiceApi {
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
    private var primaryPlayer: AVAudioPlayer?
    private var primaryAudioTrack: Track?
    private var primaryAudioURL: URL?
    
    //Background Sound
    private var backgroundPlayer: AVAudioPlayer?
    private var backgroundAudioTrack: Track?
    private var backgroundSoundURI: String?
    
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
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        invalidatePlaybackStateTimer()
        invalidatePlayer(&primaryPlayer)
        invalidatePlayer(&backgroundPlayer)
        stopObservingPlayers()
    }
    
    private func invalidatePlayer(_ player: inout AVAudioPlayer?) {
        player?.pause()
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
            object: primaryPlayer
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
            object: backgroundPlayer
        )
    }
    
    private func stopObservingPlayers() {
        notificationCenter.removeObserver(self)
    }

    func playAudio(audioData: AudioData) throws -> Bool {
        self.primaryAudioTrack = audioData.track
        
        guard let url = URL(string: audioData.url) else {
            print("audioData.url is invalid")
            return false
        }
        
        primaryAudioURL = url
        downloadAndPlayAudio(from: url)
        
        //TODO: when all is done
        startObservingPrimaryPlayer()
        startPlaybackStateTimer()
        updatePlaybackState()
        
        print("DEBUG: playAudio \(audioData)")
        
        return true
    }

    func playPauseAudio() {
        guard let player = primaryPlayer else { return }
        
        if player.isPlaying {
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
        primaryPlayer?.rate = Float(speed)
        updatePlaybackState()
    }
    
    //Position comes in percentage seems like
    func seekToPosition(position: Int64) throws {
        print("DEBUG: seekToPosition \(position)")
        guard let player = primaryPlayer else { return }
        
        let positionInSeconds = TimeInterval(position)
        seekTo(positionInSeconds: positionInSeconds)
        updatePlaybackState()
    }
    
    func skip10SecondsForward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentPosition = player.currentTime
        let newPosition = currentPosition + 10.0

        print("DEBUG: skip10SecondsForward target position: \(newPosition)")
        seekTo(positionInSeconds: newPosition)
        updatePlaybackState()
    }
    
    func skip10SecondsBackward() throws {
        guard let player = primaryPlayer else { return }
        
        let currentPosition = player.currentTime
        let newPosition = currentPosition - 10.0

        print("DEBUG: skip10SecondsForward target position: \(newPosition)")
        seekTo(positionInSeconds: newPosition)
        updatePlaybackState()
    }
    
    func setBackgroundSound(uri: String?) throws {
        guard let uri = uri, let url = URL(string: uri) else {
            throw AudioServiceError.invalidURI
        }
        
        backgroundSoundURI = uri
        
        do {
            backgroundPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundPlayer?.delegate = self
            backgroundPlayer?.prepareToPlay()
            backgroundPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
        
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
        guard let track = primaryAudioTrack else {
            preconditionFailure("The audio track should exist by now, nil found instead.")
        }
    
        let isPlaying = primaryPlayer?.isPlaying ?? false
        let duration = Int64(primaryPlayer?.duration ?? 0)
        let position = Int64(primaryPlayer?.currentTime ?? 0)
        let speed = Speed(speed: Double(primaryPlayer?.rate ?? -1))
        let volume = self.deviceVolume
        let backgroundSound = BackgroundSound(
            uri: backgroundSoundURI,
            title: ""
        )
        
        audioServiceCallback?.updatePlaybackState(state: PlaybackState(
            isPlaying: isPlaying,
            isBuffering: true,
            isSeeking: true,
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
    func seekTo(positionInSeconds: TimeInterval) {
        guard let player = primaryPlayer else {
            print("Audio player is nil.")
            return
        }
        
        // Check if the provided position is within the duration of the audio track
        let duration = player.duration
        if positionInSeconds >= 0 && positionInSeconds <= duration {
            // Set the current time (position) of the audio player
            player.currentTime = positionInSeconds
        } else {
            print("Invalid seek position.")
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func downloadAndPlayAudio(from remoteURL: URL) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localURL = documentsDirectory.appendingPathComponent(remoteURL.lastPathComponent)
        let fileExists = FileManager.default.fileExists(atPath: localURL.path)
        if fileExists {
            playAudio(from: localURL) // If the file exists locally, play it
        } else {
            downloadAudio(from: remoteURL, to: localURL) // If the file doesn't exist locally, download it
        }
    }

    private func downloadAudio(from remoteURL: URL, to localURL: URL) {
        let downloadTask = URLSession.shared.downloadTask(with: remoteURL) { (temporaryURL, response, error) in
            guard let temporaryURL = temporaryURL, error == nil else {
                print("Failed to download audio: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                try FileManager.default.moveItem(at: temporaryURL, to: localURL)
                DispatchQueue.main.async {
                    self.playAudio(from: localURL)
                }
            } catch {
                print("Failed to move downloaded file to destination: \(error)")
            }
        }
        downloadTask.resume()
    }
    
    func playAudio(from url: URL) {
        do {
            primaryPlayer = try AVAudioPlayer(contentsOf: url)
            primaryPlayer?.delegate = self
            primaryPlayer?.prepareToPlay()
            primaryPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
}


extension AudioService: AVAudioPlayerDelegate {
    // AVAudioPlayerDelegate method to handle playback finish
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Handle playback finish
        print("DEBUG: audioPlayerDidFinishPlaying")
    }
    
    // AVAudioPlayerDelegate method to handle interruptions (e.g., phone call)
    public func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        // Handle interruption
        print("DEBUG: audioPlayerBeginInterruption")
    }
    
    // AVAudioPlayerDelegate method to handle resumption after interruption
    public func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        // Handle resumption
        print("DEBUG: audioPlayerEndInterruption")
    }
}

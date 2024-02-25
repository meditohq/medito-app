import Foundation
import AVFoundation
import Flutter

public class AudioService: MeditoAudioServiceApi {
    var player: AVPlayer?
    var isPlaying = false
    
    func playAudio(audioData: AudioData) throws -> Bool {
        guard let url = URL(string: audioData.url) else {
            return false
        }
        
        print(url)
        
        // Initialize and play audio
        player = AVPlayer(url: url)
        player?.play()
        isPlaying = true
        
        return true
    }
    
    func playPauseAudio() throws {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func stopAudio() throws {
        player?.pause()
        player = nil
        isPlaying = false
    }
    
    func setSpeed(speed: Double) throws {
        print("PRINT: setSpeed")
    }
    
    func seekToPosition(position: Int64) throws {
        print("PRINT: seekToPosition")
    }
    
    func skip10SecondsForward() throws {
        print("PRINT: skip10SecondsForward")
    }
    
    func skip10SecondsBackward() throws {
        print("PRINT: skip10SecondsBackward")
    }
    
    func setBackgroundSound(uri: String?) throws {
        print("PRINT: setBackgroundSound")
    }
    
    func setBackgroundSoundVolume(volume: Double) throws {
        print("PRINT: setBackgroundSoundVolume")
    }
    
    func stopBackgroundSound() throws {
        print("PRINT: stopBackgroundSound")
    }
    
    func playBackgroundSound() throws {
        print("PRINT: playBackgroundSound")
    }
    
//    var player: AVPlayer?
//    var isPlaying = false
//
//    public func playAudio(_ audioData: AudioData, error: AutoreleasingUnsafeMutablePointer<FlutterError?>) -> NSNumber? {
//        guard let url = URL(string: audioData.url) else {
//            return false
//        }
//
//        print(url)
//        
//        // Initialize and play audio
//        player = AVPlayer(url: url)
//        player?.play()
//        isPlaying = true
//
//        return NSNumber(value: true)
//    }
//
//    public func playPauseAudioWithError(_ error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        guard let player = player else { return }
//        
//        if isPlaying {
//            player.pause()
//        } else {
//            player.play()
//        }
//        isPlaying.toggle()
//    }
//
//    public func stopAudioWithError(_ error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        player?.pause()
//        player = nil
//        isPlaying = false
//    }
//
//    public func playAudioAudioData(_ audioData: AudioData, error: AutoreleasingUnsafeMutablePointer<FlutterError?>) -> NSNumber? {
//        print("PRINT: playAudioAudioData")
//        return nil
//    }
//    
//    public func setSpeedSpeed(_ speed: Double, error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: setSpeedSpeed")
//    }
//    
//    public func seek(toPositionPosition position: Int, error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: seek")
//    }
//    
//    public func skip10SecondsForwardWithError(_ error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: skip10SecondsForwardWithError")
//    }
//    
//    public func skip10SecondsBackwardWithError(_ error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: skip10SecondsBackwardWithError")
//    }
//    
//    public func setBackgroundSoundUri(_ uri: String?, error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: setBackgroundSoundUri")
//    }
//    
//    public func setBackgroundSoundVolumeVolume(_ volume: Double, error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: setBackgroundSoundVolumeVolume")
//    }
//    
//    public func stopBackgroundSoundWithError(_ error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: stopBackgroundSoundWithError")
//    }
//    
//    public func playBackgroundSoundWithError(_ error: AutoreleasingUnsafeMutablePointer<FlutterError?>) {
//        print("PRINT: playBackgroundSoundWithError")
//    }
}

import Foundation
import AVFoundation
import Flutter

public class AudioService: NSObject, MeditoAudioServiceApi {
    func playAudio(audioData: AudioData) throws -> Bool {
        return true
    }
    
    func playPauseAudio() throws {
        
    }
    
    func stopAudio() throws {
        
    }
    
    func setSpeed(speed: Double) throws {
        
    }
    
    func seekToPosition(position: Int64) throws {
        
    }
    
    func skip10SecondsForward() throws {
        
    }
    
    func skip10SecondsBackward() throws {
        
    }
    
    func setBackgroundSound(uri: String?) throws {
        
    }
    
    func setBackgroundSoundVolume(volume: Double) throws {
        
    }
    
    func stopBackgroundSound() throws {
        
    }
    
    func playBackgroundSound() throws {
        
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

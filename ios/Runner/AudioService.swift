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
}

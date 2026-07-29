import Foundation
import AVFoundation
import Combine

class VoicePool {
    private(set) var voicePool: [AudioVoice] = []
    private let lock = NSLock()
    
    init(_ engine: AVAudioEngine,_ maxVoices: Int) {
        for _ in 0..<maxVoices {
            voicePool.append(AudioVoice(attachedTo: engine))
        }
    }
    
    func play(sample: PitchedSample, targetPitchCents: Double, volume: Double, time: AVAudioTime?) -> Int {
        lock.lock()
        defer { lock.unlock() }

        // 1. Find the first index where a voice returns true for isFree()
        if let freeIndex = voicePool.firstIndex(where: { $0.isFree() }) {
            voicePool[freeIndex].play(sample: sample, targetPitchCents: targetPitchCents, volume: volume, time: time)
            return freeIndex
        }
        
        // 2. Fallback: If no voices are free, steal the first channel (Index 0)
        let stolenIndex = 0
        print("⚠️ Polyphony limit reached. Stealing voice channel \(stolenIndex)")
        
        voicePool[stolenIndex].stop() // Interrupt the old sound cleanly
        voicePool[stolenIndex].play(sample: sample, targetPitchCents: targetPitchCents, volume: volume, time: time)
        
        return stolenIndex
    }
    
    func stop(index: Int) {
        lock.lock()
        defer { lock.unlock() }
        voicePool[index].stop()
    }
    
    func stopAll() {
        lock.lock()
        defer { lock.unlock() }
        voicePool.forEach { $0.stop() }
    }
}

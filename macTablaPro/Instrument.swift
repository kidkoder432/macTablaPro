import Foundation
import AVFoundation
import Combine

@MainActor
class Instrument: ObservableObject {
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var tempoBPM: Double = 100.0
    @Published var volume = 1.0
    
    var effectiveVolume: Double {
        return isMuted ? 0.0 : volume
    }
   
    internal var clock: LookaheadAudioScheduler!
    internal let voicePool: VoicePool
    internal let sampleRegistry: [String: PitchedSample]
    
    // 👈 Hold a weak or unowned reference to your master orchestrator container
    internal unowned let orchestrator: AppAudioOrchestrator
    
    init(orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        self.orchestrator = orchestrator
        self.voicePool = voicePool
        self.sampleRegistry = registry
        
        self.clock = LookaheadAudioScheduler(getBPM: { [weak self] in return self?.tempoBPM ?? 100.0 }, onTick: self.executeSequenceTick)
        
    }
    
    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            clock.start(stepsCount: 5)
        } else {
            clock.stop()
//            voicePool.stopAll()
        }
    }
    
    @discardableResult
    internal func executeSequenceTick(stepIndex: Int, time: AVAudioTime?) -> Double {
        print("Not implemented!")
        return 1.0
    }
}

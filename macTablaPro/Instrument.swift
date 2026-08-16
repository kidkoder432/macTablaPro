import Foundation
import AVFoundation
import Combine
import os

@MainActor
class Instrument: ObservableObject, Identifiable {
    let id: String
    let name: String
    
    let mixerNode = AVAudioMixerNode()

    @Published var isPlaying = false
    @Published var isMuted = false {
        didSet {
            mixerNode.outputVolume = isMuted ? 0.0 : Float(volume)
        }
    }
    
    nonisolated let atomicBPM: Locked<Double>

    @Published var tempoBPM: Double = 100.0 {
        didSet {
            let rounded = round(tempoBPM)
            if tempoBPM != rounded {
                tempoBPM = rounded
            }
            atomicBPM.value = tempoBPM
        }
    }
    @Published var volume = 1.0 {
        didSet {
            if !isMuted {
                mixerNode.outputVolume = Float(volume)
            }
        }
    }
    
    var effectiveVolume: Double {
        return isMuted ? 0.0 : volume
    }
   
    nonisolated(unsafe) internal var clock: LookaheadAudioScheduler!
    internal let voicePool: VoicePool
    internal let sampleRegistry: [String: PitchedSample]
    
    // 👈 Hold a weak or unowned reference to your master orchestrator container
    internal unowned let orchestrator: AppAudioOrchestrator
    
    init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        self.id = id
        self.name = name
        self.orchestrator = orchestrator
        self.voicePool = voicePool
        self.sampleRegistry = registry
        self.atomicBPM = Locked<Double>(100.0)
        
        let bpmRef = self.atomicBPM
        
        self.clock = LookaheadAudioScheduler(
            getBPM: { [bpmRef] in
                bpmRef.value
            },
            onTick: { [weak self] time in
                self?.executeSequenceTick(time: time) ?? 1.0
            }
        )
    }
    
    func startPlay() {
        guard !isPlaying else { return }
        isPlaying = true
        clock.start()
    }

    func stopPlay() {
        guard isPlaying else { return }
        isPlaying = false
        clock.stop()
    }

    func togglePlay() {
        if isPlaying {
            stopPlay()
        } else {
            startPlay()
        }
    }
    
    nonisolated internal func executeSequenceTick(time: AVAudioTime?) -> Double {
        print("Not implemented!")
        return 1.0
    }
}

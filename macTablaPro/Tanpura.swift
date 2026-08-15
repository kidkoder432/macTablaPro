//
//  Tanpura.swift
//  macTablaPro
//
//  Created by Prajwal Agrawal on 7/18/26.
//

import AVFoundation
import Combine
import Foundation

let tanpuraManifest: [PitchedSample] = [

    PitchedSample(

        fileName: "Tanpura_C#3_Pa",

        pitch: 800.0,

        role: "Cf"

    ),

    PitchedSample(

        fileName: "Tanpura_C#3_Sa",

        pitch: 1300.0,

        role: "Cf"

    ),

    PitchedSample(

        fileName: "Tanpura_G#3_Sa",

        pitch: 2000.0,

        role: "Gf"

    ),

    PitchedSample(

        fileName: "Tanpura_C#3_Ni",

        pitch: 1200.0,

        role: "Cn"

    ),

    PitchedSample(

        fileName: "Tanpura_C#3_Kharaj",

        pitch: 100.0,

        role: "Ckh"

    ),

    PitchedSample(

        fileName: "Tanpura_G#3_Kharaj",

        pitch: 800.0,

        role: "GKh"

    ),

]

@MainActor
class Tanpura: Instrument {
    @Published var firstStringPitch: Double = 700.0
    
    override init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        super.init(id: id, name: name, orchestrator: orchestrator, voicePool: voicePool, registry: registry)
    }
    
    override internal func executeSequenceTick(stepIndex: Int, time: AVAudioTime?) -> Double {
        let seq: [TanpuraSeqElem] = [
            .Note(self.firstStringPitch), .Sa, .Sa, .Kharaj, .Rest,
        ]

        let step = seq[stepIndex]
        switch step {
        case .Rest:
            break

        case _:
            var sampleName: String

            // 👈 Grab the absolute latest live data from the single source of truth!
            let liveScaleOffset = orchestrator.scaleOffsetCents
            let liveFineTune = orchestrator.fineTuneCents
            let totalInstrumentTuning = liveScaleOffset + liveFineTune

            let isTreble = liveScaleOffset > 400

            if isTreble {
                switch stepIndex {
                case 0, 1, 2: sampleName = "G#3_Sa"
                case 3: sampleName = "G#3_Kharaj"
                default: return 1.0
                }
            } else {
                switch stepIndex {
                case 0:
                    if firstStringPitch == 1100 {
                        sampleName = "C#3_Ni"
                    } else if firstStringPitch == 0 {
                        sampleName = "C#3_Kharaj"
                    } else if firstStringPitch < 1100 {
                        sampleName = "C#3_Pa"
                    } else {
                        sampleName = "C#3_Sa"
                    }
                case 1, 2: sampleName = "C#3_Sa"
                case 3: sampleName = "C#3_Kharaj"
                default: return 1.0
                }
            }
            
            if let sampleToPlay = sampleRegistry["Tanpura_" + sampleName] {
                print("Playing sample: \(sampleToPlay.fileName) at pitch \(totalInstrumentTuning + step.pitch)")
                let _ = self.voicePool.play(
                    sample: sampleToPlay,
                    // 👈 Apply the master workspace combined pitch dynamically!
                    targetPitchCents: totalInstrumentTuning + step.pitch,
                    volume: self.effectiveVolume,
                    time: time
                )
            } else {
                print("⚠️ Registry Error: Buffer missing for key '\(sampleName)'")
            }
        }
        return 1.0
    }
}

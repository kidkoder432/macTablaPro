//
//  Tanpura.swift
//  macTablaPro
//
//  Created by Prajwal Agrawal on 7/24/26.
//

import AVFoundation
import Combine
import Foundation
import os

let tanpuraManifest: [PitchedSample] = [
    // --- C# Pitch Set (Male / Lower Scales) ---
    PitchedSample(
        fileName: "Tanpura_C#3_Kharaj",
        pitch: 100.0,
        role: "CKh"
    ),
    PitchedSample(
        fileName: "Tanpura_C#3_Sa",
        pitch: 1300.0,
        role: "CSa"
    ),
    PitchedSample(
        fileName: "Tanpura_C#3_Pa",
        pitch: 800.0,
        role: "CPa"
    ),
    PitchedSample(
        fileName: "Tanpura_C#3_Ni",
        pitch: 1200.0,
        role: "CNi"
    ),

    // --- G# Pitch Set (Female / Higher Scales) ---
    PitchedSample(
        fileName: "Tanpura_G#3_Sa",
        pitch: 2000.0,
        role: "GSa"
    ),
    PitchedSample(
        fileName: "Tanpura_G#3_Kharaj",
        pitch: 800.0,
        role: "GKh"
    ),
]

@MainActor
class Tanpura: Instrument {
    nonisolated let atomicTanpura = Locked<(pitch: Double, currentStep: Int)>((pitch: 700.0, currentStep: 0))

    @Published var firstStringPitch: Double = 700.0 {
        didSet {
            atomicTanpura.withLock { $0.pitch = firstStringPitch }
        }
    }
    
    override init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        super.init(id: id, name: name, orchestrator: orchestrator, voicePool: voicePool, registry: registry)
    }

    override func startPlay() {
        guard !isPlaying else { return }
        isPlaying = true
        atomicTanpura.withLock { $0.currentStep = 0 }
        clock.start()
    }
    
    nonisolated override internal func executeSequenceTick(time: AVAudioTime?) -> Double {
        let (currentPitch, stepIndex) = atomicTanpura.withLock { state -> (Double, Int) in
            let step = state.currentStep
            state.currentStep = (state.currentStep + 1) % 5
            return (state.pitch, step)
        }

        let seq: [TanpuraSeqElem] = [
            .Note(currentPitch), .Sa, .Sa, .Kharaj, .Rest,
        ]

        let step = seq[stepIndex]
        switch step {
        case .Rest:
            break

        case _:
            var sampleName: String

            // Grab the absolute latest live data from thread-safe atomic orchestrator
            let liveScaleOffset = orchestrator.atomicScaleOffsetCents
            let liveFineTune = orchestrator.atomicFineTuneCents
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
                    if currentPitch == 1100 {
                        sampleName = "C#3_Ni"
                    } else if currentPitch == 0 {
                        sampleName = "C#3_Kharaj"
                    } else if currentPitch < 1100 {
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
                AudioLogger.logTanpuraStep(
                    instrument: self.name,
                    stepIndex: stepIndex,
                    noteName: sampleName,
                    sample: sampleToPlay.fileName,
                    hostTime: time?.hostTime ?? 0
                )
                let _ = self.voicePool.play(
                    sample: sampleToPlay,
                    targetPitchCents: totalInstrumentTuning + step.pitch,
                    volume: 1.0,
                    time: time
                )
            } else {
                print("⚠️ Registry Error: Buffer missing for key '\(sampleName)'")
            }
        }
        return 1.0
    }
}

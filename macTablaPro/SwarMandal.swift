//
//  SwarMandal.swift
//  macTablaPro
//

import AVFoundation
import Combine
import Foundation
import OSLog

var logger = Logger(subsystem: "com.praj.macTablaPro", category: "SwarMandal")

// MARK: - Swar Mandal Timing Configuration
nonisolated public struct SwarMandalTimingConfig: Sendable {
    /// Minimum tempo (BPM) for delicate arpeggios
    public static let minTempoBPM: Double = 300.0
    
    /// Maximum tempo (BPM) for fast glissandos
    public static let maxTempoBPM: Double = 800.0
    
    /// Default tempo (BPM)
    public static let defaultTempoBPM: Double = 450.0
    
    /// Natural physical slow-down decay factor per string plucked
    public static let decayRate: Double = 0.96
    
    /// String count constraints
    public static let minStringCount: Int = 15
    public static let maxStringCount: Int = 36
    public static let defaultStringCount: Int = 20
}

// MARK: - Swar Mandal Operating Modes
nonisolated public enum SwarMandalMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case pluck = "Pluck Mode"
    case strum = "Strum Mode"
    
    public var id: String { rawValue }
}

// MARK: - Auto-Loop Duration Preset Options
nonisolated public enum SwarMandalLoopOption: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sec30 = 30
    case min1 = 60
    case min2 = 120
    case min5 = 300
    case min10 = 600
    case min15 = 900
    case min20 = 1200
    case min30 = 1800
    case hour1 = 3600
    
    public var id: Int { rawValue }
    
    public var label: String {
        switch self {
        case .sec30: return "30 Sec"
        case .min1: return "1 Min"
        case .min2: return "2 Min"
        case .min5: return "5 Min"
        case .min10: return "10 Min"
        case .min15: return "15 Min"
        case .min20: return "20 Min"
        case .min30: return "30 Min"
        case .hour1: return "1 Hour"
        }
    }
}

// MARK: - Complete 36 Swar Note & Pitch Offset Definitions
nonisolated public struct SwarNoteHelper: Sendable {
    public static let centsMap: [String: Double] = [
        // --- Lower Octave / Kharaj (-1200c ... -100c) ---
        "Sa Lower": -1200.0,
        "Re Komal Lower": -1100.0,
        "Re Lower": -1000.0,
        "Ga Komal Lower": -900.0,
        "Ga Lower": -800.0,
        "Ma Lower": -700.0,
        "Ma Teevra Lower": -600.0,
        "Pa Lower": -500.0,
        "Dha Komal Lower": -400.0,
        "Dha Lower": -300.0,
        "Ni Komal Lower": -200.0,
        "Ni Lower": -100.0,
        
        // --- Middle Octave (0c ... 1100c) ---
        "Kharaj": 0.0,
        "Re Komal": 100.0,
        "Re": 200.0,
        "Ga Komal": 300.0,
        "Ga": 400.0,
        "Ga Shuddha": 400.0,
        "Ma": 500.0,
        "Ma Shuddha": 500.0,
        "Ma Teevra": 600.0,
        "Pa": 700.0,
        "Dha Komal": 800.0,
        "Dha": 900.0,
        "Dha Shuddha": 900.0,
        "Ni Komal": 1000.0,
        "Ni": 1100.0,
        "Ni Shuddha": 1100.0,
        
        // --- Higher Octave (+1200c ... +2300c) ---
        "Sa": 1200.0,
        "Re Komal Higher": 1300.0,
        "Re Higher Komal": 1300.0,
        "Re Higher": 1400.0,
        "Ga Komal Higher": 1500.0,
        "Ga Higher Komal": 1500.0,
        "Ga Higher": 1600.0,
        "Ma Higher": 1700.0,
        "Ma Teevra Higher": 1800.0,
        "Pa Higher": 1900.0,
        "Dha Komal Higher": 2000.0,
        "Dha Higher": 2100.0,
        "Ni Komal Higher": 2200.0,
        "Ni Higher": 2300.0,
        
        // --- String Mute ---
        "Off": 0.0
    ]
    
    public static let lowerOctaveSwars: [String] = [
        "Kharaj", "Re Komal Lower", "Re Lower", "Ga Komal Lower", "Ga Lower",
        "Ma Lower", "Ma Teevra Lower", "Pa Lower", "Dha Komal Lower", "Dha Lower", "Ni Komal Lower", "Ni Lower"
    ]
    
    public static let middleOctaveSwars: [String] = [
        "Sa", "Re Komal", "Re", "Ga Komal", "Ga",
        "Ma", "Ma Teevra", "Pa", "Dha Komal", "Dha", "Ni Komal", "Ni"
    ]
    
    public static let higherOctaveSwars: [String] = [
        "Sa Higher", "Re Komal Higher", "Re Higher", "Ga Komal Higher", "Ga Higher",
        "Ma Higher", "Ma Teevra Higher", "Pa Higher", "Dha Komal Higher", "Dha Higher", "Ni Komal Higher", "Ni Higher"
    ]
    
    public static let standardSwars: [String] = lowerOctaveSwars + middleOctaveSwars + higherOctaveSwars
    
    public static func cents(for noteName: String) -> Double {
        return centsMap[noteName] ?? 0.0
    }
}

// MARK: - Absolute Pitch Swar Mandal Manifest (Relative to C3 = 0c)
let swarMandalManifest: [PitchedSample] = [
    PitchedSample(fileName: "SwarMandal_C#3", pitch: 100.0, role: "C#3"),
    PitchedSample(fileName: "SwarMandal_C#4", pitch: 1300.0, role: "C#4"),
    PitchedSample(fileName: "SwarMandal_C#5", pitch: 2500.0, role: "C#5")
]

// MARK: - Swar Mandal Instrument Class (LookaheadAudioScheduler Integration)
@MainActor
class SwarMandal: Instrument {
    nonisolated let atomicState = Locked<(loopOption: SwarMandalLoopOption, stringCount: Int, stringNotes: [String], currentStep: Int)>(
        (loopOption: .min1, stringCount: SwarMandalTimingConfig.defaultStringCount, stringNotes: [], currentStep: 0)
    )

    @Published public var loopOption: SwarMandalLoopOption = .min1 {
        didSet { syncAtomicState() }
    }
    
    @Published public var stringCount: Int = SwarMandalTimingConfig.defaultStringCount {
        didSet {
            let clamped = max(SwarMandalTimingConfig.minStringCount, min(SwarMandalTimingConfig.maxStringCount, stringCount))
            if stringCount != clamped {
                stringCount = clamped
            } else {
                adjustStringNotesCount()
            }
            syncAtomicState()
        }
    }
    
    @Published public var stringNotes: [String] = [] {
        didSet { syncAtomicState() }
    }

    private func syncAtomicState() {
        atomicState.withLock {
            $0.loopOption = loopOption
            $0.stringCount = stringCount
            $0.stringNotes = stringNotes
        }
    }
    
    public override init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        super.init(id: id, name: name, orchestrator: orchestrator, voicePool: voicePool, registry: registry)
        self.tempoBPM = SwarMandalTimingConfig.defaultTempoBPM
        let initialNotes = Array(SwarNoteHelper.middleOctaveSwars + SwarNoteHelper.higherOctaveSwars.prefix(12))
        self.stringNotes = initialNotes
        self.atomicState.withLock {
            $0.loopOption = .min1
            $0.stringCount = stringCount
            $0.stringNotes = initialNotes
        }
    }
    
    private func adjustStringNotesCount() {
        if stringNotes.count < stringCount {
            while stringNotes.count < stringCount {
                stringNotes.append("Off")
            }
        } else if stringNotes.count > stringCount {
            stringNotes = Array(stringNotes.prefix(stringCount))
        }
    }
    
    public func updateNotesFromPreset(_ notes: [String]) {
        guard !notes.isEmpty else { return }
        let targetCount = max(SwarMandalTimingConfig.minStringCount, min(SwarMandalTimingConfig.maxStringCount, notes.count))
        var padded = notes
        while padded.count < targetCount {
            padded.append("Off")
        }
        self.stringNotes = Array(padded.prefix(targetCount))
        self.stringCount = targetCount
    }
    
    public override func startPlay() {
        guard !isPlaying else { return }
        isPlaying = true
        syncAtomicState()
        atomicState.withLock { $0.currentStep = 0 }
        clock.start()
    }

    // MARK: - LOOKAHEAD AUDIO SCHEDULER CALLBACK
    
    @discardableResult
    nonisolated override internal func executeSequenceTick(time: AVAudioTime?) -> Double {
        let (stepIndex, loopOption, stringCount, stringNotes) = atomicState.withLock { state -> (Int, SwarMandalLoopOption, Int, [String]) in
            let step = state.currentStep
            state.currentStep = (state.currentStep + 1) % (state.stringCount + 1)
            return (step, state.loopOption, state.stringCount, state.stringNotes)
        }
        let masterPitch = orchestrator.atomicScaleOffsetCents + orchestrator.atomicFineTuneCents
        let tempoBPM = atomicBPM.value

        if stepIndex < stringCount && stepIndex < stringNotes.count {
            let noteName = stringNotes[stepIndex]
            if noteName != "Off" {
                let swarCents = SwarNoteHelper.cents(for: noteName)
                let targetPitch = masterPitch + swarCents
                
                let sampleToPlay = sampleRegistry["SwarMandal_C#3"] ?? sampleRegistry.values.first
                if let sample = sampleToPlay {
                    AudioLogger.logSwarMandalPluck(
                        stringIndex: stepIndex,
                        noteName: noteName,
                        sample: sample.fileName,
                        hostTime: time?.hostTime ?? 0
                    )
                    let _ = voicePool.play(sample: sample, targetPitchCents: targetPitch, volume: 1.0, time: time)
                }
            }
            
            // Calculate step duration with natural physical slow-down (decay curve) from the user's chosen tempo
            let stepBPM = tempoBPM * pow(SwarMandalTimingConfig.decayRate, Double(stepIndex))
            return tempoBPM / stepBPM
        } else {
            // Step N: Auto-Loop Pause step (start-to-start interval calculation)
            let totalTargetSeconds = Double(loopOption.rawValue)
            var strumPassSeconds = 0.0
            for i in 0..<stringCount {
                let stepBPM = tempoBPM * pow(SwarMandalTimingConfig.decayRate, Double(i))
                strumPassSeconds += 60.0 / max(50.0, stepBPM)
            }
            let remainingPauseSeconds = max(0.1, totalTargetSeconds - strumPassSeconds)
            return remainingPauseSeconds * (tempoBPM / 60.0)
        }
    }
    
    /// Single string pluck trigger for interactive harp view clicks & drag sweeps
    public func pluckString(at index: Int) {
        guard index >= 0 && index < stringNotes.count else { return }
        let noteName = stringNotes[index]
        guard noteName != "Off" else { return }
        
        let swarCents = SwarNoteHelper.cents(for: noteName)
        let masterPitch = orchestrator.scaleOffsetCents + orchestrator.fineTuneCents
        let targetPitch = masterPitch + swarCents
        
        if let sample = sampleRegistry["SwarMandal_C#3"] ?? sampleRegistry.values.first {
            AudioLogger.logSwarMandalPluck(
                stringIndex: index,
                noteName: noteName,
                sample: sample.fileName,
                hostTime: 0
            )
            let _ = voicePool.play(sample: sample, targetPitchCents: targetPitch, volume: 1.0, time: nil)
        }
    }
    
    /// Manual strum trigger reusing the instrument's lookahead audio scheduler clock
    public func triggerManualStrumPass() {
        if isPlaying {
            // Reset auto-looper sequence to step 0 immediately
            atomicState.withLock { $0.currentStep = 0 }
            clock.start()
        } else {
            // Trigger single non-looping strum pass via lookahead scheduler
            atomicState.withLock { $0.currentStep = 0 }
            clock.triggerSinglePass(ticks: stringCount)
        }
    }
}

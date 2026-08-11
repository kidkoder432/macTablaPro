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
public struct SwarMandalTimingConfig: Sendable {
    /// Initial tempo (BPM) for Pluck Mode at string index 0
    public static var pluckBPM: Double = 400.0
    
    /// Final tempo (BPM) for Pluck Mode at string index (stringCount - 1)
    public static var pluckDecay = 0.95
    
    /// Constant tempo (BPM) for Strum Mode (fast ambient glissando)
    public static var strumBPM: Double = 800.0
    
    /// String count constraints
    public static let minStringCount: Int = 15
    public static let maxStringCount: Int = 36
    public static let defaultStringCount: Int = 20
}

// MARK: - Swar Mandal Operating Modes
public enum SwarMandalMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case pluck = "Pluck Mode"
    case strum = "Strum Mode"
    
    public var id: String { rawValue }
}

// MARK: - Auto-Loop Duration Preset Options
public enum SwarMandalLoopOption: Int, Codable, CaseIterable, Identifiable, Sendable {
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
public struct SwarNoteHelper: Sendable {
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
    @Published public var mode: SwarMandalMode = .pluck
    @Published public var loopOption: SwarMandalLoopOption = .min1
    
    @Published public var stringCount: Int = SwarMandalTimingConfig.defaultStringCount {
        didSet {
            let clamped = max(SwarMandalTimingConfig.minStringCount, min(SwarMandalTimingConfig.maxStringCount, stringCount))
            if stringCount != clamped {
                stringCount = clamped
            } else {
                adjustStringNotesCount()
            }
        }
    }
    
    @Published public var stringNotes: [String] = []
    
    public override init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        super.init(id: id, name: name, orchestrator: orchestrator, voicePool: voicePool, registry: registry)
        self.stringNotes = Array(SwarNoteHelper.middleOctaveSwars + SwarNoteHelper.higherOctaveSwars.prefix(12))
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
        // Begins at step 0 so sound fires immediately on start/preset load
        clock.start(stepsCount: stringCount + 1, startingAtStep: 0)
    }

    // MARK: - STUB FUNCTION FOR LOOKAHEAD AUDIO SCHEDULER (MENTOR COMPLIANCE)
    
    /// Called by `LookaheadAudioScheduler` for each sequence tick.
    /// Steps 0 ... (stringCount - 1) represent individual string plucks.
    /// Step `stringCount` represents the auto-loop pause step computed from start-to-start cycle duration.
    /// - Parameters:
    ///   - stepIndex: Current sequence step (0 ... stringCount).
    ///   - time: Host-clock sample-accurate AVAudioTime for CoreAudio playback.
    /// - Returns: Duration fraction multiplier relative to 60.0 / tempoBPM.
    @discardableResult
    override internal func executeSequenceTick(stepIndex: Int, time: AVAudioTime?) -> Double {

        if stepIndex < stringCount && stepIndex < stringNotes.count {
            let noteName = stringNotes[stepIndex]
            if noteName != "Off" {
                let swarCents = SwarNoteHelper.cents(for: noteName)
                let masterPitch = orchestrator.scaleOffsetCents + orchestrator.fineTuneCents
                let targetPitch = masterPitch + swarCents
                
                let sampleToPlay = sampleRegistry["SwarMandal_C#3"] ?? sampleRegistry.values.first
                if let sample = sampleToPlay {
                    let _ = voicePool.play(sample: sample, targetPitchCents: targetPitch, volume: effectiveVolume, time: time)
                }
            }
            
            // Return step duration fraction based on mode (Pluck mode ramps from 400 to 240 BPM)
            if mode == .pluck {
                print(100.0 / (SwarMandalTimingConfig.pluckBPM * pow(SwarMandalTimingConfig.pluckDecay, Double(stepIndex))))
                return 100.0 / (SwarMandalTimingConfig.pluckBPM * pow(SwarMandalTimingConfig.pluckDecay, Double(stepIndex)))
            } else {
                return 100.0 / SwarMandalTimingConfig.strumBPM
            }
        } else {
            // Step N: Auto-Loop Pause step (start-to-start interval calculation)
            let totalTargetSeconds = Double(loopOption.rawValue)
            var strumPassSeconds = 0.0
            if mode == .pluck {
                var stepBPM = SwarMandalTimingConfig.pluckBPM
                for i in 0..<stringCount {
                    strumPassSeconds += 60.0 / stepBPM
                    stepBPM *= SwarMandalTimingConfig.pluckDecay
                }
            } else {
                strumPassSeconds = Double(stringCount) * (60.0 / SwarMandalTimingConfig.strumBPM)
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
            let _ = voicePool.play(sample: sample, targetPitchCents: targetPitch, volume: effectiveVolume, time: nil)
        }
    }
    
    /// Manual strum trigger reusing the instrument's lookahead audio scheduler clock
    public func triggerManualStrumPass() {
        if isPlaying {
            // Reset auto-looper sequence to step 0 immediately
            clock.start(stepsCount: stringCount + 1, startingAtStep: 0)
        } else {
            // Trigger single non-looping strum pass via lookahead scheduler
            clock.triggerSinglePass(stepsCount: stringCount)
        }
    }
}

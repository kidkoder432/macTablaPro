//
//  Tabla.swift
//  macTablaPro
//
//  Created by Prajwal Agrawal on 7/18/26.
//

import AVFoundation
import Combine
import Foundation

let wavURLs: [URL] =
    Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []

let tablaManifest: [PitchedSample] = wavURLs.filter { url in
    let baseName = url.deletingPathExtension().lastPathComponent
    return baseName.contains("Bayaan") || baseName.contains("Dayaan")
}.map { url in
    let baseName = url.deletingPathExtension().lastPathComponent
    return PitchedSample(
        fileName: baseName,
        pitch: baseName.contains("C#")
            ? 100 : (baseName.contains("G#") ? 800 : 0),
        role: baseName.contains("Bayaan")
            ? "UnPitched"
            : "d"
            + (baseName.contains("Tip")
                ? "t" : (baseName.contains("Sur") ? "s" : ""))
    )
}

@MainActor
class Tabla: Instrument {
    @Published var activeTaal: String = "Teentaal"
    @Published var activeVariation: String = "Pro Default"
    @Published var useSurTabla = false
    @Published var currentMatra: Int = 1
    @Published var currentMatraSubStep: Int = 0
    @Published var currentBolName: String = ""
    @Published var currentStepIndex = 0

    override init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        super.init(id: id, name: name, orchestrator: orchestrator, voicePool: voicePool, registry: registry)
    }

    private let taalDb = TablaDatabase.shared.taalCatalog

    /// Returns the allowed BPM range (min...max) for the currently selected Taal and Variation.
    func allowedBPMRange() -> ClosedRange<Double> {
        guard let taal = taalDb[activeTaal],
              let variation = taal.variations[activeVariation],
              !variation.allowedTempos.isEmpty else {
            return 10.0...700.0
        }
        let tiers = variation.allowedTempos
        let minTier = tiers.min() ?? 0
        let maxTier = tiers.max() ?? 4
        
        let minBPMs = [10.0, 25.0, 81.0, 151.0, 301.0]
        let maxBPMs = [25.0, 80.0, 150.0, 300.0, 700.0]
        
        let low = minBPMs[minTier]
        let high = maxBPMs[maxTier]
        return low...high
    }

    /// Clamps the current tempoBPM to stay within allowedBPMRange().
    func clampTempoToAllowedRange() {
        let range = allowedBPMRange()
        if tempoBPM < range.lowerBound {
            tempoBPM = range.lowerBound
        } else if tempoBPM > range.upperBound {
            tempoBPM = range.upperBound
        }
        updateTimelinePosition()
    }

    // MARK: - Tempo & Tier Management

    /// Maps the current raw tempoBPM to its corresponding Tempo Tier Index (0...4)
    /// Tier 0: 10-25 (Ati-Vilambit), Tier 1: 25-80 (Vilambit), Tier 2: 81-150 (Madhya),
    /// Tier 3: 151-300 (Drut), Tier 4: 301-700 (Ati-Drut)
    func currentTempoTier() -> Int {
        switch tempoBPM {
        case ..<25: return 0
        case 25..<81: return 1
        case 81..<151: return 2
        case 151..<301: return 3
        default: return 4
        }
    }

    /// Resolves the active timeline for the current Taal, Variation, and Tempo Tier.
    /// Implements fallback clamping if the current tier is unavailable in the variation's allowedTempos.
    func resolveActiveTimeline() -> [TablaStrokeEvent] {
        guard let taal = taalDb[activeTaal],
            let variation = taal.variations[activeVariation]
        else {
            return []
        }

        let desiredTier = currentTempoTier()

        // If exact tier exists in variation, use it
        if let timeline = variation.timelinesByTempoTier[desiredTier],
            !timeline.isEmpty
        {
            return timeline
        }

        // Fallback clamping to nearest available tier
        if let fallbackTier = variation.allowedTempos.sorted().min(by: {
            abs($0 - desiredTier) < abs($1 - desiredTier)
        }),
            let timeline = variation.timelinesByTempoTier[fallbackTier]
        {
            return timeline
        }

        return variation.timelinesByTempoTier.values.first ?? []
    }

    private var lastExecutedTier: Int = -1

    /// Subdivisions per beat according to Tempo Tier:
    /// Ati-Vilambit (0): 16, Vilambit (1): 16, Madhya (2): 8, Drut (3): 4, Ati-Drut (4): 2
    func subdivisionsPerBeat(forTier tier: Int) -> Int {
        switch tier {
        case 0, 1: return 16
        case 2: return 8
        case 3: return 4
        default: return 2
        }
    }

    /// Total pulses in full Taal cycle for current tempo tier
    private func totalPulsesInCycle() -> Int {
        let totalMatras = Int(taalDb[activeTaal]?.matras ?? 16)
        let subs = subdivisionsPerBeat(forTier: currentTempoTier())
        return totalMatras * subs
    }

    /// Transitions playback seamlessly to a new timeline, maintaining matra position
    func updateTimelinePosition() {
        if isPlaying {
            let totalPulses = totalPulsesInCycle()
            let subs = subdivisionsPerBeat(forTier: currentTempoTier())
            let startingPulse = ((currentMatra - 1) * subs) % totalPulses
            clock.start(stepsCount: totalPulses, startingAtStep: startingPulse)
        }
    }

    func restartClockIfPlaying() {
        if isPlaying {
            let totalPulses = totalPulsesInCycle()
            clock.start(stepsCount: totalPulses)
        }
    }

    override func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            currentStepIndex = 0
            currentMatra = 1
            currentMatraSubStep = 0
            currentBolName = ""
            lastExecutedTier = currentTempoTier()
            let totalPulses = totalPulsesInCycle()
            clock.start(stepsCount: totalPulses)
        } else {
            clock.stop()
        }
    }

    override internal func executeSequenceTick(stepIndex: Int, time: AVAudioTime?) -> Double {
        let activeTier = currentTempoTier()
        if lastExecutedTier != activeTier {
            lastExecutedTier = activeTier
            updateTimelinePosition()
        }

        let subs = subdivisionsPerBeat(forTier: activeTier)
        let stepFraction = 1.0 / Double(subs)
        
        // Calculate current matra (1-indexed) and sub-pulse index within beat
        let pulseWithinBeat = stepIndex % subs
        let calculatedMatra = (stepIndex / subs) + 1
        self.currentMatra = calculatedMatra
        
        // Quarter-matra index (0, 1, 2, 3) mapped from pulse position
        self.currentMatraSubStep = (pulseWithinBeat * 4) / subs
        
        let timeline = resolveActiveTimeline()
        guard !timeline.isEmpty else {
            return stepFraction
        }

        // Calculate accumulated beat offset in sequence timeline to match against CSV events
        let pulseBeatTime = Double(stepIndex) * stepFraction
        var accumulatedTime = 0.0
        
        var matchingEvent: TablaStrokeEvent? = nil
        for event in timeline {
            if abs(accumulatedTime - pulseBeatTime) < 0.0001 {
                matchingEvent = event
                break
            }
            accumulatedTime += event.durationFraction
            if accumulatedTime > pulseBeatTime + 0.0001 {
                break
            }
        }

        guard let event = matchingEvent else {
            return stepFraction
        }

        self.currentBolName = event.bolName ?? self.currentBolName

        // Execute Left Hand (Bayan)
        if let leftSample = event.leftSampleName,
            let sampleToPlay = sampleRegistry["Bayaan_" + leftSample] {
            _ = self.voicePool.play(
                sample: sampleToPlay,
                targetPitchCents: 0,
                volume: Double(event.leftVolume) * self.effectiveVolume,
                time: time
            )
        }

        // Execute Right Hand (Dayan)
        let tablaPitch: String =
            orchestrator.scaleOffsetCents <= 400 ? "C#" : "G#"
        
        if taalDb[activeTaal]!.forceSur {
            useSurTabla = true
        }
        
        var surString: String = ""
        if tablaPitch == "C#" {
            surString = useSurTabla ? "Sur_" : "Tip_"
        }

        if let bol = event.rightSampleName {
            let sampleString = "Dayaan_" + tablaPitch + "_" + surString + bol
            if let sampleToPlay = sampleRegistry[sampleString] {
                _ = self.voicePool.play(
                    sample: sampleToPlay,
                    targetPitchCents: orchestrator.scaleOffsetCents
                        + orchestrator.fineTuneCents,
                    volume: Double(event.rightVolume) * self.effectiveVolume,
                    time: time
                )
            }
        }

        return stepFraction
    }
}

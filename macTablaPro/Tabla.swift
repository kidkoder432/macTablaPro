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
    @Published var logScaleBase: Double = 10.0

    override init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        super.init(id: id, name: name, orchestrator: orchestrator, voicePool: voicePool, registry: registry)
    }

    private let taalDb = TablaDatabase.shared.taalCatalog

    /// Returns the allowed BPM range (min...max) for the currently selected Taal and Variation.
    private func minBPM(forTier tier: Int) -> Double {
        switch tier {
        case 0: return 10.0
        case 1: return 25.0
        case 55: return 55.0
        case 2: return 81.0
        case 3: return 151.0
        case 4: return 301.0
        default: return 10.0
        }
    }

    private func maxBPM(forTier tier: Int) -> Double {
        switch tier {
        case 0: return 25.0
        case 1: return 80.0
        case 55: return 80.0
        case 2: return 150.0
        case 3: return 300.0
        case 4: return 700.0
        default: return 700.0
        }
    }

    /// Returns the allowed BPM range (min...max) for the currently selected Taal and Variation.
    func allowedBPMRange() -> ClosedRange<Double> {
        guard let taal = taalDb[activeTaal],
              let variation = taal.variations[activeVariation],
              !variation.allowedTempos.isEmpty else {
            return 10.0...700.0
        }
        let tiers = variation.allowedTempos
        let minVal = tiers.map { minBPM(forTier: $0) }.min() ?? 10.0
        let maxVal = tiers.map { maxBPM(forTier: $0) }.max() ?? 700.0
        return minVal...maxVal
    }
    
    /// Converts tempoBPM to logarithmic slider value [0.0 ... 1.0]
    func bpmToLogSliderValue(_ bpm: Double) -> Double {
        let range = allowedBPMRange()
        let minB = range.lowerBound
        let maxB = range.upperBound
        let clampedBPM = max(minB, min(maxB, bpm))
        let ratio = (clampedBPM - minB) / max(1.0, maxB - minB)
        if logScaleBase <= 1.0 {
            return ratio
        }
        let logVal = log(1.0 + (logScaleBase - 1.0) * ratio) / log(logScaleBase)
        return max(0.0, min(1.0, logVal))
    }
    
    /// Converts logarithmic slider value [0.0 ... 1.0] to tempoBPM clamped to allowed range
    func logSliderValueToBPM(_ sliderVal: Double) -> Double {
        let range = allowedBPMRange()
        let minB = range.lowerBound
        let maxB = range.upperBound
        let clampedVal = max(0.0, min(1.0, sliderVal))
        if logScaleBase <= 1.0 {
            return round(minB + clampedVal * (maxB - minB))
        }
        let frac = (pow(logScaleBase, clampedVal) - 1.0) / (logScaleBase - 1.0)
        let computedBPM = minB + frac * (maxB - minB)
        return round(max(minB, min(maxB, computedBPM)))
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

    /// Maps the current raw tempoBPM to its corresponding Tempo Tier Index
    /// Tier 0: 10-25 (Ati-Vilambit), Tier 1: 25-54 or 25-80 (Vilambit), Tier 55: 55-80 (Vilambit Fine),
    /// Tier 2: 81-150 (Madhya), Tier 3: 151-300 (Drut), Tier 4: 301-700 (Ati-Drut)
    func currentTempoTier() -> Int {
        guard let taal = taalDb[activeTaal],
              let variation = taal.variations[activeVariation] else {
            switch tempoBPM {
            case ..<25: return 0
            case 25..<81: return 1
            case 81..<151: return 2
            case 151..<301: return 3
            default: return 4
            }
        }

        switch tempoBPM {
        case ..<25:
            return 0
        case 25..<55:
            if variation.allowedTempos.contains(1) {
                return 1
            } else if variation.allowedTempos.contains(55) {
                return 55
            } else {
                return 1
            }
        case 55..<81:
            return variation.allowedTempos.contains(55) ? 55 : 1
        case 81..<151:
            return 2
        case 151..<301:
            return 3
        default:
            return 4
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

        // 1. If exact tier exists in variation, use it
        if let timeline = variation.timelinesByTempoTier[desiredTier],
            !timeline.isEmpty
        {
            return timeline
        }

        // 2. Direct fallback between 1 and 55 if one is missing
        if desiredTier == 1, let timeline = variation.timelinesByTempoTier[55], !timeline.isEmpty {
            return timeline
        }
        if desiredTier == 55, let timeline = variation.timelinesByTempoTier[1], !timeline.isEmpty {
            return timeline
        }

        // 3. Fallback clamping by closest BPM range midpoint
        let currentBPM = self.tempoBPM
        if let fallbackTier = variation.allowedTempos.min(by: {
            let mid1 = (minBPM(forTier: $0) + maxBPM(forTier: $0)) / 2.0
            let mid2 = (minBPM(forTier: $1) + maxBPM(forTier: $1)) / 2.0
            return abs(mid1 - currentBPM) < abs(mid2 - currentBPM)
        }),
            let timeline = variation.timelinesByTempoTier[fallbackTier]
        {
            return timeline
        }

        return variation.timelinesByTempoTier.values.first ?? []
    }

    private var lastExecutedTier: Int = -1

    /// Subdivisions per beat according to Tempo Tier:
    /// Ati-Vilambit (0): 16, Vilambit (1): 16, Vilambit Fine (55): 16, Madhya (2): 8, Drut (3): 4, Ati-Drut (4): 4
    func subdivisionsPerBeat(forTier tier: Int) -> Int {
        switch tier {
        case 0: return 16
        case 1: return 16
        case 55: return 16
        case 2: return 8
        case 3: return 4
        case 4: return 1
        default: return 4
        }
    }

    /// Total pulses in full Taal cycle for current tempo tier
    private func totalPulsesInCycle() -> Int {
        let totalMatras = taalDb[activeTaal]?.matras ?? 16.0
        let subs = Double(subdivisionsPerBeat(forTier: currentTempoTier()))
        return Int(round(totalMatras * subs))
    }

    /// Transitions playback seamlessly to a new timeline, maintaining exact fractional matra position
    func updateTimelinePosition() {
        if isPlaying {
            let totalPulses = totalPulsesInCycle()
            let subs = Double(subdivisionsPerBeat(forTier: currentTempoTier()))
            let currentBeatPos = Double(currentMatra - 1) + (Double(currentMatraSubStep) / 4.0)
            let startingPulse = Int(round(currentBeatPos * subs)) % (totalPulses > 0 ? totalPulses : 1)
            clock.start(stepsCount: totalPulses, startingAtStep: startingPulse)
        }
    }

    func restartClockIfPlaying() {
        if isPlaying {
            let totalPulses = totalPulsesInCycle()
            clock.start(stepsCount: totalPulses)
        }
    }

    override func startPlay() {
        guard !isPlaying else { return }
        isPlaying = true
        currentStepIndex = 0
        currentMatra = 1
        currentMatraSubStep = 0
        currentBolName = ""
        lastExecutedTier = currentTempoTier()
        let totalPulses = totalPulsesInCycle()
        clock.start(stepsCount: totalPulses)
    }

    override func stopPlay() {
        guard isPlaying else { return }
        isPlaying = false
        clock.stop()
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
        let subStep = (pulseWithinBeat * 4) / subs
        
        // Gated UI mutations: update ONLY when value changes to prevent 50+ FPS redraw loops
        if self.currentMatra != calculatedMatra {
            self.currentMatra = calculatedMatra
        }
        if self.currentMatraSubStep != subStep {
            self.currentMatraSubStep = subStep
        }
        
        let timeline = resolveActiveTimeline()
        guard !timeline.isEmpty else {
            return stepFraction
        }

        // Calculate beat offset in sequence timeline to match against CSV events
        let pulseBeatTime = Double(stepIndex) * stepFraction
        let halfStep = stepFraction * 0.5
        
        // O(log N) binary search instead of linear search
        guard let event = timeline.event(atBeat: pulseBeatTime, tolerance: halfStep) else {
            return stepFraction
        }

        if let b = event.bolName, self.currentBolName != b {
            self.currentBolName = b
        }

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

        // Execute Secondary Stroke for Fixed-Delay Compound Bols (e.g. KDa, Tra flams)
        if let delaySec = event.secondaryDelaySec, let primaryTime = time {
            let delayTicks = clock.secondsToHostTicks(delaySec)
            let secondaryTime = AVAudioTime(hostTime: primaryTime.hostTime + delayTicks)

            if let secLeft = event.secondaryLeftSample,
                let sampleToPlay = sampleRegistry["Bayaan_" + secLeft] {
                _ = self.voicePool.play(
                    sample: sampleToPlay,
                    targetPitchCents: 0,
                    volume: Double(event.leftVolume) * self.effectiveVolume,
                    time: secondaryTime
                )
            }

            if let secRight = event.secondaryRightSample {
                let sampleString = "Dayaan_" + tablaPitch + "_" + surString + secRight
                if let sampleToPlay = sampleRegistry[sampleString] {
                    _ = self.voicePool.play(
                        sample: sampleToPlay,
                        targetPitchCents: orchestrator.scaleOffsetCents
                            + orchestrator.fineTuneCents,
                        volume: Double(event.rightVolume) * self.effectiveVolume,
                        time: secondaryTime
                    )
                }
            }
        }

        return stepFraction
    }
}

// MARK: - Binary Search Timeline Extension

extension Array where Element == TablaStrokeEvent {
    /// O(log N) binary search for the stroke event matching the specified beat time within tolerance.
    func event(atBeat beatTime: Double, tolerance: Double) -> TablaStrokeEvent? {
        var low = 0
        var high = count - 1
        while low <= high {
            let mid = (low + high) / 2
            let event = self[mid]
            let diff = event.startBeatFraction - beatTime
            if abs(diff) < tolerance {
                return event
            } else if diff < 0 {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return nil
    }
}

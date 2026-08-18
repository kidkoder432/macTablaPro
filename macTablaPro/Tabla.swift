//
//  Tabla.swift
//  macTablaPro
//
//  Created by Prajwal Agrawal on 7/18/26.
//

import AVFoundation
import Combine
import Foundation
import os

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
    nonisolated let atomicTablaState = Locked<(taal: String, variation: String, sur: Bool, currentBeat: Double, lastScheduledQuarterBeat: Double)>(
        (taal: "Teentaal", variation: "Pro Default", sur: false, currentBeat: 0.0, lastScheduledQuarterBeat: -0.25)
    )

    @Published var activeTaal: String = "Teentaal" {
        didSet {
            syncAtomicState()
            if isPlaying {
                updateTimelinePosition()
            }
        }
    }
    @Published var activeVariation: String = "Pro Default" {
        didSet {
            syncAtomicState()
            if isPlaying {
                updateTimelinePosition()
            }
        }
    }
    @Published var useSurTabla = false {
        didSet {
            syncAtomicState()
        }
    }
    @Published var logScaleBase: Double = 10.0

    private func syncAtomicState() {
        atomicTablaState.withLock {
            $0.taal = activeTaal
            $0.variation = activeVariation
            $0.sur = useSurTabla
        }
    }

    /// Reference to the centralized high-resolution VSync-aligned presentation engine
    nonisolated let presentationEngine: VisualPresentationEngine

    // Computed properties forwarding directly to the presentation engine
    var currentMatra: Int? { presentationEngine.currentMatra }
    var currentMatraSubStep: Int { presentationEngine.currentMatraSubStep }
    var currentBolName: String { presentationEngine.currentBolName }
    var currentTaalSymbol: String { presentationEngine.currentTaalSymbol }

    override init(id: String, name: String, orchestrator: AppAudioOrchestrator, voicePool: VoicePool, registry: [String: PitchedSample]) {
        self.presentationEngine = VisualPresentationEngine.shared
        super.init(id: id, name: name, orchestrator: orchestrator, voicePool: voicePool, registry: registry)
        syncAtomicState()
    }

    nonisolated private var taalDb: [String: TaalDefinition] {
        TablaDatabase.shared.taalCatalog
    }

    // MARK: - Taal Symbol Helper

    nonisolated static func getTaalSymbol(matra: Int, taal: TaalDefinition?) -> String {
        guard let taal = taal else { return "" }
        if taal.khaaliMatras.contains(matra) {
            return "O"
        }
        let sortedTaalis = taal.taaliMatras.sorted()
        if let taaliIndex = sortedTaalis.firstIndex(of: matra) {
            if matra == 1 {
                return "X"
            } else {
                let number = taaliIndex + (taal.taaliMatras.contains(1) ? 1 : 2)
                return "\(number)"
            }
        }
        return ""
    }

    // MARK: - BPM & Range Calculations

    nonisolated private func minBPM(forTier tier: Int) -> Double {
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

    nonisolated private func maxBPM(forTier tier: Int) -> Double {
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
    }

    // MARK: - Tempo & Tier Management

    /// Maps the current raw tempoBPM to its corresponding Tempo Tier Index
    nonisolated func currentTempoTier(bpm: Double? = nil, taalName: String? = nil, variationName: String? = nil) -> Int {
        let effectiveBPM = bpm ?? atomicBPM.value
        let currentTaal = taalName ?? atomicTablaState.value.taal
        let currentVariation = variationName ?? atomicTablaState.value.variation

        guard let taal = taalDb[currentTaal],
              let variation = taal.variations[currentVariation] else {
            switch effectiveBPM {
            case ..<25: return 0
            case 25..<81: return 1
            case 81..<151: return 2
            case 151..<301: return 3
            default: return 4
            }
        }

        switch effectiveBPM {
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
    nonisolated func resolveActiveTimeline(bpm: Double? = nil, taalName: String? = nil, variationName: String? = nil) -> [TablaStrokeEvent] {
        let effectiveBPM = bpm ?? atomicBPM.value
        let currentTaal = taalName ?? atomicTablaState.value.taal
        let currentVariation = variationName ?? atomicTablaState.value.variation

        guard let taal = taalDb[currentTaal],
            let variation = taal.variations[currentVariation]
        else {
            return []
        }

        let desiredTier = currentTempoTier(bpm: effectiveBPM, taalName: currentTaal, variationName: currentVariation)

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
        if let fallbackTier = variation.allowedTempos.min(by: {
            let mid1 = (minBPM(forTier: $0) + maxBPM(forTier: $0)) / 2.0
            let mid2 = (minBPM(forTier: $1) + maxBPM(forTier: $1)) / 2.0
            return abs(mid1 - effectiveBPM) < abs(mid2 - effectiveBPM)
        }),
            let timeline = variation.timelinesByTempoTier[fallbackTier]
        {
            return timeline
        }

        return variation.timelinesByTempoTier.values.first ?? []
    }

    /// Transitions playback seamlessly to a new timeline, maintaining exact fractional matra position
    func updateTimelinePosition() {
        if isPlaying {
            syncAtomicState()
            let currentBeat = atomicTablaState.value.currentBeat
            let newTotalMatras = taalDb[activeTaal]?.matras ?? 16.0

            if currentBeat >= newTotalMatras {
                // If current beat is past the new Taal's length, reset cleanly to Sam (0.0 / Beat 1)
                atomicTablaState.withLock { $0.currentBeat = 0.0 }
            }
        }
    }

    override func startPlay() {
        guard !isPlaying else { return }
        isPlaying = true
        syncAtomicState()
        atomicTablaState.withLock {
            $0.currentBeat = 0.0
            $0.lastScheduledQuarterBeat = -0.25
        }
        presentationEngine.start()
        clock.start(initialDelaySec: 0.005)
    }

    override func stopPlay() {
        guard isPlaying else { return }
        isPlaying = false
        clock.stop()
        presentationEngine.stop()
        voicePool.stopFuture()
    }

    nonisolated override internal func executeSequenceTick(time: AVAudioTime?) -> Double {
        let currentBPM = atomicBPM.value
        let (currentTaal, currentVariation, surMode, currentBeat, lastScheduledQuarter) = atomicTablaState.value
        let timeline = resolveActiveTimeline(bpm: currentBPM, taalName: currentTaal, variationName: currentVariation)
        
        guard !timeline.isEmpty else {
            return 1.0
        }

        let totalMatras = taalDb[currentTaal]?.matras ?? 16.0
        guard let event = timeline.nextEvent(atOrAfterBeat: currentBeat) else {
            return 1.0
        }

        let startFraction = event.startBeatFraction
        let duration = event.durationFraction
        let endFraction = startFraction + duration

        // Advance to next beat timestamp for subsequent tick
        let nextBeat = endFraction.truncatingRemainder(dividingBy: totalMatras)

        let calculatedMatra = event.matra
        let bolName = event.bolName
        let taalSymbol = Tabla.getTaalSymbol(matra: calculatedMatra, taal: taalDb[currentTaal])
        let primaryHostTime = time?.hostTime ?? mach_absolute_time()
        let activeTier = currentTempoTier(bpm: currentBPM, taalName: currentTaal, variationName: currentVariation)

        if activeTier == 0 {
            // AT-VILAMBIT (Tier 0): Metronomic quarter-matra sub-clock is completely decoupled from stroke events.
            // Enqueue visual quarter-matra pulses strictly for every 0.25 matra boundary [0.0, 0.25, 0.50, 0.75].
            var maxScheduledQ = lastScheduledQuarter
            let firstPossibleQ = max(0.0, floor((lastScheduledQuarter + 0.001) * 4.0 + 1.0) / 4.0)
            var q = (lastScheduledQuarter < 0) ? 0.0 : firstPossibleQ

            while q < endFraction - 0.0001 || (abs(q - startFraction) < 0.0001 && q <= lastScheduledQuarter + 0.25) {
                if q > lastScheduledQuarter + 0.0001 {
                    let offsetSeconds = (q - startFraction) * 60.0 / max(1.0, currentBPM)
                    let qHostTime = primaryHostTime + clock.secondsToHostTicks(offsetSeconds)
                    let qSubStep = Int(round((q.truncatingRemainder(dividingBy: 1.0)) * 4.0)) % 4
                    let qMatra = Int(floor(q.truncatingRemainder(dividingBy: totalMatras))) + 1
                    let qSymbol = (qSubStep == 0) ? Tabla.getTaalSymbol(matra: qMatra, taal: taalDb[currentTaal]) : nil

                    let quarterPulse = VisualBeatEvent(
                        matra: qMatra,
                        subStep: qSubStep,
                        bolName: nil,
                        taalSymbol: qSymbol,
                        targetHostTime: qHostTime
                    )
                    presentationEngine.ringBuffer.push(quarterPulse)
                    maxScheduledQ = max(maxScheduledQ, q)
                }
                q += 0.25
                if q > endFraction + 0.001 { break }
            }

            atomicTablaState.withLock {
                $0.currentBeat = nextBeat
                $0.lastScheduledQuarterBeat = maxScheduledQ
            }

            // Enqueue the stroke event with subStep = nil so strokes never perturb the 0.25 metronomic dots
            let strokeEvent = VisualBeatEvent(
                matra: calculatedMatra,
                subStep: nil,
                bolName: bolName,
                taalSymbol: taalSymbol,
                targetHostTime: primaryHostTime
            )
            presentationEngine.ringBuffer.push(strokeEvent)
        } else {
            atomicTablaState.withLock { $0.currentBeat = nextBeat }

            // In Ati-Drut (Tier 4: BPM > 300), only enqueue visual events on Khand / Vibhag boundaries (Taali/Khaali beats)
            // to minimize UI redraw churn and prevent strobing at ultra-high speeds (300-700 BPM)
            if activeTier != 4 || !taalSymbol.isEmpty {
                let subStep = Int(round((event.startBeatFraction.truncatingRemainder(dividingBy: 1.0)) * 4.0)) % 4
                let visualEvent = VisualBeatEvent(
                    matra: calculatedMatra,
                    subStep: subStep,
                    bolName: bolName,
                    taalSymbol: taalSymbol,
                    targetHostTime: primaryHostTime
                )
                presentationEngine.ringBuffer.push(visualEvent)
            }
        }

        // Execute Left Hand (Bayan)
        if let leftSample = event.leftSampleName,
            let sampleToPlay = sampleRegistry["Bayaan_" + leftSample] {
            _ = self.voicePool.play(
                sample: sampleToPlay,
                targetPitchCents: 0,
                volume: Double(event.leftVolume),
                time: time
            )
        }

        // Execute Right Hand (Dayan)
        let liveScaleOffset = orchestrator.atomicScaleOffsetCents
        let liveFineTune = orchestrator.atomicFineTuneCents

        let tablaPitch: String =
            liveScaleOffset <= 400 ? "C#" : "G#"
        
        let forceSur = taalDb[currentTaal]?.forceSur ?? false
        let isSur = forceSur || surMode
        
        var surString: String = ""
        if tablaPitch == "C#" {
            surString = isSur ? "Sur_" : "Tip_"
        }

        if let bol = event.rightSampleName {
            let sampleString = "Dayaan_" + tablaPitch + "_" + surString + bol
            if let sampleToPlay = sampleRegistry[sampleString] {
                _ = self.voicePool.play(
                    sample: sampleToPlay,
                    targetPitchCents: liveScaleOffset + liveFineTune,
                    volume: Double(event.rightVolume),
                    time: time
                )
            }
        }

        // OSLog structured telemetry
        AudioLogger.logTablaStroke(
            bol: event.bolName ?? "Rest",
            matra: event.matra,
            beatFraction: event.startBeatFraction,
            sample: (event.rightSampleName ?? "") + (event.leftSampleName.map { " / " + $0 } ?? ""),
            hostTime: time?.hostTime ?? 0
        )

        // Execute Secondary Stroke for Fixed-Delay Compound Bols (e.g. KDa, Tra flams)
        if let delaySec = event.secondaryDelaySec, let primaryTime = time {
            let delayTicks = clock.secondsToHostTicks(delaySec)
            let secondaryTime = AVAudioTime(hostTime: primaryTime.hostTime + delayTicks)

            if let secLeft = event.secondaryLeftSample,
                let sampleToPlay = sampleRegistry["Bayaan_" + secLeft] {
                _ = self.voicePool.play(
                    sample: sampleToPlay,
                    targetPitchCents: 0,
                    volume: Double(event.leftVolume),
                    time: secondaryTime
                )
            }

            if let secRight = event.secondaryRightSample {
                let sampleString = "Dayaan_" + tablaPitch + "_" + surString + secRight
                if let sampleToPlay = sampleRegistry[sampleString] {
                    _ = self.voicePool.play(
                        sample: sampleToPlay,
                        targetPitchCents: liveScaleOffset + liveFineTune,
                        volume: Double(event.rightVolume),
                        time: secondaryTime
                    )
                }
            }
        }

        return max(0.001, event.durationFraction)
    }
}

// MARK: - Binary Search Timeline Extension

extension Array where Element == TablaStrokeEvent {
    /// O(log N) binary search for the stroke event matching or immediately following the specified beat time.
    nonisolated func nextEvent(atOrAfterBeat targetBeat: Double, tolerance: Double = 0.001) -> TablaStrokeEvent? {
        guard !isEmpty else { return nil }
        
        var low = 0
        var high = count - 1
        var candidateIndex = 0
        
        while low <= high {
            let mid = (low + high) / 2
            let event = self[mid]
            if abs(event.startBeatFraction - targetBeat) < tolerance {
                return event
            } else if event.startBeatFraction < targetBeat {
                low = mid + 1
            } else {
                candidateIndex = mid
                high = mid - 1
            }
        }
        
        if low < count {
            return self[low]
        } else if candidateIndex < count && self[candidateIndex].startBeatFraction >= targetBeat - tolerance {
            return self[candidateIndex]
        }
        return self.first
    }
}

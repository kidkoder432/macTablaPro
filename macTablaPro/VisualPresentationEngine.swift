//
//  VisualPresentationEngine.swift
//  macTablaPro
//
//  High-resolution VSync-aligned presentation engine.
//  Reads timestamped VisualBeatEvents from the SPSCRingBuffer and updates
//  SwiftUI state on @MainActor at the exact instant audio exits physical speakers.
//

import AppKit
import Combine
import CoreAudio
import Foundation

nonisolated public struct VisualBeatEvent: Sendable {
    public let matra: Int
    public let subStep: Int
    public let bolName: String?
    public let taalSymbol: String
    public let targetHostTime: UInt64

    public init(
        matra: Int,
        subStep: Int,
        bolName: String?,
        taalSymbol: String,
        targetHostTime: UInt64
    ) {
        self.matra = matra
        self.subStep = subStep
        self.bolName = bolName
        self.taalSymbol = taalSymbol
        self.targetHostTime = targetHostTime
    }
}

@MainActor
public final class VisualPresentationEngine: ObservableObject {
    public static let shared = VisualPresentationEngine()

    // MARK: - Published Presentation State
    @Published public var currentMatra: Int = 1
    @Published public var currentMatraSubStep: Int = 0
    @Published public var currentBolName: String = ""
    @Published public var currentTaalSymbol: String = ""
    
    /// Dynamic CoreAudio / Bluetooth latency compensation in milliseconds [-300ms ... +300ms]
    @Published public var visualLatencyOffsetMs: Double = 25.0
    
    /// Indicates whether the user has manually set a custom latency offset or is using the auto-detected CoreAudio value
    @Published public var isCustomLatency: Bool = false

    // MARK: - Event Queue
    nonisolated public let ringBuffer: SPSCRingBuffer<VisualBeatEvent>

    // MARK: - Display Loop
    private var displayTimer: DispatchSourceTimer?
    private var isRunning: Bool = false

    private init() {
        self.ringBuffer = SPSCRingBuffer<VisualBeatEvent>(capacity: 64)
        
        let isCustom = UserDefaults.standard.bool(forKey: "IsCustomVisualLatency")
        if isCustom && UserDefaults.standard.object(forKey: "CustomVisualLatencyOffsetMs") != nil {
            let saved = UserDefaults.standard.double(forKey: "CustomVisualLatencyOffsetMs")
            self.visualLatencyOffsetMs = round(saved)
            self.isCustomLatency = true
        } else {
            let detected = Self.detectCoreAudioOutputLatencyMs()
            self.visualLatencyOffsetMs = detected
            self.isCustomLatency = false
        }
    }

    // MARK: - CoreAudio Hardware Latency Detection

    /// Queries the default output audio device for hardware DAC latency, safety offset, and buffer size.
    nonisolated public static func detectCoreAudioOutputLatencyMs() -> Double {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr, deviceID != 0 else { return 25.0 }

        var latencyFrames: UInt32 = 0
        var latencySize = UInt32(MemoryLayout<UInt32>.size)
        var latencyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyLatency,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &latencyAddress, 0, nil, &latencySize, &latencyFrames)

        var safetyFrames: UInt32 = 0
        var safetySize = UInt32(MemoryLayout<UInt32>.size)
        var safetyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertySafetyOffset,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &safetyAddress, 0, nil, &safetySize, &safetyFrames)

        var bufferFrames: UInt32 = 512
        var bufferSize = UInt32(MemoryLayout<UInt32>.size)
        var bufferAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &bufferAddress, 0, nil, &bufferSize, &bufferFrames)

        var sampleRate: Float64 = 44100.0
        var srSize = UInt32(MemoryLayout<Float64>.size)
        var srAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &srAddress, 0, nil, &srSize, &sampleRate)

        let totalFrames = Double(latencyFrames + safetyFrames + bufferFrames)
        let latencyMs = (totalFrames / max(1.0, sampleRate)) * 1000.0
        return max(0.0, round(latencyMs))
    }

    /// Automatically measures and sets the latency offset to match current audio output device.
    @discardableResult
    public func autoDetectLatency() -> Double {
        let detected = Self.detectCoreAudioOutputLatencyMs()
        self.visualLatencyOffsetMs = detected
        self.isCustomLatency = false
        UserDefaults.standard.set(false, forKey: "IsCustomVisualLatency")
        return detected
    }

    /// Sets a user-customized latency offset and persists it to preferences.
    public func setCustomLatency(_ ms: Double) {
        let rounded = round(max(-300.0, min(300.0, ms)))
        self.visualLatencyOffsetMs = rounded
        self.isCustomLatency = true
        UserDefaults.standard.set(true, forKey: "IsCustomVisualLatency")
        UserDefaults.standard.set(rounded, forKey: "CustomVisualLatencyOffsetMs")
    }

    /// Resets latency back to the auto-detected hardware value.
    public func resetToAutoLatency() {
        autoDetectLatency()
    }

    /// Starts the high-frequency presentation consumer loop on the main thread.
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: DispatchQueue.main)
        // Check at 120Hz (every ~8.33ms) for sub-millisecond visual frame accuracy
        timer.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.processPendingEvents()
        }
        timer.resume()
        self.displayTimer = timer
    }

    /// Stops the presentation consumer loop and resets state.
    public func stop() {
        isRunning = false
        displayTimer?.cancel()
        displayTimer = nil
        ringBuffer.clear()
        
        currentMatra = 1
        currentMatraSubStep = 0
        currentBolName = ""
        currentTaalSymbol = ""
    }

    /// Resets presentation state without stopping the timer.
    public func reset() {
        ringBuffer.clear()
        currentMatra = 1
        currentMatraSubStep = 0
        currentBolName = ""
        currentTaalSymbol = ""
    }

    // MARK: - Frame Processing

    private func processPendingEvents() {
        let now = mach_absolute_time()
        let offsetTicks = msToHostTicks(visualLatencyOffsetMs)
        
        var latestEvent: VisualBeatEvent? = nil

        // Drain any events whose target host time (plus latency offset) has arrived
        while let nextEvent = ringBuffer.peek() {
            let baseTarget = Int64(nextEvent.targetHostTime)
            let effectiveTarget = UInt64(max(0, baseTarget + offsetTicks))
            if now >= effectiveTarget {
                latestEvent = ringBuffer.pop()
            } else {
                // Future event: stop consuming and wait for subsequent frames
                break
            }
        }

        // Apply only the latest valid event to avoid unnecessary intermediate redraws
        if let event = latestEvent {
            if self.currentMatra != event.matra {
                self.currentMatra = event.matra
            }
            if self.currentMatraSubStep != event.subStep {
                self.currentMatraSubStep = event.subStep
            }
            if let newBol = event.bolName, !newBol.isEmpty {
                self.currentBolName = newBol
            }
            if self.currentTaalSymbol != event.taalSymbol {
                self.currentTaalSymbol = event.taalSymbol
            }
        }
    }

    // MARK: - Timing Conversion

    private func msToHostTicks(_ ms: Double) -> Int64 {
        guard ms != 0 else { return 0 }
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        let ns = ms * 1e6
        let ticks = Double(ns) * Double(info.denom) / Double(info.numer)
        return Int64(ticks)
    }
}

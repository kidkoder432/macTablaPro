//
//  LookaheadAudioScheduler.swift
//  macTablaPro
//
//  Created for User Implementation - Level 2 Ahead-of-Time AVAudioTime Host Scheduler
//

import AVFoundation
import Darwin
import Foundation

@MainActor
class LookaheadAudioScheduler {
    private var schedulerTask: Task<Void, Never>?
    private let tickCallback: (Int, AVAudioTime) -> Double
    private let getBPM: () -> Double

    /// The lookahead window duration in seconds (100ms)
    let lookaheadWindowSec: Double = 0.100

    init(
        getBPM: @escaping () -> Double,
        onTick: @escaping (Int, AVAudioTime) -> Double
    ) {
        self.getBPM = getBPM
        self.tickCallback = onTick
    }

    // MARK: - 1. Time Conversion Helpers (STUBS FOR YOU TO IMPLEMENT)

    /// Converts a time interval in seconds to CPU mach_absolute_time host ticks.
    func secondsToHostTicks(_ seconds: Double) -> UInt64 {
        var info: mach_timebase_info = .init()
        mach_timebase_info(&info)
        let ns = UInt64(seconds * 1e9)
        return UInt64(ns * UInt64(info.denom) / UInt64(info.numer))

    }

    /// Converts CPU mach_absolute_time host ticks to a time interval in seconds.
    func hostTicksToSeconds(_ ticks: UInt64) -> Double {
        var info: mach_timebase_info = .init()
        mach_timebase_info(&info)
        let ns = Double(ticks) * Double(info.numer) / Double(info.denom)
        return ns / 1e9
    }

    // MARK: - 2. Ahead-of-Time Loop (STUBS FOR YOU TO IMPLEMENT)

    /// Starts the ahead-of-time lookahead scheduler loop.
    /// - Parameters:
    ///   - stepsCount: Total steps in the active sequence.
    ///   - startingAtStep: Step index to begin scheduling from.
    func start(stepsCount: Int, startingAtStep: Int = 0) {
        schedulerTask?.cancel()

        schedulerTask = Task {
            var currentTicks = mach_absolute_time() + secondsToHostTicks(0.05)
            var stepIndex = startingAtStep

            while !Task.isCancelled {

                let boundaryTicks =
                    mach_absolute_time() + secondsToHostTicks(lookaheadWindowSec)

                while currentTicks < boundaryTicks {
                    if Task.isCancelled {
                        return
                    }
                    let durationFraction = await MainActor.run {
                        tickCallback(
                            stepIndex,
                            AVAudioTime(hostTime: currentTicks)
                        )
                    }
                    let safeFraction =
                        durationFraction > 0 ? durationFraction : 1.0

                    let seconds = safeFraction * 60.0 / getBPM()
                    currentTicks += secondsToHostTicks(seconds)
                    
                    stepIndex = (stepIndex + 1) % (stepsCount > 0 ? stepsCount : 1)
                }
                try? await Task.sleep(nanoseconds: UInt64(2.5e7))

            }
        }
    }

    /// Stops the ahead-of-time scheduler loop.
    func stop() {
        schedulerTask?.cancel()
        schedulerTask = nil
    }
}

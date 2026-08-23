//
//  LookaheadAudioScheduler.swift
//  macTablaPro
//
//  Dedicated Ahead-of-Time AVAudioTime Host Scheduler.
//  Runs on a dedicated high-priority background queue (.userInteractive QoS)
//  to guarantee audio timing accuracy regardless of UI activity.
//

import AVFoundation
import Darwin
import Foundation
import os

nonisolated public final class LookaheadAudioScheduler: @unchecked Sendable {
    private let schedulerQueue = DispatchQueue(
        label: "com.macTablaPro.audioScheduler",
        qos: .userInteractive,
        attributes: []
    )
    
    private var schedulerTimer: DispatchSourceTimer?
    private var isRunning: Bool = false
    private let lock = os_unfair_lock_t.allocate(capacity: 1)

    private let tickCallback: @Sendable (AVAudioTime) -> Double
    private let getBPM: @Sendable () -> Double

    public let lookaheadWindowSec: Double = 0.100

    public init(
        getBPM: @escaping @Sendable () -> Double,
        onTick: @escaping @Sendable (AVAudioTime) -> Double
    ) {
        self.getBPM = getBPM
        self.tickCallback = onTick
        self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
        stop()
        lock.deallocate()
    }

    // MARK: - 1. Time Conversion Helpers

    /// Converts a time interval in seconds to CPU mach_absolute_time host ticks.
    public func secondsToHostTicks(_ seconds: Double) -> UInt64 {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        let ns = UInt64(abs(seconds) * 1e9)
        return UInt64(ns * UInt64(info.denom) / UInt64(info.numer))
    }

    /// Converts CPU mach_absolute_time host ticks to a time interval in seconds.
    public func hostTicksToSeconds(_ ticks: UInt64) -> Double {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        let ns = Double(ticks) * Double(info.numer) / Double(info.denom)
        return ns / 1e9
    }

    // MARK: - 2. Ahead-of-Time Scheduling Loop

    /// - Parameters:
    ///   - initialDelaySec: Lead time in seconds before the first tick sounds (default 0.025s = 25ms to guarantee attack transient clarity).
    public func start(initialDelaySec: Double = 0.025) {
        stop()

        os_unfair_lock_lock(lock)
        isRunning = true
        os_unfair_lock_unlock(lock)

        let targetLookahead = self.lookaheadWindowSec
        let onTick = self.tickCallback
        let bpmProvider = self.getBPM

        schedulerQueue.async { [weak self] in
            guard let self = self else { return }

            var currentTicks = mach_absolute_time() + self.secondsToHostTicks(initialDelaySec)

            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: self.schedulerQueue)
            // Wake up every 25ms to keep lookahead buffer filled 100ms in advance
            timer.schedule(deadline: .now(), repeating: .milliseconds(25), leeway: .milliseconds(2))

            timer.setEventHandler { [weak self] in
                guard let self = self else { return }

                os_unfair_lock_lock(self.lock)
                let active = self.isRunning
                os_unfair_lock_unlock(self.lock)

                guard active else { return }

                let boundaryTicks = mach_absolute_time() + self.secondsToHostTicks(targetLookahead)

                while currentTicks < boundaryTicks {
                    os_unfair_lock_lock(self.lock)
                    let stillActive = self.isRunning
                    os_unfair_lock_unlock(self.lock)
                    if !stillActive { return }

                    let durationBeats = onTick(AVAudioTime(hostTime: currentTicks))
                    let safeDuration = max(0.001, durationBeats)
                    let seconds = safeDuration * 60.0 / max(1.0, bpmProvider())
                    currentTicks += self.secondsToHostTicks(seconds)
                }
            }

            self.schedulerTimer = timer
            timer.resume()
        }
    }

    /// Stops the ahead-of-time scheduler loop.
    public func stop() {
        os_unfair_lock_lock(lock)
        isRunning = false
        os_unfair_lock_unlock(lock)

        schedulerTimer?.cancel()
        schedulerTimer = nil
    }

    /// Runs a single non-looping pass of N ticks on the background queue.
    public func triggerSinglePass(ticks: Int) {
        let onTick = self.tickCallback
        let bpmProvider = self.getBPM

        schedulerQueue.async { [weak self] in
            guard let self = self else { return }
            var currentTicks = mach_absolute_time() + self.secondsToHostTicks(0.01)
            for _ in 0..<ticks {
                let durationBeats = onTick(AVAudioTime(hostTime: currentTicks))
                let safeDuration = max(0.001, durationBeats)
                let seconds = safeDuration * 60.0 / max(1.0, bpmProvider())
                currentTicks += self.secondsToHostTicks(seconds)
            }
        }
    }
}

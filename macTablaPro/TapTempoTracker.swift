//
//  TapTempoTracker.swift
//  macTablaPro
//
//  Monotonic tap tempo tracking engine.
//  Maintains a rolling sample buffer of recent tap timestamps,
//  automatically detects pauses/timeouts, and computes dynamic BPM.
//

import Foundation
import os

nonisolated public final class TapTempoTracker: @unchecked Sendable {
    public let minSamples: Int
    public let maxSamples: Int
    public let timeoutInterval: TimeInterval

    private var lock = os_unfair_lock()
    private var _tapTimestamps: [TimeInterval] = []

    /// Monotonic timestamps of recent taps
    public var tapTimestamps: [TimeInterval] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _tapTimestamps
    }

    /// Creates a tap tempo tracker with configurable sample requirements and timeout threshold.
    /// - Parameters:
    ///   - minSamples: Minimum number of taps required before activating tempo calculation (default 4).
    ///   - maxSamples: Maximum number of recent taps to maintain in the rolling buffer (default 5).
    ///   - timeoutInterval: Maximum time (in seconds) between taps before history resets (default 2.0s).
    public init(minSamples: Int = 4, maxSamples: Int = 5, timeoutInterval: TimeInterval = 2.0) {
        let safeMin = max(2, minSamples)
        self.minSamples = safeMin
        self.maxSamples = max(safeMin, maxSamples)
        self.timeoutInterval = max(0.5, timeoutInterval)
    }

    /// Records a new tap event at the specified monotonic timestamp.
    /// Automatically resets the buffer if the interval exceeds `timeoutInterval`.
    /// - Parameter timestamp: Monotonic time in seconds (defaults to `ProcessInfo.processInfo.systemUptime`).
    /// - Returns: Newly computed BPM if `minSamples` or more active samples exist, or `nil` otherwise.
    @discardableResult
    public func recordTap(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Double? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        if let last = _tapTimestamps.last, (timestamp - last) > timeoutInterval {
            _tapTimestamps.removeAll()
        }

        _tapTimestamps.append(timestamp)

        if _tapTimestamps.count > maxSamples {
            _tapTimestamps.removeFirst(_tapTimestamps.count - maxSamples)
        }

        return calculateBPMInternal()
    }

    /// Computes the average BPM from the rolling delta intervals between consecutive taps.
    /// - Returns: Calculated BPM as a Double, or `nil` if fewer than `minSamples` taps have been recorded.
    public func calculateBPM() -> Double? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return calculateBPMInternal()
    }

    private func calculateBPMInternal() -> Double? {
        guard _tapTimestamps.count >= minSamples else { return nil }

        // Compute adjacent inter-tap intervals (deltas in seconds)
        var intervals: [Double] = []
        for i in 1..<_tapTimestamps.count {
            let delta = _tapTimestamps[i] - _tapTimestamps[i - 1]
            if delta > 0.0001 {
                intervals.append(delta)
            }
        }

        guard !intervals.isEmpty else { return nil }

        let averageInterval = intervals.reduce(0.0, +) / Double(intervals.count)
        guard averageInterval > 0 else { return nil }

        let calculatedBPM = 60.0 / averageInterval
        return calculatedBPM
    }

    /// Clears all recorded tap history.
    public func reset() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        _tapTimestamps.removeAll()
    }

    /// Returns the number of currently active tap timestamps in the buffer.
    public var sampleCount: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _tapTimestamps.count
    }
}

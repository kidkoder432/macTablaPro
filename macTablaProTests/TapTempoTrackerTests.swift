//
//  TapTempoTrackerTests.swift
//  macTablaProTests
//
//  Unit tests for monotonic tap tempo tracking, rolling sample buffer,
//  minSamples activation threshold, timeout auto-reset, and edge cases.
//

import XCTest
@testable import macTablaPro

final class TapTempoTrackerTests: XCTestCase {
    
    func testSingleTapReturnsNil() {
        let tracker = TapTempoTracker(minSamples: 4, maxSamples: 5, timeoutInterval: 2.0)
        let result = tracker.recordTap(at: 100.0)
        XCTAssertNil(result, "First tap must return nil because minimum threshold is not met.")
        XCTAssertEqual(tracker.sampleCount, 1)
    }

    func testTapsBelowMinSamplesReturnNil() {
        let tracker = TapTempoTracker(minSamples: 4, maxSamples: 5, timeoutInterval: 2.0)
        XCTAssertNil(tracker.recordTap(at: 100.0), "Tap 1 must return nil")
        XCTAssertNil(tracker.recordTap(at: 100.5), "Tap 2 must return nil (below minSamples 4)")
        XCTAssertNil(tracker.recordTap(at: 101.0), "Tap 3 must return nil (below minSamples 4)")
        XCTAssertEqual(tracker.sampleCount, 3)
    }

    func testReachingMinSamplesActivatesBPMCalculation() {
        let tracker = TapTempoTracker(minSamples: 4, maxSamples: 5, timeoutInterval: 2.0)
        tracker.recordTap(at: 100.0) // Tap 1
        tracker.recordTap(at: 100.5) // Tap 2
        tracker.recordTap(at: 101.0) // Tap 3
        
        // Tap 4 (0.5s interval -> 120 BPM)
        let bpm = tracker.recordTap(at: 101.5)
        XCTAssertNotNil(bpm, "Tap 4 reaches minSamples threshold and must return calculated BPM")
        XCTAssertEqual(bpm!, 120.0, accuracy: 0.001)
        XCTAssertEqual(tracker.sampleCount, 4)

        // Tap 5 continues updating live
        let nextBPM = tracker.recordTap(at: 102.0)
        XCTAssertNotNil(nextBPM)
        XCTAssertEqual(nextBPM!, 120.0, accuracy: 0.001)
        XCTAssertEqual(tracker.sampleCount, 5)
    }

    func testRollingBufferEnforcesMaxCapacity() {
        let tracker = TapTempoTracker(minSamples: 4, maxSamples: 5, timeoutInterval: 2.0)
        var t = 10.0
        // Record 8 taps at 0.5s intervals (120 BPM)
        for _ in 0..<8 {
            _ = tracker.recordTap(at: t)
            t += 0.5
        }
        XCTAssertEqual(tracker.sampleCount, 5, "Buffer must cap at maxSamples (5).")
        let bpm = tracker.calculateBPM()
        XCTAssertNotNil(bpm)
        XCTAssertEqual(bpm!, 120.0, accuracy: 0.001)
    }

    func testTimeoutResetsBufferAndRequiresMinSamplesAgain() {
        let tracker = TapTempoTracker(minSamples: 4, maxSamples: 5, timeoutInterval: 2.0)
        tracker.recordTap(at: 10.0)
        tracker.recordTap(at: 10.5)
        tracker.recordTap(at: 11.0)
        let initialBPM = tracker.recordTap(at: 11.5) // 120 BPM
        XCTAssertNotNil(initialBPM)
        XCTAssertEqual(tracker.sampleCount, 4)

        // Gap of 3.0 seconds (exceeds timeout of 2.0s)
        let resetTap1 = tracker.recordTap(at: 14.5)
        XCTAssertNil(resetTap1, "Tap occurring after timeout interval must reset the buffer and return nil.")
        XCTAssertEqual(tracker.sampleCount, 1)

        // Taps 2 & 3 after timeout must return nil until minSamples is met
        XCTAssertNil(tracker.recordTap(at: 15.25)) // delta 0.75s
        XCTAssertNil(tracker.recordTap(at: 16.00)) // delta 0.75s

        // Tap 4 reaches minSamples again (0.75s interval -> 80 BPM)
        let newBPM = tracker.recordTap(at: 16.75)
        XCTAssertNotNil(newBPM)
        XCTAssertEqual(newBPM!, 80.0, accuracy: 0.001)
    }

    func testIrregularTapsMovingAverage() {
        let tracker = TapTempoTracker(minSamples: 4, maxSamples: 4, timeoutInterval: 2.0)
        // Intervals: 0.5s, 0.6s, 0.4s -> mean delta = 0.5s -> 120 BPM
        tracker.recordTap(at: 0.0)
        tracker.recordTap(at: 0.5) // delta 0.5
        tracker.recordTap(at: 1.1) // delta 0.6
        let bpm = tracker.recordTap(at: 1.5) // delta 0.4

        XCTAssertNotNil(bpm)
        XCTAssertEqual(bpm!, 120.0, accuracy: 0.001)
    }

    func testExplicitReset() {
        let tracker = TapTempoTracker(minSamples: 2, maxSamples: 5, timeoutInterval: 2.0)
        tracker.recordTap(at: 1.0)
        tracker.recordTap(at: 1.5)
        XCTAssertEqual(tracker.sampleCount, 2)

        tracker.reset()
        XCTAssertEqual(tracker.sampleCount, 0)
        XCTAssertNil(tracker.calculateBPM())
    }
}

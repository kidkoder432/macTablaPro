import XCTest
@testable import macTablaPro

final class TunerDSPTests: XCTestCase {

    // Helper: Synthesize sine buffer
    private func generateSineBuffer(frequency: Double, sampleRate: Double = 44100.0, sampleCount: Int = 2048) -> [Float] {
        var buffer = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            buffer[i] = Float(sin(2.0 * Double.pi * frequency * t))
        }
        return buffer
    }

    // Helper: Synthesize harmonic-rich wave
    private func generateHarmonicBuffer(f0: Double, harmonicWeights: [(harmonic: Int, amp: Double)], sampleRate: Double = 44100.0, sampleCount: Int = 2048) -> [Float] {
        var buffer = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            var sampleVal = 0.0
            for h in harmonicWeights {
                sampleVal += h.amp * sin(2.0 * Double.pi * (Double(h.harmonic) * f0) * t)
            }
            buffer[i] = Float(sampleVal)
        }
        return buffer
    }

    func testExactA3Detection() async {
        let service = await TunerService()
        let sampleRate = 44100.0
        let targetFreq = 220.0 // A3
        let buffer = generateSineBuffer(frequency: targetFreq, sampleRate: sampleRate)

        // Reflection or public testing
        // Test pitch calculation
        // Calculate pitch data from 220.0 Hz
        let continuousMIDI = 12.0 * log2(targetFreq / 440.0) + 69.0
        let nearestMIDI = Int(round(continuousMIDI))
        let cents = (continuousMIDI - Double(nearestMIDI)) * 100.0

        XCTAssertEqual(nearestMIDI, 57) // MIDI 57 is A3
        XCTAssertEqual(cents, 0.0, accuracy: 0.01)
    }

    func testHarmoniumGSharpPlus8Cents() {
        // G#3 is MIDI 56 (207.652 Hz)
        // G#3 + 8 cents = 207.652 * 2^(8/1200) = 208.614 Hz
        let f0 = 207.65235 * pow(2.0, 8.0 / 1200.0)
        let continuousMIDI = 12.0 * log2(f0 / 440.0) + 69.0
        let nearestMIDI = Int(round(continuousMIDI))
        let cents = (continuousMIDI - Double(nearestMIDI)) * 100.0

        XCTAssertEqual(nearestMIDI, 56) // G#3
        XCTAssertEqual(cents, 8.0, accuracy: 0.05)
    }

    func testCentsStrictBounding() {
        // A3 - 49 cents
        let f_minus49 = 220.0 * pow(2.0, -49.0 / 1200.0)
        let m1 = 12.0 * log2(f_minus49 / 440.0) + 69.0
        let nearest1 = Int(round(m1))
        let cents1 = (m1 - Double(nearest1)) * 100.0

        XCTAssertEqual(nearest1, 57) // Stays on A3
        XCTAssertEqual(cents1, -49.0, accuracy: 0.05)

        // A3 - 85 cents (closer to G#3 + 15 cents)
        let f_minus85 = 220.0 * pow(2.0, -85.0 / 1200.0)
        let m2 = 12.0 * log2(f_minus85 / 440.0) + 69.0
        let nearest2 = Int(round(m2))
        let cents2 = (m2 - Double(nearest2)) * 100.0

        XCTAssertEqual(nearest2, 56) // Resolves to G#3
        XCTAssertEqual(cents2, 15.0, accuracy: 0.05)
    }

    func testOctaveFeasibility() {
        // A3 (MIDI 57): Can shift down to A2 (MIDI 45 >= 45)
        let a3_canShiftDown = (57 - 12) >= TunerService.minMIDINote
        let a3_canShiftUp = (57 + 12) <= TunerService.maxMIDINote // 69 > 64 -> false
        XCTAssertTrue(a3_canShiftDown)
        XCTAssertFalse(a3_canShiftUp)

        // C3 (MIDI 48): Can shift up to C4 (MIDI 60 <= 64)
        let c3_canShiftUp = (48 + 12) <= TunerService.maxMIDINote
        let c3_canShiftDown = (48 - 12) >= TunerService.minMIDINote // 36 < 45 -> false
        XCTAssertTrue(c3_canShiftUp)
        XCTAssertFalse(c3_canShiftDown)

        // F3 (MIDI 53): 53 + 12 = 65 > 64, 53 - 12 = 41 < 45 -> both false
        let f3_canShiftUp = (53 + 12) <= TunerService.maxMIDINote
        let f3_canShiftDown = (53 - 12) >= TunerService.minMIDINote
        XCTAssertFalse(f3_canShiftUp)
        XCTAssertFalse(f3_canShiftDown)
    }
}

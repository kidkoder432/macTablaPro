import AVFoundation
import Accelerate
import Combine
import Foundation

// MARK: - Tuner Pitch Data Model
struct TunerPitchData: Sendable {
    let rawFrequencyHz: Double
    let noteName: String
    let midiNoteNumber: Int
    let centsOffset: Double       // Bounded strictly in [-50.0, +50.0]
    let scaleOffsetCents: Double   // Relative to C3 (0 cents)
    let canShiftOctaveUp: Bool
    let canShiftOctaveDown: Bool
}

// MARK: - Dedicated AVCaptureSession Tuner Service
@MainActor
final class TunerService: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    // 1. Published State for UI
    @Published var isListening: Bool = false
    @Published var hasMicPermission: Bool = true
    @Published var inputLevelRMS: Float = 0.0          // Normalized 0.0 ... 1.0
    @Published var inputLevelDBFS: Float = -100.0      // Decibels Full Scale
    @Published var detectedPitch: TunerPitchData? = nil
    @Published var smoothedCents: Double = 0.0          // EMA smoothed needle angle
    @Published var isSignalDetected: Bool = false

    // 2. Configurable DSP & Audio Capture Parameters
    // -------------------------------------------------------------------------
    // Configurable Analysis Rate (Updates Per Second):
    // - 5.0  = updates every 200ms (ultra-calm, rock-solid, zero flutter)
    // - 8.0  = updates every 125ms (smooth and steady, balanced default)
    // - 10.0 = updates every 100ms (crisp and responsive)
    nonisolated static let targetUpdatesPerSecond: Double = 8.0

    // Configurable needle smoothing factor (0.05 to 0.20)
    nonisolated static let needleDampingAlpha: Double = 0.15

    private var session: AVCaptureSession?
    private let captureQueue = DispatchQueue(label: "com.macTablaPro.tunerCapture", qos: .userInteractive)
    nonisolated static let noiseGateThresholdDBFS: Float = -48.0
    nonisolated static let analysisWindowSize: Int = 2048

    // Background DSP Processing State (isolated exclusively to captureQueue)
    nonisolated(unsafe) private var backgroundRollingBuffer: [Float] = []
    nonisolated(unsafe) private var lastAnalysisTime: CFAbsoluteTime = 0.0
    nonisolated(unsafe) private var smoothedF0: Double = 0.0
    nonisolated(unsafe) private var smoothedRMS: Float = 0.0

    // Supported Note Gamut Range (A2 = MIDI 45 ... E4 = MIDI 64)
    nonisolated static let minMIDINote: Int = 45 // A2
    nonisolated static let maxMIDINote: Int = 64 // E4
    nonisolated static let baseC3MIDI: Int = 48  // C3 (0 scaleOffsetCents)

    nonisolated static let allNoteNames: [String] = [
        "A2", "A#2", "B2", "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3",
        "G3", "G#3", "A3", "A#3", "B3", "C4", "C#4", "D4", "D#4", "E4"
    ]

    // Pitch Class Names
    nonisolated static let pitchClassNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - Lifecycle Management

    func start() {
        guard !isListening else { return }

        // Check/Request Microphone Authorization
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicPermission = true
            startCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicPermission = granted
                    if granted {
                        self?.startCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            hasMicPermission = false
            print("⚠️ TunerService: Microphone access denied or restricted by user/system.")
        @unknown default:
            hasMicPermission = false
        }
    }

    func stop() {
        guard isListening else { return }
        stopCaptureSession()
        inputLevelRMS = 0.0
        inputLevelDBFS = -100.0
        detectedPitch = nil
        isSignalDetected = false
    }

    // MARK: - AVCaptureSession Setup

    private func startCaptureSession() {
        let newSession = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("❌ TunerService: Could not access default audio input device.")
            return
        }

        if newSession.canAddInput(input) {
            newSession.addInput(input)
        }

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)

        if newSession.canAddOutput(output) {
            newSession.addOutput(output)
        }

        captureQueue.async {
            self.backgroundRollingBuffer = [Float](repeating: 0.0, count: Self.analysisWindowSize)
            self.lastAnalysisTime = 0.0
            self.smoothedF0 = 0.0
            self.smoothedRMS = 0.0
            newSession.startRunning()
        }

        self.session = newSession
        self.isListening = true
    }

    private func stopCaptureSession() {
        if let session = self.session {
            captureQueue.async {
                session.stopRunning()
                self.backgroundRollingBuffer.removeAll()
            }
            self.session = nil
        }
        self.isListening = false
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate Callback (Background captureQueue)

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let rawPtr = dataPointer, length > 0 else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else { return }

        let sampleRate = asbd.mSampleRate
        guard sampleRate > 0 else { return }

        let floatCount = length / MemoryLayout<Float>.size
        guard floatCount > 0 else { return }

        let channels = max(1, Int(asbd.mChannelsPerFrame))
        let frameCount = floatCount / channels
        guard frameCount > 0 else { return }

        let floatPtr = rawPtr.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 }

        // 1. Fast Buffer Accumulation on Background Queue
        if channels == 1 {
            let incoming = UnsafeBufferPointer(start: floatPtr, count: floatCount)
            if backgroundRollingBuffer.count >= Self.analysisWindowSize {
                backgroundRollingBuffer.removeFirst(min(backgroundRollingBuffer.count, floatCount))
            }
            backgroundRollingBuffer.append(contentsOf: incoming)
        } else {
            // Multi-channel interface: isolate primary channel
            if backgroundRollingBuffer.count >= Self.analysisWindowSize {
                backgroundRollingBuffer.removeFirst(min(backgroundRollingBuffer.count, frameCount))
            }
            for i in 0..<frameCount {
                backgroundRollingBuffer.append(floatPtr[i * channels])
            }
        }

        // 2. Throttle DSP & UI Updates to Configurable Rate (Zero-allocation throttle)
        let now = CFAbsoluteTimeGetCurrent()
        let minInterval = 1.0 / max(1.0, Self.targetUpdatesPerSecond)
        guard now - lastAnalysisTime >= minInterval else { return }
        lastAnalysisTime = now

        guard backgroundRollingBuffer.count >= 512 else { return }

        // 3. Vectorized RMS Energy Computation (Background)
        var rms: Float = 0.0
        vDSP_rmsqv(backgroundRollingBuffer, 1, &rms, vDSP_Length(backgroundRollingBuffer.count))

        let dbfs = 20.0 * log10(max(rms, 1e-6))
        let normalizedRMS = min(1.0, max(0.0, (dbfs + 60.0) / 60.0))
        smoothedRMS = 0.70 * smoothedRMS + 0.30 * normalizedRMS

        // 4. Noise Gate Threshold
        guard dbfs >= Self.noiseGateThresholdDBFS else {
            smoothedF0 = 0.0
            let currentRMS = smoothedRMS
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.inputLevelRMS = currentRMS
                self.inputLevelDBFS = dbfs
                self.isSignalDetected = false
                self.detectedPitch = nil
            }
            return
        }

        // 5. Autocorrelation & Sub-Sample Parabolic Interpolation (Background)
        guard let rawF0 = detectFundamentalFrequency(buffer: backgroundRollingBuffer, sampleRate: sampleRate) else {
            let currentRMS = smoothedRMS
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.inputLevelRMS = currentRMS
                self.inputLevelDBFS = dbfs
                self.isSignalDetected = false
            }
            return
        }

        // Pitch stabilization EMA on Background Thread
        if smoothedF0 == 0.0 || abs(rawF0 - smoothedF0) > 35.0 {
            smoothedF0 = rawF0
        } else {
            smoothedF0 = 0.75 * smoothedF0 + 0.25 * rawF0
        }

        guard let pitchInfo = calculatePitchData(from: smoothedF0) else { return }
        let currentRMS = smoothedRMS

        // 6. Downsampled UI Update onto Main Thread (Only 5-10 times/sec)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.inputLevelRMS = currentRMS
            self.inputLevelDBFS = dbfs
            self.isSignalDetected = true
            self.detectedPitch = pitchInfo

            let alpha = Self.needleDampingAlpha
            if abs(pitchInfo.centsOffset - self.smoothedCents) > 35.0 {
                self.smoothedCents = pitchInfo.centsOffset
            } else {
                self.smoothedCents = (1.0 - alpha) * self.smoothedCents + alpha * pitchInfo.centsOffset
            }
        }
    }

    // MARK: - Autocorrelation Function with 3-Point Parabolic Interpolation (Zero Heap Allocations)

    nonisolated private func detectFundamentalFrequency(buffer: [Float], sampleRate: Double) -> Double? {
        let n = buffer.count
        let minFreq = 80.0
        let maxFreq = 450.0

        let minLag = max(1, Int(sampleRate / maxFreq))
        let maxLag = min(n / 2, Int(sampleRate / minFreq))

        guard maxLag > minLag else { return nil }
        let corrLength = n - maxLag
        guard corrLength > 0 else { return nil }

        return buffer.withUnsafeBufferPointer { ptr -> Double? in
            guard let baseAddress = ptr.baseAddress else { return nil }

            // Zero-lag energy R[0] = sum(x[n]^2)
            var r0: Float = 0.0
            vDSP_svesq(baseAddress, 1, &r0, vDSP_Length(corrLength))
            guard r0 > 1e-5 else { return nil }

            var acf = [Float](repeating: 0.0, count: maxLag + 2)
            var maxVal: Float = -1.0
            var bestLag: Int = 0

            // Direct vectorized dot product for each lag tau
            for lag in minLag...maxLag {
                var sum: Float = 0.0
                vDSP_dotpr(baseAddress, 1, baseAddress.advanced(by: lag), 1, &sum, vDSP_Length(corrLength))
                acf[lag] = sum

                let normalizedCorr = sum / r0
                if normalizedCorr > 0.48 && sum > maxVal {
                    maxVal = sum
                    bestLag = lag
                }
            }

            guard bestLag > minLag && bestLag < maxLag else { return nil }

            // 3-Point Sub-Sample Parabolic Interpolation
            let alpha = acf[bestLag - 1]
            let beta = acf[bestLag]
            let gamma = acf[bestLag + 1]

            let denominator = 2.0 * (alpha - 2.0 * beta + gamma)
            guard abs(denominator) > 1e-6 else {
                let period = Double(bestLag)
                return sampleRate / period
            }

            let delta = Double(alpha - gamma) / Double(denominator)
            let refinedPeriod = Double(bestLag) + delta

            guard refinedPeriod > 0 else { return nil }
            return sampleRate / refinedPeriod
        }
    }

    // MARK: - Pitch Class & Cents Calculation

    nonisolated private func calculatePitchData(from f0: Double) -> TunerPitchData? {
        guard f0 > 20.0 && f0 < 5000.0 else { return nil }

        let continuousMIDI = 12.0 * log2(f0 / 440.0) + 69.0
        let nearestMIDI = Int(round(continuousMIDI))
        let cents = (continuousMIDI - Double(nearestMIDI)) * 100.0

        let pitchClassIndex = (nearestMIDI % 12 + 12) % 12
        let octave = (nearestMIDI / 12) - 1
        let noteName = "\(Self.pitchClassNames[pitchClassIndex])\(octave)"
        let scaleOffset = Double((nearestMIDI - Self.baseC3MIDI) * 100)

        let canShiftUp = (nearestMIDI + 12) <= Self.maxMIDINote
        let canShiftDown = (nearestMIDI - 12) >= Self.minMIDINote

        return TunerPitchData(
            rawFrequencyHz: f0,
            noteName: noteName,
            midiNoteNumber: nearestMIDI,
            centsOffset: cents,
            scaleOffsetCents: scaleOffset,
            canShiftOctaveUp: canShiftUp,
            canShiftOctaveDown: canShiftDown
        )
    }
}

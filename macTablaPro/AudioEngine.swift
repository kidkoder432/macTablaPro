import Foundation
import AVFoundation
import Combine

@MainActor
class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let masterPitch = AVAudioUnitTimePitch()

    // 4 separate players and pitch nodes for the 4 strings
    private let players: [AVAudioPlayerNode] = (0..<4).map { _ in AVAudioPlayerNode() }
    private let stringPitches: [AVAudioUnitTimePitch] = (0..<4).map { _ in AVAudioUnitTimePitch() }

    // Audio Buffers stored in RAM
    private var bufferPaC3: AVAudioPCMBuffer?
    private var bufferNiC3: AVAudioPCMBuffer?
    private var bufferSaC3: AVAudioPCMBuffer?
    private var bufferKharajC3: AVAudioPCMBuffer?
    private var bufferSaG3: AVAudioPCMBuffer?
    private var bufferKharajG3: AVAudioPCMBuffer?

    @Published var isPlaying = false

    // State driven by the UI. @MainActor isolation on the class keeps these
    // safe to read/write from SwiftUI and from the sequencing Task alike.
    @Published var pitchOffset: Double = 0.0 // 0 = C#3
    @Published var tempo: Double = 100 // BPM
    @Published var firstStringIsPa: Bool = true // true = Pa, false = Ni

    private var sequenceTask: Task<Void, Never>?

    init() {
        loadBuffers()
        setupEngine()
    }

    // MARK: - Loading

    private func loadBuffer(name: String) -> AVAudioPCMBuffer? {
        // Files are copied flat into the bundle (Resources), so no subdirectory.
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("⚠️ Could not find \(name).wav in bundle")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                print("⚠️ Could not create buffer for \(name)")
                return nil
            }
            try file.read(into: buffer)
            return buffer
        } catch {
            print("⚠️ Failed to load \(name).wav: \(error)")
            return nil
        }
    }

    private func loadBuffers() {
        bufferPaC3 = loadBuffer(name: "Tanpura_C#3_Pa")
        bufferNiC3 = loadBuffer(name: "Tanpura_C#3_Ni")
        bufferSaC3 = loadBuffer(name: "Tanpura_C#3_Sa")
        bufferKharajC3 = loadBuffer(name: "Tanpura_C#3_Kharaj")
        bufferSaG3 = loadBuffer(name: "Tanpura_G#3_Sa")
        bufferKharajG3 = loadBuffer(name: "Tanpura_G#3_Kharaj")

        let allBuffers = [bufferPaC3, bufferNiC3, bufferSaC3, bufferKharajC3, bufferSaG3, bufferKharajG3]
        let loadedCount = allBuffers.compactMap { $0 }.count
        print("Loaded \(loadedCount)/6 tanpura buffers")

        let formats = Set(allBuffers.compactMap { $0?.format })
        if formats.count > 1 {
            print("⚠️ WARNING: wav files have mismatched formats (sample rate/channel count differs): \(formats)")
        }
    }

    // MARK: - Engine setup

    private func setupEngine() {
        // Grab the actual audio format from one of our loaded files
        guard let format = bufferSaC3?.format else {
            print("CRITICAL ERROR: Audio files did not load. Check file names / bundle membership.")
            return
        }

        engine.attach(mixer)
        engine.attach(masterPitch)

        engine.connect(mixer, to: masterPitch, format: format)
        engine.connect(masterPitch, to: engine.mainMixerNode, format: format)

        for i in 0..<4 {
            engine.attach(players[i])
            engine.attach(stringPitches[i])
            engine.connect(players[i], to: stringPitches[i], format: format)
            engine.connect(stringPitches[i], to: mixer, format: format)
        }

        do {
            try engine.start()
            print("Engine started successfully with format: \(format)")
        } catch {
            print("Failed to start engine: \(error)")
        }
    }

    // MARK: - Transport

    func togglePlay() {
        if isPlaying {
            isPlaying = false
            sequenceTask?.cancel()
            players.forEach { $0.stop() }
        } else {
            isPlaying = true
            startSequence()
        }
    }

    /// Sequence is: String 1, String 2, String 3, String 4, Rest — then repeats.
    private enum Step {
        case string(Int)
        case rest
    }
    private let sequence: [Step] = [.string(0), .string(1), .string(2), .string(3), .rest]

    private func startSequence() {
        sequenceTask?.cancel()
        sequenceTask = Task { [weak self] in
            guard let self else { return }
            var stepIndex = 0
            while !Task.isCancelled {
                let step = self.sequence[stepIndex]
                switch step {
                case .string(let i):
                    self.playString(index: i)
                case .rest:
                    break // silence — just wait out the beat
                }

                stepIndex = (stepIndex + 1) % self.sequence.count

                let delaySeconds = 60.0 / self.tempo
                do {
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                } catch {
                    // Task was cancelled during sleep — loop will exit on next isCancelled check.
                    break
                }
            }
        }
    }

    // MARK: - Playback

    private func playString(index: Int) {
        // If target pitch > E3 (offset +3 semitones from C#3), switch to G#3-based samples.
        let useG3 = pitchOffset > 3

        // Master shift: if using G#3 samples, subtract 7 semitones (C#3 -> G#3 interval)
        // so the offset math stays consistent relative to C#3.
        let masterShift = useG3 ? (pitchOffset - 7) : pitchOffset
        masterPitch.pitch = Float(masterShift * 100)

        var bufferToPlay: AVAudioPCMBuffer?
        var localShift: Float = 0.0

        switch index {
        case 0: // 1st String (Pa / Ni) — selectable
            bufferToPlay = firstStringIsPa ? bufferPaC3 : bufferNiC3
            // We only have C#3 assets for the first string, so pitch it up
            // 7 semitones when the G#3 base is active to match the other strings.
            if useG3 { localShift = 700.0 }
        case 1, 2: // Middle Sa strings
            bufferToPlay = useG3 ? bufferSaG3 : bufferSaC3
        case 3: // Kharaj string
            bufferToPlay = useG3 ? bufferKharajG3 : bufferKharajC3
        default:
            break
        }

        guard let buffer = bufferToPlay else {
            print("⚠️ No buffer available for string index \(index) (useG3: \(useG3))")
            return
        }

        stringPitches[index].pitch = localShift

        // Stop the current string's previous ring and strike it again.
//        players[index].stop()
        players[index].scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        players[index].play()
    }
}

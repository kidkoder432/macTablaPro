import AVFoundation
import Combine
import Foundation

nonisolated class AudioVoice: @unchecked Sendable {
    private(set) var playerNode = AVAudioPlayerNode()

    private let lock = NSLock()
    private var _isBusy = false

    var isBusy: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isBusy
        }
        set {
            lock.lock()
            _isBusy = newValue
            lock.unlock()
        }
    }

    init(attachedTo engine: AVAudioEngine) {
        // 1. Permanently register these nodes with the engine graph
        engine.attach(playerNode)

        // Note: We don't perform the engine.connect here because we don't
        // know the shared mixer's destination or format yet.
        // We will expose these nodes so the Engine handles the line routing.
    }

    func isFree() -> Bool {
        return !isBusy
    }

    func play(
        sample: PitchedSample,
        targetPitchCents: Double,
        volume: Double,
        time: AVAudioTime?
    ) {
        guard var buffer = sample.resampledBuffer else {
            print(
                "⚠️ Voice error: Attempted to play an unallocated sample buffer."
            )
            return
        }

        isBusy = true
        
        try? buffer = OfflineAudioResampler.resample(
            sourceBuffer: buffer,
            centsOffset: targetPitchCents - sample.resampledPitch
        ) ?? buffer

        playerNode.volume = Float(volume)
        // Schedule the buffer on the real-time audio thread pipeline
        playerNode.scheduleBuffer(
            buffer,
            at: time,
            options: [],
            completionHandler: { [weak self] in
                // Fires automatically when the buffer reaches absolute end-of-file
                self?.isBusy = false
            }
        )

        playerNode.play()
    }

    func stop() {
        if playerNode.isPlaying {
            playerNode.volume = 0.0
            playerNode.stop()
        }
        isBusy = false
    }
}

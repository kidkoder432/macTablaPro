import AVFoundation
import Combine
import Foundation

nonisolated class AudioVoice: @unchecked Sendable {
    private(set) var playerNode = AVAudioPlayerNode()

    private let lock = NSLock()
    private var _isBusy = false
    private var _scheduledPlayTime: AVAudioTime?

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

    var scheduledPlayTime: AVAudioTime? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _scheduledPlayTime
        }
        set {
            lock.lock()
            _scheduledPlayTime = newValue
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

        try? buffer = OfflineAudioResampler.resample(
            sourceBuffer: buffer,
            centsOffset: targetPitchCents - sample.resampledPitch
        ) ?? buffer

        lock.lock()
        _scheduledPlayTime = time
        _isBusy = true
        lock.unlock()

        playerNode.volume = Float(volume)
        // Schedule the buffer on the real-time audio thread pipeline
        playerNode.scheduleBuffer(
            buffer,
            at: time,
            options: [],
            completionHandler: { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                self._isBusy = false
                self._scheduledPlayTime = nil
                self.lock.unlock()
            }
        )

        playerNode.play()
    }

    func stop() {
        playerNode.volume = 0.0
        playerNode.stop()
        
        lock.lock()
        _isBusy = false
        _scheduledPlayTime = nil
        lock.unlock()
    }
}

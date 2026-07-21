import AVFoundation
import Combine
import Foundation

@MainActor
class AudioVoice {
    private(set) var playerNode = AVAudioPlayerNode()
    private(set) var pitchNode = AVAudioUnitVarispeed()

    // Tracks state safely for the allocator pool
    private(set) var isBusy = false

    init(attachedTo engine: AVAudioEngine) {
        // 1. Permanently register these nodes with the engine graph
        engine.attach(playerNode)
        engine.attach(pitchNode)

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
        guard let buffer = sample.buffer else {
            print(
                "⚠️ Voice error: Attempted to play an unallocated sample buffer."
            )
            return
        }

        isBusy = true

        // Calculate raw target tuning relative to the file's recording properties
        // Target Cents + Inherent Sample Recording Offset
        let adjustedCents = targetPitchCents - sample.absolutePitch
        print(sample.absolutePitch, adjustedCents)

        // Update the physical DSP processor block
        // pitchNode.pitch = Float(adjustedCents)
        let newRate = Float(pow(2, (adjustedCents / 1200.0)))
        if pitchNode.rate != newRate {
            pitchNode.rate = newRate
        }

        playerNode.volume = Float(volume)
        // Schedule the buffer on the real-time audio thread pipeline
        playerNode.scheduleBuffer(
            buffer,
            at: time,
            options: [],
            completionHandler: { [weak self] in
                // Fires automatically when the buffer reaches absolute end-of-file
                Task { @MainActor in
                    self?.isBusy = false
                }
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

import Foundation

@MainActor
class AudioClock {
    private var clockTask: Task<Void, Never>?
    private let tickCallback: (Int) -> Double
    // Fetch the live BPM on demand instead of storing a static copy
    private let getBPM: () -> Double
    
    init(getBPM: @escaping () -> Double, onTick: @escaping (Int) -> Double) {
        self.tickCallback = onTick
        self.getBPM = getBPM
    }
    
    func start(stepsCount: Int, startingAtStep: Int = 0) {
        clockTask?.cancel()
        clockTask = Task {
            var stepIndex = (startingAtStep >= 0 && startingAtStep < (stepsCount > 0 ? stepsCount : 1)) ? startingAtStep : 0
            while !Task.isCancelled {
                let tickStartTime = DispatchTime.now().uptimeNanoseconds
                
                // Fire tick callback on MainActor and capture sleep fraction
                let durationFraction = await MainActor.run { tickCallback(stepIndex) }
                let safeFraction = durationFraction > 0 ? durationFraction : 1.0
                
                stepIndex = (stepIndex + 1) % (stepsCount > 0 ? stepsCount : 1)
                
                // Read the absolute latest BPM from the instrument right before sleeping
                let currentBPM = getBPM()
                let targetDelaySec = (60.0 / currentBPM) * safeFraction
                let targetDelayNanos = UInt64(targetDelaySec * 1_000_000_000)
                
                // Subtract elapsed tick processing time to guarantee exact monotonic tempo
                let elapsedTimeNanos = DispatchTime.now().uptimeNanoseconds - tickStartTime
                let remainingNanos = targetDelayNanos > elapsedTimeNanos ? (targetDelayNanos - elapsedTimeNanos) : 0
                
                try? await Task.sleep(nanoseconds: remainingNanos)
            }
        }
    }
    
    func stop() {
        clockTask?.cancel()
        clockTask = nil
    }
}

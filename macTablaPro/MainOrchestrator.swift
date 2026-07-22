import AVFoundation
import Combine
import Foundation

@MainActor
class AppAudioOrchestrator: ObservableObject {
    // 1. Shared core hardware objects
    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()
    private var voicePool: VoicePool!

    // The single, master database of loaded audio data in RAM
    private var masterSampleRegistry: [String: PitchedSample] = [:]

    // 2. The Active Instruments
    @Published var tanpura1: Tanpura!
    @Published var tanpura2: Tanpura!
    @Published var tabla: Tabla!
    
    @Published var scaleOffsetCents: Double = 100.0 {
        didSet { updateMasterPitch() }
    }
    @Published var fineTuneCents: Double = 0.0 {
        didSet { updateMasterPitch() }
    }
    
    @Published var sharedTanpuraBPM: Double = 60.0 {
        didSet {
            tanpura1?.tempoBPM = sharedTanpuraBPM
            tanpura2?.tempoBPM = sharedTanpuraBPM
        }
    }
    @Published var isInspectorPresented: Bool = false
    @Published var hasStartedFirstTime: Bool = false
    @Published var masterVolume: Double = 1.0 {
        didSet {
            masterMixer.outputVolume = Float(masterVolume)
        }
    }

    private var activeInstrumentsSnapshot: Set<ObjectIdentifier> = []

    var isAnyInstrumentPlaying: Bool {
        return (tanpura1?.isPlaying ?? false) || (tanpura2?.isPlaying ?? false) || (tabla?.isPlaying ?? false)
    }

    func toggleMasterTransport() {
        if !hasStartedFirstTime {
            hasStartedFirstTime = true
            if let t1 = tanpura1, !t1.isPlaying { t1.togglePlay() }
            if let t2 = tanpura2, !t2.isPlaying { t2.togglePlay() }
            if let tb = tabla, !tb.isPlaying { tb.togglePlay() }
            return
        }
        
        if isAnyInstrumentPlaying {
            stopAllWorkstationAudio()
        } else {
            resumePreviousWorkstationAudio()
        }
    }

    init() {
        // Step 1: Preload all data directly into system memory
        preloadAllManifestAssets()

        // Step 2: Spin up a shared pool of voices
        self.voicePool = VoicePool(engine, 64)

        // Step 3: Wire up the hardware signal graph
        setupAudioGraph()

        // Step 4: Isolate instrument registries using filtered slices of the master cache
        let tanpuraRegistry = masterSampleRegistry.filter { $0.key.contains("Tanpura_") }
        
        // Step 5: Instantiate your concrete child instruments
        self.tanpura1 = Tanpura(orchestrator: self, voicePool: self.voicePool, registry: tanpuraRegistry)
        self.tanpura2 = Tanpura(orchestrator: self, voicePool: self.voicePool, registry: tanpuraRegistry)
        self.tanpura1.tempoBPM = self.sharedTanpuraBPM
        self.tanpura2.tempoBPM = self.sharedTanpuraBPM
        
        let tablaRegistry = masterSampleRegistry.filter { $0.key.contains("Bayaan_") || $0.key.contains("Dayaan_") }
        self.tabla = Tabla(orchestrator: self, voicePool: self.voicePool, registry: tablaRegistry)
        
        updateMasterPitch()
    }

    private func preloadAllManifestAssets() {
        let totalManifest: [PitchedSample] = tanpuraManifest + tablaManifest
        for sample in totalManifest {
            if masterSampleRegistry[sample.fileName] != nil {
                print("⚠️ Centralized Audio Core Warning: Duplicate asset key '\(sample.fileName)' detected! Overwriting existing entry.")
            }
            sample.load()
            masterSampleRegistry[sample.fileName] = sample
        }
        print("📁 Centralized Audio Core Online. Loaded \(masterSampleRegistry.count) assets safely.")
    }

    private func setupAudioGraph() {
        engine.attach(masterMixer)
        guard let assetFormat = tanpuraManifest.first?.buffer?.format else { return }

        engine.connect(masterMixer, to: engine.mainMixerNode, format: assetFormat)

        for voice in voicePool.voicePool {
            engine.connect(voice.playerNode, to: masterMixer, format: assetFormat)
        }

        do {
            try engine.start()
        } catch {
            print("❌ Critical Hardware Failure: \(error)")
        }
    }

    func stopAllWorkstationAudio() {
        activeInstrumentsSnapshot.removeAll()
        if tanpura1.isPlaying {
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tanpura1))
            tanpura1.togglePlay()
        }
        if tanpura2.isPlaying {
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tanpura2))
            tanpura2.togglePlay()
        }
        if tabla.isPlaying {
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tabla))
            tabla.togglePlay()
        }
        voicePool.stopAll()
    }

    func resumePreviousWorkstationAudio() {
        guard !activeInstrumentsSnapshot.isEmpty else { return }
        
        if activeInstrumentsSnapshot.contains(ObjectIdentifier(tanpura1)) && !tanpura1.isPlaying {
            tanpura1.togglePlay()
        }
        if activeInstrumentsSnapshot.contains(ObjectIdentifier(tanpura2)) && !tanpura2.isPlaying {
            tanpura2.togglePlay()
        }
        if activeInstrumentsSnapshot.contains(ObjectIdentifier(tabla)) && !tabla.isPlaying {
            tabla.togglePlay()
        }
    }
                                                                                          
    private func updateMasterPitch() {
        let totalCents = scaleOffsetCents + fineTuneCents
        let tablaRegistry = masterSampleRegistry.filter { key, _ in key.contains("Dayaan") || key.contains("Bayaan")}
        OfflineAudioResampler.resampleBatch(
            samples: Array(tablaRegistry.values),
            targetPitchCents: totalCents
        )
    }
    
    
}

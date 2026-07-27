import AVFoundation
import Combine
import CoreAudio
import Foundation

struct AudioOutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
}

@MainActor
class AppAudioOrchestrator: ObservableObject {
    // 1. Shared core hardware objects
    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()
    private var voicePool: VoicePool!

    // The single, master database of loaded audio data in RAM
    private var masterSampleRegistry: [String: PitchedSample] = [:]

    // 2. Centralized Instrument Collection & Registry
    @Published var instruments: [Instrument] = []

    var tanpura1: Tanpura! {
        instruments.first(where: { $0.id == "tanpura_1" }) as? Tanpura
    }
    var tanpura2: Tanpura! {
        instruments.first(where: { $0.id == "tanpura_2" }) as? Tanpura
    }
    var tabla: Tabla! {
        instruments.first(where: { $0.id == "tabla_main" }) as? Tabla
    }
    
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
    @Published var isAntiqueThemeEnabled: Bool = false
    @Published var isPresetsPresented: Bool = false
    @Published var isInspectorPresented: Bool = false
    @Published var hasStartedFirstTime: Bool = false
    @Published var masterVolume: Double = 1.0 {
        didSet {
            masterMixer.outputVolume = Float(masterVolume)
            engine.mainMixerNode.outputVolume = 1
            setSystemMasterVolume(Float(masterVolume))
        }
    }

    @Published var availableOutputDevices: [AudioOutputDevice] = []
    @Published var selectedOutputDeviceID: AudioDeviceID = 0 {
        didSet { setAudioOutputDevice(deviceID: selectedOutputDeviceID) }
    }

    private var activeInstrumentsSnapshot: Set<ObjectIdentifier> = []

    var isAnyInstrumentPlaying: Bool {
        return instruments.contains(where: { $0.isPlaying })
    }

    func toggleMasterTransport() {
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
        let tablaRegistry = masterSampleRegistry.filter { $0.key.contains("Bayaan_") || $0.key.contains("Dayaan_") }

        // Step 5: Instantiate concrete child instruments into unified registry
        let t1 = Tanpura(id: "tanpura_1", name: "Tanpura 1", orchestrator: self, voicePool: self.voicePool, registry: tanpuraRegistry)
        let t2 = Tanpura(id: "tanpura_2", name: "Tanpura 2", orchestrator: self, voicePool: self.voicePool, registry: tanpuraRegistry)
        t1.tempoBPM = self.sharedTanpuraBPM
        t2.tempoBPM = self.sharedTanpuraBPM

        let tb = Tabla(id: "tabla_main", name: "Tabla", orchestrator: self, voicePool: self.voicePool, registry: tablaRegistry)

        self.instruments = [t1, t2, tb]
        
        setupChildSubscriptions()
        let sysVol = getSystemMasterVolume()
        if sysVol > 0 {
            self.masterVolume = Double(sysVol)
        }
        
        updateMasterPitch()
        refreshAudioOutputDevices()
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
        // Note: Intentional omission of voicePool.stopAll() to allow lingering sustain/decay ring out naturally!
    }

    func resumePreviousWorkstationAudio() {
        if activeInstrumentsSnapshot.isEmpty {
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tanpura1))
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tabla))
        }
        
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

    private func refreshAudioOutputDevices() {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else { return }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs) == noErr else { return }
        
        var devices: [AudioOutputDevice] = []
        for devID in deviceIDs {
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            if AudioObjectGetPropertyDataSize(devID, &streamAddress, 0, nil, &streamSize) == noErr && streamSize > 0 {
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioObjectPropertyName,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var nameString: CFString = "" as CFString
                var nameSize = UInt32(MemoryLayout<CFString>.size)
                if AudioObjectGetPropertyData(devID, &nameAddress, 0, nil, &nameSize, &nameString) == noErr {
                    devices.append(AudioOutputDevice(id: devID, name: nameString as String))
                }
            }
        }
        self.availableOutputDevices = devices
        if let first = devices.first {
            self.selectedOutputDeviceID = first.id
        }
    }

    private func setAudioOutputDevice(deviceID: AudioDeviceID) {
        guard deviceID != 0, let audioUnit = engine.outputNode.audioUnit else { return }
        var devID = deviceID
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    private var cancellables = Set<AnyCancellable>()

    private func setupChildSubscriptions() {
        cancellables.removeAll()
        for instrument in instruments {
            instrument.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    private func getSystemMasterVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &defaultOutputDeviceID) == noErr {
            var volume: Float32 = 0.0
            var volSize = UInt32(MemoryLayout<Float32>.size)
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, &volSize, &volume) == noErr {
                return volume
            }
        }
        return 1.0
    }

    private func setSystemMasterVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &defaultOutputDeviceID) == noErr {
            var vol = volume
            let volSize = UInt32(MemoryLayout<Float32>.size)
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectSetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, volSize, &vol)
        }
    }
}

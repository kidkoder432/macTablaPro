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
    var swarMandal: SwarMandal! {
        instruments.first(where: { $0.id == "swar_mandal" }) as? SwarMandal
    }
    
    @Published var scaleOffsetCents: Double = 100.0 {
        didSet {
            let rounded = round(scaleOffsetCents)
            if scaleOffsetCents != rounded {
                scaleOffsetCents = rounded
            }
        }
    }
    @Published var fineTuneCents: Double = 0.0 {
        didSet {
            let rounded = round(fineTuneCents)
            if fineTuneCents != rounded {
                fineTuneCents = rounded
            }
        }
    }
    
    @Published var sharedTanpuraBPM: Double = 60.0 {
        didSet {
            let rounded = round(sharedTanpuraBPM)
            if sharedTanpuraBPM != rounded {
                sharedTanpuraBPM = rounded
            }
            tanpura1?.tempoBPM = sharedTanpuraBPM
            tanpura2?.tempoBPM = sharedTanpuraBPM
        }
    }
    @Published var isAntiqueThemeEnabled: Bool = false
    @Published var isPresetsPresented: Bool = false
    @Published var isInspectorPresented: Bool = false
    @Published var hasStartedFirstTime: Bool = false
    @Published var activePresetName: String? = nil
    @Published var allPresets: [ITablaProPreset] = []
    @Published var isAppLoading: Bool = true

    @Published var sankalp = SankalpPracticeManager.shared

    func refreshAllPresets() {
        Task {
            let container = await SettingsStorageService.shared.loadAllPresetsContainer()
            self.allPresets = container.objects
        }
    }

    @Published var masterVolume: Double = 1.0 {
        didSet {
            if !isMasterMuted {
                masterMixer.outputVolume = Float(masterVolume)
            }
        }
    }

    @Published var isMasterMuted: Bool = false {
        didSet {
            if isMasterMuted {
                masterMixer.outputVolume = 0.0
                voicePool.stopAll()
            } else {
                masterMixer.outputVolume = Float(masterVolume)
            }
        }
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
        sankalp.onPlaybackStateChanged(isPlaying: isAnyInstrumentPlaying)
    }

    init() {
        // Step 1: Preload all data directly into system memory
        preloadAllManifestAssets()

        // Step 2: Spin up a shared pool of voices
        self.voicePool = VoicePool(engine, 256)

        // Step 3: Wire up the hardware signal graph
        setupAudioGraph()

        // Step 4: Isolate instrument registries using filtered slices of the master cache
        let tanpuraRegistry = masterSampleRegistry.filter { $0.key.contains("Tanpura_") }
        let tablaRegistry = masterSampleRegistry.filter { $0.key.contains("Bayaan_") || $0.key.contains("Dayaan_") }
        let swarMandalRegistry = masterSampleRegistry.filter { $0.key.contains("SwarMandal_") }

        // Step 5: Instantiate concrete child instruments into unified registry
        let t1 = Tanpura(id: "tanpura_1", name: "Tanpura 1", orchestrator: self, voicePool: self.voicePool, registry: tanpuraRegistry)
        let t2 = Tanpura(id: "tanpura_2", name: "Tanpura 2", orchestrator: self, voicePool: self.voicePool, registry: tanpuraRegistry)
        t1.tempoBPM = self.sharedTanpuraBPM
        t2.tempoBPM = self.sharedTanpuraBPM

        let tb = Tabla(id: "tabla_main", name: "Tabla", orchestrator: self, voicePool: self.voicePool, registry: tablaRegistry)
        let sm = SwarMandal(id: "swar_mandal", name: "Swar Mandal", orchestrator: self, voicePool: self.voicePool, registry: swarMandalRegistry)

        self.instruments = [t1, t2, tb, sm]
        
        setupChildSubscriptions()
        updateMasterPitch()
        setupAudioEngineNotifications()

        // Load persisted settings (or defaults) off main thread asynchronously
        Task {
            let container = await SettingsStorageService.shared.loadAllPresetsContainer()
            self.allPresets = container.objects
            var loaded = await SettingsStorageService.shared.loadActiveSettings()
            // Ensure all instruments start OFF on initial app launch
            loaded.Tanpura1On = false
            loaded.Tanpura2On = false
            loaded.TablaOn = false
            loaded.SwarMandalOn = false
            self.applyPreset(loaded)
            self.setupAutosavePipeline()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.isAppLoading = false
            }
        }
    }

    // MARK: Settings Capture & Application

    private var activePresetBase: ITablaProPreset? = nil

    func capturePreset(name: String? = nil) -> ITablaProPreset {
        var preset = activePresetBase ?? ITablaProPreset.defaultPreset
        preset.PresetName = name ?? activePresetName ?? preset.PresetName
        preset.PitchName = ITablaProPreset.scaleOffsetCentsToPitchName(self.scaleOffsetCents)
        preset.FineTuneCents = self.fineTuneCents
        preset.Tempo = self.tabla?.tempoBPM ?? preset.Tempo
        preset.SharedTanpuraBPM = self.sharedTanpuraBPM

        if let tb = self.tabla {
            preset.TablaOn = tb.isPlaying
            preset.TablaGain = tb.volume
            preset.TaalName = tb.activeTaal
            preset.StyleName = tb.activeVariation
            preset.UseSurTabla = tb.useSurTabla
        }

        if let t1 = self.tanpura1 {
            preset.Tanpura1On = t1.isPlaying
            preset.Tanpura1Gain = t1.volume
            preset.Tanpura1FirstString = ITablaProPreset.centsToStringName(t1.firstStringPitch)
        }

        if let t2 = self.tanpura2 {
            preset.Tanpura2On = t2.isPlaying
            preset.Tanpura2Gain = t2.volume
            preset.Tanpura2FirstString = ITablaProPreset.centsToStringName(t2.firstStringPitch)
        }

        return preset
    }

    func applyPreset(_ preset: ITablaProPreset) {
        isApplyingPreset = true
        activePresetBase = preset
        activePresetName = preset.PresetName

        // 1. Ingest ALL UI state properties immediately at t = 0s
        self.scaleOffsetCents = ITablaProPreset.pitchNameToScaleOffsetCents(preset.PitchName)
        self.fineTuneCents = preset.FineTuneCents

        if let tanpuraBPM = preset.SharedTanpuraBPM {
            self.sharedTanpuraBPM = tanpuraBPM
        }

        if let t1 = self.tanpura1 {
            t1.volume = preset.Tanpura1Gain
            t1.firstStringPitch = ITablaProPreset.stringNameToCents(preset.Tanpura1FirstString)
        }

        if let t2 = self.tanpura2 {
            t2.volume = preset.Tanpura2Gain
            t2.firstStringPitch = ITablaProPreset.stringNameToCents(preset.Tanpura2FirstString)
        }

        if let tb = self.tabla {
            tb.activeTaal = preset.TaalName
            tb.activeVariation = preset.StyleName
            tb.tempoBPM = preset.Tempo
            tb.volume = preset.TablaGain
            tb.useSurTabla = preset.UseSurTabla
        }

        if let sm = self.swarMandal {
            sm.volume = preset.SwarMandalGain ?? 0.25
            if let durationSec = preset.SwarMandalLoopDuration, let opt = SwarMandalLoopOption(rawValue: durationSec) {
                sm.loopOption = opt
            }
            if let notes = preset.SwarMandalNotes?.nsObjects {
                sm.updateNotesFromPreset(notes)
            }
        }

        self.commitPitchChange()

        // 2. Staggered Audio Playback Triggers
        if let t1 = self.tanpura1 {
            if preset.Tanpura1On { t1.startPlay() } else { t1.stopPlay() }
        }
        if let tb = self.tabla {
            if preset.TablaOn { tb.startPlay() } else { tb.stopPlay() }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if let t2 = self.tanpura2 {
                if preset.Tanpura2On { t2.startPlay() } else { t2.stopPlay() }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self else { return }
            if let sm = self.swarMandal {
                if preset.SwarMandalOn ?? false { sm.startPlay() } else { sm.stopPlay() }
            }
            self.isApplyingPreset = false
        }
    }

    private var isApplyingPreset = false
    private var lastMusicalSnapshot: (Double, Double, Double, Double, String, String, Double)? = nil

    private func setupAutosavePipeline() {
        objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                let currentSnapshot = (
                    self.scaleOffsetCents,
                    self.fineTuneCents,
                    self.tanpura1?.firstStringPitch ?? 700.0,
                    self.tanpura2?.firstStringPitch ?? 1200.0,
                    self.tabla?.activeTaal ?? "",
                    self.tabla?.activeVariation ?? "",
                    self.tabla?.tempoBPM ?? 100.0
                )

                if !self.isApplyingPreset && self.activePresetName != nil {
                    if let last = self.lastMusicalSnapshot,
                       (last.0 != currentSnapshot.0 || last.1 != currentSnapshot.1 ||
                        last.2 != currentSnapshot.2 || last.3 != currentSnapshot.3 ||
                        last.4 != currentSnapshot.4 || last.5 != currentSnapshot.5 ||
                        last.6 != currentSnapshot.6) {
                        self.activePresetName = nil
                    }
                }
                self.lastMusicalSnapshot = currentSnapshot

                let current = self.capturePreset()
                Task.detached(priority: .utility) {
                    await SettingsStorageService.shared.saveActiveSettings(current)
                }
            }
            .store(in: &cancellables)
    }

    private func preloadAllManifestAssets() {
        let totalManifest: [PitchedSample] = tanpuraManifest + tablaManifest + swarMandalManifest
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
        if let sm = swarMandal, sm.isPlaying {
            activeInstrumentsSnapshot.insert(ObjectIdentifier(sm))
            sm.togglePlay()
        }
    }

    func resumePreviousWorkstationAudio() {
        if activeInstrumentsSnapshot.isEmpty {
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tanpura1))
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tanpura2))
            activeInstrumentsSnapshot.insert(ObjectIdentifier(tabla))
            if let sm = swarMandal {
                activeInstrumentsSnapshot.insert(ObjectIdentifier(sm))
            }
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
        if let sm = swarMandal, activeInstrumentsSnapshot.contains(ObjectIdentifier(sm)) && !sm.isPlaying {
            sm.togglePlay()
        }
    }
                                                                                          
    // MARK: - Mouse-Up Pitch Commit & Background Resampling

    /// Fired on mouse-up (editing release) when dragging pitch sliders.
    func commitPitchChange() {
        let totalCents = scaleOffsetCents + fineTuneCents
        schedulePitchResample(targetCents: totalCents)
    }

    private var resampleTask: Task<Void, Never>?

    /// Offloads CPU-heavy sample resampling off the @MainActor thread to prevent UI lag.
    func schedulePitchResample(targetCents: Double) {
        // Cancel any pending/running resampling task to prevent stacking CPU work
        resampleTask?.cancel()

        let tablaRegistry = masterSampleRegistry.filter { key, _ in key.contains("Dayaan") || key.contains("Bayaan") }
        let samples = Array(tablaRegistry.values)

        resampleTask = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else { return }
            OfflineAudioResampler.resampleBatch(
                samples: samples,
                targetPitchCents: targetCents
            )
        }
    }

    private func updateMasterPitch() {
        commitPitchChange()
    }

    private var cancellables = Set<AnyCancellable>()

    private func setupChildSubscriptions() {
        cancellables.removeAll()
        for instrument in instruments {
            instrument.$isPlaying
                .dropFirst()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.objectWillChange.send()
                    self.sankalp.onPlaybackStateChanged(isPlaying: self.isAnyInstrumentPlaying)
                }
                .store(in: &cancellables)
        }
    }

    private func setupAudioEngineNotifications() {
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange, object: engine)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleEngineConfigurationChange()
            }
            .store(in: &cancellables)
    }

    private func handleEngineConfigurationChange() {
        print("🔄 AVAudioEngine Configuration Changed - Resetting Graph for Hardware Switch")
        engine.stop()
        engine.reset()
        setupAudioGraph()
    }
}

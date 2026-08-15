import SwiftUI

// Global variables retained as requested[cite: 10]
private let centsNoteNames: [String] = [
    "A2", "A#2", "B2", "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3",
    "G3", "G#3", "A3", "A#3", "B3", "C4", "C#4", "D4", "D#4", "E4",
]

struct PickerNote: Hashable {
    let name: String
    let cents: Double
}

struct NoteDisplayData {
    let noteName: String
    let fineCentsString: String?
}

let stringPickerItems: [PickerNote] = Array(tanpuraNotes.keys)
    .sorted(by: { (tanpuraNotes[$0] ?? 0.0) < (tanpuraNotes[$1] ?? 0.0) })
    .map { PickerNote(name: $0, cents: tanpuraNotes[$0] ?? -1.0) }

typealias VisualEffectBackground = VisualEffectView

// MARK: - Reusable Press-and-Hold Auto-Repeating Touch Button
struct RepeatingTouchButton<Content: View>: View {
    let action: () -> Void
    var label: () -> Content

    @State private var isPressed: Bool = false
    @State private var repeatTask: Task<Void, Never>? = nil

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Content) {
        self.action = action
        self.label = label
    }

    var body: some View {
        label()
            .opacity(isPressed ? 0.75 : 1.0)
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            action()
                            repeatTask?.cancel()
                            repeatTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 350_000_000) // 350ms hold delay
                                while !Task.isCancelled && isPressed {
                                    action()
                                    try? await Task.sleep(nanoseconds: 75_000_000) // ~13 ticks/sec
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        repeatTask?.cancel()
                        repeatTask = nil
                    }
            )
    }
}

struct TempoActionButton: View {
    let label: String
    var isAntique: Bool = false
    let action: () -> Void

    var body: some View {
        RepeatingTouchButton(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isAntique ? Color.orange : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isAntique ?
                            Color.black.opacity(0.35) :
                            Color(NSColor.controlBackgroundColor)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isAntique ?
                            Color.orange.opacity(0.45) :
                            Color(NSColor.separatorColor),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
        }
    }
}

struct StepperCircleButton: View {
    var iconName: String? = nil
    var textLabel: String? = nil
    var isAntique: Bool = false
    let action: () -> Void

    var body: some View {
        RepeatingTouchButton(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isAntique ?
                        Color.black.opacity(0.35) :
                        Color(NSColor.controlBackgroundColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isAntique ?
                                Color.orange.opacity(0.45) :
                                Color(NSColor.separatorColor),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)

                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isAntique ? Color.orange : .primary)
                } else if let txt = textLabel {
                    Text(txt)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isAntique ? Color.orange : .primary)
                }
            }
            .frame(width: 32, height: 32)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Workstation Layout Constants
struct WorkstationLayout {
    static let cardWidth: CGFloat = 340
    static let cardCornerRadius: CGFloat = 16
    
    static let minHorizontalSpacing: CGFloat = 16
    static let verticalCardSpacing: CGFloat = 14
    static let topPadding: CGFloat = 16
    static let bottomPadding: CGFloat = 16

    static let minWindowWidth: CGFloat = 1100
    static let minWindowHeight: CGFloat = 670
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct NativeCardModifier: ViewModifier {
    var isAntique: Bool = false
    var cornerRadius: CGFloat = WorkstationLayout.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isAntique ?
                        Color(NSColor.windowBackgroundColor).opacity(0.85) :
                        Color(NSColor.controlBackgroundColor)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isAntique ?
                        Color.orange.opacity(0.4) :
                        Color(NSColor.separatorColor),
                        lineWidth: 1
                    )
            )
            .shadow(color: isAntique ? Color.orange.opacity(0.12) : Color.black.opacity(0.06), radius: isAntique ? 6 : 3, x: 0, y: 2)
    }
}

extension View {
    func nativeCard(isAntique: Bool = false, cornerRadius: CGFloat = WorkstationLayout.cardCornerRadius) -> some View {
        self.modifier(NativeCardModifier(isAntique: isAntique, cornerRadius: cornerRadius))
    }
}

struct NativeDisplayBox<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    var isAntique: Bool = false
    let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isAntique ?
                        Color(red: 0.12, green: 0.08, blue: 0.05) :
                        Color(NSColor.controlBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isAntique ? Color.orange.opacity(0.4) : Color(NSColor.separatorColor),
                            lineWidth: 1
                        )
                )
            
            content()
        }
        .frame(width: width, height: height)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case global = "Global"
    case sankalp = "Sankalp Info"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .global: return "slider.horizontal.3"
        case .sankalp: return "clock.badge.checkmark.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var audio = AppAudioOrchestrator()
    @State private var settingsTab: SettingsTab = .global

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            // MARK: - Main Workspace (Zero-Scroll 3-Column Layout with Split Glass Overlays)
            ZStack(alignment: .top) {
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)

                    // 1. LEFT COLUMN: Tanpura 1 & 2 Cards Stacked + Swar Mandal Underneath
                    VStack(spacing: WorkstationLayout.verticalCardSpacing) {
                        if let tanpura1 = audio.tanpura1 {
                            TanpuraCardView(tanpura: tanpura1, audio: audio, title: "Tanpura 1")
                        }

                        if let tanpura2 = audio.tanpura2 {
                            TanpuraCardView(tanpura: tanpura2, audio: audio, title: "Tanpura 2")
                        }

                        if let swarMandal = audio.swarMandal {
                            SwarMandalView(swarMandal: swarMandal)
                        }
                    }
                    .frame(width: WorkstationLayout.cardWidth)

                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)

                    // 2. CENTER COLUMN: Master Pitch (Top) + Tabla Controls (Center)
                    VStack(spacing: WorkstationLayout.verticalCardSpacing) {
                        MasterPitchView(audio: audio)
                        
                        if let tabla = audio.tabla {
                            TablaCardView(tabla: tabla)
                        }
                    }
                    .frame(width: WorkstationLayout.cardWidth)

                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)

                    // 3. RIGHT COLUMN: Master Mixer Hub (ALWAYS VISIBLE!) + Sankalp Card
                    VStack(spacing: WorkstationLayout.verticalCardSpacing) {
                        MixerCardView(audio: audio)
                        SankalpCardView(audio: audio)
                    }
                    .frame(width: WorkstationLayout.cardWidth)

                    Spacer(minLength: WorkstationLayout.minHorizontalSpacing)
                }
                .padding(.top, WorkstationLayout.topPadding)
                .padding(.bottom, WorkstationLayout.bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // MARK: - Left Presets Drawer Overlay (Pre-rendered offscreen for 0ms instant open)
                HStack {
                    PresetsDrawerView(audio: audio)
                        .offset(x: audio.isPresetsPresented ? 0 : -350)
                        .opacity(audio.isPresetsPresented ? 1 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: audio.isPresetsPresented)
                    Spacer()
                }
                .allowsHitTesting(audio.isPresetsPresented)

                // MARK: - Liquid Glass Translucent Overlay (Floating Settings Panel)
                // MARK: - Liquid Glass Translucent Overlay (Floating Settings Panel)
                if audio.isInspectorPresented {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Settings")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    audio.isInspectorPresented = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding([.horizontal, .top], 20)
                        .padding(.bottom, 12)

                        // Horizontal Tab Selector
                        HStack(spacing: 8) {
                            ForEach(SettingsTab.allCases) { tab in
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        settingsTab = tab
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: tab.iconName)
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(tab.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(settingsTab == tab ?
                                                (audio.isAntiqueThemeEnabled ? Color.orange : Color.accentColor) :
                                                Color.clear)
                                    )
                                    .foregroundColor(settingsTab == tab ?
                                        (audio.isAntiqueThemeEnabled ? .black : .white) :
                                        .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                        Divider()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if settingsTab == .global {
                                    // Antique Electronic Box Theme Toggle
                                    Toggle("Antique Box Theme", isOn: $audio.isAntiqueThemeEnabled)
                                        .toggleStyle(.switch)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    // Shared Tanpura Tempo Controller
                                    VStack(spacing: 12) {
                                        HStack {
                                            Text("Shared Tanpura Tempo")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text("\(Int(audio.sharedTanpuraBPM)) BPM")
                                                .font(.caption)
                                                .monospacedDigit()
                                                .foregroundColor(.secondary)
                                        }
                                        Slider(
                                            value: Binding(
                                                get: { audio.sharedTanpuraBPM },
                                                set: { audio.sharedTanpuraBPM = round($0) }
                                            ),
                                            in: 20...180
                                        )
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Sankalp Form Info")
                                            .font(.headline)
                                            .foregroundColor(audio.isAntiqueThemeEnabled ? Color.orange : .primary)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("MKSM ID")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextField("Enter MKSM ID", text: $audio.studentID)
                                                .textFieldStyle(.roundedBorder)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("First Name")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextField("Enter First Name", text: $audio.firstName)
                                                .textFieldStyle(.roundedBorder)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Last Name")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextField("Enter Last Name", text: $audio.lastName)
                                                .textFieldStyle(.roundedBorder)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Email")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextField("Enter Email", text: $audio.email)
                                                .textFieldStyle(.roundedBorder)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Batch")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextField("Enter Batch", text: $audio.batch)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    }
                                }
                            }
                            .padding(20)
                        }
                    }
                    .frame(width: 280)
                    .frame(maxHeight: 520)
                    .nativeCard(isAntique: audio.isAntiqueThemeEnabled, cornerRadius: 20)
                    .padding(.trailing, 24)
                    .padding(.top, 24)
                }

                // MARK: - Launch Blurry Loading Overlay
                if audio.isAppLoading {
                    ZStack {
                        VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .progressViewStyle(.circular)
                            Text("Loading Workstation Audio & Assets...")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(28)
                        .nativeCard(isAntique: audio.isAntiqueThemeEnabled, cornerRadius: 22)
                    }
                    .transition(.opacity)
                }
            }
        }
        .frame(minWidth: WorkstationLayout.minWindowWidth, idealWidth: WorkstationLayout.minWindowWidth, minHeight: WorkstationLayout.minWindowHeight)
        .navigationTitle(Text(""))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    audio.isPresetsPresented.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sidebar.left")
                        Text("Presets")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(audio.isPresetsPresented ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help("Toggle Presets Drawer")
            }

            ToolbarItem(placement: .principal) {
                Text(audio.isAntiqueThemeEnabled ? "macTablaPro Vintage" : "macTablaPro")
                    .font(audio.isAntiqueThemeEnabled ? .custom("Snell Roundhand", size: 18).weight(.bold) : .headline)
                    .foregroundColor(audio.isAntiqueThemeEnabled ? Color.orange : .secondary)
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: {
                        audio.isMasterMuted.toggle()
                    }) {
                        Image(systemName: audio.isMasterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(audio.isMasterMuted ? .red : (audio.isAntiqueThemeEnabled ? Color.orange : .primary))
                    }
                    .buttonStyle(.plain)
                    .help(audio.isMasterMuted ? "Unmute All Instruments" : "Quick Mute All Instruments")

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            audio.isInspectorPresented.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Settings")
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(audio.isInspectorPresented ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Settings Drawer")
                }
            }
        }
    }
}

// MARK: - Dedicated Mixer Hub
struct MixerCardView: View {
    @ObservedObject var audio: AppAudioOrchestrator

    var body: some View {
        let isAntique = audio.isAntiqueThemeEnabled
        VStack(spacing: 16) {
            // Header with Master Play/Stop Transport Button
            HStack {
                Text("Master Mixer")
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                Spacer()
                
                Button(action: { audio.toggleMasterTransport() }) {
                    HStack(spacing: 4) {
                        Image(systemName: audio.isAnyInstrumentPlaying ? "square.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(audio.isAnyInstrumentPlaying ? "Stop All" : "Play All")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(CustomTagButtonStyle(isSelected: audio.isAnyInstrumentPlaying, isAntique: isAntique))
            }

            // System Master Volume Controller
            VStack(spacing: 6) {
                HStack {
                    Text("Master Volume")
                        .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                    Spacer()
                    Text("\(Int(audio.masterVolume * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(isAntique ? Color.yellow : .secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").font(.caption).foregroundColor(isAntique ? Color.orange : .secondary)
                    Slider(value: $audio.masterVolume, in: 0.0...1.0) { isEditing in
                        if !isEditing {
                            let snapshot = audio.capturePreset()
                            Task.detached(priority: .utility) {
                                await SettingsStorageService.shared.saveActiveSettings(snapshot)
                            }
                        }
                    }
                    .tint(isAntique ? .orange : .accentColor)
                    Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundColor(isAntique ? Color.orange : .secondary)
                }
            }
            .padding(10)
            .background(isAntique ? Color.black.opacity(0.2) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))



            Divider()

            VStack(spacing: 14) {
                if let tanpura1 = audio.tanpura1 {
                    MixerChannelRow(name: "Tanpura 1", instrument: tanpura1, isAntique: isAntique)
                }
                
                if let tanpura2 = audio.tanpura2 {
                    MixerChannelRow(name: "Tanpura 2", instrument: tanpura2, isAntique: isAntique)
                }

                if let tabla = audio.tabla {
                    MixerChannelRow(name: "Tabla", instrument: tabla, isAntique: isAntique)
                }
                
                if let swarMandal = audio.swarMandal {
                    MixerChannelRow(name: "Swar Mandal", instrument: swarMandal, isAntique: isAntique)
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
    }
}

// Extracted into a dedicated View to safely use @ObservedObject bindings
struct MixerChannelRow: View {
    let name: String
    @ObservedObject var instrument: Instrument
    var isAntique: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { instrument.togglePlay() }) {
                Text(name)
                    .font(isAntique ? .custom("Baskerville-Italic", size: 14).weight(.semibold) : .caption)
                    .frame(width: 70, alignment: .leading)
            }
            .buttonStyle(CustomTagButtonStyle(isSelected: instrument.isPlaying, isAntique: isAntique))

            // Mute Toggle Button
            Button(action: { instrument.isMuted.toggle() }) {
                Image(systemName: instrument.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(instrument.isMuted ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(instrument.isMuted ? "Unmute channel" : "Mute channel")

            // Volume Slider
            Slider(value: $instrument.volume, in: 0.0...1.0) { isEditing in
                if !isEditing {
                    let snapshot = instrument.orchestrator.capturePreset()
                    Task.detached(priority: .utility) {
                        await SettingsStorageService.shared.saveActiveSettings(snapshot)
                    }
                }
            }
            .tint((instrument.isPlaying && !instrument.isMuted) ? .accentColor : .gray)
        }
    }
}

// MARK: - 2. Global Pitch Controls
struct MasterPitchView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    
    // Split timers to handle the initial delay before fast-forwarding
    @State private var delayTimer: Timer?
    @State private var repeatTimer: Timer?
    
    var body: some View {
        let isAntique = audio.isAntiqueThemeEnabled
        VStack(spacing: 20) {
            Text("Master Tuning")
                .font(isAntique ? .custom("Snell Roundhand", size: 22).weight(.bold) : .headline)
                .foregroundColor(isAntique ? Color.orange : .secondary)
            
            // Giant Pitch Display with Chevrons (Full Display Height Click Target)
            HStack(spacing: 16) {
                RepeatingTouchButton(action: { executeCoarsePitchStep(upwards: false) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        Image(systemName: "chevron.left")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(isAntique ? Color.orange : .secondary)
                    }
                    .frame(width: 44, height: 105)
                    .contentShape(Rectangle())
                }
                
                let displayData = getDisplayData(baseCents: audio.scaleOffsetCents, fineCents: audio.fineTuneCents)
                
                NativeDisplayBox(width: 170, height: 105, isAntique: isAntique) {
                    ZStack(alignment: .topLeading) {
                        Text(displayData.noteName)
                            .font(isAntique ?
                                .system(size: 54, weight: .bold, design: .monospaced) :
                                .system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(isAntique ? Color.orange : .accentColor)
                            .shadow(color: isAntique ? Color.orange.opacity(0.8) : Color.cyan.opacity(0.4), radius: isAntique ? 8 : 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        if let centsText = displayData.fineCentsString {
                            Text(centsText)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(isAntique ? Color.yellow : (audio.fineTuneCents > 0 ? Color.green : Color.orange))
                                .shadow(color: isAntique ? Color.yellow.opacity(0.8) : (audio.fineTuneCents > 0 ? Color.green : Color.orange).opacity(0.6), radius: 4)
                                .padding([.top, .leading], 12)
                        }
                    }
                }
                
                RepeatingTouchButton(action: { executeCoarsePitchStep(upwards: true) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(isAntique ? Color.orange : .secondary)
                    }
                    .frame(width: 44, height: 105)
                    .contentShape(Rectangle())
                }
            }
            
            // Fine Tuning Slider Row with Circular ♭ / ♯ Buttons
            HStack(spacing: 12) {
                StepperCircleButton(textLabel: "♭", isAntique: isAntique) {
                    audio.fineTuneCents = max(-100, min(100, audio.fineTuneCents - 1.0))
                }
                
                Slider(
                    value: Binding(
                        get: { audio.fineTuneCents },
                        set: { audio.fineTuneCents = round($0) }
                    ),
                    in: -100...100
                ) { isEditing in
                    if !isEditing {
                        audio.commitPitchChange()
                    }
                }
                .tint(isAntique ? .orange : (audio.fineTuneCents == 0 ? .gray : .accentColor))
                
                StepperCircleButton(textLabel: "♯", isAntique: isAntique) {
                    audio.fineTuneCents = max(-100, min(100, audio.fineTuneCents + 1.0))
                }
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isAntique ?
                    Color(NSColor.windowBackgroundColor).opacity(0.85) :
                    Color(NSColor.controlBackgroundColor)
                )
                .shadow(color: isAntique ? Color.orange.opacity(0.15) : Color.black.opacity(0.05), radius: isAntique ? 6 : 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isAntique ?
                    LinearGradient(colors: [Color.orange.opacity(0.5), Color.yellow.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isAntique ? 1.5 : 1.0
                )
        )
    }
    
    private func executeCoarsePitchStep(upwards: Bool) {
        if upwards {
            if audio.fineTuneCents > 0 {
                audio.scaleOffsetCents = min(1600, audio.scaleOffsetCents + 100)
            } else if audio.fineTuneCents < 0 {
                // Snap forward[cite: 10]
            } else {
                audio.scaleOffsetCents = min(1600, audio.scaleOffsetCents + 100)
            }
        } else {
            if audio.fineTuneCents > 0 {
                 // Snap backward[cite: 10]
            } else if audio.fineTuneCents < 0 {
                audio.scaleOffsetCents = max(-300, audio.scaleOffsetCents - 100)
            } else {
                audio.scaleOffsetCents = max(-300, audio.scaleOffsetCents - 100)
            }
        }
        audio.fineTuneCents = 0.0
    }

    private func getDisplayData(baseCents: Double, fineCents: Double) -> NoteDisplayData {
        let baseIndex = 3
        let semitoneOffset = Int(baseCents / 100.0)
        let currentIndex = baseIndex + semitoneOffset
        
        guard currentIndex >= 0 && currentIndex < centsNoteNames.count else {
            return NoteDisplayData(noteName: "---", fineCentsString: nil)
        }

        var fineString: String? = nil
        if fineCents != 0 {
            let sign = fineCents > 0 ? "+" : ""
            fineString = "\(sign)\(Int(fineCents))¢"
        }
        return NoteDisplayData(noteName: centsNoteNames[currentIndex], fineCentsString: fineString)
    }
}

/// MARK: - Tanpura Card View (No Play Button)
struct TanpuraCardView: View {
    @ObservedObject var tanpura: Tanpura
    @ObservedObject var audio: AppAudioOrchestrator
    let title: String
    @State private var isSettingsExpanded: Bool = false
    @State private var delayTimer: Timer?
    @State private var repeatTimer: Timer?

    let quickOptions: [PickerNote] = [
        PickerNote(name: "Pa", cents: 700.0),
        PickerNote(name: "Ma", cents: 500.0),
        PickerNote(name: "Ni", cents: 1100.0),
    ]

    var isQuickOptionSelected: Bool {
        quickOptions.contains { $0.cents == tanpura.firstStringPitch }
    }

    var body: some View {
        let isAntique = tanpura.orchestrator.isAntiqueThemeEnabled
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tanpura.isPlaying ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .shadow(color: tanpura.isPlaying ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                
                Text(title)
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                Spacer()
            }

            // String Pitch Selector & Off Control
            HStack(spacing: 6) {
                // 1. Off Tag Button (Default Off)
                Button(action: {
                    if tanpura.isPlaying {
                        tanpura.togglePlay()
                    }
                }) {
                    Text("Off").fontWeight(.medium).frame(maxWidth: .infinity)
                }
                .buttonStyle(CustomTagButtonStyle(isSelected: !tanpura.isPlaying, isAntique: isAntique))

                // 2. Note Tag Buttons (Pa, Ma, Ni)
                ForEach(quickOptions, id: \.cents) { option in
                    Button(action: {
                        tanpura.firstStringPitch = option.cents
                        if !tanpura.isPlaying {
                            tanpura.togglePlay()
                        }
                    }) {
                        Text(option.name).fontWeight(.medium).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CustomTagButtonStyle(isSelected: tanpura.isPlaying && tanpura.firstStringPitch == option.cents, isAntique: isAntique))
                }

                // 3. Overflow Menu for custom pitches
                let customPitchName = stringPickerItems.first(where: { $0.cents == tanpura.firstStringPitch })?.name ?? "..."
                let isCustomSelected = tanpura.isPlaying && !isQuickOptionSelected
                Menu {
                    ForEach(stringPickerItems, id: \.self) { item in
                        Button(action: {
                            tanpura.firstStringPitch = item.cents
                            if !tanpura.isPlaying {
                                tanpura.togglePlay()
                            }
                        }) {
                            HStack {
                                Text(item.name)
                                if tanpura.firstStringPitch == item.cents { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Text("...").fontWeight(.medium).frame(maxWidth: .infinity)
                }
                .menuIndicator(.hidden)
                .buttonStyle(CustomTagButtonStyle(isSelected: isCustomSelected, isAntique: isAntique))
            }

        }
        .padding(16)
        .frame(width: 340)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
    }

    @ViewBuilder
    private func tempoAdjustmentButton(label: String, isIncrementing: Bool) -> some View {
        Image(systemName: label)
            .foregroundColor(.secondary)
            .font(.title3)
            .contentShape(Rectangle())
            .onTapGesture {
                tanpura.tempoBPM = max(60, min(140, tanpura.tempoBPM + (isIncrementing ? 1.0 : -1.0)))
            }
            .onLongPressGesture(minimumDuration: 0.0, pressing: { isPressing in
                if isPressing {
                    delayTimer?.invalidate()
                    repeatTimer?.invalidate()
                    delayTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in
                            tanpura.tempoBPM = max(60, min(140, tanpura.tempoBPM + (isIncrementing ? 1.0 : -1.0)))
                        }
                        RunLoop.main.add(timer, forMode: .common)
                        self.repeatTimer = timer
                    }
                } else {
                    delayTimer?.invalidate()
                    repeatTimer?.invalidate()
                }
            }, perform: {})
    }
}

// MARK: - Custom Styles
struct CustomTagButtonStyle: ButtonStyle {
    var isSelected: Bool
    var isAntique: Bool = false
    
    private var backgroundColor: Color {
        if isSelected {
            return isAntique ? Color.orange : Color.accentColor
        } else {
            return isAntique ? Color.black.opacity(0.12) : Color.gray.opacity(0.15)
        }
    }
    
    private var strokeColor: Color {
        if isAntique {
            return isSelected ? Color.yellow.opacity(0.8) : Color.orange.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else {
            return .primary
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(strokeColor, lineWidth: isAntique ? 1.0 : 0)
            )
            .foregroundColor(textColor)
            .shadow(color: (isAntique && isSelected) ? Color.orange.opacity(0.6) : Color.clear, radius: 4)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Tabla Card View
struct TablaCardView: View {
    @ObservedObject var tabla: Tabla
    let database = TablaDatabase.shared
    
    @State private var isSettingsExpanded: Bool = false
    @State private var bpmInputText: String = ""
    @State private var isEditingBPM: Bool = false

    private func tempoCategoryName(tier: Int) -> String {
        switch tier {
        case 0: return "Ati-Vilambit"
        case 1, 55: return "Vilambit"
        case 2: return "Madhya"
        case 3: return "Drut"
        case 4: return "Ati-Drut"
        default: return "Custom"
        }
    }

    private func getTaalSymbol(matra: Int, taal: TaalDefinition?) -> String {
        guard let taal = taal else { return "" }
        if taal.khaaliMatras.contains(matra) {
            return "O"
        }
        let sortedTaalis = taal.taaliMatras.sorted()
        if let taaliIndex = sortedTaalis.firstIndex(of: matra) {
            if matra == 1 {
                return "X"
            } else {
                let number = taaliIndex + (taal.taaliMatras.contains(1) ? 1 : 2)
                return "\(number)"
            }
        }
        return ""
    }

    private var sortedTaalList: [TaalDefinition] {
        database.taalCatalog.values.sorted {
            if $0.matras != $1.matras {
                return $0.matras < $1.matras
            }
            return $0.name < $1.name
        }
    }

    private func matraDisplayString(for matras: Double) -> String {
        if matras.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(matras))"
        } else {
            return String(format: "%.2f", matras)
        }
    }

    private var subBeatDotsText: String {
        let activeDots = (tabla.currentMatraSubStep % 4) + 1
        return String(repeating: "· ", count: activeDots).trimmingCharacters(in: .whitespaces)
    }

    private var activeTaalSymbol: String {
        getTaalSymbol(matra: tabla.currentMatra, taal: database.taalCatalog[tabla.activeTaal])
    }

    var body: some View {
        let isAntique = tabla.orchestrator.isAntiqueThemeEnabled
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tabla.isPlaying ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .shadow(color: tabla.isPlaying ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                
                Text("Tabla")
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                Spacer()
            }

            // Dropdown Pickers for Taal and Variation selection
            VStack(spacing: 8) {
                HStack {
                    Text("Taal")
                        .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                    Spacer()
                    Menu {
                        ForEach(sortedTaalList, id: \.name) { taal in
                            Button(action: {
                                if tabla.activeTaal != taal.name {
                                    tabla.activeTaal = taal.name
                                    if taal.name == "Metronome" {
                                        tabla.activeVariation = "1 beat Basic"
                                    } else {
                                        tabla.activeVariation = "Pro Default"
                                    }
                                    DispatchQueue.main.async {
                                        tabla.clampTempoToAllowedRange()
                                    }
                                }
                            }) {
                                HStack {
                                    Text("\(taal.name) (\(matraDisplayString(for: taal.matras)))")
                                    if tabla.activeTaal == taal.name {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(tabla.activeTaal) (\(matraDisplayString(for: database.taalCatalog[tabla.activeTaal]?.matras ?? 16.0)))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isAntique ? Color.orange : .primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isAntique ? Color.orange.opacity(0.8) : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isAntique ? Color.black.opacity(0.3) : Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isAntique ? Color.orange.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                
                HStack {
                    Text("Style")
                        .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                    Spacer()
                    Menu {
                        ForEach(database.taalCatalog[tabla.activeTaal]?.orderedVariationNames ?? [], id: \.self) { variationName in
                            Button(action: {
                                if tabla.activeVariation != variationName {
                                    tabla.activeVariation = variationName
                                    DispatchQueue.main.async {
                                        tabla.clampTempoToAllowedRange()
                                    }
                                }
                            }) {
                                HStack {
                                    Text(variationName)
                                    if tabla.activeVariation == variationName {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(tabla.activeVariation)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isAntique ? Color.orange : .primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isAntique ? Color.orange.opacity(0.8) : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isAntique ? Color.black.opacity(0.3) : Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isAntique ? Color.orange.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }

            // Central Display and Play/Stop Control
            HStack(spacing: 20) {
                NativeDisplayBox(width: 145, height: 95, isAntique: isAntique) {
                    ZStack {
                        // 1. Top Bar: Symbol (Left), Sub-beat Dots (Center), BPM Number & Label (Right)
                        VStack {
                            HStack(alignment: .top) {
                                // Top-Left: Taal Symbol (Sam 'X' or Taali/Khali)
                                if tabla.isPlaying && !activeTaalSymbol.isEmpty {
                                    Text(activeTaalSymbol)
                                        .font(isAntique ?
                                            .system(size: 14, weight: .bold, design: .monospaced) :
                                            .system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(isAntique ? Color.yellow : Color.cyan.opacity(0.9))
                                        .shadow(color: isAntique ? Color.yellow.opacity(0.8) : Color.cyan.opacity(0.6), radius: 3)
                                }
                                
                                Spacer()

                                // Top-Center: Quarter-Matra Sub-Clock Dots (STRICTLY for Ati-Vilambit, Tier 0)
                                if tabla.isPlaying && tabla.currentTempoTier() == 0 {
                                    Text(subBeatDotsText)
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundColor(isAntique ? Color.yellow : Color.cyan)
                                        .shadow(color: isAntique ? Color.yellow.opacity(0.8) : Color.cyan.opacity(0.7), radius: 3)
                                }

                                Spacer()

                                // Top-Right: BPM Number (Editable with I-Beam Cursor) with 'bpm' underneath
                                VStack(alignment: .trailing, spacing: -2) {
                                    if isEditingBPM {
                                        TextField("", text: $bpmInputText, onCommit: {
                                            if let val = Double(bpmInputText) {
                                                let range = tabla.allowedBPMRange()
                                                tabla.tempoBPM = max(range.lowerBound, min(range.upperBound, val))
                                            }
                                            isEditingBPM = false
                                        })
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                        .font(isAntique ?
                                            .system(size: 15, weight: .bold, design: .monospaced) :
                                            .system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(isAntique ? Color.yellow : Color.cyan.opacity(0.95))
                                        .frame(width: 45)
                                    } else {
                                        Text("\(Int(tabla.tempoBPM))")
                                            .font(isAntique ?
                                                .system(size: 15, weight: .bold, design: .monospaced) :
                                                .system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(isAntique ? Color.yellow : Color.cyan.opacity(0.95))
                                            .onTapGesture {
                                                bpmInputText = "\(Int(tabla.tempoBPM))"
                                                isEditingBPM = true
                                            }
                                            .onHover { isHovered in
                                                if isHovered {
                                                    NSCursor.iBeam.push()
                                                } else {
                                                    NSCursor.pop()
                                                }
                                            }
                                    }
                                    Text("bpm")
                                        .font(isAntique ?
                                            .system(size: 9, weight: .semibold, design: .monospaced) :
                                            .system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundColor(isAntique ? Color.yellow.opacity(0.7) : Color.cyan.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            // Bottom-Center: Laya Category Name (Ati-Vilambit, Vilambit, Madhya, Drut, Ati-Drut)
                            Text(tempoCategoryName(tier: tabla.currentTempoTier()))
                                .font(isAntique ?
                                    .custom("Baskerville-Italic", size: 13).weight(.semibold) :
                                    .system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(isAntique ? Color.orange : Color.white.opacity(0.85))
                        }
                        .padding(8)

                        // 2. Center: Larger Matra Beat Number (No "OFF" label)
                        if tabla.isPlaying {
                            Text("\(tabla.currentMatra)")
                                .font(isAntique ?
                                    .system(size: 44, weight: .bold, design: .monospaced) :
                                    .system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(isAntique ? Color.orange : .white)
                                .shadow(color: isAntique ? Color.orange.opacity(0.8) : Color.white.opacity(0.7), radius: 8)
                        }
                    }
                }

                Button(action: { tabla.togglePlay() }) {
                    Image(systemName: tabla.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(tabla.isPlaying ? Color.red : (isAntique ? Color.orange : Color.accentColor))
                        .clipShape(Circle())
                        .shadow(color: isAntique ? Color.orange.opacity(0.5) : Color.clear, radius: 4)
                }
                .buttonStyle(.plain)
            }

            // Debugging Panel: Phonetic Bol Name Display
            HStack {
                Text("Bol:")
                    .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                    .foregroundColor(isAntique ? Color.orange : .secondary)
                Text(tabla.isPlaying && !tabla.currentBolName.isEmpty ? tabla.currentBolName : "—")
                    .font(isAntique ? .custom("Snell Roundhand", size: 16).weight(.bold) : .subheadline)
                    .foregroundColor(isAntique ? Color.yellow : .primary)
                Spacer()
                
                // Sur Tabla Toggle Switch
                Toggle("Sur Tabla", isOn: $tabla.useSurTabla)
                    .toggleStyle(.switch)
                    .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                    .foregroundColor(isAntique ? Color.orange : .secondary)
            }
            .padding(.horizontal, 4)

            // Permanently Visible Settings & Tempo Controls (Flanked Slider & Multipliers)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StepperCircleButton(iconName: "minus", isAntique: isAntique) {
                        let range = tabla.allowedBPMRange()
                        tabla.tempoBPM = max(range.lowerBound, tabla.tempoBPM - 1)
                    }

                    Slider(
                        value: Binding(
                            get: { tabla.bpmToLogSliderValue(tabla.tempoBPM) },
                            set: { newValue in
                                tabla.tempoBPM = tabla.logSliderValueToBPM(newValue)
                            }
                        ),
                        in: 0.0...1.0
                    ) { isEditing in
                        if !isEditing {
                            let snapshot = tabla.orchestrator.capturePreset()
                            Task.detached(priority: .utility) {
                                await SettingsStorageService.shared.saveActiveSettings(snapshot)
                            }
                        }
                    }
                    .tint(isAntique ? .orange : .accentColor)

                    StepperCircleButton(iconName: "plus", isAntique: isAntique) {
                        let range = tabla.allowedBPMRange()
                        tabla.tempoBPM = min(range.upperBound, tabla.tempoBPM + 1)
                    }
                }

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        let range = tabla.allowedBPMRange()
                        TempoActionButton(label: "-5", isAntique: isAntique) {
                            tabla.tempoBPM = max(range.lowerBound, round(tabla.tempoBPM - 5))
                        }

                        TempoActionButton(label: "x/2", isAntique: isAntique) {
                            tabla.tempoBPM = max(range.lowerBound, round(tabla.tempoBPM / 2.0))
                        }

                        TempoActionButton(label: "2x", isAntique: isAntique) {
                            tabla.tempoBPM = min(range.upperBound, round(tabla.tempoBPM * 2.0))
                        }

                        TempoActionButton(label: "+5", isAntique: isAntique) {
                            tabla.tempoBPM = min(range.upperBound, round(tabla.tempoBPM + 5))
                        }
                    }
                }
            }
            .font(.subheadline)
            .tint(isAntique ? Color.orange : .secondary)
        }
        .padding(16)
        .frame(width: 340)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
    }
}



// MARK: - Left Presets Translucent Glass Drawer View
struct PresetsDrawerView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @State private var searchFilter: String = ""
    @State private var newPresetName: String = ""
    @State private var isShowingSaveField = false

    var filteredPresets: [ITablaProPreset] {
        let baseList = audio.allPresets.sorted { $0.PresetName.localizedStandardCompare($1.PresetName) == .orderedAscending }
        if searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return baseList
        }
        return baseList.filter { $0.PresetName.localizedCaseInsensitiveContains(searchFilter) }
    }

    private func presetTooltipText(for preset: ITablaProPreset) -> String {
        """
        🎵 Preset: \(preset.PresetName)
        • Pitch: \(preset.PitchName)
        • Tanpura 1: \(preset.Tanpura1FirstString) (\(Int(preset.Tanpura1Gain * 100))%)
        • Tanpura 2: \(preset.Tanpura2FirstString) (\(Int(preset.Tanpura2Gain * 100))%)
        • Tabla: \(preset.TaalName) - \(preset.StyleName) (\(Int(preset.Tempo)) BPM)
        """
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Workstation Presets")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        audio.isPresetsPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Search Bar Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Filter presets...", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchFilter.isEmpty {
                    Button(action: { searchFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            Divider()

            // Presets Scroll List (Auto-centered on active preset)
            if filteredPresets.isEmpty {
                Text("No matching presets found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(filteredPresets) { preset in
                                let isActive = (audio.activePresetName == preset.PresetName)
                                HStack(spacing: 6) {
                                    // Favorite Star Toggle
                                    Button(action: {
                                        Task {
                                            await SettingsStorageService.shared.toggleFavorite(presetName: preset.PresetName)
                                            audio.refreshAllPresets()
                                        }
                                    }) {
                                        Image(systemName: preset.IsFavorite ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundColor(preset.IsFavorite ? .yellow : .secondary.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)

                                    // Apply Preset Button with Hover Tooltip & Right-Click Context Menu
                                    Button(action: {
                                        audio.applyPreset(preset)
                                        Task {
                                            await SettingsStorageService.shared.saveActiveSettings(preset)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isActive ? (audio.isAntiqueThemeEnabled ? .orange : .accentColor) : .secondary)
                                            Text(preset.PresetName)
                                                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                                                .foregroundColor(isActive ? .primary : .secondary)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isActive ?
                                                    (audio.isAntiqueThemeEnabled ? Color.orange.opacity(0.25) : Color.accentColor.opacity(0.2)) :
                                                    Color(NSColor.controlBackgroundColor).opacity(0.4)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isActive ? (audio.isAntiqueThemeEnabled ? Color.orange : Color.accentColor) : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .help(presetTooltipText(for: preset))
                                    .contextMenu {
                                        Text("🎵 \(preset.PresetName)").font(.headline)
                                        Divider()
                                        Text("Pitch: \(preset.PitchName)")
                                        Text("Tanpura 1: \(preset.Tanpura1FirstString) (\(Int(preset.Tanpura1Gain * 100))%)")
                                        Text("Tanpura 2: \(preset.Tanpura2FirstString) (\(Int(preset.Tanpura2Gain * 100))%)")
                                        Text("Tabla: \(preset.TaalName) (\(preset.StyleName)) @ \(Int(preset.Tempo)) BPM")
                                    }

                                    // Delete Preset Button
                                    Button(action: {
                                        Task {
                                            await SettingsStorageService.shared.deletePreset(name: preset.PresetName)
                                            if audio.activePresetName == preset.PresetName {
                                                audio.activePresetName = nil
                                            }
                                            audio.refreshAllPresets()
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete Preset")
                                }
                                .id(preset.PresetName)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                    .onAppear {
                        if let activeName = audio.activePresetName {
                            scrollProxy.scrollTo(activeName, anchor: .center)
                        }
                    }
                    .onChange(of: audio.isPresetsPresented) { isPresented in
                        if isPresented, let activeName = audio.activePresetName {
                            scrollProxy.scrollTo(activeName, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Save Custom Preset Field
            if isShowingSaveField {
                VStack(spacing: 8) {
                    TextField("Preset Name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Cancel") {
                            isShowingSaveField = false
                            newPresetName = ""
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Save") {
                            let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let snapshot = audio.capturePreset(name: name)
                            Task {
                                await SettingsStorageService.shared.savePreset(snapshot)
                                audio.activePresetName = name
                                audio.refreshAllPresets()
                                isShowingSaveField = false
                                newPresetName = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                Button(action: {
                    isShowingSaveField = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Save Current as Preset")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            // Finder & Reset Utility Buttons
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await SettingsStorageService.shared.openPresetsFolderInFinder()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                        Text("Reveal in Finder")
                    }
                    .font(.system(size: 11, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Open Application Support folder containing presets.json to share")

                Spacer()

                Button(action: {
                    Task {
                        await SettingsStorageService.shared.resetPresetsToDefault()
                        audio.refreshAllPresets()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Defaults")
                    }
                    .font(.system(size: 11, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundColor(.orange.opacity(0.8))
                .help("Restore factory presets.json from app bundle")
            }
        }
        .padding(16)
        .frame(width: 300)
        .nativeCard(isAntique: audio.isAntiqueThemeEnabled, cornerRadius: 20)
        .padding(.leading, 24)
        .padding(.top, 12)
    }
}

// MARK: - Sankalp Practice Log Views & Styles
struct SankalpCardView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @State private var isShowingLogDialog = false
    
    var body: some View {
        let isAntique = audio.isAntiqueThemeEnabled
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .foregroundColor(isAntique ? Color.orange : .accentColor)
                Text("Sankalp Practice Log")
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                Spacer()
            }
            
            // Stats Row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SESSION")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatDuration(seconds: audio.sessionSeconds))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isAntique ? Color.yellow : .primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatDuration(seconds: audio.dailySeconds))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isAntique ? Color.yellow : .primary)
                }
            }
            .padding(.vertical, 2)
            
            // Log Button
            Button(action: {
                isShowingLogDialog = true
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "square.and.pencil")
                    Text("Log Sankalp")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(SankalpButtonStyle(isProminent: !audio.hasLoggedToday, isAntique: isAntique))
        }
        .padding(16)
        .frame(width: 340)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
        .sheet(isPresented: $isShowingLogDialog) {
            SankalpLogDialog(audio: audio, isPresented: $isShowingLogDialog)
        }
    }
    
    private func formatDuration(seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins)m \(secs)s"
    }
}

struct SankalpButtonStyle: ButtonStyle {
    var isProminent: Bool
    var isAntique: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let defaultBg: Color = isProminent ? .accentColor : Color(NSColor.controlBackgroundColor)
        let antiqueBg: Color = isProminent ? .orange : Color.black.opacity(0.3)
        let activeBg = isAntique ? antiqueBg : defaultBg
        
        let defaultFg: Color = isProminent ? .white : .primary
        let antiqueFg: Color = isProminent ? .black : Color.orange
        let activeFg = isAntique ? antiqueFg : defaultFg
        
        return configuration.label
            .foregroundColor(activeFg)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(activeBg.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAntique ? Color.orange.opacity(0.6) : Color(NSColor.separatorColor), lineWidth: isProminent ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SankalpLogDialog: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @Binding var isPresented: Bool
    
    @State private var minutes: Int = 1
    @State private var date: Date = Date()
    @State private var summary: String = ""
    @State private var sankalpWord: String = ""
    
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        let isAntique = audio.isAntiqueThemeEnabled
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("Submit Sankalp Practice Log")
                .font(isAntique ? .custom("Snell Roundhand", size: 22).weight(.bold) : .title2)
                .foregroundColor(isAntique ? Color.orange : .primary)
                .padding(.bottom, 2)
            
            // Student Info Summary
            VStack(alignment: .leading, spacing: 4) {
                Text("STUDENT INFO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                if audio.studentID.isEmpty || audio.firstName.isEmpty || audio.lastName.isEmpty || audio.email.isEmpty {
                    Text("⚠️ Warning: Sankalp Form Info is incomplete. Please configure it in Settings first.")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("\(audio.firstName) \(audio.lastName) (\(audio.studentID))")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("\(audio.email) — Batch: \(audio.batch)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isAntique ? Color.black.opacity(0.2) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Inputs List
            VStack(spacing: 12) {
                // Practice Date Row
                HStack {
                    Text("Practice Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                
                // Minutes Practiced Row
                HStack {
                    Text("Minutes Practiced")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("", value: $minutes, formatter: NumberFormatter())
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $minutes, in: 1...1440)
                            .labelsHidden()
                    }
                }
                
                // Practice Summary
                VStack(alignment: .leading, spacing: 6) {
                    Text("Practice Summary (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextEditor(text: $summary)
                        .frame(height: 80)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isAntique ? Color.orange.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Sankalp Word
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sankalp Word (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Enter Sankalp word", text: $sankalpWord)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)
                
                Button(action: submitLog) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 60, height: 16)
                    } else {
                        Text("Submit Log")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || audio.studentID.isEmpty || audio.firstName.isEmpty || audio.lastName.isEmpty || audio.email.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            // Set defaults
            self.minutes = max(1, Int(audio.sessionSeconds / 60.0))
            self.summary = UserDefaults.standard.string(forKey: "SankalpLastPracticeSummary") ?? ""
            self.sankalpWord = UserDefaults.standard.string(forKey: "SankalpLastWord") ?? ""
        }
    }
    
    private func submitLog() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await audio.submitSankalpForm(
                    studentId: audio.studentID,
                    firstName: audio.firstName,
                    lastName: audio.lastName,
                    email: audio.email,
                    batch: audio.batch,
                    minutes: minutes,
                    summary: summary,
                    sankalpWord: sankalpWord,
                    date: date
                )
                
                // Save last used parameters for prefill
                UserDefaults.standard.set(summary, forKey: "SankalpLastPracticeSummary")
                UserDefaults.standard.set(sankalpWord, forKey: "SankalpLastWord")
                
                // Mark as logged today
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let todayStr = formatter.string(from: Date())
                audio.lastLogDateString = todayStr
                UserDefaults.standard.set(todayStr, forKey: "SankalpLastLogDate")
                
                // Reset session seconds
                audio.sessionSeconds = 0.0
                
                isSubmitting = false
                isPresented = false
            } catch {
                errorMessage = "❌ Submission failed: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

#Preview {
    ContentView()
}

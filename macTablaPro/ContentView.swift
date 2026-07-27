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

struct ContentView: View {
    @StateObject private var audio = AppAudioOrchestrator()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Master Header Bar (Integrated with macOS Traffic Lights)
            HStack(spacing: 16) {
                // Presets Drawer Toggle Button (Left)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        audio.isPresetsPresented.toggle()
                    }
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

                Spacer()

                Text(audio.isAntiqueThemeEnabled ? "Raagini & Tabla Digital" : "macTablaPro Studio")
                    .font(audio.isAntiqueThemeEnabled ? .custom("Snell Roundhand", size: 22).weight(.bold) : .headline)
                    .foregroundColor(audio.isAntiqueThemeEnabled ? Color.orange : .secondary)

                Spacer()

                // Settings Floating Panel Toggle Button (Right)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // MARK: - Main Workspace (Zero-Scroll 3-Column Layout with Split Glass Overlays)
            ZStack(alignment: .top) {
                HStack(alignment: .top, spacing: 24) {
                    // 1. LEFT COLUMN: Tanpura 1 & 2 Cards Stacked
                    VStack(spacing: 18) {
                        if let tanpura1 = audio.tanpura1 {
                            TanpuraCardView(tanpura: tanpura1, audio: audio, title: "Tanpura 1")
                        }
                        
                        if let tanpura2 = audio.tanpura2 {
                            TanpuraCardView(tanpura: tanpura2, audio: audio, title: "Tanpura 2")
                        }
                    }

                    // 2. CENTER COLUMN: Master Pitch (Top) + Tabla Controls (Center)
                    VStack(spacing: 20) {
                        MasterPitchView(audio: audio)
                        
                        if let tabla = audio.tabla {
                            TablaCardView(tabla: tabla)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // 3. RIGHT COLUMN: Master Mixer Hub (ALWAYS VISIBLE!)
                    MixerCardView(audio: audio)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // MARK: - Left Presets Drawer Overlay
                if audio.isPresetsPresented {
                    HStack {
                        PresetsDrawerView(audio: audio)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Spacer()
                    }
                }

                // MARK: - Liquid Glass Translucent Overlay (Floating Settings Panel)
                if audio.isInspectorPresented {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Global Settings")
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

                        Divider()

                        // Antique Electronic Box Theme Toggle
                        Toggle("Antique Box Theme", isOn: $audio.isAntiqueThemeEnabled)
                            .toggleStyle(.switch)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // Audio Output Selector
                        if !audio.availableOutputDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Audio Output Device")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Picker("", selection: $audio.selectedOutputDeviceID) {
                                    ForEach(audio.availableOutputDevices) { device in
                                        Text(device.name).tag(device.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }

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
                            Slider(value: $audio.sharedTanpuraBPM, in: 20...180, step: 1.0)
                        }
                    }
                    .padding(20)
                    .frame(width: 280)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: -2, y: 4)
                    .padding(.trailing, 24)
                    .padding(.top, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 1050, idealWidth: 1150, minHeight: 650)
        .background(Color(NSColor.windowBackgroundColor))
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
                    Slider(value: $audio.masterVolume, in: 0.0...1.0)
                        .tint(isAntique ? .orange : .accentColor)
                    Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundColor(isAntique ? Color.orange : .secondary)
                }
            }
            .padding(10)
            .background(isAntique ? Color.black.opacity(0.2) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Audio Output Device Selector
            if !audio.availableOutputDevices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Audio Output")
                            .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                            .foregroundColor(isAntique ? Color.orange : .secondary)
                        Spacer()
                        Picker("", selection: $audio.selectedOutputDeviceID) {
                            ForEach(audio.availableOutputDevices) { device in
                                Text(device.name).tag(device.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
                .padding(.horizontal, 4)
            }

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
            }
        }
        .padding(20)
        .frame(width: 300)
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
            Slider(value: $instrument.volume, in: 0.0...1.0)
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
            
            // Giant Pitch Display with Chevrons
            HStack(spacing: 30) {
                Button(action: { executeCoarsePitchStep(upwards: false) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                }
                .buttonStyle(.plain)
                
                let displayData = getDisplayData(baseCents: audio.scaleOffsetCents, fineCents: audio.fineTuneCents)
                
                LiquidGlassDisplay(width: 170, height: 105, isAntique: isAntique) {
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
                
                Button(action: { executeCoarsePitchStep(upwards: true) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Fine Tuning Slider Row
            HStack(spacing: 16) {
                continuousAdjustmentButton(label: "♭", isIncrementing: false)
                    .font(.title2)
                    .foregroundColor(isAntique ? Color.orange : .secondary)
                
                Slider(value: $audio.fineTuneCents, in: -100...100, step: 1.0)
                    .tint(isAntique ? .orange : (audio.fineTuneCents == 0 ? .gray : .accentColor))
                    .frame(width: 200)
                
                continuousAdjustmentButton(label: "♯", isIncrementing: true)
                    .font(.title2)
                    .foregroundColor(isAntique ? Color.orange : .secondary)
            }
        }
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
    
    @ViewBuilder
    private func continuousAdjustmentButton(label: String, isIncrementing: Bool) -> some View {
        Text(label)
            .foregroundColor(.secondary)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
            .onTapGesture {
                audio.fineTuneCents = max(-100, min(100, audio.fineTuneCents + (isIncrementing ? 1.0 : -1.0)))
            }
            .onLongPressGesture(minimumDuration: 0.0, pressing: { isPressing in
                if isPressing {
                    // Wait 0.4 seconds before starting the fast-forward loop
                    delayTimer?.invalidate()
                    repeatTimer?.invalidate()
                    delayTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                        let timer = Timer(timeInterval: 0.02, repeats: true) { _ in
                            audio.fineTuneCents = max(-100, min(100, audio.fineTuneCents + (isIncrementing ? 1.0 : -1.0)))
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
                if isAntique {
                    Circle()
                        .fill(tanpura.isPlaying ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: (tanpura.isPlaying ? Color.green : Color.red).opacity(0.8), radius: 4)
                }
                
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

            // RESTORED: Collapsible Settings Pane
            DisclosureGroup("Settings", isExpanded: $isSettingsExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tempo: \(Int(tanpura.tempoBPM)) BPM")
                        .font(.caption)
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                        .padding(.top, 4)

                    HStack(spacing: 12) {
                        tempoAdjustmentButton(label: "minus.circle.fill", isIncrementing: false)
                        
                        Slider(value: $tanpura.tempoBPM, in: 60...140, step: 1.0)
                            .tint(isAntique ? .orange : .accentColor)
                        
                        tempoAdjustmentButton(label: "plus.circle.fill", isIncrementing: true)
                    }
                }
            }
            .font(.subheadline)
            .tint(isAntique ? Color.orange : .secondary)
        }
        .padding(16)
        .frame(width: 280)
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
    let database = TablaDatabase()
    
    @State private var isSettingsExpanded: Bool = false

    private func tempoCategoryName(tier: Int) -> String {
        switch tier {
        case 0: return "Ati-Vilambit"
        case 1: return "Vilambit"
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

    var body: some View {
        let isAntique = tabla.orchestrator.isAntiqueThemeEnabled
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                if isAntique {
                    Circle()
                        .fill(tabla.isPlaying ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: (tabla.isPlaying ? Color.green : Color.red).opacity(0.8), radius: 4)
                }
                
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
                    let sortedTaals = database.taalCatalog.values.sorted {
                        if $0.matras != $1.matras {
                            return $0.matras < $1.matras
                        }
                        return $0.name < $1.name
                    }
                    Picker("", selection: $tabla.activeTaal) {
                        ForEach(sortedTaals, id: \.name) { taal in
                            Text("\(taal.name) (\(Int(taal.matras)))").tag(taal.name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: tabla.activeTaal) { newTaal in
                        if let firstVar = database.taalCatalog[newTaal]?.orderedVariationNames.first {
                            tabla.activeVariation = firstVar
                        }
                        tabla.clampTempoToAllowedRange()
                    }
                }
                
                HStack {
                    Text("Style")
                        .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                    Spacer()
                    Picker("", selection: $tabla.activeVariation) {
                        let variations = database.taalCatalog[tabla.activeTaal]?.orderedVariationNames ?? []
                        ForEach(variations, id: \.self) { variationName in
                            Text(variationName).tag(variationName)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: tabla.activeVariation) { _ in
                        tabla.clampTempoToAllowedRange()
                    }
                }
            }

            // Central Matra Display and Play/Stop Control
            HStack(spacing: 20) {
                LiquidGlassDisplay(width: 115, height: 75, isAntique: isAntique) {
                    ZStack(alignment: .topLeading) {
                        if tabla.isPlaying {
                            let symbol = getTaalSymbol(matra: tabla.currentMatra, taal: database.taalCatalog[tabla.activeTaal])
                            if !symbol.isEmpty {
                                Text(symbol)
                                    .font(isAntique ?
                                        .system(size: 15, weight: .bold, design: .monospaced) :
                                        .system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(isAntique ? Color.yellow : Color.cyan.opacity(0.9))
                                    .shadow(color: isAntique ? Color.yellow.opacity(0.8) : Color.cyan.opacity(0.6), radius: 4)
                                    .padding(.top, 8)
                                    .padding(.leading, 12)
                            }
                            
                            Text("\(tabla.currentMatra)")
                                .font(isAntique ?
                                    .system(size: 38, weight: .bold, design: .monospaced) :
                                    .system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(isAntique ? Color.orange : .white)
                                .shadow(color: isAntique ? Color.orange.opacity(0.8) : Color.white.opacity(0.7), radius: 8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            // Permanently Visible Settings & Tempo Controls
            VStack(spacing: 12) {
                Divider()

                HStack {
                    Text("\(tempoCategoryName(tier: tabla.currentTempoTier())) • \(Int(tabla.tempoBPM)) BPM")
                        .font(isAntique ? .custom("Baskerville-Italic", size: 14).weight(.bold) : .caption)
                        .foregroundColor(isAntique ? Color.orange : .accentColor)
                    Spacer()
                }

                Slider(value: $tabla.tempoBPM, in: tabla.allowedBPMRange(), step: 1.0)
                    .tint(isAntique ? .orange : .accentColor)

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Button(action: { tabla.tempoBPM = max(10, tabla.tempoBPM - 5) }) {
                            Text("-5").font(.caption).fontWeight(.medium).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomTagButtonStyle(isSelected: false, isAntique: isAntique))

                        Button(action: { tabla.tempoBPM = max(10, tabla.tempoBPM - 1) }) {
                            Text("-").font(.caption).fontWeight(.medium).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomTagButtonStyle(isSelected: false, isAntique: isAntique))

                        Button(action: { tabla.tempoBPM = min(700, tabla.tempoBPM + 1) }) {
                            Text("+").font(.caption).fontWeight(.medium).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomTagButtonStyle(isSelected: false, isAntique: isAntique))

                        Button(action: { tabla.tempoBPM = min(700, tabla.tempoBPM + 5) }) {
                            Text("+5").font(.caption).fontWeight(.medium).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomTagButtonStyle(isSelected: false, isAntique: isAntique))
                    }

                    GridRow {
                        Button(action: { tabla.tempoBPM = max(10, tabla.tempoBPM / 2.0) }) {
                            Text("x/2").font(.caption).fontWeight(.medium).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomTagButtonStyle(isSelected: false, isAntique: isAntique))
                        
                        Spacer()
                        Spacer()

                        Button(action: { tabla.tempoBPM = min(700, tabla.tempoBPM * 2.0) }) {
                            Text("2x").font(.caption).fontWeight(.medium).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CustomTagButtonStyle(isSelected: false, isAntique: isAntique))
                    }
                }
            }
            .font(.subheadline)
            .tint(isAntique ? Color.orange : .secondary)
        }
        .padding(16)
        .frame(width: 320)
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
}

// MARK: - Native macOS Liquid Glass Backlit Display Box
struct LiquidGlassDisplay<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    var isAntique: Bool = false
    let content: () -> Content

    var body: some View {
        ZStack {
            // 1. Recessed Outer Electronic Box Bezel Frame
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isAntique ?
                            [Color.orange.opacity(0.35), Color.black.opacity(0.9)] :
                            [Color.black.opacity(0.85), Color(NSColor.darkGray).opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 2)

            // 2. Liquid Glass Translucent Backstage Pane
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: isAntique ?
                            [Color.orange.opacity(0.2), Color.black.opacity(0.8)] :
                            [Color.black.opacity(0.5), Color.black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(2)

            // 3. High-Gloss Specular Glare (Top Refraction Specular Highlight)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isAntique ? 0.3 : 0.22),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(2)

            // 4. Subtle Inner Glow & Chamfered Glass Edge Border
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isAntique ?
                            [Color.yellow.opacity(0.65), Color.orange.opacity(0.4), Color.yellow.opacity(0.15)] :
                            [Color.white.opacity(0.45), Color.white.opacity(0.1), Color.cyan.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .padding(2)

            // 5. Backlit Digital Display Content
            content()
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Left Presets Translucent Glass Drawer View
struct PresetsDrawerView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @State private var presetNames: [String] = []
    @State private var newPresetName: String = ""
    @State private var isShowingSaveField = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            Divider()

            // Presets List
            if presetNames.isEmpty {
                Text("No user presets saved yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(presetNames, id: \.self) { name in
                            HStack {
                                Text(name)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Button(action: {
                                    Task {
                                        if let settings = await SettingsStorageService.shared.loadPreset(name: name) {
                                            await SettingsStorageService.shared.saveActiveSettings(settings)
                                            audio.applySettings(settings)
                                        }
                                    }
                                }) {
                                    Text("Load")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button(action: {
                                    Task {
                                        await SettingsStorageService.shared.deletePreset(name: name)
                                        await refreshPresetsList()
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxHeight: 250)
            }

            Divider()

            // Save Preset Controls
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
                            let snapshot = audio.captureSettings()
                            let name = newPresetName
                            Task {
                                await SettingsStorageService.shared.savePreset(name: name, settings: snapshot)
                                await refreshPresetsList()
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
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 2, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.leading, 24)
        .padding(.top, 12)
        .onAppear {
            Task {
                await refreshPresetsList()
            }
        }
    }

    private func refreshPresetsList() async {
        let list = await SettingsStorageService.shared.listPresetNames()
        self.presetNames = list
    }
}

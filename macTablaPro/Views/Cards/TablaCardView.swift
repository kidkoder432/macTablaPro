import SwiftUI
import AppKit

// MARK: - Tabla Card View
struct TablaCardView: View {
    @ObservedObject var tabla: Tabla
    @ObservedObject private var presentation = VisualPresentationEngine.shared
    let database = TablaDatabase.shared
    
    @State private var bpmInputText: String = ""
    @State private var isEditingBPM: Bool = false
    @State private var isTapFlashing: Bool = false
    @State private var tapTracker = TapTempoTracker(minSamples: 4, maxSamples: 5, timeoutInterval: 2.0)

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
        guard presentation.currentMatra != nil else { return "" }
        let activeDots = (presentation.currentMatraSubStep % 4) + 1
        return String(repeating: "· ", count: activeDots).trimmingCharacters(in: .whitespaces)
    }

    private var activeTaalSymbol: String {
        if !presentation.currentTaalSymbol.isEmpty {
            return presentation.currentTaalSymbol
        }
        guard let matra = presentation.currentMatra else { return "" }
        return getTaalSymbol(matra: matra, taal: database.taalCatalog[tabla.activeTaal])
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
                                if tabla.isPlaying && tabla.currentTempoTier() == 0 && !subBeatDotsText.isEmpty {
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
                        if tabla.isPlaying, let matra = presentation.currentMatra {
                            Text("\(matra)")
                                .font(isAntique ?
                                    .system(size: 44, weight: .bold, design: .monospaced) :
                                    .system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(isAntique ? Color.orange : .white)
                                .shadow(color: isAntique ? Color.orange.opacity(0.8) : Color.white.opacity(0.7), radius: 8)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isEditingBPM else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        isTapFlashing = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeIn(duration: 0.15)) {
                            isTapFlashing = false
                        }
                    }
                    if let calculatedBPM = tapTracker.recordTap() {
                        let range = tabla.allowedBPMRange()
                        tabla.tempoBPM = max(range.lowerBound, min(range.upperBound, round(calculatedBPM)))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isAntique ? Color.orange : Color.cyan,
                            lineWidth: isTapFlashing ? 2.5 : 0
                        )
                        .opacity(isTapFlashing ? 0.9 : 0)
                )

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

            // Phonetic Bol Name Display
            HStack {
                Text("Bol:")
                    .font(isAntique ? .custom("Baskerville-Italic", size: 14) : .caption)
                    .foregroundColor(isAntique ? Color.orange : .secondary)
                Text(tabla.isPlaying && !presentation.currentBolName.isEmpty ? presentation.currentBolName : "—")
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

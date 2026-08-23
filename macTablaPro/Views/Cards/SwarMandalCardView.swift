import SwiftUI
import AppKit

// MARK: - Swar Mandal Card View
struct SwarMandalCardView: View {
    @ObservedObject var swarMandal: SwarMandal
    
    @State private var selectedStringIndex: Int? = nil
    @State private var hoveredStringIndex: Int? = nil
    @State private var activePluckedIndex: Int? = nil
    @State private var isPopoverPresented: Bool = false
    
    var body: some View {
        let isAntique = swarMandal.orchestrator.isAntiqueThemeEnabled
        VStack(spacing: 10) {
            // MARK: - Header Row: Title, LED, Auto-Loop Toggle & Manual Play Icon
            HStack(spacing: 8) {
                Circle()
                    .fill(swarMandal.isPlaying ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .shadow(color: swarMandal.isPlaying ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                
                Text("Swar Mandal")
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                
                Spacer()
                
                Toggle("Auto", isOn: Binding(
                    get: { swarMandal.isPlaying },
                    set: { newValue in
                        if newValue {
                            swarMandal.startPlay()
                        } else {
                            swarMandal.stopPlay()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .font(.caption2)
                .foregroundColor(isAntique ? Color.orange : .secondary)
                
                Button(action: {
                    swarMandal.triggerManualStrumPass()
                }) {
                    ZStack {
                        Circle()
                            .fill(isAntique ? Color.orange : Color.accentColor)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(isAntique ? .black : .white)
                            .offset(x: 1)
                    }
                }
                .buttonStyle(.plain)
                .help("Manual Strum Now")
            }
            
            // MARK: - Row 1: Tempo Control (Slider & Direct Input, 300 to 800 BPM)
            HStack(spacing: 8) {
                Text("Tempo:")
                    .font(.caption2)
                    .foregroundColor(isAntique ? Color.orange : .secondary)
                
                Slider(
                    value: $swarMandal.tempoBPM,
                    in: SwarMandalTimingConfig.minTempoBPM...SwarMandalTimingConfig.maxTempoBPM,
                )
                .tint(isAntique ? .orange : .accentColor)
                
                TextField(
                    "",
                    value: $swarMandal.tempoBPM,
                    format: .number
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.caption)
                .monospacedDigit()
                .frame(width: 36)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isAntique ? Color.black.opacity(0.3) : Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isAntique ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                Text("BPM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Row 2: Strings Stepper & Loop Duration Picker
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Strings:")
                        .font(.caption2)
                        .foregroundColor(isAntique ? Color.orange : .secondary)
                    Stepper("\(swarMandal.stringCount)", value: $swarMandal.stringCount, in: SwarMandalTimingConfig.minStringCount...SwarMandalTimingConfig.maxStringCount)
                        .labelsHidden()
                    Text("\(swarMandal.stringCount)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(isAntique ? Color.yellow : .primary)
                }
                
                Spacer()
                
                Picker("Loop", selection: $swarMandal.loopOption) {
                    ForEach(SwarMandalLoopOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 140)
            }
            
            // MARK: - Row 3: Volume Slider
            HStack(spacing: 6) {
                Text("Vol")
                    .font(.caption2)
                    .foregroundColor(isAntique ? Color.orange : .secondary)
                Slider(value: $swarMandal.volume, in: 0...1)
                    .tint(isAntique ? .orange : .accentColor)
            }
            
            Divider()
            
            // MARK: - Two-Tier Harp Visualizer
            VStack(alignment: .leading, spacing: 6) {
                // 1. Top Note Tuning Tags Rail
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 4) {
                        ForEach(0..<swarMandal.stringCount, id: \.self) { idx in
                            let noteName = idx < swarMandal.stringNotes.count ? swarMandal.stringNotes[idx] : "Off"
                            let isOff = noteName == "Off"
                            let isPlucked = activePluckedIndex == idx
                            
                            Button(action: {
                                selectedStringIndex = idx
                                isPopoverPresented = true
                                swarMandal.pluckString(at: idx)
                            }) {
                                Text(noteName)
                                    .font(.system(size: 9, weight: isOff ? .regular : .semibold, design: .monospaced))
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 3)
                                    .background(
                                        isPlucked ?
                                        (isAntique ? Color.orange : Color.accentColor) :
                                        (isOff ? Color.gray.opacity(0.15) : (isAntique ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.15)))
                                    )
                                    .foregroundColor(
                                        isPlucked ?
                                        (isAntique ? .black : .white) :
                                        (isOff ? .secondary : (isAntique ? Color.orange : .primary))
                                    )
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // 2. Bottom Interactive Strum Bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        let totalWidth = geo.size.width
                        let count = max(1, swarMandal.stringCount)
                        let stepWidth = totalWidth / CGFloat(count)
                        
                        HStack(spacing: 0) {
                            ForEach(0..<count, id: \.self) { idx in
                                let isEditing = selectedStringIndex == idx && isPopoverPresented
                                let isPlucked = activePluckedIndex == idx
                                let isHovered = hoveredStringIndex == idx
                                let noteName = idx < swarMandal.stringNotes.count ? swarMandal.stringNotes[idx] : "Off"
                                let isOff = noteName == "Off"
                                
                                let lineColor: Color = {
                                    if isEditing {
                                        return Color.green
                                    } else if isPlucked {
                                        return isAntique ? Color.yellow : Color.accentColor
                                    } else if isHovered {
                                        return isAntique ? Color.orange : Color.accentColor.opacity(0.8)
                                    } else if isOff {
                                        return Color.secondary.opacity(0.25)
                                    } else {
                                        return isAntique ? Color.orange.opacity(0.7) : Color.primary.opacity(0.45)
                                    }
                                }()
                                
                                let lineWidth: CGFloat = isEditing ? 3.0 : ((isPlucked || isHovered) ? 2.5 : 1.0)
                                
                                ZStack {
                                    Rectangle()
                                        .fill(
                                            isEditing ?
                                            Color.green.opacity(0.3) :
                                            (isHovered || isPlucked ? (isAntique ? Color.orange.opacity(0.3) : Color.accentColor.opacity(0.25)) : Color.clear)
                                        )
                                    
                                    Rectangle()
                                        .fill(lineColor)
                                        .frame(width: lineWidth)
                                        .shadow(color: isEditing ? Color.green.opacity(0.8) : (isPlucked ? lineColor.opacity(0.6) : Color.clear), radius: isEditing ? 4 : 2)
                                }
                                .frame(width: stepWidth, height: 40)
                                .contentShape(Rectangle())
                                .help("String \(idx + 1): \(noteName)")
                                .onHover { isHovering in
                                    if isHovering {
                                        hoveredStringIndex = idx
                                    } else if hoveredStringIndex == idx {
                                        hoveredStringIndex = nil
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .overlay(
                            RightClickBarDetector { location in
                                let clampedX = max(0, min(totalWidth - 1, location.x))
                                let stringIdx = Int(clampedX / stepWidth)
                                if stringIdx >= 0 && stringIdx < swarMandal.stringCount {
                                    selectedStringIndex = stringIdx
                                    isPopoverPresented = true
                                }
                            }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let locX = value.location.x
                                    let clampedX = max(0, min(totalWidth - 1, locX))
                                    let stringIdx = Int(clampedX / stepWidth)
                                    
                                    if stringIdx != activePluckedIndex && stringIdx >= 0 && stringIdx < swarMandal.stringCount {
                                        activePluckedIndex = stringIdx
                                        hoveredStringIndex = stringIdx
                                        swarMandal.pluckString(at: stringIdx)
                                    }
                                }
                                .onEnded { _ in
                                    activePluckedIndex = nil
                                    hoveredStringIndex = nil
                                }
                        )
                    }
                    .frame(height: 40)
                    .background(isAntique ? Color.black.opacity(0.25) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                    
                    // Subtle feature guidance hint
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 8))
                        Text("Drag across strings to strum • Right-click to tune")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(isAntique ? Color.orange.opacity(0.4) : Color.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            if let idx = selectedStringIndex, idx < swarMandal.stringNotes.count {
                SwarTunerPopoverView(
                    stringIndex: idx,
                    currentNote: swarMandal.stringNotes[idx],
                    onSelectNote: { newNote in
                        swarMandal.stringNotes[idx] = newNote
                        swarMandal.pluckString(at: idx)
                        isPopoverPresented = false
                    }
                )
            }
        }
    }
}

// MARK: - 36 Swar Categorized Tuner Popover
struct SwarTunerPopoverView: View {
    let stringIndex: Int
    let currentNote: String
    let onSelectNote: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tune String #\(stringIndex + 1)")
                    .font(.headline)
                Spacer()
                Text("Current: \(currentNote)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    SwarOctaveSectionView(title: "String Mute", notes: ["Off"], currentNote: currentNote, onSelect: onSelectNote)
                    SwarOctaveSectionView(title: "Middle Octave (12 Swars)", notes: SwarNoteHelper.middleOctaveSwars, currentNote: currentNote, onSelect: onSelectNote)
                    SwarOctaveSectionView(title: "Lower Octave / Kharaj (12 Swars)", notes: SwarNoteHelper.lowerOctaveSwars, currentNote: currentNote, onSelect: onSelectNote)
                    SwarOctaveSectionView(title: "Higher Octave (12 Swars)", notes: SwarNoteHelper.higherOctaveSwars, currentNote: currentNote, onSelect: onSelectNote)
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .frame(width: 320)
    }
}

struct SwarOctaveSectionView: View {
    let title: String
    let notes: [String]
    let currentNote: String
    let onSelect: (String) -> Void
    
    let columns = [GridItem(.adaptive(minimum: 70), spacing: 5)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(notes, id: \.self) { swar in
                    let isSelected = swar == currentNote
                    Button(action: {
                        onSelect(swar)
                    }) {
                        Text(swar)
                            .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.accentColor : Color(NSColor.controlColor))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Right-Click Gesture Interceptor for macOS Strum Bar
struct RightClickBarDetector: NSViewRepresentable {
    var onRightClick: (CGPoint) -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    class RightClickNSView: NSView {
        var onRightClick: ((CGPoint) -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            let localPoint = convert(event.locationInWindow, from: nil)
            onRightClick?(localPoint)
        }

        override func mouseDown(with event: NSEvent) {
            nextResponder?.mouseDown(with: event)
        }

        override func mouseDragged(with event: NSEvent) {
            nextResponder?.mouseDragged(with: event)
        }

        override func mouseUp(with event: NSEvent) {
            nextResponder?.mouseUp(with: event)
        }
    }
}

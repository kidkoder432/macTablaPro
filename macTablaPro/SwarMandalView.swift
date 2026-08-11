//
//  SwarMandalView.swift
//  macTablaPro
//

import SwiftUI

struct SwarMandalView: View {
    @ObservedObject var swarMandal: SwarMandal
    @EnvironmentObject var orchestrator: AppAudioOrchestrator
    
    @State private var selectedStringIndex: Int? = nil
    @State private var hoveredStringIndex: Int? = nil
    @State private var activePluckedIndex: Int? = nil
    @State private var isPopoverPresented: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            // MARK: - Header Row: Title, LED, Auto-Loop Toggle & Manual Play Icon
            HStack(spacing: 8) {
                Circle()
                    .fill(swarMandal.isPlaying ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                
                Text("Swar Mandal")
                    .font(.headline)
                    .fontWeight(.bold)
                
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
                
                Button(action: {
                    swarMandal.triggerManualStrumPass()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                }
                .buttonStyle(.plain)
                .help("Manual Strum Now")
            }
            
            // MARK: - Row 1: Mode Segmented Control
            Picker("Mode", selection: $swarMandal.mode) {
                ForEach(SwarMandalMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // MARK: - Row 2: Strings Stepper & Loop Duration Picker
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Strings:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Stepper("\(swarMandal.stringCount)", value: $swarMandal.stringCount, in: SwarMandalTimingConfig.minStringCount...SwarMandalTimingConfig.maxStringCount)
                        .labelsHidden()
                    Text("\(swarMandal.stringCount)")
                        .font(.caption)
                        .monospacedDigit()
                }
                
                Spacer()
                
                Picker("Loop", selection: $swarMandal.loopOption) {
                    ForEach(SwarMandalLoopOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            
            // MARK: - Row 3: Volume Slider
            HStack(spacing: 6) {
                Text("Vol")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Slider(value: $swarMandal.volume, in: 0...1)
                    .tint(.accentColor)
            }
            
            Divider()
            
            // MARK: - Two-Tier Harp Visualizer
            VStack(alignment: .leading, spacing: 6) {
                // 1. Top Note Tuning Tags Rail (Scrollable with Visible Indicator)
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
                                    .background(isPlucked ? Color.accentColor : (isOff ? Color.gray.opacity(0.15) : Color.accentColor.opacity(0.15)))
                                    .foregroundColor(isPlucked ? .white : (isOff ? .secondary : .primary))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // 2. Bottom Interactive Strum Bar (20-36 Vertical String Lines with Continuous Drag)
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let count = max(1, swarMandal.stringCount)
                    let stepWidth = totalWidth / CGFloat(count)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<count, id: \.self) { idx in
                            let isPlucked = activePluckedIndex == idx
                            let isHovered = hoveredStringIndex == idx
                            let noteName = idx < swarMandal.stringNotes.count ? swarMandal.stringNotes[idx] : "Off"
                            let isOff = noteName == "Off"
                            
                            ZStack {
                                Rectangle()
                                    .fill(isHovered || isPlucked ? Color.accentColor.opacity(0.25) : Color.clear)
                                
                                Rectangle()
                                    .fill(isOff ? Color.secondary.opacity(0.2) : (isPlucked || isHovered ? Color.accentColor : Color.primary.opacity(0.5)))
                                    .frame(width: isPlucked || isHovered ? 2.5 : 1.0)
                            }
                            .frame(width: stepWidth, height: 40)
                        }
                    }
                    .contentShape(Rectangle())
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
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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

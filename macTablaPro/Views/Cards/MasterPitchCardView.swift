import SwiftUI
import AppKit

struct NoteDisplayData {
    let noteName: String
    let fineCentsString: String?
}

let centsNoteNames: [String] = [
    "A2", "A#2", "B2", "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3",
    "A3", "A#3", "B3", "C4", "C#4", "D4", "D#4", "E4"
]

// MARK: - Master Pitch Card View
struct MasterPitchCardView: View {
    @ObservedObject var audio: AppAudioOrchestrator

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
        .nativeCard(isAntique: isAntique, cornerRadius: 14)
    }
    
    private func executeCoarsePitchStep(upwards: Bool) {
        if upwards {
            if audio.fineTuneCents < 0 {
                audio.fineTuneCents = 0.0
            } else {
                audio.scaleOffsetCents = min(1600, audio.scaleOffsetCents + 100)
                audio.fineTuneCents = 0.0
            }
        } else {
            if audio.fineTuneCents > 0 {
                audio.fineTuneCents = 0.0
            } else {
                audio.scaleOffsetCents = max(-300, audio.scaleOffsetCents - 100)
                audio.fineTuneCents = 0.0
            }
        }
        audio.commitPitchChange()
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

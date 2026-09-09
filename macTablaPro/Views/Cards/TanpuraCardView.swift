import SwiftUI

struct PickerNote: Hashable, Identifiable {
    var id: Double { cents }
    let name: String
    let cents: Double
}

let lowerOctavePickerNotes: [PickerNote] = [
    PickerNote(name: "Kharaj", cents: 0.0),
    PickerNote(name: "Re Komal", cents: 100.0),
    PickerNote(name: "Re", cents: 200.0),
    PickerNote(name: "Ga Komal", cents: 300.0),
    PickerNote(name: "Ga Shuddha", cents: 400.0),
    PickerNote(name: "Ma", cents: 500.0),
    PickerNote(name: "Ma Teevra", cents: 600.0),
    PickerNote(name: "Pa", cents: 700.0),
    PickerNote(name: "Dha Komal", cents: 800.0),
    PickerNote(name: "Dha", cents: 900.0),
    PickerNote(name: "Ni Komal", cents: 1000.0),
    PickerNote(name: "Ni", cents: 1100.0),
]

let higherOctavePickerNotes: [PickerNote] = [
    PickerNote(name: "Sa", cents: 1200.0),
    PickerNote(name: "Re Higher Komal", cents: 1300.0),
    PickerNote(name: "Re Higher", cents: 1400.0),
    PickerNote(name: "Ga Higher Komal", cents: 1500.0),
    PickerNote(name: "Ga Higher", cents: 1600.0),
    PickerNote(name: "Ma Higher", cents: 1700.0),
]

let stringPickerItems: [PickerNote] = lowerOctavePickerNotes + higherOctavePickerNotes

// MARK: - Tanpura Card View
struct TanpuraCardView: View {
    @ObservedObject var tanpura: Tanpura
    let title: String

    let quickOptions: [PickerNote] = [
        PickerNote(name: "Pa", cents: 700.0),
        PickerNote(name: "Ma", cents: 500.0),
        PickerNote(name: "Ni", cents: 1100.0),
    ]

    var isQuickOptionSelected: Bool {
        quickOptions.contains { $0.cents == tanpura.firstStringPitch }
    }

    var isCustomSelected: Bool {
        tanpura.isPlaying && !isQuickOptionSelected
    }

    var customOptionLabel: String {
        if isCustomSelected {
            return ITablaProPreset.centsToStringName(tanpura.firstStringPitch)
        }
        return "..."
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

                // 3. Overflow Menu for custom pitches (Kharaj through Ma Higher)
                Menu {
                    Section("Lower Octave (Kharaj - Ni)") {
                        ForEach(lowerOctavePickerNotes) { item in
                            Button(action: {
                                tanpura.firstStringPitch = item.cents
                                if !tanpura.isPlaying {
                                    tanpura.togglePlay()
                                }
                            }) {
                                HStack {
                                    Text(item.name)
                                    if tanpura.firstStringPitch == item.cents {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Section("Higher Octave (Sa - Ma Higher)") {
                        ForEach(higherOctavePickerNotes) { item in
                            Button(action: {
                                tanpura.firstStringPitch = item.cents
                                if !tanpura.isPlaying {
                                    tanpura.togglePlay()
                                }
                            }) {
                                HStack {
                                    Text(item.name)
                                    if tanpura.firstStringPitch == item.cents {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Text(customOptionLabel)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
                .menuIndicator(.hidden)
                .buttonStyle(CustomTagButtonStyle(isSelected: isCustomSelected, isAntique: isAntique))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
    }
}

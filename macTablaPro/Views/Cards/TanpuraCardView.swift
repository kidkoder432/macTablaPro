import SwiftUI

struct PickerNote: Hashable {
    let name: String
    let cents: Double
}

private let tanpuraNotesMap: [String: Double] = [
    "Ni (Low)": 1100.0, "Sa": 0.0, "Re (komal)": 100.0, "Re": 200.0,
    "Ga (komal)": 300.0, "Ga": 400.0, "Ma": 500.0, "Ma (tivra)": 600.0,
    "Pa": 700.0, "Dha (komal)": 800.0, "Dha": 900.0, "Ni": 1100.0
]

let stringPickerItems: [PickerNote] = [
    "Ni (Low)", "Sa", "Re (komal)", "Re", "Ga (komal)", "Ga", "Ma", "Ma (tivra)", "Pa", "Dha (komal)", "Dha", "Ni"
]
.sorted(by: { (tanpuraNotesMap[$0] ?? 0.0) < (tanpuraNotesMap[$1] ?? 0.0) })
.map { PickerNote(name: $0, cents: tanpuraNotesMap[$0] ?? -1.0) }

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
        .frame(maxWidth: .infinity)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
    }
}

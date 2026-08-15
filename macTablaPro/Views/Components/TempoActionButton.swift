import SwiftUI
import AppKit

// MARK: - Tempo Multiplier Action Pill Button (-5 / x/2 / 2x / +5)
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

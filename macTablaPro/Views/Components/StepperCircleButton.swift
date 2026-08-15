import SwiftUI
import AppKit

// MARK: - Circular Stepper Button (- / + / ♭ / ♯)
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

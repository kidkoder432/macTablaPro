import SwiftUI

// MARK: - Custom Tag / Pill Button Style
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
                    .stroke(strokeColor, lineWidth: isAntique ? 1.0 : 0.0)
            )
            .foregroundColor(textColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

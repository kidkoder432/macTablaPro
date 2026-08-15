import SwiftUI
import AppKit

// MARK: - Sankalp Dynamic Status-Based Button Style
struct SankalpButtonStyle: ButtonStyle {
    var isProminent: Bool
    var isAntique: Bool

    func makeBody(configuration: Configuration) -> some View {
        let defaultBg: Color = isProminent ? .accentColor : Color(NSColor.controlBackgroundColor)
        let antiqueBg: Color = isProminent ? .orange : Color.black.opacity(0.3)
        let activeBg = isAntique ? antiqueBg : defaultBg
        
        let defaultFg: Color = isProminent ? .white : .primary
        let antiqueFg: Color = isProminent ? .black : Color.orange
        let activeFg = isAntique ? antiqueFg : defaultFg
        
        return configuration.label
            .foregroundColor(activeFg)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(activeBg.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAntique ? Color.orange.opacity(0.6) : Color(NSColor.separatorColor), lineWidth: isProminent ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

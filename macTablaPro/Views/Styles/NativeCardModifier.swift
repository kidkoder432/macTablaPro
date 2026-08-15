import SwiftUI
import AppKit

// MARK: - Native Card Modifier & View Extension
struct NativeCardModifier: ViewModifier {
    var isAntique: Bool = false
    var cornerRadius: CGFloat = WorkstationLayout.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isAntique ?
                        Color(NSColor.windowBackgroundColor).opacity(0.85) :
                        Color(NSColor.controlBackgroundColor)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isAntique ?
                        Color.orange.opacity(0.4) :
                        Color(NSColor.separatorColor),
                        lineWidth: 1
                    )
            )
            .shadow(color: isAntique ? Color.orange.opacity(0.12) : Color.black.opacity(0.06), radius: isAntique ? 6 : 3, x: 0, y: 2)
    }
}

extension View {
    func nativeCard(isAntique: Bool = false, cornerRadius: CGFloat = WorkstationLayout.cardCornerRadius) -> some View {
        self.modifier(NativeCardModifier(isAntique: isAntique, cornerRadius: cornerRadius))
    }
}

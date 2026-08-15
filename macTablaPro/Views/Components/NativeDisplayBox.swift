import SwiftUI
import AppKit

// MARK: - Native Display Box (LED / LCD Note and Tempo Display Container)
struct NativeDisplayBox<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    var isAntique: Bool = false
    let content: () -> Content

    init(width: CGFloat, height: CGFloat, isAntique: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.height = height
        self.isAntique = isAntique
        self.content = content
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isAntique ?
                    Color.black.opacity(0.85) :
                    Color(NSColor.controlBackgroundColor)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isAntique ?
                    LinearGradient(colors: [Color.orange.opacity(0.6), Color.yellow.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color(NSColor.separatorColor)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isAntique ? 1.5 : 1.0
                )

            content()
        }
        .frame(width: width, height: height)
    }
}

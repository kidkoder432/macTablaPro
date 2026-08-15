import SwiftUI
import AppKit

// MARK: - Workstation Layout Constants
struct WorkstationLayout {
    static let cardWidth: CGFloat = 340
    static let cardCornerRadius: CGFloat = 16
    
    static let minHorizontalSpacing: CGFloat = 16
    static let verticalCardSpacing: CGFloat = 14
    static let topPadding: CGFloat = 16
    static let bottomPadding: CGFloat = 16

    static let minWindowWidth: CGFloat = 1100
    static let minWindowHeight: CGFloat = 670
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

typealias VisualEffectBackground = VisualEffectView

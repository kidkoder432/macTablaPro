import SwiftUI
import AppKit

// MARK: - Workstation Layout Constants
struct WorkstationLayout {
    static let defaultCardWidth: CGFloat = 340
    static let compactCardWidth: CGFloat = 265
    static let cardWidth: CGFloat = 340

    static func cardWidth(isPresetsPresented: Bool) -> CGFloat {
        isPresetsPresented ? compactCardWidth : defaultCardWidth
    }

    static let cardCornerRadius: CGFloat = 16
    
    static let minHorizontalSpacing: CGFloat = 14
    static let verticalCardSpacing: CGFloat = 12
    static let topPadding: CGFloat = 14
    static let bottomPadding: CGFloat = 14

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

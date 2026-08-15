import SwiftUI

// MARK: - Reusable Press-and-Hold Auto-Repeating Touch Button
struct RepeatingTouchButton<Content: View>: View {
    let action: () -> Void
    var label: () -> Content

    @State private var isPressed: Bool = false
    @State private var repeatTask: Task<Void, Never>? = nil

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Content) {
        self.action = action
        self.label = label
    }

    var body: some View {
        label()
            .opacity(isPressed ? 0.75 : 1.0)
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            action()
                            repeatTask?.cancel()
                            repeatTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 350_000_000) // 350ms initial delay
                                while !Task.isCancelled && isPressed {
                                    action()
                                    try? await Task.sleep(nanoseconds: 75_000_000) // ~13 ticks/sec
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        repeatTask?.cancel()
                        repeatTask = nil
                    }
            )
    }
}

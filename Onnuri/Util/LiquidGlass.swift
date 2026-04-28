import SwiftUI

/// iOS 26 / macOS 26 Liquid Glass 헬퍼.
extension View {
    func glassCard(cornerRadius: CGFloat = 28) -> some View {
        self.glassEffect(.regular,
                         in: RoundedRectangle(cornerRadius: cornerRadius,
                                              style: .continuous))
    }

    func glassPanel(cornerRadius: CGFloat = 18) -> some View {
        self.glassEffect(.regular,
                         in: RoundedRectangle(cornerRadius: cornerRadius,
                                              style: .continuous))
    }
}

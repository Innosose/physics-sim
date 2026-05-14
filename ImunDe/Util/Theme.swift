import SwiftUI
import UIKit

enum Theme {
    // Paper — pure white on light, near-black on dark.
    static let void = Color.adaptive(
        light: Color(white: 0.95),
        dark:  Color(white: 0.10))

    static let deep = Color.adaptive(
        light: Color(white: 0.97),
        dark:  Color(white: 0.13))

    static let surface = Color.adaptive(
        light: Color(white: 1.00),
        dark:  Color(white: 0.17))

    static let crest = Color.adaptive(
        light: Color(white: 0.92),
        dark:  Color(white: 0.22))

    // Graphite — primary stroke color.
    static let ink = Color.adaptive(
        light: Color(white: 0.12),
        dark:  Color(white: 0.92))

    static let mist = Color.adaptive(
        light: Color(white: 0.42),
        dark:  Color(white: 0.65))

    static let stroke = Color.adaptive(
        light: Color.black.opacity(0.20),
        dark:  Color.white.opacity(0.16))

    static let divider = Color.adaptive(
        light: Color.black.opacity(0.10),
        dark:  Color.white.opacity(0.08))

    // 포인트 (cream) — slider fill, inspector ring, prominent buttons, totals.
    static let glow = Color.adaptive(
        light: Color(red: 0.88, green: 0.74, blue: 0.36),
        dark:  Color(red: 0.95, green: 0.83, blue: 0.50))

    // Other accents — still grayscale for chrome consistency.
    static let accent  = Color.adaptive(light: Color(white: 0.34), dark: Color(white: 0.74))
    static let pulse   = Color.adaptive(light: Color(white: 0.28), dark: Color(white: 0.80))
    static let confirm = Color.adaptive(light: Color(white: 0.32), dark: Color(white: 0.76))
    static let danger  = Color.adaptive(light: Color(white: 0.22), dark: Color(white: 0.86))

    // Grayscale body palette — for particles, planets, carts. Indexed by body order.
    static let bodyPalette: [Color] = [
        Color.adaptive(light: Color(white: 0.14), dark: Color(white: 0.92)),
        Color.adaptive(light: Color(white: 0.55), dark: Color(white: 0.55)),
        Color.adaptive(light: Color(white: 0.30), dark: Color(white: 0.78)),
        Color.adaptive(light: Color(white: 0.72), dark: Color(white: 0.38)),
        Color.adaptive(light: Color(white: 0.22), dark: Color(white: 0.85)),
        Color.adaptive(light: Color(white: 0.45), dark: Color(white: 0.62)),
        Color.adaptive(light: Color(white: 0.62), dark: Color(white: 0.45)),
        Color.adaptive(light: Color(white: 0.36), dark: Color(white: 0.70)),
        Color.adaptive(light: Color(white: 0.18), dark: Color(white: 0.88)),
        Color.adaptive(light: Color(white: 0.50), dark: Color(white: 0.60)),
    ]
}

extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark) : UIColor(light)
        })
    }
}

extension Font {
    static var themeMono: Font     { .system(size: 12, weight: .regular,  design: .monospaced) }
    static var themeMonoBold: Font { .system(size: 12, weight: .semibold, design: .monospaced) }
    static var themeHeader: Font   { .system(size: 11, weight: .semibold).smallCaps() }
    static var themeLabel: Font    { .system(size: 13, weight: .regular) }
}

// MARK: - Formula rendering

extension AttributedString {
    /// Render a physics formula string with proper sub/superscripts.
    /// Recognized syntax: `_x` (single char subscript), `_{xx}` (group subscript),
    /// `^x`, `^{xx}` (superscripts). Existing Unicode glyphs (₀ ² ′ etc.)
    /// pass through unchanged.
    static func formula(_ s: String, baseSize: CGFloat = 15) -> AttributedString {
        let base: Font = .system(size: baseSize, design: .serif)
        let small: Font = .system(size: baseSize * 0.72, design: .serif)
        var result = AttributedString()
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if (c == "_" || c == "^"), let token = nextToken(in: s, after: i) {
                var attr = AttributedString(token.text)
                attr.font = small
                attr.baselineOffset = (c == "_") ? -baseSize * 0.22 : baseSize * 0.36
                result.append(attr)
                i = token.endIndex
            } else {
                var attr = AttributedString(String(c))
                attr.font = base
                result.append(attr)
                i = s.index(after: i)
            }
        }
        return result
    }

    private static func nextToken(in s: String, after marker: String.Index)
        -> (text: String, endIndex: String.Index)? {
        let start = s.index(after: marker)
        guard start < s.endIndex else { return nil }
        if s[start] == "{" {
            guard let close = s[start..<s.endIndex].firstIndex(of: "}") else { return nil }
            let inner = String(s[s.index(after: start)..<close])
            return (inner, s.index(after: close))
        }
        return (String(s[start]), s.index(after: start))
    }
}

extension View {
    func themeCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(ThemeCard(cornerRadius: cornerRadius))
    }
}

private struct ThemeCard: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(shape.fill(Theme.surface))
            .overlay(shape.stroke(Theme.stroke, lineWidth: 1))
            .shadow(color: Theme.ink.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct PropertyDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

// MARK: - Paper background

struct ImunDeBackground: View {
    var topGlow: Color = Theme.glow.opacity(0.0)

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()
            LinearGradient(colors: [topGlow, .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
    }
}

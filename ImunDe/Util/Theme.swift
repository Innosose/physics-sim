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

    // Accents — all grayscale shades, just different greys for emphasis.
    static let glow    = Color.adaptive(light: Color(white: 0.12), dark: Color(white: 0.92))
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
    static var themeHeader: Font   { .system(size: 11, weight: .semibold, design: .serif).smallCaps() }
    static var themeLabel: Font    { .system(size: 13, weight: .regular,  design: .serif) }
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
            .background(shape.fill(Theme.surface.opacity(0.85)))
            .overlay(shape.stroke(Theme.ink.opacity(0.55),
                                  style: StrokeStyle(lineWidth: 1.1)))
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
    var topGlow: Color = Theme.glow.opacity(0.0)  // legacy param, ignored

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deep, Theme.void],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            PaperGrainOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// Subtle paper-grain noise drawn with sparse dots. Deterministic per layout.
private struct PaperGrainOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededGenerator(0x6A09E667F3BCC908)
            let density: Double = 0.0006
            let count = max(40, Int(size.width * size.height * density))
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r = CGFloat.random(in: 0.3...0.9, using: &rng)
                let a = Double.random(in: 0.03...0.10, using: &rng)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(Theme.ink.opacity(a)))
            }
        }
    }
}

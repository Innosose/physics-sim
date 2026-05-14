import SwiftUI
import UIKit

enum Theme {
    // Paper tones — light = aged cream, dark = warm dim (chalkboard-ish but warm).
    static let void = Color.adaptive(
        light: Color(red: 0.93, green: 0.90, blue: 0.84),
        dark:  Color(red: 0.13, green: 0.11, blue: 0.09))

    static let deep = Color.adaptive(
        light: Color(red: 0.96, green: 0.93, blue: 0.86),
        dark:  Color(red: 0.16, green: 0.14, blue: 0.11))

    static let surface = Color.adaptive(
        light: Color(red: 0.98, green: 0.96, blue: 0.91),
        dark:  Color(red: 0.21, green: 0.19, blue: 0.16))

    static let crest = Color.adaptive(
        light: Color(red: 0.91, green: 0.87, blue: 0.79),
        dark:  Color(red: 0.26, green: 0.23, blue: 0.18))

    // Pencil & ink — primary stroke color.
    static let ink = Color.adaptive(
        light: Color(red: 0.16, green: 0.14, blue: 0.13),
        dark:  Color(red: 0.94, green: 0.91, blue: 0.83))

    static let mist = Color.adaptive(
        light: Color(red: 0.43, green: 0.40, blue: 0.36),
        dark:  Color(red: 0.66, green: 0.62, blue: 0.54))

    static let stroke = Color.adaptive(
        light: Color.black.opacity(0.18),
        dark:  Color.white.opacity(0.14))

    static let divider = Color.adaptive(
        light: Color.black.opacity(0.10),
        dark:  Color.white.opacity(0.08))

    // Accent — warm sketch-amber (like a colored pencil).
    static let glow = Color.adaptive(
        light: Color(red: 0.70, green: 0.45, blue: 0.18),
        dark:  Color(red: 0.86, green: 0.66, blue: 0.36))

    static let accent = Color.adaptive(
        light: Color(red: 0.27, green: 0.50, blue: 0.46),
        dark:  Color(red: 0.49, green: 0.74, blue: 0.69))

    static let pulse = Color.adaptive(
        light: Color(red: 0.46, green: 0.38, blue: 0.55),
        dark:  Color(red: 0.69, green: 0.59, blue: 0.81))

    static let confirm = Color.adaptive(
        light: Color(red: 0.32, green: 0.50, blue: 0.32),
        dark:  Color(red: 0.55, green: 0.76, blue: 0.55))

    static let danger = Color.adaptive(
        light: Color(red: 0.68, green: 0.30, blue: 0.27),
        dark:  Color(red: 0.85, green: 0.50, blue: 0.45))
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

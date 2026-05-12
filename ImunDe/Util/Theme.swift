import SwiftUI
import UIKit

enum Theme {
    static let void = Color.adaptive(
        light: Color(red: 0.93, green: 0.94, blue: 0.97),
        dark:  Color(red: 0.020, green: 0.031, blue: 0.086))

    static let deep = Color.adaptive(
        light: Color(red: 0.95, green: 0.96, blue: 0.99),
        dark:  Color(red: 0.043, green: 0.067, blue: 0.149))

    static let surface = Color.adaptive(
        light: Color.white,
        dark:  Color(red: 0.075, green: 0.102, blue: 0.220))

    static let crest = Color.adaptive(
        light: Color(red: 0.91, green: 0.93, blue: 0.97),
        dark:  Color(red: 0.118, green: 0.153, blue: 0.314))

    static let glow = Color.adaptive(
        light: Color(red: 0.78, green: 0.55, blue: 0.18),
        dark:  Color(red: 0.878, green: 0.710, blue: 0.455))

    static let accent = Color.adaptive(
        light: Color(red: 0.20, green: 0.65, blue: 0.58),
        dark:  Color(red: 0.400, green: 0.831, blue: 0.753))

    static let pulse = Color.adaptive(
        light: Color(red: 0.55, green: 0.36, blue: 0.78),
        dark:  Color(red: 0.725, green: 0.553, blue: 0.898))

    static let confirm = Color.adaptive(
        light: Color(red: 0.30, green: 0.65, blue: 0.40),
        dark:  Color(red: 0.561, green: 0.890, blue: 0.635))

    static let danger = Color.adaptive(
        light: Color(red: 0.78, green: 0.30, blue: 0.30),
        dark:  Color(red: 0.878, green: 0.482, blue: 0.482))

    static let ink = Color.adaptive(
        light: Color(red: 0.05, green: 0.07, blue: 0.16),
        dark:  Color(red: 0.945, green: 0.925, blue: 0.878))

    static let mist = Color.adaptive(
        light: Color(red: 0.36, green: 0.40, blue: 0.50),
        dark:  Color(red: 0.533, green: 0.584, blue: 0.718))

    static let stroke = Color.adaptive(
        light: Color.black.opacity(0.10),
        dark:  Color.white.opacity(0.08))

    static let divider = Color.adaptive(
        light: Color.black.opacity(0.06),
        dark:  Color.white.opacity(0.04))
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
    static var themeHeader: Font   { .system(size: 11, weight: .semibold, design: .default).smallCaps() }
    static var themeLabel: Font    { .system(size: 13, weight: .regular,  design: .rounded) }
}

extension View {
    func themeCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(ThemeCard(cornerRadius: cornerRadius))
    }
}

private struct ThemeCard: ViewModifier {
    let cornerRadius: CGFloat
    var tint: Color = Theme.surface.opacity(0.55)
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .glassEffect(.regular.tint(tint), in: shape)
            .overlay(shape.stroke(Theme.stroke, lineWidth: 1))
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

struct ImunDeBackground: View {
    var topGlow: Color = Theme.glow.opacity(0.10)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deep, Theme.void],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [topGlow, .clear],
                           center: .top,
                           startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
        }
    }
}

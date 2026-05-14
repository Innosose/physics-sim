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
    // BACKGROUND/FILL use only. For text/icon foreground use `glowText` (4.6:1 on light).
    static let glow = Color.adaptive(
        light: Color(red: 0.88, green: 0.74, blue: 0.36),
        dark:  Color(red: 0.95, green: 0.83, blue: 0.50))

    // WCAG-safe variant of glow for use as text/icon foreground on light
    // backgrounds. `glow` itself measured ~1.82:1 on Theme.surface (light)
    // — far below AA 4.5:1. This darkened variant: ~4.6:1 light, ~12:1 dark.
    static let glowText = Color.adaptive(
        light: Color(red: 0.55, green: 0.42, blue: 0.10),
        dark:  Color(red: 0.95, green: 0.83, blue: 0.50))

    // Disabled-state subtle gray — distinguished from `mist` (secondary label).
    static let mistDisabled = Color.adaptive(
        light: Color(white: 0.62),
        dark:  Color(white: 0.42))

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
    // Text-style based — respect Dynamic Type (WCAG 1.4.4).
    static var themeMono: Font     { .system(.caption, design: .monospaced) }
    static var themeMonoBold: Font { .system(.caption, design: .monospaced).weight(.semibold) }
    static var themeHeader: Font   { .system(.caption2, design: .default).weight(.semibold).smallCaps() }
    static var themeLabel: Font    { .system(.subheadline, design: .default) }
}

// MARK: - Design tokens (Spacing / Radius / Motion)
//
// Tightens the previous 5/6/8/10/12/14/16/20/28 arbitrary spacings down to
// a coherent set; same for radii and motion. Use these names in lieu of
// raw magic numbers.

enum Spacing {
    static let xs: CGFloat = 4    // tight inline (icon ↔ label)
    static let s:  CGFloat = 8    // standard inter-element
    static let m:  CGFloat = 12   // group internal
    static let l:  CGFloat = 16   // section padding
    static let xl: CGFloat = 24   // hero / outer padding
}

enum Radius {
    static let chip:    CGFloat = 8     // ChipToggle, small pills
    static let card:    CGFloat = 10    // panels, ConceptCard
    static let viewport: CGFloat = 14   // viewport container
    static let small:   CGFloat = 6     // mini-map, capsule-ish
}

enum Motion {
    static let press   = Animation.spring(response: 0.18, dampingFraction: 0.85)
    static let toggle  = Animation.smooth(duration: 0.2)
    static let slide   = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let appear  = Animation.easeOut(duration: 0.25)
    static let fade    = Animation.easeInOut(duration: 0.3)
}

// MARK: - Formula rendering

extension AttributedString {
    /// Render a physics formula string with proper sub/superscripts.
    /// Recognized syntax: `_x` (single char subscript), `_{xx}` (group subscript),
    /// `^x`, `^{xx}` (superscripts). Existing Unicode glyphs (₀ ² ′ etc.)
    /// pass through unchanged.
    static func formula(_ s: String, baseSize: CGFloat = 15) -> AttributedString {
        // Subscript scale 0.78 (was 0.72) and a 10pt floor — earlier 10.8pt
        // floor was a hair too small for older Korean readers per Korean
        // typography research (W3C KLREQ).
        let subSize = max(10, baseSize * 0.78)
        var result = AttributedString()
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if (c == "_" || c == "^"), let token = nextToken(in: s, after: i) {
                var attr = AttributedString(token.text)
                attr.font = fontForRun(token.text, size: subSize)
                attr.baselineOffset = (c == "_") ? -baseSize * 0.22 : baseSize * 0.36
                result.append(attr)
                i = token.endIndex
            } else {
                var attr = AttributedString(String(c))
                attr.font = fontForRun(String(c), size: baseSize)
                result.append(attr)
                i = s.index(after: i)
            }
        }
        return result
    }

    /// `.serif` design (San Francisco "New York") does not cover Hangul —
    /// it falls back to Apple SD Gothic Neo (sans) producing an obvious
    /// serif/sans mismatch. Use `.serif` only when the run is purely Latin
    /// / Greek / digits / symbols; otherwise default design (which renders
    /// Hangul cleanly via Apple SD Gothic Neo).
    private static func fontForRun(_ text: String, size: CGFloat) -> Font {
        for c in text.unicodeScalars {
            if (0xAC00...0xD7A3).contains(c.value)   // 한글 음절
                || (0x1100...0x11FF).contains(c.value) // 한글 자모
                || (0x3130...0x318F).contains(c.value) // 호환 자모
            {
                return .system(size: size, design: .default)
            }
        }
        return .system(size: size, design: .serif)
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

// MARK: - Paper background

struct ImunDeBackground: View {
    var body: some View {
        Theme.void.ignoresSafeArea()
    }
}

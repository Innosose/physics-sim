import SwiftUI
import UIKit

/// **윤슬 (Yunseul)** 디자인 시스템 — 앱 이름이자 테마 이름.
///
/// "햇빛·달빛에 어린 잔물결" 이라는 순우리말. 깊은 밤바다(다크) 또는
/// 잔잔한 새벽 수면(라이트) 위에 떠 있는 따뜻한 금빛 결을 모티프로 한다.
///
/// 모든 토큰은 `Color.adaptive(light:dark:)` 로 정의되어 시스템 테마 또는
/// 사용자 선택에 자동 반응한다.
enum Theme {
    // MARK: - 팔레트

    /// 가장 깊은 어둠/가장 옅은 빛 — 앱의 외곽 그라데이션 끝.
    static let void = Color.adaptive(
        light: Color(red: 0.93, green: 0.94, blue: 0.97),   // 옅은 안개
        dark:  Color(red: 0.020, green: 0.031, blue: 0.086)) // #050816

    /// 뷰포트 바닥 — 잔잔한 수면.
    static let deep = Color.adaptive(
        light: Color(red: 0.95, green: 0.96, blue: 0.99),
        dark:  Color(red: 0.043, green: 0.067, blue: 0.149)) // #0B1126

    /// 패널 표면.
    static let surface = Color.adaptive(
        light: Color.white,
        dark:  Color(red: 0.075, green: 0.102, blue: 0.220)) // #131A38

    /// 헤더 바·강조 행.
    static let crest = Color.adaptive(
        light: Color(red: 0.91, green: 0.93, blue: 0.97),
        dark:  Color(red: 0.118, green: 0.153, blue: 0.314)) // #1E2750

    /// 주 액션 — 따뜻한 황금빛 윤슬 (라이트·다크 공통, 라이트는 약간 진하게).
    static let glow = Color.adaptive(
        light: Color(red: 0.78, green: 0.55, blue: 0.18),
        dark:  Color(red: 0.878, green: 0.710, blue: 0.455)) // #E0B574

    /// 보조 — 청록 진주.
    static let accent = Color.adaptive(
        light: Color(red: 0.20, green: 0.65, blue: 0.58),
        dark:  Color(red: 0.400, green: 0.831, blue: 0.753)) // #66D4C0

    /// 선택 강조 — 부드러운 자수정.
    static let pulse = Color.adaptive(
        light: Color(red: 0.55, green: 0.36, blue: 0.78),
        dark:  Color(red: 0.725, green: 0.553, blue: 0.898)) // #B98DE5

    /// 보존·성공 — 박하.
    static let confirm = Color.adaptive(
        light: Color(red: 0.30, green: 0.65, blue: 0.40),
        dark:  Color(red: 0.561, green: 0.890, blue: 0.635)) // #8FE3A2

    /// 위험 — 따뜻한 산호.
    static let danger = Color.adaptive(
        light: Color(red: 0.78, green: 0.30, blue: 0.30),
        dark:  Color(red: 0.878, green: 0.482, blue: 0.482)) // #E07B7B

    /// 본문 텍스트.
    static let ink = Color.adaptive(
        light: Color(red: 0.05, green: 0.07, blue: 0.16),
        dark:  Color(red: 0.945, green: 0.925, blue: 0.878)) // #F1ECE0

    /// 보조 텍스트.
    static let mist = Color.adaptive(
        light: Color(red: 0.36, green: 0.40, blue: 0.50),
        dark:  Color(red: 0.533, green: 0.584, blue: 0.718)) // #8895B7

    /// 외곽선·1px 보더.
    static let stroke = Color.adaptive(
        light: Color.black.opacity(0.10),
        dark:  Color.white.opacity(0.08))

    /// 분할선.
    static let divider = Color.adaptive(
        light: Color.black.opacity(0.06),
        dark:  Color.white.opacity(0.04))
}

// MARK: - Color.adaptive

extension Color {
    /// `UITraitCollection.userInterfaceStyle` 에 따라 자동으로 라이트/다크 색을 고른다.
    /// 시스템 테마 또는 `.preferredColorScheme(_:)` 양쪽에 반응.
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - 폰트

extension Font {
    /// 수치·단위에 사용 — SF Mono.
    static var themeMono: Font     { .system(size: 12, weight: .regular,  design: .monospaced) }
    static var themeMonoBold: Font { .system(size: 12, weight: .semibold, design: .monospaced) }
    /// 패널 헤더 — small caps + 살짝 트래킹.
    static var themeHeader: Font   { .system(size: 11, weight: .semibold, design: .default).smallCaps() }
    /// 본문 라벨 — 둥근 SF Pro.
    static var themeLabel: Font    { .system(size: 13, weight: .regular,  design: .rounded) }
}

// MARK: - 카드 모디파이어

extension View {
    /// 윤슬 카드 — Liquid Glass 위에 surface 톤 살짝.
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

// MARK: - 그라데이션 배경 (앱 전체 공용)

/// 앱 전체에서 쓰는 윤슬 그라데이션 배경. 라이트/다크 자동 전환.
struct YunseulBackground: View {
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

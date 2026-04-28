import SwiftUI

/// Blender 모바일 스타일 팔레트 — 어두운 그래파이트 + 강한 액션 색.
///
/// Liquid Glass 위에 살짝 입혀서 "전문 도구의 모바일 버전" 느낌을 노린다.
enum BlenderTheme {
    /// 액션·재생·강조 (Blender 의 selected/active 와 비슷한 톤).
    static let accent     = Color(red: 0.91, green: 0.49, blue: 0.05)   // #E87D0E
    /// 하이라이트·선택 (Blender 의 active selection 파란색).
    static let highlight  = Color(red: 0.28, green: 0.45, blue: 0.71)   // #4772B3
    /// 보조 그린 (Blender 의 mesh outline).
    static let confirm    = Color(red: 0.42, green: 0.79, blue: 0.45)
    /// 위험·삭제.
    static let danger     = Color(red: 0.86, green: 0.32, blue: 0.30)

    /// 가장 어두운 viewport 배경 — Blender 의 viewport 그래파이트.
    static let viewportBg = Color(red: 0.13, green: 0.13, blue: 0.15)
    /// 패널 바닥(Property panel) — 아주 살짝 밝은 회색.
    static let panel      = Color(red: 0.18, green: 0.18, blue: 0.20)
    /// 헤더 바 색.
    static let header     = Color(red: 0.22, green: 0.22, blue: 0.24)
    /// 모노 텍스트 기본.
    static let monoText   = Color(white: 0.92)
    /// 보조 텍스트.
    static let dimText    = Color(white: 0.62)
    /// 패널 외곽선.
    static let stroke     = Color.white.opacity(0.07)
    /// 분할선.
    static let divider    = Color.white.opacity(0.05)
}

extension Font {
    /// Blender 의 작은 모노스페이스 라벨 — 수치·단위에 사용.
    static var blenderMono: Font { .system(size: 12, weight: .regular, design: .monospaced) }
    static var blenderMonoBold: Font { .system(size: 12, weight: .semibold, design: .monospaced) }
    /// 패널 헤더.
    static var blenderHeader: Font { .system(size: 11, weight: .semibold, design: .default).smallCaps() }
    /// 본문 라벨.
    static var blenderLabel: Font { .system(size: 13, weight: .regular, design: .default) }
}

extension View {
    /// Blender 풍 카드 — Liquid Glass 에 어두운 panel 색을 살짝 입히고 가는 외곽선.
    func blenderCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(BlenderCard(cornerRadius: cornerRadius,
                             tint: BlenderTheme.panel.opacity(0.45)))
    }

    /// 살짝 떠 보이는 헤더 바 — 시뮬 상단/하단에 사용.
    func blenderHeaderBar() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .modifier(BlenderCard(cornerRadius: 12,
                                  tint: BlenderTheme.header.opacity(0.55)))
    }
}

private struct BlenderCard: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .glassEffect(.regular.tint(tint), in: shape)
            .overlay(shape.stroke(BlenderTheme.stroke, lineWidth: 1))
    }
}

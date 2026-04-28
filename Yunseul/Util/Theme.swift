import SwiftUI

/// **윤슬 (Yunseul)** 디자인 시스템 — 앱 이름이자 테마 이름.
///
/// "햇빛·달빛에 어린 잔물결" 이라는 순우리말. 깊은 밤바다 위에 떠 있는
/// 따뜻한 금빛 결을 모티프로 한 고유 팔레트와 보조 뷰의 모음.
///
/// 팔레트는 한 곳에서만 정의되어 있고, `themeCard`, `themeHeaderBar`,
/// `RippleField`, `StarField` 같은 보조 뷰가 같은 톤을 재사용한다.
enum Theme {
    // MARK: - 팔레트

    /// 가장 깊은 어둠 — 앱의 외곽 그라데이션 끝.
    static let void     = Color(red: 0.020, green: 0.031, blue: 0.086)   // #050816
    /// 뷰포트 바닥 — 잔잔한 밤바다.
    static let deep     = Color(red: 0.043, green: 0.067, blue: 0.149)   // #0B1126
    /// 패널 표면 — 아주 살짝 떠 보이는 수면.
    static let surface  = Color(red: 0.075, green: 0.102, blue: 0.220)   // #131A38
    /// 헤더 바·강조 행 — 가장 가까운 수면.
    static let crest    = Color(red: 0.118, green: 0.153, blue: 0.314)   // #1E2750

    /// 주 액션 — 따뜻한 황금빛 윤슬.
    static let glow     = Color(red: 0.878, green: 0.710, blue: 0.455)   // #E0B574
    /// 보조 액션·하이라이트 — 청록 진주.
    static let accent   = Color(red: 0.400, green: 0.831, blue: 0.753)   // #66D4C0
    /// 선택 강조 — 부드러운 자수정.
    static let pulse    = Color(red: 0.725, green: 0.553, blue: 0.898)   // #B98DE5
    /// 보존·성공 — 박하 새벽.
    static let confirm  = Color(red: 0.561, green: 0.890, blue: 0.635)   // #8FE3A2
    /// 위험·삭제 — 따뜻한 산호.
    static let danger   = Color(red: 0.878, green: 0.482, blue: 0.482)   // #E07B7B

    /// 본문 텍스트 — 따뜻한 상아.
    static let ink      = Color(red: 0.945, green: 0.925, blue: 0.878)   // #F1ECE0
    /// 보조 텍스트 — 안개 푸른 회색.
    static let mist     = Color(red: 0.533, green: 0.584, blue: 0.718)   // #8895B7

    /// 외곽선·1px 보더.
    static let stroke   = Color.white.opacity(0.08)
    /// 분할선.
    static let divider  = Color.white.opacity(0.04)
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
    /// 큰 표제.
    static var themeTitle: Font    { .system(size: 56, weight: .heavy,    design: .rounded) }
}

// MARK: - 카드·헤더 모디파이어

extension View {
    /// 윤슬 카드 — Liquid Glass 위에 surface 톤 살짝 입히고, 좌상단에 작은 금빛 마커.
    func themeCard(cornerRadius: CGFloat = 16, marker: Bool = true) -> some View {
        modifier(ThemeCard(cornerRadius: cornerRadius, marker: marker))
    }

    /// 슬림한 헤더 바 (옵션) — 시뮬 화면 윗부분 등에 쓰기.
    func themeHeaderBar() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .modifier(ThemeCard(cornerRadius: 12, marker: false, tint: Theme.crest.opacity(0.55)))
    }
}

private struct ThemeCard: ViewModifier {
    let cornerRadius: CGFloat
    var marker: Bool = true
    var tint: Color = Theme.surface.opacity(0.55)
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .glassEffect(.regular.tint(tint), in: shape)
            .overlay(shape.stroke(Theme.stroke, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                if marker {
                    Circle()
                        .fill(Theme.glow)
                        .frame(width: 5, height: 5)
                        .shadow(color: Theme.glow.opacity(0.7), radius: 4)
                        .padding(10)
                }
            }
    }
}

// MARK: - 윤슬 — 잔물결 라인 배경 (시뮬 뷰포트 용)

/// 가로로 길게 누운 잔물결을 몇 줄 그려서 "수면" 같은 느낌을 준다.
/// 정적 (시간에 의존하지 않음) — 적분 비용 0.
struct RippleField: View {
    var body: some View {
        Canvas { ctx, size in
            let n = 7                                    // 잔물결 줄 수
            let amp: CGFloat = 6
            let wavelength: CGFloat = max(120, size.width / 6)
            for i in 0..<n {
                let f = CGFloat(i) / CGFloat(n - 1)
                let cy = size.height * (0.18 + f * 0.72)
                var path = Path()
                let phase = CGFloat(i) * 0.7
                let step: CGFloat = 6
                var x: CGFloat = 0
                while x <= size.width {
                    let y = cy + amp * CGFloat(sin(Double(x / wavelength * 2 * .pi + phase)))
                    if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else      { path.addLine(to: CGPoint(x: x, y: y)) }
                    x += step
                }
                let alpha = 0.05 + 0.04 * cos(Double(f) * .pi)
                ctx.stroke(path,
                           with: .color(Theme.glow.opacity(alpha)),
                           lineWidth: 0.7)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 별자리 — 시작화면 배경

/// 듬성듬성한 점 + 두세 개의 빛나는 별. 비결정적이지만 안정적인 배치를 위해
/// 단일 시드 기반 의사난수를 사용.
struct StarField: View {
    var body: some View {
        Canvas { ctx, size in
            // 전체 화면에 작은 점 분포.
            var rng = SeededGenerator(seed: 1729)
            let n = max(40, Int(size.width * size.height / 12_000))
            for _ in 0..<n {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r: CGFloat = CGFloat.random(in: 0.4...1.4, using: &rng)
                let a = Double.random(in: 0.08...0.35, using: &rng)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(a)))
            }
            // 두 개의 큰 별 — glow 색.
            for (cx, cy, br) in [(size.width * 0.18, size.height * 0.22, 1.0),
                                  (size.width * 0.78, size.height * 0.34, 0.7)] {
                let core: CGFloat = 2.0
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - core, y: cy - core,
                                           width: core * 2, height: core * 2)),
                    with: .color(Theme.glow.opacity(0.8 * br)))
                // halo
                let h: CGFloat = 14
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - h, y: cy - h,
                                           width: h * 2, height: h * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Theme.glow.opacity(0.30 * br), .clear]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: h))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 짧은 금빛 잔물결 — 시작화면 표제 아래 같은 곳에 쓰는 작은 장식.
struct RippleAccent: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            let amp = size.height * 0.35
            let cy = size.height / 2
            let n = 64
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                let x = t * size.width
                let y = cy + amp * CGFloat(sin(Double(t) * .pi * 4))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else      { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path,
                       with: .linearGradient(
                            Gradient(colors: [.clear, Theme.glow, .clear]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)),
                       lineWidth: 1.2)
        }
        .allowsHitTesting(false)
    }
}

/// 결정적 의사 난수 — StarField 가 매 렌더마다 점 위치를 바꾸지 않도록.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - 그라데이션 배경 (앱 전체 공용)

/// 앱 전체에서 쓰는 깊은 밤바다 그라데이션.
struct YunseulBackground: View {
    /// 위쪽에서 부드럽게 떨어지는 광원의 색 — 화면별로 달리해 분위기 차이.
    var topGlow: Color = Theme.glow.opacity(0.10)
    /// 별자리 패턴을 깔지 여부.
    var stars: Bool = true

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
            if stars {
                StarField()
                    .opacity(0.85)
                    .ignoresSafeArea()
            }
        }
    }
}

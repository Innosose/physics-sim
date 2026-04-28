import SwiftUI

/// 1차원 충돌 — 두 카트가 마찰 없는 트랙 위에서 부딪힌다.
///
/// 탄성 계수 e (0..1) 로 매개:
///   v1' = ((m1 - e·m2)·v1 + (1 + e)·m2·v2) / (m1 + m2)
///   v2' = ((m2 - e·m1)·v2 + (1 + e)·m1·v1) / (m1 + m2)
struct CollisionScene: View {
    @State private var m1: Double = 2.0
    @State private var m2: Double = 1.0
    @State private var v1: Double = 3.0
    @State private var v2: Double = -1.0
    @State private var restitution: Double = 1.0     // 1=완전탄성, 0=완전비탄성
    @State private var running = true

    @State private var x1: Double = -3.0
    @State private var x2: Double =  3.0
    @State private var u1: Double = 0
    @State private var u2: Double = 0
    @State private var lastTime: TimeInterval? = nil
    @State private var hasCollided = false

    private let halfWidth = 0.4   // 카트의 반-폭 (m)
    private let trackHalf = 6.0   // m

    var body: some View {
        SimChrome(
                  blurb: "운동량은 항상 보존, 운동에너지는 e=1 일 때만 보존. 화면 아래에 충돌 직후 측정값이 나타난다.",
                  canvas: { canvas },
                  controls: { controls })
            .onAppear { reset() }
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                advance(to: tl.date.timeIntervalSinceReferenceDate)
                draw(ctx: ctx, size: size)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "질량 m₁", value: $m1, range: 0.2...10, format: "%.1f", unit: "kg")
            LabeledSlider(title: "질량 m₂", value: $m2, range: 0.2...10, format: "%.1f", unit: "kg")
            LabeledSlider(title: "초속 v₁", value: $v1, range: -8...8, format: "%.1f", unit: "m/s")
            LabeledSlider(title: "초속 v₂", value: $v2, range: -8...8, format: "%.1f", unit: "m/s")
            LabeledSlider(title: "반발계수 e", value: $restitution, range: 0...1, format: "%.2f")
            PlayResetBar(running: $running, onReset: reset)
            Divider()
            let p = m1 * u1 + m2 * u2
            let ke = 0.5 * m1 * u1 * u1 + 0.5 * m2 * u2 * u2
            Readout(label: "u₁", value: String(format: "%.2f m/s", u1))
            Readout(label: "u₂", value: String(format: "%.2f m/s", u2))
            Readout(label: "총 운동량 p",  value: String(format: "%.2f kg·m/s", p))
            Readout(label: "총 운동에너지 KE", value: String(format: "%.2f J", ke))
            Text(hasCollided ? "충돌 후" : "충돌 전")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - 동역학

    private func reset() {
        x1 = -3; x2 = 3; u1 = v1; u2 = v2; lastTime = nil; hasCollided = false
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now

        x1 += u1 * dt
        x2 += u2 * dt

        // 충돌 검출 (접촉 + 접근중).
        if x2 - x1 < 2 * halfWidth && (u1 - u2) > 0 {
            let m = m1 + m2
            let n1 = ((m1 - restitution * m2) * u1 + (1 + restitution) * m2 * u2) / m
            let n2 = ((m2 - restitution * m1) * u2 + (1 + restitution) * m1 * u1) / m
            u1 = n1; u2 = n2
            // 침투 보정.
            let pen = 2 * halfWidth - (x2 - x1)
            x1 -= pen / 2
            x2 += pen / 2
            hasCollided = true
        }

        // 트랙 양 끝에서 반사 (시뮬을 화면 안에 가두기 위함).
        if x1 - halfWidth < -trackHalf { x1 = -trackHalf + halfWidth; u1 = abs(u1) }
        if x2 + halfWidth >  trackHalf { x2 =  trackHalf - halfWidth; u2 = -abs(u2) }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let world = CGRect(x: -trackHalf - 0.5, y: -1.5,
                           width: 2 * trackHalf + 1, height: 3)
        let map = CanvasMap(view: size, world: world, padding: 16)
        // 트랙.
        var track = Path()
        track.move(to: map.point(x: -trackHalf, y: 0))
        track.addLine(to: map.point(x:  trackHalf, y: 0))
        ctx.stroke(track, with: .color(.white.opacity(0.5)), lineWidth: 2)
        // 카트.
        drawCart(ctx: ctx, map: map, x: x1, m: m1, color: .yellow)
        drawCart(ctx: ctx, map: map, x: x2, m: m2, color: .cyan)
    }

    private func drawCart(ctx: GraphicsContext, map: CanvasMap,
                          x: Double, m: Double, color: Color) {
        // 높이 ∝ 질량 (가시화용).
        let h = 0.4 + 0.18 * m
        let rect = CGRect(x: map.point(x: x - halfWidth, y: h).x,
                          y: map.point(x: x - halfWidth, y: h).y,
                          width: map.length(2 * halfWidth),
                          height: map.length(h))
        ctx.fill(Path(rect), with: .color(color))
        ctx.stroke(Path(rect), with: .color(.white.opacity(0.4)), lineWidth: 1)
        // 바퀴.
        for off in [-halfWidth * 0.6, halfWidth * 0.6] {
            let p = map.point(x: x + off, y: 0)
            let r: CGFloat = 6
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r,
                                            width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(0.7)))
        }
    }
}

import SwiftUI

/// 케플러 궤도 — 고정된 중심 질량 주위의 시험질점.
///
/// F = -GM·r̂ / r²  (m=1).
/// 시ymplectic Euler 로 적분 → 에너지가 장기간 안정.
struct KeplerScene: View {
    @State private var GM: Double = 200.0          // 임의 단위
    @State private var r0: Double = 5.0
    @State private var v0: Double = 6.0            // 접선 방향
    @State private var running = true

    @State private var pos = Vec2(x: 5, y: 0)
    @State private var vel = Vec2(x: 0, y: 6)
    @State private var trail: [Vec2] = []
    private let trailMax = 600
    @State private var lastTime: TimeInterval? = nil

    var body: some View {
        SimChrome(
                  blurb: "v₀ 가 작으면 타원, 원궤도 속도(√(GM/r))이면 원, 더 크면 더 길쭉한 타원/포물선/쌍곡선.",
                  canvas: { canvas },
                  controls: { controls })
            .onAppear { reset() }
            .onChange(of: r0) { _, _ in reset() }
            .onChange(of: v0) { _, _ in reset() }
            .onChange(of: GM) { _, _ in reset() }
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
            LabeledSlider(title: "GM",     value: $GM, range: 50...600, format: "%.0f")
            LabeledSlider(title: "초기 거리 r₀", value: $r0, range: 2...10, format: "%.2f")
            LabeledSlider(title: "초기 접선속력 v₀", value: $v0, range: 1...12, format: "%.2f")
            PlayResetBar(running: $running, onReset: reset)
            Divider()
            let r = pos.length
            let speed = vel.length
            let circ = sqrt(GM / r0)
            let esc  = sqrt(2 * GM / r0)
            let energy = 0.5 * speed * speed - GM / r
            let L = pos.x * vel.y - pos.y * vel.x
            Readout(label: "원궤도 속력",   value: String(format: "%.2f", circ))
            Readout(label: "탈출속력",     value: String(format: "%.2f", esc))
            Readout(label: "현재 r",       value: String(format: "%.2f", r))
            Readout(label: "현재 |v|",     value: String(format: "%.2f", speed))
            Readout(label: "역학적 에너지", value: String(format: "%.3f", energy))
            Readout(label: "각운동량 L",   value: String(format: "%.3f", L))
        }
    }

    // MARK: - 동역학

    private func reset() {
        pos = Vec2(x: r0, y: 0)
        vel = Vec2(x: 0, y: v0)
        trail.removeAll()
        lastTime = nil
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        let sub = 200
        let h = dt / Double(sub)
        for _ in 0..<sub {
            let r2 = pos.lengthSquared
            if r2 < 1e-4 { break }
            let r = sqrt(r2)
            let acc = pos * (-GM / (r2 * r))
            vel += acc * h
            pos += vel * h
        }
        // 너무 멀리 가면 리셋 (탈출 궤도 보호).
        if pos.length > 60 { reset(); return }
        trail.append(pos)
        if trail.count > trailMax { trail.removeFirst(trail.count - trailMax) }
        lastTime = now
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let extent = max(8.0, max(abs(pos.x), abs(pos.y)) * 1.4 + 2)
        let world = CGRect(x: -extent, y: -extent, width: 2 * extent, height: 2 * extent)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 자취.
        var trailPath = Path()
        for (i, p) in trail.enumerated() {
            let pt = map.point(p)
            if i == 0 { trailPath.move(to: pt) } else { trailPath.addLine(to: pt) }
        }
        ctx.stroke(trailPath, with: .color(.cyan.opacity(0.7)), lineWidth: 1.4)

        // 중심 질량.
        let c = map.point(.zero)
        let cr: CGFloat = 10
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - cr, y: c.y - cr,
                                        width: cr * 2, height: cr * 2)),
                 with: .color(.orange))

        // 궤도 입자.
        let pp = map.point(pos)
        let pr: CGFloat = 6
        ctx.fill(Path(ellipseIn: CGRect(x: pp.x - pr, y: pp.y - pr,
                                        width: pr * 2, height: pr * 2)),
                 with: .color(.yellow))

        // 속도 화살표.
        let vEnd = map.point(pos + vel * 0.3)
        var v = Path()
        v.move(to: pp); v.addLine(to: vEnd)
        ctx.stroke(v, with: .color(.green), lineWidth: 1.2)
    }
}

import SwiftUI

/// 자유낙하 / 연직 던지기 — 등가속도 운동의 정확한 분석해.
///
///  v(t) = v₀ − g·t
///  y(t) = y₀ + v₀·t − ½ g t²
///
/// 적분 오차 없음 — 모든 측정값은 정확한 닫힌 해를 사용.
struct FreeFallScene: View {
    @State private var initialHeight: Double = 20.0    // m
    @State private var initialVelocity: Double = 5.0   // m/s, 위쪽 +
    @State private var gravity: Double = 9.81

    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "공의 위치와 속도는 시간의 1차·2차 함수. 던져 올린 뒤 가장 높은 점에서 v=0, 그 시각은 t=v₀/g.",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                let t = elapsed(at: tl.date)
                draw(ctx: ctx, size: size, t: t)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "처음 높이 y₀", value: $initialHeight,
                          range: 0...50, format: "%.1f", unit: "m")
            LabeledSlider(title: "처음 속도 v₀ (위 +)", value: $initialVelocity,
                          range: -10...20, format: "%.1f", unit: "m/s")
            LabeledSlider(title: "중력 g", value: $gravity,
                          range: 1.62...24.79, format: "%.2f", unit: "m/s²")
            PlayResetBar(running: $running, onReset: { startTime = Date(); running = true }, resetLabel: "처음부터")
            Divider()
            let t = elapsed(at: Date())
            let s = state(at: t)
            Readout(label: "시간 t", value: String(format: "%.2f s", t))
            Readout(label: "높이 y", value: String(format: "%.2f m", s.y))
            Readout(label: "속도 v", value: String(format: "%+.2f m/s", s.v))
            // 최고점에 도달하는 시각·높이 (해석해).
            if initialVelocity > 0 {
                let tApex = initialVelocity / gravity
                let yApex = initialHeight + initialVelocity * tApex - 0.5 * gravity * tApex * tApex
                Readout(label: "최고점 시각", value: String(format: "%.2f s", tApex))
                Readout(label: "최고점 높이", value: String(format: "%.2f m", yApex))
            }
            // 바닥(y=0)에 닿는 시각.
            if let tg = groundTime() {
                Readout(label: "바닥 도달 시각", value: String(format: "%.2f s", tg))
            }
        }
    }

    // MARK: - 분석해

    private func elapsed(at date: Date) -> Double {
        max(0, date.timeIntervalSince(startTime))
    }

    private func state(at t: Double) -> (y: Double, v: Double) {
        // 바닥을 만나면 정지 (시각화용). 측정값은 정확.
        if let tg = groundTime(), t > tg { return (y: 0, v: 0) }
        let y = initialHeight + initialVelocity * t - 0.5 * gravity * t * t
        let v = initialVelocity - gravity * t
        return (y, v)
    }

    /// y(t) = 0 의 양의 해. 이차방정식: ½ g t² − v₀ t − y₀ = 0.
    private func groundTime() -> Double? {
        let a = 0.5 * gravity
        let b = -initialVelocity
        let c = -initialHeight
        let disc = b * b - 4 * a * c
        guard disc >= 0 else { return nil }
        let r = sqrt(disc)
        let t1 = (-b - r) / (2 * a)
        let t2 = (-b + r) / (2 * a)
        return [t1, t2].filter { $0 > 1e-6 }.min()
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let split = size.width * 0.38
        let leftRect  = CGRect(x: 0, y: 0, width: split, height: size.height)
        let rightRect = CGRect(x: split, y: 0, width: size.width - split, height: size.height)
        drawWorld(ctx: ctx, in: leftRect, t: t)
        drawGraphs(ctx: ctx, in: rightRect, t: t)
    }

    private func drawWorld(ctx: GraphicsContext, in r: CGRect, t: Double) {
        let yMax = max(initialHeight + 5,
                       initialHeight + (initialVelocity * initialVelocity) / (2 * gravity) + 5)
        let world = CGRect(x: -2, y: -1, width: 4, height: yMax + 1)
        let map = CanvasMap(view: r.size, world: world, padding: 14)
        // y 격자.
        let step = niceStep(yMax / 8)
        var y = 0.0
        var grid = Path()
        while y <= yMax {
            grid.move(to: CGPoint(x: r.minX + map.point(x: -2, y: y).x,
                                  y: r.minY + map.point(x: 0, y: y).y))
            grid.addLine(to: CGPoint(x: r.minX + map.point(x: 2, y: y).x,
                                     y: r.minY + map.point(x: 0, y: y).y))
            y += step
        }
        ctx.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)
        // 바닥.
        var ground = Path()
        ground.move(to: CGPoint(x: r.minX + map.point(x: -2, y: 0).x,
                                y: r.minY + map.point(x: 0, y: 0).y))
        ground.addLine(to: CGPoint(x: r.minX + map.point(x: 2, y: 0).x,
                                   y: r.minY + map.point(x: 0, y: 0).y))
        ctx.stroke(ground, with: .color(.white.opacity(0.4)), lineWidth: 1.2)
        // 공.
        let s = state(at: t)
        let p = map.point(x: 0, y: s.y)
        let pr: CGFloat = 10
        ctx.fill(Path(ellipseIn: CGRect(x: r.minX + p.x - pr,
                                        y: r.minY + p.y - pr,
                                        width: pr * 2, height: pr * 2)),
                 with: .color(.yellow))
    }

    private func drawGraphs(ctx: GraphicsContext, in r: CGRect, t: Double) {
        let topRect = CGRect(x: r.minX + 10, y: r.minY + 10,
                             width: r.width - 20, height: (r.height - 30) / 2)
        let botRect = CGRect(x: r.minX + 10, y: topRect.maxY + 10,
                             width: r.width - 20, height: (r.height - 30) / 2)
        let tg = groundTime() ?? max(2, t * 1.2)
        let tEnd = max(tg, t * 1.2, 2)

        // y(t).
        drawAxis(ctx: ctx, in: topRect, label: "y(t)")
        drawCurve(ctx: ctx, in: topRect, tEnd: tEnd, tNow: t,
                  color: .green, fn: { state(at: $0).y },
                  yRange: (0, max(initialHeight + 5,
                                  initialHeight + (initialVelocity * initialVelocity) / (2 * gravity) + 5)))

        // v(t).
        drawAxis(ctx: ctx, in: botRect, label: "v(t)")
        let vMin = min(0.0, initialVelocity - gravity * tEnd, initialVelocity)
        let vMax = max(0.0, initialVelocity)
        drawCurve(ctx: ctx, in: botRect, tEnd: tEnd, tNow: t,
                  color: .pink, fn: { state(at: $0).v },
                  yRange: (vMin - 1, vMax + 1))
    }

    private func drawAxis(ctx: GraphicsContext, in r: CGRect, label: String) {
        ctx.stroke(Path(roundedRect: r, cornerRadius: 8),
                   with: .color(.white.opacity(0.18)), lineWidth: 1)
        ctx.draw(Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 18, y: r.minY + 12))
    }

    private func mapY(_ y: Double, in r: CGRect, yRange: (Double, Double)) -> CGFloat? {
        let (lo, hi) = yRange
        guard hi > lo else { return nil }
        let f = (y - lo) / (hi - lo)
        return r.maxY - 6 - CGFloat(f) * (r.height - 18)
    }

    private func drawCurve(ctx: GraphicsContext, in r: CGRect,
                           tEnd: Double, tNow: Double,
                           color: Color,
                           fn: (Double) -> Double,
                           yRange: (Double, Double)) {
        // 0 축.
        if let zeroY = mapY(0, in: r, yRange: yRange) {
            var ax = Path()
            ax.move(to: CGPoint(x: r.minX + 6, y: zeroY))
            ax.addLine(to: CGPoint(x: r.maxX - 6, y: zeroY))
            ctx.stroke(ax, with: .color(.white.opacity(0.25)), lineWidth: 1)
        }

        var path = Path()
        let n = 200
        for i in 0...n {
            let tt = tEnd * Double(i) / Double(n)
            guard let py = mapY(fn(tt), in: r, yRange: yRange) else { continue }
            let f = CGFloat(i) / CGFloat(n)
            let px = r.minX + 6 + f * (r.width - 12)
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(color), lineWidth: 1.6)

        // 현재 시각 마커.
        let f = CGFloat(min(tNow, tEnd) / tEnd)
        let cx = r.minX + 6 + f * (r.width - 12)
        if let cy = mapY(fn(min(tNow, tEnd)), in: r, yRange: yRange) {
            let pr: CGFloat = 4
            ctx.fill(Path(ellipseIn: CGRect(x: cx - pr, y: cy - pr,
                                            width: pr * 2, height: pr * 2)),
                     with: .color(color))
        }
    }
}

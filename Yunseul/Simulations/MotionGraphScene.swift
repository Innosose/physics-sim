import SwiftUI

/// 등속 vs 등가속도 운동 비교 — 위치-시간, 속도-시간 그래프.
///
/// 등속:        x₁(t) = v₁·t,             v₁(t) = v₁  (상수)
/// 등가속도:    x₂(t) = v₀·t + ½ a t²,    v₂(t) = v₀ + a·t
///
/// 두 입자가 같은 트랙 위에서 동시에 출발한 모습을 위에 그리고,
/// 그 아래에 두 가지 그래프를 동시에 표시.
struct MotionGraphScene: View {
    @State private var v1: Double = 5.0      // 등속 속도 (m/s)
    @State private var v0: Double = 0.0      // 등가속도 입자의 초기 속도
    @State private var a: Double  = 1.5      // 가속도 (m/s²)

    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "위치-시간 그래프에서 등속은 직선, 등가속도는 포물선. 속도-시간 그래프에서는 등속이 수평선, 등가속도가 직선.",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                let t = max(0, tl.date.timeIntervalSince(startTime))
                draw(ctx: ctx, size: size, t: t)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "등속 속도 v₁", value: $v1, range: 0...10,
                          format: "%.2f", unit: "m/s")
            LabeledSlider(title: "등가속도 초기속도 v₀", value: $v0, range: 0...10,
                          format: "%.2f", unit: "m/s")
            LabeledSlider(title: "가속도 a", value: $a, range: -3...4,
                          format: "%.2f", unit: "m/s²")
            PlayResetBar(running: $running, onReset: { startTime = Date(); running = true }, resetLabel: "처음부터")
            Divider()
            let t = max(0, Date().timeIntervalSince(startTime))
            Readout(label: "현재 t", value: String(format: "%.2f s", t))
            Readout(label: "등속 x₁", value: String(format: "%.2f m", x1(t)))
            Readout(label: "등가속도 x₂", value: String(format: "%.2f m", x2(t)))
            Readout(label: "등가속도 v₂", value: String(format: "%.2f m/s", v0 + a * t))
        }
    }

    private func x1(_ t: Double) -> Double { v1 * t }
    private func x2(_ t: Double) -> Double { v0 * t + 0.5 * a * t * t }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let trackRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.30)
        let xtRect    = CGRect(x: 0, y: trackRect.maxY,
                               width: size.width / 2, height: size.height * 0.70)
        let vtRect    = CGRect(x: xtRect.maxX, y: trackRect.maxY,
                               width: size.width / 2, height: size.height * 0.70)
        drawTrack(ctx: ctx, in: trackRect, t: t)
        let tEnd = max(8.0, t * 1.05)
        drawXT(ctx: ctx, in: xtRect, t: t, tEnd: tEnd)
        drawVT(ctx: ctx, in: vtRect, t: t, tEnd: tEnd)
    }

    private func drawTrack(ctx: GraphicsContext, in r: CGRect, t: Double) {
        var line = Path()
        line.move(to: CGPoint(x: r.minX + 16, y: r.midY))
        line.addLine(to: CGPoint(x: r.maxX - 16, y: r.midY))
        ctx.stroke(line, with: .color(.white.opacity(0.4)), lineWidth: 1.2)

        let xMax = max(20.0, max(x1(t), x2(t)) * 1.2 + 5)
        let usableW = r.width - 32
        let toX: (Double) -> CGFloat = { val in
            r.minX + 16 + CGFloat(val / xMax) * usableW
        }
        // 등속 (파랑).
        let p1 = CGPoint(x: toX(x1(t)), y: r.midY - 14)
        let pr: CGFloat = 8
        ctx.fill(Path(ellipseIn: CGRect(x: p1.x - pr, y: p1.y - pr,
                                        width: pr * 2, height: pr * 2)),
                 with: .color(.cyan))
        // 등가속도 (주황).
        let p2 = CGPoint(x: toX(x2(t)), y: r.midY + 14)
        ctx.fill(Path(ellipseIn: CGRect(x: p2.x - pr, y: p2.y - pr,
                                        width: pr * 2, height: pr * 2)),
                 with: .color(.orange))
    }

    private func drawXT(ctx: GraphicsContext, in r: CGRect, t: Double, tEnd: Double) {
        ctx.draw(Text("위치–시간  x(t)").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 80, y: r.minY + 12))
        let yMax = max(20.0,
                       max(x1(tEnd), x2(tEnd), x1(t), x2(t)) * 1.1 + 1)
        drawCurves(ctx: ctx, in: r.insetBy(dx: 12, dy: 24),
                   tEnd: tEnd, tNow: t,
                   yRange: (0, yMax),
                   curves: [(self.x1, .cyan), (self.x2, .orange)])
    }

    private func drawVT(ctx: GraphicsContext, in r: CGRect, t: Double, tEnd: Double) {
        ctx.draw(Text("속도–시간  v(t)").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 80, y: r.minY + 12))
        let v2Now = v0 + a * tEnd
        let yMin = min(0.0, v2Now - 1)
        let yMax = max(v1, v2Now, v1) + 2
        drawCurves(ctx: ctx, in: r.insetBy(dx: 12, dy: 24),
                   tEnd: tEnd, tNow: t,
                   yRange: (yMin, yMax),
                   curves: [({ _ in self.v1 }, .cyan),
                            ({ self.v0 + self.a * $0 }, .orange)])
    }

    private func drawCurves(ctx: GraphicsContext, in r: CGRect,
                            tEnd: Double, tNow: Double,
                            yRange: (Double, Double),
                            curves: [((Double) -> Double, Color)]) {
        // 박스.
        ctx.stroke(Path(roundedRect: r, cornerRadius: 8),
                   with: .color(.white.opacity(0.18)), lineWidth: 1)
        // 0축.
        let (lo, hi) = yRange
        if hi > lo, lo <= 0, hi >= 0 {
            let f = (0 - lo) / (hi - lo)
            let zy = r.maxY - 6 - CGFloat(f) * (r.height - 14)
            var z = Path()
            z.move(to: CGPoint(x: r.minX + 4, y: zy))
            z.addLine(to: CGPoint(x: r.maxX - 4, y: zy))
            ctx.stroke(z, with: .color(.white.opacity(0.25)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        // 곡선.
        for (fn, color) in curves {
            var path = Path()
            let n = 200
            for i in 0...n {
                let tt = tEnd * Double(i) / Double(n)
                let val = fn(tt)
                let f = (val - lo) / (hi - lo)
                let py = r.maxY - 6 - CGFloat(f) * (r.height - 14)
                let px = r.minX + 6 + CGFloat(i) / CGFloat(n) * (r.width - 12)
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            ctx.stroke(path, with: .color(color), lineWidth: 1.6)
            // 현재 점.
            let val = fn(min(tNow, tEnd))
            let f = (val - lo) / (hi - lo)
            let py = r.maxY - 6 - CGFloat(f) * (r.height - 14)
            let px = r.minX + 6 + CGFloat(min(tNow, tEnd) / tEnd) * (r.width - 12)
            let pr: CGFloat = 4
            ctx.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr,
                                            width: pr * 2, height: pr * 2)),
                     with: .color(color))
        }
    }
}

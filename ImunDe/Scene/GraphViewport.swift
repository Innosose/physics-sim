import SwiftUI

struct GraphViewport: View {
    let preset: Preset
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Theme.deep
            switch preset.id {
            case "motiongraph": MotionGraphView()
            case "heat":        HeatTransferView()
            default:            Text("준비 중").foregroundStyle(Theme.mist)
            }
        }
        .id(colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct MotionGraphView: View {
    @State private var v1: Double = 5
    @State private var v0: Double = 0
    @State private var a: Double  = 1.5
    @State private var elapsed: Double = 0
    @State private var lastTick: TimeInterval? = nil
    @State private var running: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size, t: elapsed)
                }
                .onChange(of: tl.date) { _, newDate in
                    advance(to: newDate.timeIntervalSinceReferenceDate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("v₁ (등속)", value: $v1, range: 0...10, unit: "m/s")
                slider("v₀ (등가속 초기)", value: $v0, range: 0...10, unit: "m/s")
                slider("a (가속도)", value: $a, range: -3...4, unit: "m/s²")
                playReset
            }
        }
        .padding(8)
    }

    private var playReset: some View {
        HStack(spacing: 8) {
            Button {
                if !running && bothCartsAtWall() {
                    elapsed = 0; lastTick = nil
                }
                running.toggle()
            } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketchProminent)

            Button {
                elapsed = 0; lastTick = nil; running = false
            } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketch)
        }
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTick else { lastTick = now; return }
        guard running else { lastTick = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTick = now
        elapsed += dt
        if bothCartsAtWall() { running = false }
    }

    private func bothCartsAtWall() -> Bool {
        let trackLength: Double = 30
        guard elapsed > 0.1 else { return false }
        let x1 = v1 * elapsed
        let x2 = v0 * elapsed + 0.5 * a * elapsed * elapsed
        let cart1Done = v1 <= 1e-3 || x1 >= trackLength
        let vNow = v0 + a * elapsed
        let cart2Done = (x2 >= trackLength) || (x2 <= 0 && vNow <= 0)
        return cart1Done && cart2Done
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            PaperSlider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let trackH = size.height * 0.30
        let plotH  = size.height - trackH
        let track = CGRect(x: 0, y: 0, width: size.width, height: trackH)
        let plot  = CGRect(x: 0, y: trackH, width: size.width, height: plotH)

        let trackLength: Double = 30
        // 벽에 닿으면 정지 — 클램프.
        let x1 = min(trackLength, max(0, v1 * t))
        let x2 = min(trackLength, max(0, v0 * t + 0.5 * a * t * t))

        Sketchy.line(from: CGPoint(x: 16, y: track.midY),
                     to: CGPoint(x: track.maxX - 16, y: track.midY),
                     ctx: ctx, color: Theme.ink.opacity(0.6),
                     lineWidth: 1.0, passes: 1, jitter: 0.4)

        let wallX = track.maxX - 16
        Sketchy.line(from: CGPoint(x: wallX, y: track.midY - 24),
                     to: CGPoint(x: wallX, y: track.midY + 24),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.8, passes: 2, jitter: 0.4)

        let usable = track.width - 32
        let toX: (Double) -> CGFloat = { val in
            16 + CGFloat(val / trackLength) * usable
        }
        let p1 = CGPoint(x: toX(x1), y: track.midY - 14)
        let p2 = CGPoint(x: toX(x2), y: track.midY + 14)
        Sketchy.fillCircle(center: p1, radius: 8, ctx: ctx,
                            fill: Theme.bodyPalette[0], stroke: Theme.ink,
                            strokeWidth: 1.2)
        Sketchy.fillCircle(center: p2, radius: 8, ctx: ctx,
                            fill: Theme.bodyPalette[4], stroke: Theme.ink,
                            strokeWidth: 1.2)

        let tEnd = max(8.0, t * 1.05)
        let yMax2 = trackLength * 1.1
        let plotInner = plot.insetBy(dx: 12, dy: 12)
        ctx.stroke(Path(roundedRect: plotInner, cornerRadius: 8),
                   with: .color(Theme.ink.opacity(0.45)), lineWidth: 1.0)
        drawCurve(ctx, in: plotInner, tEnd: tEnd, yMax: yMax2,
                  fn: { min(trackLength, max(0, v1 * $0)) }, dashed: false)
        drawCurve(ctx, in: plotInner, tEnd: tEnd, yMax: yMax2,
                  fn: { min(trackLength, max(0, v0 * $0 + 0.5 * a * $0 * $0)) },
                  dashed: true)
        ctx.draw(Text("실선 ○ 등속   점선 ● 등가속")
                    .font(.system(size: 9)).foregroundStyle(Theme.mist),
                 at: CGPoint(x: plotInner.maxX - 4, y: plotInner.minY + 8),
                 anchor: .trailing)
    }

    private func drawCurve(_ ctx: GraphicsContext, in r: CGRect, tEnd: Double,
                           yMax: Double, fn: (Double) -> Double, dashed: Bool) {
        var path = Path()
        let n = 200
        for i in 0...n {
            let tt = tEnd * Double(i) / Double(n)
            let val = fn(tt)
            let f = CGFloat(i) / CGFloat(n)
            let px = r.minX + 6 + f * (r.width - 12)
            let py = r.maxY - 6 - CGFloat(val / yMax) * (r.height - 14)
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        let style: StrokeStyle = dashed
            ? StrokeStyle(lineWidth: 1.3, lineCap: .round,
                          lineJoin: .round, dash: [5, 3])
            : StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
        ctx.stroke(path, with: .color(Theme.ink), style: style)
    }
}

private struct HeatTransferView: View {
    @State private var T1: Double = 80
    @State private var T2: Double = 20
    @State private var capRatio: Double = 1
    @State private var hA: Double = 1
    @State private var elapsed: Double = 0
    @State private var lastTick: TimeInterval? = nil
    @State private var running: Bool = false

    private var Teq: Double { (T1 + capRatio * T2) / (1 + capRatio) }
    private var tau: Double { capRatio / (hA * (1 + capRatio)) }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size, t: elapsed)
                }
                .onChange(of: tl.date) { _, newDate in
                    advance(to: newDate.timeIntervalSinceReferenceDate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("T₁", value: $T1, range: 0...100, unit: "°C")
                slider("T₂", value: $T2, range: 0...100, unit: "°C")
                slider("열용량 비", value: $capRatio, range: 0.1...5, unit: "")
                slider("h·A", value: $hA, range: 0.1...5, unit: "")
                playReset
            }
        }
        .padding(8)
    }

    private var playReset: some View {
        HStack(spacing: 8) {
            Button {
                if !running && heatSettled {
                    elapsed = 0; lastTick = nil
                }
                running.toggle()
            } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketchProminent)

            Button {
                elapsed = 0; lastTick = nil; running = false
            } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketch)
        }
    }

    private var heatSettled: Bool {
        guard elapsed > 0.5 else { return false }
        let f = exp(-elapsed / tau)
        let gap = max(abs(T1 - Teq), abs(T2 - Teq)) * f
        return gap < 0.3
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTick else { lastTick = now; return }
        guard running else { lastTick = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTick = now
        elapsed += dt
        if heatSettled { running = false }
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            PaperSlider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let topH: CGFloat = 80
        let topR = CGRect(x: 0, y: 0, width: size.width, height: topH)
        let plotR = CGRect(x: 0, y: topH, width: size.width, height: size.height - topH)
        let f = exp(-t / tau)
        let cur1 = Teq + (T1 - Teq) * f
        let cur2 = Teq + (T2 - Teq) * f

        let bw: CGFloat = 100, bh: CGFloat = 60
        let r1 = CGRect(x: topR.midX - bw - 16, y: topR.midY - bh / 2, width: bw, height: bh)
        let r2 = CGRect(x: topR.midX + 16, y: topR.midY - bh / 2, width: bw, height: bh)
        ctx.fill(Path(roundedRect: r1, cornerRadius: 8), with: .color(tempColor(cur1).opacity(0.8)))
        ctx.fill(Path(roundedRect: r2, cornerRadius: 8), with: .color(tempColor(cur2).opacity(0.8)))
        Sketchy.rect(r1, ctx: ctx, color: Theme.ink, lineWidth: 1.2, passes: 1, jitter: 0.5)
        Sketchy.rect(r2, ctx: ctx, color: Theme.ink, lineWidth: 1.2, passes: 1, jitter: 0.5)
        ctx.draw(Text(String(format: "T₁=%.1f°C", cur1)).font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: r1.midX, y: r1.midY))
        ctx.draw(Text(String(format: "T₂=%.1f°C", cur2)).font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: r2.midX, y: r2.midY))

        let inner = plotR.insetBy(dx: 12, dy: 12)
        ctx.stroke(Path(roundedRect: inner, cornerRadius: 8),
                   with: .color(Theme.ink.opacity(0.45)), lineWidth: 1.0)
        let tEnd = max(2 * tau, t * 1.1, 0.5)
        let lo = min(0.0, T1, T2), hi = max(100.0, T1, T2)
        var p1 = Path(), p2 = Path()
        let n = 200
        for i in 0...n {
            let f0 = Double(i) / Double(n)
            let tt = f0 * tEnd
            let v1 = Teq + (T1 - Teq) * exp(-tt / tau)
            let v2 = Teq + (T2 - Teq) * exp(-tt / tau)
            let px = inner.minX + 4 + CGFloat(f0) * (inner.width - 8)
            let py1 = inner.maxY - 6 - CGFloat((v1 - lo) / (hi - lo)) * (inner.height - 12)
            let py2 = inner.maxY - 6 - CGFloat((v2 - lo) / (hi - lo)) * (inner.height - 12)
            if i == 0 {
                p1.move(to: CGPoint(x: px, y: py1)); p2.move(to: CGPoint(x: px, y: py2))
            } else {
                p1.addLine(to: CGPoint(x: px, y: py1)); p2.addLine(to: CGPoint(x: px, y: py2))
            }
        }
        ctx.stroke(p1, with: .color(Theme.ink), lineWidth: 1.5)
        ctx.stroke(p2, with: .color(Theme.ink),
                   style: StrokeStyle(lineWidth: 1.3, lineCap: .round,
                                       lineJoin: .round, dash: [5, 3]))

        // Teq 기준선
        let teqFrac = (hi - lo) > 1e-6 ? (Teq - lo) / (hi - lo) : 0.5
        let teqPY = inner.maxY - 6 - CGFloat(teqFrac) * (inner.height - 12)
        var teqLine = Path()
        teqLine.move(to: CGPoint(x: inner.minX, y: teqPY))
        teqLine.addLine(to: CGPoint(x: inner.maxX, y: teqPY))
        ctx.stroke(teqLine, with: .color(Theme.mist.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 0.8, dash: [2, 4]))
        ctx.draw(Text(String(format: "Teq=%.1f°", Teq))
                    .font(.system(size: 8)).foregroundStyle(Theme.mist),
                 at: CGPoint(x: inner.minX + 4, y: teqPY - 7), anchor: .leading)
        ctx.draw(Text("실선 T₁   점선 T₂")
                    .font(.system(size: 9)).foregroundStyle(Theme.mist),
                 at: CGPoint(x: inner.maxX - 4, y: inner.minY + 8), anchor: .trailing)
    }

    private func tempColor(_ T: Double) -> Color {
        // 차가움 = 옅은 회색, 뜨거움 = 짙은 회색
        let t = max(0, min(1, T / 100))
        return Color.adaptive(light: Color(white: 0.85 - 0.65 * t),
                              dark:  Color(white: 0.30 + 0.55 * t))
    }
}

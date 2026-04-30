import SwiftUI

struct GraphViewport: View {
    let preset: Preset

    var body: some View {
        ZStack {
            Theme.deep
            switch preset.id {
            case "motiongraph": MotionGraphView()
            case "heat":        HeatTransferView()
            default:            Text("준비 중").foregroundStyle(Theme.mist)
            }
        }
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
    @State private var startTime = Date()

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = max(0, tl.date.timeIntervalSince(startTime))
                    draw(ctx: ctx, size: size, t: t)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("v₁ (등속)", value: $v1, range: 0...10, unit: "m/s")
                slider("v₀ (등가속 초기)", value: $v0, range: 0...10, unit: "m/s")
                slider("a (가속도)", value: $a, range: -3...4, unit: "m/s²")
                Button("처음부터") { startTime = Date() }
                    .buttonStyle(.glass)
            }
        }
        .padding(8)
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            Slider(value: value, in: range).tint(Theme.glow)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let trackH = size.height * 0.30
        let plotH  = size.height - trackH
        let track = CGRect(x: 0, y: 0, width: size.width, height: trackH)
        let plot  = CGRect(x: 0, y: trackH, width: size.width, height: plotH)

        let x1 = v1 * t
        let x2 = v0 * t + 0.5 * a * t * t

        var line = Path()
        line.move(to: CGPoint(x: 16, y: track.midY))
        line.addLine(to: CGPoint(x: track.maxX - 16, y: track.midY))
        ctx.stroke(line, with: .color(Theme.ink.opacity(0.4)), lineWidth: 1)

        let xMax = max(20.0, max(x1, x2) * 1.2 + 5)
        let usable = track.width - 32
        let p1 = CGPoint(x: 16 + CGFloat(x1 / xMax) * usable, y: track.midY - 14)
        let p2 = CGPoint(x: 16 + CGFloat(x2 / xMax) * usable, y: track.midY + 14)
        ctx.fill(Path(ellipseIn: CGRect(x: p1.x - 8, y: p1.y - 8, width: 16, height: 16)),
                 with: .color(.cyan))
        ctx.fill(Path(ellipseIn: CGRect(x: p2.x - 8, y: p2.y - 8, width: 16, height: 16)),
                 with: .color(.orange))

        let tEnd = max(8.0, t * 1.05)
        let yMax2 = max(20.0, max(v1 * tEnd, v0 * tEnd + 0.5 * a * tEnd * tEnd) * 1.1 + 1)
        ctx.stroke(Path(roundedRect: plot.insetBy(dx: 12, dy: 12), cornerRadius: 8),
                   with: .color(Theme.ink.opacity(0.18)), lineWidth: 1)
        drawCurve(ctx, in: plot.insetBy(dx: 12, dy: 12), tEnd: tEnd, yMax: yMax2,
                  fn: { v1 * $0 }, color: .cyan)
        drawCurve(ctx, in: plot.insetBy(dx: 12, dy: 12), tEnd: tEnd, yMax: yMax2,
                  fn: { v0 * $0 + 0.5 * a * $0 * $0 }, color: .orange)
    }

    private func drawCurve(_ ctx: GraphicsContext, in r: CGRect, tEnd: Double,
                           yMax: Double, fn: (Double) -> Double, color: Color) {
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
        ctx.stroke(path, with: .color(color), lineWidth: 1.6)
    }
}

private struct HeatTransferView: View {
    @State private var T1: Double = 80
    @State private var T2: Double = 20
    @State private var capRatio: Double = 1
    @State private var hA: Double = 1
    @State private var startTime = Date()

    private var Teq: Double { (T1 + capRatio * T2) / (1 + capRatio) }
    private var tau: Double { capRatio / (hA * (1 + capRatio)) }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = max(0, tl.date.timeIntervalSince(startTime))
                    draw(ctx: ctx, size: size, t: t)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("T₁", value: $T1, range: 0...100, unit: "°C")
                slider("T₂", value: $T2, range: 0...100, unit: "°C")
                slider("열용량 비", value: $capRatio, range: 0.1...5, unit: "")
                slider("h·A", value: $hA, range: 0.1...5, unit: "")
                Button("처음부터") { startTime = Date() }
                    .buttonStyle(.glass)
            }
        }
        .padding(8)
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            Slider(value: value, in: range).tint(Theme.glow)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
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
        ctx.fill(Path(roundedRect: r1, cornerRadius: 8), with: .color(tempColor(cur1)))
        ctx.fill(Path(roundedRect: r2, cornerRadius: 8), with: .color(tempColor(cur2)))
        ctx.draw(Text(String(format: "T₁=%.1f°C", cur1)).font(.caption.weight(.bold))
                    .foregroundColor(.black),
                 at: CGPoint(x: r1.midX, y: r1.midY))
        ctx.draw(Text(String(format: "T₂=%.1f°C", cur2)).font(.caption.weight(.bold))
                    .foregroundColor(.black),
                 at: CGPoint(x: r2.midX, y: r2.midY))

        let inner = plotR.insetBy(dx: 12, dy: 12)
        ctx.stroke(Path(roundedRect: inner, cornerRadius: 8),
                   with: .color(Theme.ink.opacity(0.18)), lineWidth: 1)
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
        ctx.stroke(p1, with: .color(.red), lineWidth: 1.6)
        ctx.stroke(p2, with: .color(.cyan), lineWidth: 1.6)
    }

    private func tempColor(_ T: Double) -> Color {
        let t = max(0, min(1, T / 100))
        return Color(hue: (1 - t) * 0.6, saturation: 0.85, brightness: 1)
    }
}

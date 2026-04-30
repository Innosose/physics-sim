import SwiftUI

struct WaveViewport: View {
    let scene: Preset.WaveScene

    var body: some View {
        ZStack {
            Theme.deep
            switch scene {
            case .waveSum: WaveSumView()
            case .doppler: DopplerView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct WaveSumView: View {
    @State private var f1: Double = 1.0
    @State private var f2: Double = 1.1
    @State private var oppose: Bool = false
    @State private var startTime = Date()

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(startTime)
                    draw(ctx: ctx, size: size, t: t)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("f₁", value: $f1, range: 0.1...4, unit: "Hz")
                slider("f₂", value: $f2, range: 0.1...4, unit: "Hz")
                Toggle("두 번째 파 반대 진행 (정상파)", isOn: $oppose).font(.caption)
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
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let h = size.height / 3
        drawWave(ctx, in: CGRect(x: 0, y: 0, width: size.width, height: h),
                 amp: 1, omega: 2 * .pi * f1, t: t, sign: 1, color: .cyan)
        drawWave(ctx, in: CGRect(x: 0, y: h, width: size.width, height: h),
                 amp: 1, omega: 2 * .pi * f2, t: t, sign: oppose ? -1 : 1, color: .pink)
        drawSum(ctx, in: CGRect(x: 0, y: 2 * h, width: size.width, height: h), t: t)
    }

    private func drawWave(_ ctx: GraphicsContext, in r: CGRect,
                          amp: Double, omega: Double, t: Double,
                          sign: Double, color: Color) {
        var path = Path()
        let n = 400
        let xMax = 12.0
        let amplitudePx = r.height * 0.4
        for i in 0...n {
            let f = Double(i) / Double(n)
            let x = f * xMax
            let y = amp * sin(x - sign * omega * t)
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amplitudePx / 1.5
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(color), lineWidth: 1.6)
    }

    private func drawSum(_ ctx: GraphicsContext, in r: CGRect, t: Double) {
        var path = Path()
        let n = 600
        let xMax = 12.0
        let s2: Double = oppose ? -1 : 1
        let ω1 = 2 * .pi * f1
        let ω2 = 2 * .pi * f2
        let amp = r.height * 0.45
        for i in 0...n {
            let f = Double(i) / Double(n)
            let x = f * xMax
            let y = sin(x - ω1 * t) + sin(x - s2 * ω2 * t)
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amp / 3
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(.yellow), lineWidth: 1.8)
    }
}

private struct DopplerView: View {
    @State private var sourceSpeed: Double = 60
    @State private var soundSpeed: Double = 340
    @State private var freq: Double = 1.5
    @State private var startTime = Date()

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(startTime)
                    draw(ctx: ctx, size: size, t: t)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("v_s", value: $sourceSpeed, range: 0...400, unit: "m/s")
                slider("c", value: $soundSpeed, range: 100...400, unit: "m/s")
                slider("f", value: $freq, range: 0.5...4, unit: "Hz")
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
        let span: Double = 800
        let scale = size.width / CGFloat(span)
        let cy = size.height / 2

        let cur = -span / 4 + sourceSpeed * t
        let period = 1 / freq
        let tMax = span / soundSpeed * 1.4
        let kMin = max(0, Int(((t - tMax) / period).rounded(.up)))
        let kMax = Int((t / period).rounded(.down))
        if kMax >= kMin {
            for k in kMin...kMax {
                let te = Double(k) * period
                let xs = -span / 4 + sourceSpeed * te
                let radius = soundSpeed * (t - te)
                if radius < 0 { continue }
                let center = CGPoint(x: CGFloat(xs + span / 2) * scale, y: cy)
                let rPx = CGFloat(radius) * scale
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: center.x - rPx, y: center.y - rPx,
                                           width: rPx * 2, height: rPx * 2)),
                    with: .color(.cyan.opacity(0.8)), lineWidth: 1)
            }
        }
        let sx = CGFloat(cur + span / 2) * scale
        let sr: CGFloat = 6
        ctx.fill(Path(ellipseIn: CGRect(x: sx - sr, y: cy - sr,
                                         width: sr * 2, height: sr * 2)),
                 with: .color(.yellow))
    }
}

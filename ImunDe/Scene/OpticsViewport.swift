import SwiftUI

struct OpticsViewport: View {
    let scene: Preset.OpticsScene

    var body: some View {
        ZStack {
            Theme.deep
            switch scene {
            case .reflection:  ReflectionView()
            case .lens:        LensView()
            case .doubleSlit:  DoubleSlitView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct ReflectionView: View {
    @State private var incidenceDeg: Double = 30
    @State private var n1: Double = 1.0
    @State private var n2: Double = 1.5

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            controls
        }
        .padding(8)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider("입사각 θ₁", value: $incidenceDeg, range: 0...89, unit: "°")
            slider("위쪽 n₁", value: $n1, range: 1...2.5, unit: "")
            slider("아래쪽 n₂", value: $n2, range: 1...2.5, unit: "")
        }
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            PaperSlider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let mid = size.height / 2

        // Boundary
        Sketchy.line(from: CGPoint(x: 0, y: mid),
                     to: CGPoint(x: size.width, y: mid),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.6, passes: 2, jitter: 1.0)

        // Normal — keep dashed-look via small segments
        let nx0 = size.width / 2
        let ny0: CGFloat = 30
        let ny1 = size.height - 30
        let segs = 14
        for i in stride(from: 0, to: segs, by: 2) {
            let t0 = CGFloat(i) / CGFloat(segs)
            let t1 = CGFloat(i + 1) / CGFloat(segs)
            Sketchy.line(from: CGPoint(x: nx0, y: ny0 + (ny1 - ny0) * t0),
                          to: CGPoint(x: nx0, y: ny0 + (ny1 - ny0) * t1),
                          ctx: ctx, color: Theme.ink.opacity(0.6),
                          lineWidth: 1.0, passes: 1, jitter: 0.25)
        }

        let θ1 = incidenceDeg * .pi / 180
        let cx = size.width / 2
        let len: CGFloat = min(min(cx, size.width - cx) - 16,
                               min(mid, size.height - mid) - 16)

        Sketchy.line(from: CGPoint(x: cx - CGFloat(sin(θ1)) * len,
                                    y: mid - CGFloat(cos(θ1)) * len),
                     to: CGPoint(x: cx, y: mid),
                     ctx: ctx, color: .yellow,
                     lineWidth: 1.8, passes: 2, jitter: 0.6)

        Sketchy.line(from: CGPoint(x: cx, y: mid),
                     to: CGPoint(x: cx + CGFloat(sin(θ1)) * len,
                                  y: mid - CGFloat(cos(θ1)) * len),
                     ctx: ctx, color: .cyan,
                     lineWidth: 1.8, passes: 2, jitter: 0.6)

        let s2 = n1 * sin(θ1) / n2
        if abs(s2) <= 1 {
            let θ2 = asin(s2)
            Sketchy.line(from: CGPoint(x: cx, y: mid),
                         to: CGPoint(x: cx + CGFloat(sin(θ2)) * len,
                                      y: mid + CGFloat(cos(θ2)) * len),
                         ctx: ctx, color: .orange,
                         lineWidth: 1.8, passes: 2, jitter: 0.6)
        }
    }
}

private struct LensView: View {
    @State private var f: Double = 2.0
    @State private var p: Double = 5.0
    @State private var diverging: Bool = false

    private var fSigned: Double { diverging ? -abs(f) : abs(f) }
    private var q: Double {
        let denom = p - fSigned
        return abs(denom) < 1e-9 ? .infinity * (denom >= 0 ? 1 : -1) : p * fSigned / denom
    }

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            VStack(alignment: .leading, spacing: 8) {
                Toggle("발산 렌즈 (f<0)", isOn: $diverging)
                    .font(.caption)
                slider("|f|", value: $f, range: 0.5...6, unit: "m")
                slider("p", value: $p, range: 0.3...10, unit: "m")
            }
        }
        .padding(8)
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            PaperSlider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let qVal = q.isFinite ? q : 0
        let maxExtent = max(p, abs(qVal), abs(fSigned), 4) * 1.15
        let scale: CGFloat = (min(size.width, size.height * 1.6) / 2 - 20)
                             / CGFloat(maxExtent)

        Sketchy.line(from: CGPoint(x: 10, y: cy),
                     to: CGPoint(x: size.width - 10, y: cy),
                     ctx: ctx, color: Theme.ink.opacity(0.6),
                     lineWidth: 1.2, passes: 1, jitter: 0.5)

        Sketchy.line(from: CGPoint(x: cx, y: cy - 80),
                     to: CGPoint(x: cx, y: cy + 80),
                     ctx: ctx, color: .cyan,
                     lineWidth: 1.8, passes: 2, jitter: 0.4)

        for s in [-1.0, 1.0] {
            let fx = cx + CGFloat(s * abs(fSigned)) * scale
            Sketchy.fillCircle(center: CGPoint(x: fx, y: cy), radius: 3.5,
                               ctx: ctx, fill: .orange, stroke: Theme.ink,
                               strokeWidth: 1.0)
        }

        let objX = cx - CGFloat(p) * scale
        Sketchy.line(from: CGPoint(x: objX, y: cy),
                     to: CGPoint(x: objX, y: cy - 40),
                     ctx: ctx, color: .yellow,
                     lineWidth: 1.8, passes: 2, jitter: 0.5)

        if q.isFinite {
            let imgX = cx + CGFloat(q) * scale
            let m = -q / p
            let h = -CGFloat(m) * 40
            if q > 0 {
                Sketchy.line(from: CGPoint(x: imgX, y: cy),
                             to: CGPoint(x: imgX, y: cy - h),
                             ctx: ctx, color: .green,
                             lineWidth: 1.8, passes: 2, jitter: 0.5)
            } else {
                // virtual image — dashed via segments
                let total = abs(h)
                let segs = max(6, Int(total / 6))
                for i in stride(from: 0, to: segs, by: 2) {
                    let t0 = CGFloat(i) / CGFloat(segs)
                    let t1 = CGFloat(i + 1) / CGFloat(segs)
                    Sketchy.line(from: CGPoint(x: imgX, y: cy - h * t0),
                                  to: CGPoint(x: imgX, y: cy - h * t1),
                                  ctx: ctx, color: .gray,
                                  lineWidth: 1.4, passes: 1, jitter: 0.3)
                }
            }
        }
    }
}

private struct DoubleSlitView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case both    = "이중 슬릿"
        case single  = "단일 슬릿"
        case compare = "비교"
        var id: String { rawValue }
    }

    @State private var lambdaNm: Double = 550
    @State private var dUm: Double      = 50
    @State private var aUm: Double      = 8
    @State private var D: Double        = 1.5
    @State private var mode: Mode       = .both

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            VStack(alignment: .leading, spacing: 8) {
                PaperPicker(selection: $mode,
                             options: Mode.allCases) { $0.rawValue }
                slider("λ", value: $lambdaNm, range: 380...780, unit: "nm")
                slider("d", value: $dUm, range: 10...200, unit: "μm")
                    .disabled(mode == .single)
                slider("a", value: $aUm, range: 2...30, unit: "μm")
                slider("D", value: $D, range: 0.3...3, unit: "m")
            }
        }
        .padding(8)
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

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let r = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let stripH: CGFloat = 40
        let stripRect = CGRect(x: 0, y: r.midY - stripH/2,
                               width: r.width, height: stripH)
        let curveRect = CGRect(x: 0, y: stripRect.maxY + 4,
                               width: r.width, height: r.height - stripRect.maxY - 4)

        let λ = lambdaNm * 1e-9
        let d = dUm * 1e-6
        let a = aUm * 1e-6
        let yMax = λ * D / max(d, 1e-9) * 5
        let n = 600

        func intensities(_ y: Double) -> (combined: Double, singleOnly: Double) {
            let θ = atan2(y, D)
            let kλ = .pi * d / λ * sin(θ)
            let aλ = .pi * a / λ * sin(θ)
            let single = abs(aλ) < 1e-9 ? 1.0 : pow(sin(aλ) / aλ, 2)
            let interf = pow(cos(kλ), 2)
            return (single * interf, single)
        }

        var combined: [(Double, Double)] = []
        var singleOnly: [(Double, Double)] = []
        var combMax = 0.001, singMax = 0.001
        for k in 0...n {
            let f = Double(k) / Double(n)
            let y = -yMax + 2 * yMax * f
            let (c, s) = intensities(y)
            combined.append((y, c)); combMax = max(combMax, c)
            singleOnly.append((y, s)); singMax = max(singMax, s)
        }

        let displaySamples: [(Double, Double)] = mode == .single ? singleOnly : combined
        let displayMax: Double = mode == .single ? singMax : combMax
        let stripColor = wavelengthColor(lambdaNm)

        for (y, I) in displaySamples {
            let f = CGFloat((y + yMax) / (2 * yMax))
            let x = stripRect.minX + f * stripRect.width
            let bar = CGRect(x: x, y: stripRect.minY,
                             width: stripRect.width / CGFloat(n) + 1, height: stripRect.height)
            ctx.fill(Path(bar), with: .color(stripColor.opacity(I / displayMax)))
        }

        let curveInner = curveRect.insetBy(dx: 0, dy: 3)

        func curvePath(samples: [(Double, Double)], maxI: Double) -> Path {
            var p = Path()
            for (idx, (y, I)) in samples.enumerated() {
                let f = CGFloat((y + yMax) / (2 * yMax))
                let x = curveInner.minX + f * curveInner.width
                let py = curveInner.maxY - CGFloat(I / maxI) * curveInner.height
                if idx == 0 { p.move(to: CGPoint(x: x, y: py)) }
                else        { p.addLine(to: CGPoint(x: x, y: py)) }
            }
            return p
        }

        switch mode {
        case .both:
            ctx.stroke(curvePath(samples: combined, maxI: combMax),
                       with: .color(.yellow), lineWidth: 1.6)
        case .single:
            ctx.stroke(curvePath(samples: singleOnly, maxI: singMax),
                       with: .color(.orange), lineWidth: 1.6)
        case .compare:
            ctx.stroke(curvePath(samples: singleOnly, maxI: combMax),
                       with: .color(.orange.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
            ctx.stroke(curvePath(samples: combined, maxI: combMax),
                       with: .color(.yellow), lineWidth: 1.6)
            ctx.draw(Text("주황: 단일슬릿 회절 포락선   노랑: 이중슬릿 간섭")
                        .font(.caption2).foregroundStyle(Theme.mist.opacity(0.85)),
                     at: CGPoint(x: curveInner.midX, y: curveInner.minY + 10))
        }
    }

    private func wavelengthColor(_ wl: Double) -> Color {
        var rr = 0.0, gg = 0.0, bb = 0.0
        switch wl {
        case 380..<440: rr = -(wl - 440) / 60; bb = 1
        case 440..<490: gg = (wl - 440) / 50; bb = 1
        case 490..<510: gg = 1; bb = -(wl - 510) / 20
        case 510..<580: rr = (wl - 510) / 70; gg = 1
        case 580..<645: rr = 1; gg = -(wl - 645) / 65
        case 645...780: rr = 1
        default: rr = 0.5; gg = 0.5; bb = 0.5
        }
        return Color(red: max(0, min(1, rr)),
                     green: max(0, min(1, gg)),
                     blue: max(0, min(1, bb)))
    }
}

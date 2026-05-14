import SwiftUI

struct OpticsViewport: View {
    let scene: Preset.OpticsScene
    @Environment(\.colorScheme) private var colorScheme

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
    @Environment(\.colorScheme) private var colorScheme

    private var derived: (theta2: Double?, thetaC: Double?) {
        let θ1 = incidenceDeg * .pi / 180
        let s2 = n1 * sin(θ1) / n2
        let θ2 = abs(s2) <= 1 ? asin(s2) * 180 / .pi : nil
        let θc = n1 > n2 ? asin(n2 / n1) * 180 / .pi : nil
        return (θ2, θc)
    }

    var body: some View {
        _ = colorScheme  // body-level read for dependency tracking
        return VStack(spacing: 8) {
            Canvas { ctx, size in
                draw(ctx: ctx, size: size)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("광학 시각화"))
                .accessibilityHint(Text("아래 슬라이더로 광학 파라미터를 조절합니다"))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    derivedRow
                    controls
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 220)
        }
        .padding(8)
    }

    private var derivedRow: some View {
        let d = derived
        let parts: [String] = [
            d.theta2.map { String(format: "굴절각 θ₂ = %.2f°", $0) } ?? "굴절각 = 전반사",
            d.thetaC.map { String(format: "임계각 θ_c = %.2f°", $0) } ?? "임계각 없음",
        ]
        return HStack(spacing: 14) {
            ForEach(parts, id: \.self) { p in
                Text(p)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
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
        HStack(spacing: Spacing.s) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 96, alignment: .leading)
            PaperSlider(value: value, in: range)
            EditableValue(value: value, range: range,
                           format: "%.2f\(unit)", width: 70)
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

        // 입사광 (실선, 굵게)
        Sketchy.line(from: CGPoint(x: cx - CGFloat(sin(θ1)) * len,
                                    y: mid - CGFloat(cos(θ1)) * len),
                     to: CGPoint(x: cx, y: mid),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.9, passes: 2, jitter: 0.6)

        // 반사광 (점선)
        Sketchy.line(from: CGPoint(x: cx, y: mid),
                     to: CGPoint(x: cx + CGFloat(sin(θ1)) * len,
                                  y: mid - CGFloat(cos(θ1)) * len),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.5, passes: 2, jitter: 0.4,
                     dash: [5, 3])

        let s2 = n1 * sin(θ1) / n2
        if abs(s2) <= 1 {
            let θ2 = asin(s2)
            // 굴절광 (얇은 실선)
            Sketchy.line(from: CGPoint(x: cx, y: mid),
                         to: CGPoint(x: cx + CGFloat(sin(θ2)) * len,
                                      y: mid + CGFloat(cos(θ2)) * len),
                         ctx: ctx, color: Theme.ink,
                         lineWidth: 1.3, passes: 2, jitter: 0.5)
        }

        // Legend
        ctx.draw(
            Text("실 입사 · ㅡㅡ 반사 · 얇 굴절")
                .font(.system(size: 9)).foregroundStyle(Theme.mist),
            at: CGPoint(x: size.width / 2, y: size.height - 8))
    }
}

private struct LensView: View {
    @State private var f: Double = 2.0
    @State private var p: Double = 5.0
    @State private var diverging: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var fSigned: Double { diverging ? -abs(f) : abs(f) }
    private var q: Double {
        let denom = p - fSigned
        return abs(denom) < 1e-9 ? .infinity * (denom >= 0 ? 1 : -1) : p * fSigned / denom
    }
    private var magnification: Double { q.isFinite ? -q / p : .nan }
    private var imageKind: String {
        guard q.isFinite else { return "∞ (상 없음)" }
        let real = q > 0, inverted = magnification < 0, enlarged = abs(magnification) > 1
        return (real ? "실상" : "허상") + "·" +
               (inverted ? "도립" : "정립") + "·" +
               (enlarged ? "확대" : "축소")
    }

    var body: some View {
        let _ = colorScheme
        VStack(spacing: 8) {
            Canvas { ctx, size in
                draw(ctx: ctx, size: size)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("광학 시각화"))
                .accessibilityHint(Text("아래 슬라이더로 광학 파라미터를 조절합니다"))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    derivedRow
                    ChipToggle(title: "발산 렌즈 (f<0)",
                                systemImage: "arrow.left.arrow.right",
                                isOn: diverging,
                                alignment: .leading) {
                        diverging.toggle()
                    }
                    slider("초점거리 |f|", value: $f, range: 0.5...6, unit: "m")
                    slider("물체거리 p", value: $p, range: 0.3...10, unit: "m")
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 220)
        }
        .padding(8)
    }

    private var derivedRow: some View {
        HStack(spacing: 14) {
            Text(q.isFinite ? String(format: "상거리 q = %+.2f m", q) : "상거리 q = ∞")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(magnification.isFinite
                 ? String(format: "배율 m = %+.2f", magnification)
                 : "배율 m = ∞")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(imageKind)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack(spacing: Spacing.s) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 96, alignment: .leading)
            PaperSlider(value: value, in: range)
            EditableValue(value: value, range: range,
                           format: "%.2f\(unit)", width: 70)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let qVal = q.isFinite ? q : 0
        let maxExtent = max(p, abs(qVal), abs(fSigned), 4) * 1.15
        let scale: CGFloat = (min(size.width, size.height * 1.6) / 2 - 20)
                             / CGFloat(maxExtent)

        // Optical axis
        Sketchy.line(from: CGPoint(x: 10, y: cy),
                     to: CGPoint(x: size.width - 10, y: cy),
                     ctx: ctx, color: Theme.ink.opacity(0.55),
                     lineWidth: 1.1, passes: 1, jitter: 0.4)

        // Lens
        Sketchy.line(from: CGPoint(x: cx, y: cy - 80),
                     to: CGPoint(x: cx, y: cy + 80),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.8, passes: 2, jitter: 0.4)

        // Focal points (filled ink circles)
        for s in [-1.0, 1.0] {
            let fx = cx + CGFloat(s * abs(fSigned)) * scale
            Sketchy.fillCircle(center: CGPoint(x: fx, y: cy), radius: 3.5,
                               ctx: ctx, fill: Theme.ink, stroke: Theme.ink,
                               strokeWidth: 1.0)
        }

        // Object (solid)
        let objX = cx - CGFloat(p) * scale
        Sketchy.line(from: CGPoint(x: objX, y: cy),
                     to: CGPoint(x: objX, y: cy - 40),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.8, passes: 2, jitter: 0.5)

        if q.isFinite {
            let imgX = cx + CGFloat(q) * scale
            let m = -q / p
            let h = -CGFloat(m) * 40
            // 실상=solid, 허상=dashed (둘 다 ink)
            Sketchy.line(from: CGPoint(x: imgX, y: cy),
                         to: CGPoint(x: imgX, y: cy - h),
                         ctx: ctx, color: Theme.ink,
                         lineWidth: 1.6, passes: 2, jitter: 0.5,
                         dash: q > 0 ? nil : [4, 3])
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
    @Environment(\.colorScheme) private var colorScheme

    private var derived: (deltaY: Double, yA: Double) {
        let λ = lambdaNm * 1e-9
        let d = dUm * 1e-6
        let a = aUm * 1e-6
        let dy = λ * D / max(d, 1e-12)
        let ya = λ * D / max(a, 1e-12)
        return (dy, ya)
    }

    var body: some View {
        let _ = colorScheme
        VStack(spacing: 8) {
            Canvas { ctx, size in
                draw(ctx: ctx, size: size)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("광학 시각화"))
                .accessibilityHint(Text("아래 슬라이더로 광학 파라미터를 조절합니다"))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Text(String(format: "무늬 간격 Δy = %.2f mm", derived.deltaY * 1000))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(String(format: "회절 영점 y_a = %.2f mm", derived.yA * 1000))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    PaperPicker(selection: $mode,
                                 options: Mode.allCases) { $0.rawValue }
                    slider("파장 λ", value: $lambdaNm, range: 380...780, unit: "nm")
                    slider("슬릿 간격 d", value: $dUm, range: 10...200, unit: "μm")
                        .disabled(mode == .single)
                    slider("슬릿 폭 a", value: $aUm, range: 2...30, unit: "μm")
                    slider("스크린 거리 D", value: $D, range: 0.3...3, unit: "m")
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 240)
        }
        .padding(8)
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack(spacing: Spacing.s) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 96, alignment: .leading)
            PaperSlider(value: value, in: range)
            EditableValue(value: value, range: range,
                           format: "%.2f\(unit)", width: 80)
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

        for (y, I) in displaySamples {
            let f = CGFloat((y + yMax) / (2 * yMax))
            let x = stripRect.minX + f * stripRect.width
            let bar = CGRect(x: x, y: stripRect.minY,
                             width: stripRect.width / CGFloat(n) + 1, height: stripRect.height)
            ctx.fill(Path(bar), with: .color(Theme.ink.opacity(I / displayMax)))
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
                       with: .color(Theme.ink), lineWidth: 1.5)
        case .single:
            ctx.stroke(curvePath(samples: singleOnly, maxI: singMax),
                       with: .color(Theme.ink), lineWidth: 1.5)
        case .compare:
            ctx.stroke(curvePath(samples: singleOnly, maxI: combMax),
                       with: .color(Theme.ink.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 1.1, dash: [4, 3]))
            ctx.stroke(curvePath(samples: combined, maxI: combMax),
                       with: .color(Theme.ink), lineWidth: 1.5)
            ctx.draw(Text("ㅡㅡ 단일슬릿 포락선   실선 이중슬릿 간섭")
                        .font(.caption2).foregroundStyle(Theme.mist),
                     at: CGPoint(x: curveInner.midX, y: curveInner.minY + 10))
        }
    }
}

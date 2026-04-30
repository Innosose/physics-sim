import SwiftUI

/// 광학 — 광선 추적 (반사·굴절·렌즈·이중슬릿). 통합 World 엔진을 쓰지 않고
/// 각 케이스별 기하 광학식을 SwiftUI Canvas 로 직접 그림. 향후 RealityKit
/// 광선 가시화로 확장 가능.
struct OpticsViewport: View {
    let scene: Preset.OpticsScene

    var body: some View {
        ZStack {
            Color.black
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

// MARK: - 반사·굴절

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
            Slider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let mid = size.height / 2
        // 경계.
        var boundary = Path()
        boundary.move(to: CGPoint(x: 0, y: mid))
        boundary.addLine(to: CGPoint(x: size.width, y: mid))
        ctx.stroke(boundary, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
        // 법선.
        var normal = Path()
        normal.move(to: CGPoint(x: size.width / 2, y: 30))
        normal.addLine(to: CGPoint(x: size.width / 2, y: size.height - 30))
        ctx.stroke(normal, with: .color(.white.opacity(0.4)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        let θ1 = incidenceDeg * .pi / 180
        let len: CGFloat = 220
        let cx = size.width / 2
        // 입사.
        var inc = Path()
        inc.move(to: CGPoint(x: cx - CGFloat(sin(θ1)) * len, y: mid - CGFloat(cos(θ1)) * len))
        inc.addLine(to: CGPoint(x: cx, y: mid))
        ctx.stroke(inc, with: .color(.yellow), lineWidth: 2)
        // 반사.
        var refl = Path()
        refl.move(to: CGPoint(x: cx, y: mid))
        refl.addLine(to: CGPoint(x: cx + CGFloat(sin(θ1)) * len, y: mid - CGFloat(cos(θ1)) * len))
        ctx.stroke(refl, with: .color(.cyan), lineWidth: 2)
        // 굴절 (스넬).
        let s2 = n1 * sin(θ1) / n2
        if abs(s2) <= 1 {
            let θ2 = asin(s2)
            var refr = Path()
            refr.move(to: CGPoint(x: cx, y: mid))
            refr.addLine(to: CGPoint(x: cx + CGFloat(sin(θ2)) * len,
                                     y: mid + CGFloat(cos(θ2)) * len))
            ctx.stroke(refr, with: .color(.orange), lineWidth: 2)
        }
    }
}

// MARK: - 얇은 렌즈

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
            Slider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let scale: CGFloat = min(size.width, size.height * 1.5) / 16
        // 광축.
        var axis = Path()
        axis.move(to: CGPoint(x: 10, y: cy))
        axis.addLine(to: CGPoint(x: size.width - 10, y: cy))
        ctx.stroke(axis, with: .color(.white.opacity(0.4)), lineWidth: 1)
        // 렌즈.
        var lens = Path()
        lens.move(to: CGPoint(x: cx, y: cy - 80))
        lens.addLine(to: CGPoint(x: cx, y: cy + 80))
        ctx.stroke(lens, with: .color(.cyan), lineWidth: 2)
        // 초점.
        for s in [-1.0, 1.0] {
            let fx = cx + CGFloat(s * abs(fSigned)) * scale
            ctx.fill(Path(ellipseIn: CGRect(x: fx - 3, y: cy - 3, width: 6, height: 6)),
                     with: .color(.orange))
        }
        // 물체 (왼쪽).
        let objX = cx - CGFloat(p) * scale
        var obj = Path()
        obj.move(to: CGPoint(x: objX, y: cy))
        obj.addLine(to: CGPoint(x: objX, y: cy - 40))
        ctx.stroke(obj, with: .color(.yellow), lineWidth: 2)
        // 상.
        if q.isFinite {
            let imgX = cx + CGFloat(q) * scale
            let m = -q / p
            let h = -CGFloat(m) * 40
            var img = Path()
            img.move(to: CGPoint(x: imgX, y: cy))
            img.addLine(to: CGPoint(x: imgX, y: cy - h))
            ctx.stroke(img, with: .color(q > 0 ? .green : .gray),
                       style: StrokeStyle(lineWidth: 2,
                                          dash: q > 0 ? [] : [4, 3]))
        }
    }
}

// MARK: - 이중 슬릿

private struct DoubleSlitView: View {
    @State private var lambdaNm: Double = 550
    @State private var dUm: Double      = 50
    @State private var aUm: Double      = 8
    @State private var D: Double        = 1.5

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            VStack(alignment: .leading, spacing: 8) {
                slider("λ", value: $lambdaNm, range: 380...780, unit: "nm")
                slider("d", value: $dUm, range: 10...200, unit: "μm")
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
            Slider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
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
        let yMax = λ * D / d * 5
        let n = 600
        var samples: [(Double, Double)] = []
        var Imax = 0.001
        for k in 0...n {
            let f = Double(k) / Double(n)
            let y = -yMax + 2 * yMax * f
            let θ = atan2(y, D)
            let kλ = .pi * d / λ * sin(θ)
            let aλ = .pi * a / λ * sin(θ)
            let single = abs(aλ) < 1e-9 ? 1.0 : pow(sin(aλ) / aλ, 2)
            let interf = pow(cos(kλ), 2)
            let I = single * interf
            samples.append((y, I)); Imax = max(Imax, I)
        }
        let color = wavelengthColor(lambdaNm)
        // 강도 띠.
        for (y, I) in samples {
            let f = CGFloat((y + yMax) / (2 * yMax))
            let x = stripRect.minX + f * stripRect.width
            let bar = CGRect(x: x, y: stripRect.minY,
                             width: stripRect.width / CGFloat(n) + 1, height: stripRect.height)
            ctx.fill(Path(bar), with: .color(color.opacity(I / Imax)))
        }
        // 곡선.
        var path = Path()
        for (idx, (y, I)) in samples.enumerated() {
            let f = CGFloat((y + yMax) / (2 * yMax))
            let x = curveRect.minX + f * curveRect.width
            let py = curveRect.maxY - CGFloat(I / Imax) * (curveRect.height - 6)
            if idx == 0 { path.move(to: CGPoint(x: x, y: py)) }
            else        { path.addLine(to: CGPoint(x: x, y: py)) }
        }
        ctx.stroke(path, with: .color(.yellow), lineWidth: 1.6)
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

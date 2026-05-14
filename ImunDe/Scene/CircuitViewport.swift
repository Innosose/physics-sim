import SwiftUI

struct CircuitViewport: View {
    let scene: Preset.CircuitScene

    var body: some View {
        ZStack {
            Theme.deep
            switch scene {
            case .circuit:  SimpleCircuitView()
            case .rlc:      RLCView()
            case .faraday:  FaradayView()
            case .solenoid: SolenoidView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct SimpleCircuitView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case series = "직렬", parallel = "병렬"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .series
    @State private var emf: Double = 12
    @State private var R1: Double = 4
    @State private var R2: Double = 6

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            VStack(alignment: .leading, spacing: 8) {
                PaperPicker(selection: $mode,
                             options: Mode.allCases) { $0.rawValue }
                slider("V", value: $emf, range: 1...30, unit: "V")
                slider("R₁", value: $R1, range: 0.5...30, unit: "Ω")
                slider("R₂", value: $R2, range: 0.5...30, unit: "Ω")
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
        let r = CGRect(origin: .zero, size: size).insetBy(dx: 30, dy: 30)
        let lt = CGPoint(x: r.minX, y: r.minY)
        let rt = CGPoint(x: r.maxX, y: r.minY)
        let rb = CGPoint(x: r.maxX, y: r.maxY)
        let lb = CGPoint(x: r.minX, y: r.maxY)

        // Battery
        Sketchy.line(from: CGPoint(x: lt.x - 14, y: r.midY - 14),
                     to: CGPoint(x: lt.x + 14, y: r.midY - 14),
                     ctx: ctx, color: Theme.ink, lineWidth: 2.6, passes: 2, jitter: 0.4)
        Sketchy.line(from: CGPoint(x: lt.x - 8, y: r.midY + 14),
                     to: CGPoint(x: lt.x + 8, y: r.midY + 14),
                     ctx: ctx, color: Theme.ink, lineWidth: 1.8, passes: 2, jitter: 0.3)
        ctx.draw(Text(String(format: "%.1fV", emf))
                    .font(.caption2.weight(.semibold)).foregroundStyle(Theme.mist),
                 at: CGPoint(x: lt.x - 22, y: r.midY))

        // Wires
        let outerSegs: [(CGPoint, CGPoint)] = [
            (lt, rt), (rt, rb), (rb, lb),
            (lt, CGPoint(x: lt.x, y: r.midY - 30)),
            (CGPoint(x: lb.x, y: r.midY + 30), lb),
        ]
        for (a, b) in outerSegs {
            Sketchy.line(from: a, to: b, ctx: ctx, color: Theme.ink,
                         lineWidth: 1.7, passes: 1, jitter: 0.6)
        }

        switch mode {
        case .series:
            drawResistor(ctx, at: CGPoint(x: r.midX - 70, y: lt.y),
                         label: String(format: "R₁=%.2fΩ", R1))
            drawResistor(ctx, at: CGPoint(x: r.midX + 70, y: lt.y),
                         label: String(format: "R₂=%.2fΩ", R2))
        case .parallel:
            let branchY = lt.y + 60
            let leftJ = CGPoint(x: lt.x + 60, y: lt.y)
            let rightJ = CGPoint(x: rt.x - 60, y: lt.y)
            let branchSegs: [(CGPoint, CGPoint)] = [
                (leftJ, CGPoint(x: leftJ.x, y: branchY)),
                (CGPoint(x: leftJ.x, y: branchY), CGPoint(x: rightJ.x, y: branchY)),
                (CGPoint(x: rightJ.x, y: branchY), rightJ),
            ]
            for (a, b) in branchSegs {
                Sketchy.line(from: a, to: b, ctx: ctx, color: Theme.ink,
                             lineWidth: 1.7, passes: 1, jitter: 0.5)
            }
            drawResistor(ctx, at: CGPoint(x: r.midX, y: lt.y),
                         label: String(format: "R₁=%.2fΩ", R1))
            drawResistor(ctx, at: CGPoint(x: r.midX, y: branchY),
                         label: String(format: "R₂=%.2fΩ", R2))
        }

        let req: Double, I: Double
        switch mode {
        case .series:   req = R1 + R2; I = emf / req
        case .parallel: req = (R1 * R2) / (R1 + R2); I = emf / req
        }
        ctx.draw(Text(String(format: "R_eq=%.2fΩ   I=%.2fA   P=%.2fW",
                              req, I, emf * I))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: r.midX, y: r.maxY + 18))
    }

    private func drawResistor(_ ctx: GraphicsContext, at c: CGPoint, label: String) {
        let w: CGFloat = 60, h: CGFloat = 22
        let rect = CGRect(x: c.x - w/2, y: c.y - h/2, width: w, height: h)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 6),
                 with: .color(Theme.mist.opacity(0.45)))
        Sketchy.rect(rect, ctx: ctx, color: Theme.ink,
                     lineWidth: 1.1, passes: 1, jitter: 0.4)
        ctx.draw(Text(label).font(.caption2.weight(.semibold)).foregroundColor(Theme.ink),
                 at: CGPoint(x: c.x, y: c.y + h / 2 + 10))
    }
}

private struct RLCView: View {
    @State private var R: Double = 5
    @State private var L: Double = 0.5
    @State private var C: Double = 0.005
    @State private var V0: Double = 10
    @State private var omega: Double = 20

    private var omega0: Double { 1 / (L * C).squareRoot() }

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            VStack(alignment: .leading, spacing: 8) {
                slider("R", value: $R, range: 0.1...30, unit: "Ω")
                slider("L", value: $L, range: 0.05...3, unit: "H")
                slider("C", value: $C, range: 0.0005...0.05, unit: "F")
                slider("V₀", value: $V0, range: 0.1...30, unit: "V")
                slider("ω", value: $omega, range: 0.5...100, unit: "rad/s")
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
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {

        let r = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16)
        let omegaMax = max(omega * 1.4, omega0 * 2.5)
        var path = Path()
        let n = 200
        var maxInv = 0.001
        var samples: [Double] = []
        for k in 0...n {
            let w = omegaMax * Double(k) / Double(n)
            let XL = w * L, XC = w > 1e-6 ? 1 / (w * C) : 1e9
            let Z = (R * R + (XL - XC) * (XL - XC)).squareRoot()
            let inv = 1 / max(0.001, Z)
            samples.append(inv); maxInv = max(maxInv, inv)
        }
        for (k, inv) in samples.enumerated() {
            let f = CGFloat(k) / CGFloat(n)
            let px = r.minX + f * r.width
            let py = r.maxY - CGFloat(inv / maxInv) * (r.height - 20)
            if k == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(Theme.ink), lineWidth: 1.6)

        let xω = r.minX + CGFloat(min(omega, omegaMax) / omegaMax) * r.width
        var line = Path()
        line.move(to: CGPoint(x: xω, y: r.minY))
        line.addLine(to: CGPoint(x: xω, y: r.maxY))
        ctx.stroke(line, with: .color(Theme.ink.opacity(0.75)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        ctx.draw(Text("1/|Z(ω)| — 공명 위치 ω₀=\(String(format: "%.2f", omega0))")
                    .font(.caption).foregroundStyle(Theme.mist),
                 at: CGPoint(x: r.minX + 80, y: r.minY + 12))
    }
}

// MARK: - FaradayView

private struct FaradayView: View {
    @State private var nTurns: Double = 200
    @State private var speed: Double = 1.5
    @State private var elapsed: Double = 0
    @State private var lastTick: TimeInterval? = nil
    @State private var running: Bool = false
    @State private var emfHistory: [Double] = []

    private let amplitude: Double = 3.0
    private let coilRadius: Double = 0.9
    private let histLen = 300

    private func magnetPos(_ t: Double) -> Double { amplitude * sin(speed * t) }
    private func magnetVel(_ t: Double) -> Double { amplitude * speed * cos(speed * t) }
    private func emf(x: Double, v: Double) -> Double {
        let R2 = coilRadius * coilRadius
        let dPhiDx = -3 * R2 * coilRadius * x / pow(R2 + x * x, 2.5)
        return -nTurns * 0.006 * dPhiDx * v
    }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in draw(ctx: ctx, size: size, t: elapsed) }
                    .onChange(of: tl.date) { _, d in
                        advance(to: d.timeIntervalSinceReferenceDate)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                fSlider("N (코일 감은 수)", value: $nTurns, range: 20...500, unit: "회")
                fSlider("진동 속도 ω", value: $speed, range: 0.2...5, unit: "rad/s")
                faradayPlayReset
            }
        }
        .padding(8)
    }

    private var faradayPlayReset: some View {
        HStack(spacing: 8) {
            Button { running.toggle() } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketchProminent)
            Button { elapsed = 0; lastTick = nil; running = false; emfHistory = [] } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketch)
        }
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTick else { lastTick = now; return }
        guard running else { lastTick = now; return }
        let dt = min(now - last, 0.05)
        lastTick = now
        elapsed += dt
        let x = magnetPos(elapsed), v = magnetVel(elapsed)
        emfHistory.append(emf(x: x, v: v))
        if emfHistory.count > histLen { emfHistory.removeFirst() }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let sceneH = size.height * 0.52
        drawScene(ctx: ctx, in: CGRect(x: 0, y: 0, width: size.width, height: sceneH), t: t)
        drawScope(ctx: ctx, in: CGRect(x: 0, y: sceneH + 4,
                                        width: size.width, height: size.height - sceneH - 4))
    }

    private func drawScene(ctx: GraphicsContext, in r: CGRect, t: Double) {
        let cx = r.midX, cy = r.midY
        let worldW: Double = 10.0
        let scale = CGFloat(r.width) / CGFloat(worldW)
        let Rpx = CGFloat(coilRadius) * scale

        // Coil rings
        for i in 0..<10 {
            let f = CGFloat(i) / 9
            let xOff = (f - 0.5) * Rpx * 0.55
            let path = Path(ellipseIn: CGRect(x: cx + xOff - Rpx * 0.12, y: cy - Rpx,
                                              width: Rpx * 0.24, height: Rpx * 2))
            ctx.stroke(path, with: .color(Theme.ink.opacity(0.7)), lineWidth: 1.3)
        }

        // Bar magnet — N darker, S lighter, both with ink outline
        let mx = CGFloat(magnetPos(t)) * scale
        let mW = scale * 1.2, mH = scale * 0.45
        let northR = CGRect(x: cx + mx - mW, y: cy - mH / 2, width: mW, height: mH)
        let southR = CGRect(x: cx + mx,      y: cy - mH / 2, width: mW, height: mH)
        ctx.fill(Path(roundedRect: northR, cornerRadius: 5),
                 with: .color(Theme.ink.opacity(0.78)))
        ctx.fill(Path(roundedRect: southR, cornerRadius: 5),
                 with: .color(Theme.mist.opacity(0.55)))
        Sketchy.rect(northR, ctx: ctx, color: Theme.ink, lineWidth: 1.2, passes: 1, jitter: 0.4)
        Sketchy.rect(southR, ctx: ctx, color: Theme.ink, lineWidth: 1.2, passes: 1, jitter: 0.4)
        ctx.draw(Text("N").font(.caption.bold()).foregroundColor(Theme.surface),
                 at: CGPoint(x: northR.midX, y: northR.midY))
        ctx.draw(Text("S").font(.caption.bold()).foregroundColor(Theme.ink),
                 at: CGPoint(x: southR.midX, y: southR.midY))

        let curEMF = emfHistory.last ?? 0
        let dir = curEMF > 0.01 ? "↑" : curEMF < -0.01 ? "↓" : "·"
        ctx.draw(
            Text(String(format: "ε = %.2f V  %@", curEMF, dir))
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.ink),
            at: CGPoint(x: r.midX, y: r.maxY - 8))
    }

    private func drawScope(ctx: GraphicsContext, in r: CGRect) {
        let inner = r.insetBy(dx: 8, dy: 6)
        ctx.stroke(Path(roundedRect: inner, cornerRadius: 6),
                   with: .color(Theme.ink.opacity(0.18)), lineWidth: 1)
        var zero = Path()
        zero.move(to: CGPoint(x: inner.minX, y: inner.midY))
        zero.addLine(to: CGPoint(x: inner.maxX, y: inner.midY))
        ctx.stroke(zero, with: .color(Theme.ink.opacity(0.3)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        ctx.draw(Text("EMF").font(.caption2).foregroundStyle(Theme.mist),
                 at: CGPoint(x: inner.minX + 20, y: inner.minY + 8))
        guard emfHistory.count > 1 else { return }
        let peak = max(emfHistory.map { abs($0) }.max() ?? 1, 0.001)
        var path = Path()
        for (i, v) in emfHistory.enumerated() {
            let f = CGFloat(i) / CGFloat(histLen)
            let px = inner.minX + f * inner.width
            let py = inner.midY - CGFloat(v / peak) * (inner.height / 2 - 4)
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(Theme.ink), lineWidth: 1.6)
    }

    private func fSlider(_ title: String, value: Binding<Double>,
                         range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            PaperSlider(value: value, in: range)
            Text(String(format: "%.1f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit()).foregroundStyle(Theme.ink)
                .frame(width: 90, alignment: .trailing)
        }
    }
}

// MARK: - SolenoidView

private struct SolenoidView: View {
    @State private var nPerM: Double = 500
    @State private var current: Double = 2.0
    @State private var soleL: Double = 3.0
    @State private var soleR: Double = 0.9

    private var B0mT: Double { 4 * .pi * 1e-7 * nPerM * current * 1000 }

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                sSlider("n (권선수/m)", value: $nPerM, range: 100...2000, fmt: "%.0f")
                sSlider("I (전류)", value: $current, range: 0.1...10, fmt: "%.1f A")
                sSlider("길이 L", value: $soleL, range: 1...5, fmt: "%.1f")
                sSlider("반지름 R", value: $soleR, range: 0.3...1.5, fmt: "%.2f")
            }
        }
        .padding(8)
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let L = soleL, R = soleR
        let extZ = max(L * 1.6, 6.0)
        let extR = max(R * 3.5, 3.5)
        let scale = min(CGFloat(size.width) / CGFloat(2 * extZ),
                        CGFloat(size.height * 0.85) / CGFloat(2 * extR))
        let cx = size.width / 2, cy = size.height * 0.43

        func toScreen(_ z: Double, _ r: Double) -> CGPoint {
            CGPoint(x: cx + CGFloat(z) * scale, y: cy - CGFloat(r) * scale)
        }

        // Field lines (upper half, mirrored below)
        let nLines = 7
        for k in 0..<nLines {
            let r0 = R * Double(k) / Double(nLines) * 0.95
            traceAndDraw(ctx: ctx, startZ: -L/2 + 0.02, startR: r0,
                         L: L, R: R, size: size, toScreen: toScreen)
            if r0 > 0.01 {
                traceAndDraw(ctx: ctx, startZ: -L/2 + 0.02, startR: -r0,
                             L: L, R: R, size: size, toScreen: toScreen)
            }
        }

        // Solenoid body outline
        let tl = toScreen(-L/2, R), br = toScreen(L/2, -R)
        Sketchy.rect(CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.7, passes: 2, jitter: 1.0)

        // Turn marks
        let nTurns = max(4, Int(L * 4))
        for i in 0...nTurns {
            let z = -L/2 + L * Double(i) / Double(nTurns)
            Sketchy.line(from: toScreen(z, R), to: toScreen(z, -R),
                         ctx: ctx, color: Theme.ink.opacity(0.45),
                         lineWidth: 0.8, passes: 1, jitter: 0.3)
        }

        // Dashed axis — segmented sketchy
        let ax0 = toScreen(-extZ + 0.5, 0)
        let ax1 = toScreen(extZ - 0.5, 0)
        let segs = 22
        for i in stride(from: 0, to: segs, by: 2) {
            let t0 = CGFloat(i) / CGFloat(segs)
            let t1 = CGFloat(i + 1) / CGFloat(segs)
            Sketchy.line(from: CGPoint(x: ax0.x + (ax1.x - ax0.x) * t0, y: ax0.y),
                          to: CGPoint(x: ax0.x + (ax1.x - ax0.x) * t1, y: ax0.y),
                          ctx: ctx, color: Theme.ink.opacity(0.45),
                          lineWidth: 0.9, passes: 1, jitter: 0.2)
        }

        // Label
        ctx.draw(
            Text(String(format: "B₀ = μ₀nI = %.2f mT", B0mT))
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.ink),
            at: CGPoint(x: cx, y: size.height - 10))
    }

    private func traceAndDraw(ctx: GraphicsContext,
                               startZ: Double, startR: Double,
                               L: Double, R: Double,
                               size: CGSize,
                               toScreen: (Double, Double) -> CGPoint) {
        var z = startZ, r = startR
        var pts: [CGPoint] = []
        let step = 0.05
        let halfL = L / 2
        var hasExited = false

        for _ in 0..<2500 {
            let p = toScreen(z, r)
            if p.x < -30 || p.x > size.width + 30 ||
               p.y < -30 || p.y > size.height + 30 { break }
            pts.append(p)

            let inside = abs(z) <= halfL && abs(r) <= R
            if !inside { hasExited = true }
            if hasExited && inside { break }

            let bz: Double, br: Double
            if inside {
                bz = 1.0; br = 0.0
            } else {
                let m = R * R * L
                let rr2 = z * z + r * r
                guard rr2 > 0.01 else { break }
                let rr5 = pow(rr2, 2.5)
                bz = m * (2*z*z - r*r) / rr5
                br = m * 3*z*r / rr5
            }
            let mag = (bz*bz + br*br).squareRoot()
            guard mag > 1e-12 else { break }
            z += step * bz / mag
            r += step * br / mag
        }

        guard pts.count > 1 else { return }
        Sketchy.polyline(pts, ctx: ctx, color: Theme.glow,
                         lineWidth: 1.2, passes: 1, jitter: 0.25)

        // Arrowhead at midpoint
        let mid = pts.count / 2
        if mid > 0 && mid < pts.count {
            let a = pts[mid - 1], b = pts[mid]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = (dx*dx + dy*dy).squareRoot()
            guard len > 0.5 else { return }
            let nx = dx/len, ny = dy/len, s: CGFloat = 6
            let h1 = CGPoint(x: b.x - nx*s - ny*s*0.5, y: b.y - ny*s + nx*s*0.5)
            let h2 = CGPoint(x: b.x - nx*s + ny*s*0.5, y: b.y - ny*s - nx*s*0.5)
            Sketchy.line(from: b, to: h1, ctx: ctx, color: Theme.glow,
                         lineWidth: 1.2, passes: 1, jitter: 0.2)
            Sketchy.line(from: b, to: h2, ctx: ctx, color: Theme.glow,
                         lineWidth: 1.2, passes: 1, jitter: 0.2)
        }
    }

    private func sSlider(_ title: String, value: Binding<Double>,
                         range: ClosedRange<Double>, fmt: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            PaperSlider(value: value, in: range)
            Text(String(format: fmt, value.wrappedValue))
                .font(.caption.monospacedDigit()).foregroundStyle(Theme.ink)
                .frame(width: 90, alignment: .trailing)
        }
    }
}

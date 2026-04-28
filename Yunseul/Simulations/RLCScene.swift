import SwiftUI

/// 직렬 RLC 회로 — 사인파 EMF 구동.
///
///  L·q̈ + R·q̇ + q/C = V₀·cos(ω t)
///
/// 위 화면: 시간 영역 i(t), v_R(t), v_L(t), v_C(t).
/// 아래 화면: 임피던스 |Z(ω)| 와 위상 φ(ω) 곡선, 현재 ω 마커.
struct RLCScene: View {
    @State private var R: Double = 5.0       // Ω
    @State private var L: Double = 0.5       // H
    @State private var C: Double = 0.005     // F
    @State private var V0: Double = 10.0     // V
    @State private var omega: Double = 20.0  // rad/s
    @State private var running = true

    @State private var q: Double = 0
    @State private var i: Double = 0
    @State private var t: Double = 0
    @State private var lastTime: TimeInterval? = nil
    @State private var iTrace: [Double] = []
    private let traceLen = 360

    var body: some View {
        SimChrome(
                  blurb: "공명 진동수 ω₀ = 1/√(LC) 에서 |Z| 가 최소이고 전류가 최대. ω 가 ω₀ 보다 작으면 용량성, 크면 유도성 위상.",
                  canvas: { canvas },
                  controls: { controls })
            .onChange(of: L) { _, _ in restart() }
            .onChange(of: C) { _, _ in restart() }
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
            LabeledSlider(title: "저항 R", value: $R, range: 0.1...30, format: "%.2f", unit: "Ω")
            LabeledSlider(title: "인덕턴스 L", value: $L, range: 0.05...3, format: "%.2f", unit: "H")
            LabeledSlider(title: "전기용량 C", value: $C, range: 0.0005...0.05, format: "%.4f", unit: "F")
            LabeledSlider(title: "EMF 진폭 V₀", value: $V0, range: 0.1...30, format: "%.1f", unit: "V")
            LabeledSlider(title: "각진동수 ω", value: $omega, range: 0.5...100, format: "%.1f", unit: "rad/s")
            PlayResetBar(running: $running, onReset: restart)
            Divider()
            let omega0 = 1 / sqrt(L * C)
            let XL = omega * L
            let XC = 1 / (omega * C)
            let Z = sqrt(R * R + (XL - XC) * (XL - XC))
            let phi = atan2(XL - XC, R)
            Readout(label: "공명 ω₀ = 1/√(LC)", value: String(format: "%.2f rad/s", omega0))
            Readout(label: "X_L = ωL", value: String(format: "%.2f Ω", XL))
            Readout(label: "X_C = 1/(ωC)", value: String(format: "%.2f Ω", XC))
            Readout(label: "|Z|", value: String(format: "%.2f Ω", Z))
            Readout(label: "위상 φ", value: String(format: "%+.0f°", phi * 180 / .pi))
        }
    }

    // MARK: - ODE

    private func restart() {
        q = 0; i = 0; t = 0; iTrace.removeAll(); lastTime = nil
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now
        let sub = max(1, Int((dt / 0.0005).rounded()))
        let h = dt / Double(sub)
        for _ in 0..<sub {
            // L·di/dt = V₀·cos(ωt) - R·i - q/C; dq/dt = i.
            let v = V0 * cos(omega * t)
            let didt = (v - R * i - q / C) / L
            i += didt * h
            q += i * h
            t += h
        }
        iTrace.append(i)
        if iTrace.count > traceLen { iTrace.removeFirst(iTrace.count - traceLen) }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.55)
        let botRect = CGRect(x: 0, y: topRect.maxY, width: size.width,
                             height: size.height - topRect.maxY)
        drawTrace(ctx: ctx, in: topRect)
        drawImpedance(ctx: ctx, in: botRect)
    }

    private func drawTrace(ctx: GraphicsContext, in r: CGRect) {
        var axis = Path()
        axis.move(to: CGPoint(x: r.minX + 8, y: r.midY))
        axis.addLine(to: CGPoint(x: r.maxX - 8, y: r.midY))
        ctx.stroke(axis, with: .color(.white.opacity(0.25)), lineWidth: 1)

        guard !iTrace.isEmpty else { return }
        let maxI = max(0.001, iTrace.map(abs).max() ?? 0.001)
        var p = Path()
        for (k, v) in iTrace.enumerated() {
            let f = CGFloat(k) / CGFloat(traceLen - 1)
            let px = r.minX + 8 + f * (r.width - 16)
            let py = r.midY - CGFloat(v / maxI) * (r.height * 0.4)
            if k == 0 { p.move(to: CGPoint(x: px, y: py)) }
            else { p.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(p, with: .color(.green), lineWidth: 1.6)
        ctx.draw(Text("i(t)").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 22, y: r.minY + 12))
    }

    private func drawImpedance(ctx: GraphicsContext, in r: CGRect) {
        let omegaMax = max(omega * 1.4, 1 / sqrt(L * C) * 2.5)
        var p = Path()
        let n = 200
        var maxZ = 0.001
        var zs: [Double] = []
        for k in 0...n {
            let w = omegaMax * Double(k) / Double(n)
            let XL = w * L; let XC = w > 1e-6 ? 1 / (w * C) : 1e9
            let Z = sqrt(R * R + (XL - XC) * (XL - XC))
            zs.append(Z); maxZ = max(maxZ, Z)
        }
        // 1/|Z| 곡선이 더 직관적 (전류가 최대인 곳).
        let invMax = 1 / max(0.001, R)
        for (k, Z) in zs.enumerated() {
            let f = CGFloat(k) / CGFloat(n)
            let px = r.minX + 8 + f * (r.width - 16)
            let py = r.maxY - 18 - CGFloat((1 / Z) / invMax) * (r.height - 36)
            if k == 0 { p.move(to: CGPoint(x: px, y: py)) }
            else { p.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(p, with: .color(.orange), lineWidth: 1.5)

        // 현재 ω 마커.
        let f = CGFloat(min(omega, omegaMax) / omegaMax)
        let xω = r.minX + 8 + f * (r.width - 16)
        var line = Path()
        line.move(to: CGPoint(x: xω, y: r.minY))
        line.addLine(to: CGPoint(x: xω, y: r.maxY))
        ctx.stroke(line, with: .color(.red.opacity(0.7)), lineWidth: 1)

        ctx.draw(Text("1/|Z(ω)|").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 36, y: r.minY + 12))
    }
}

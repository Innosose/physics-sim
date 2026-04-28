import SwiftUI

/// 직렬 RLC 회로 — **닫힌 해 (analytical)**.
///
///  L·q̈ + R·q̇ + q/C = V₀·cos(ω t)
///
/// Spring/Mass-damper 와 정확히 동형: m=L, c=R, k=1/C.
///
///  • ω₀ = 1/√(LC),  ζ = R/2 · √(C/L)
///  • 정상상태: q_p(t) = Q·cos(ωt − φ),  Q = V₀/√((1/C − Lω²)² + (Rω)²),
///                                     φ = atan2(Rω, 1/C − Lω²)
///  • 과도상태 q_h(t): ζ < 1, ζ = 1, ζ > 1 분기 (Spring 과 같음).
///  • 전류 i(t) = q̇(t) — 닫힌 해의 미분으로 구함.
///
/// 적분 없음 — 시각 t 가 주어지면 위 식으로 직접 계산.
struct RLCScene: View {
    @State private var R: Double = 5.0       // Ω
    @State private var L: Double = 0.5       // H
    @State private var C: Double = 0.005     // F
    @State private var V0: Double = 10.0     // V
    @State private var omega: Double = 20.0  // rad/s
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "공명 진동수 ω₀ = 1/√(LC) 에서 |Z| 가 최소이고 전류가 최대. ω 가 ω₀ 보다 작으면 용량성, 크면 유도성.",
            canvas: { canvas },
            controls: { controls })
    }

    private func onSliderEnd(_ editing: Bool) {
        if !editing { startTime = Date() }
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
            LabeledSlider(title: "저항 R", value: $R, range: 0.1...30,
                          format: "%.2f", unit: "Ω", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "인덕턴스 L", value: $L, range: 0.05...3,
                          format: "%.2f", unit: "H", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "전기용량 C", value: $C, range: 0.0005...0.05,
                          format: "%.2f", unit: "F", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "EMF 진폭 V₀", value: $V0, range: 0.1...30,
                          format: "%.2f", unit: "V", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "각진동수 ω", value: $omega, range: 0.5...100,
                          format: "%.2f", unit: "rad/s", onEditingChanged: onSliderEnd)
            PlayResetBar(running: $running,
                         onReset: { startTime = Date() },
                         resetLabel: "처음부터")
            Divider()
            Readout(label: "공명 ω₀ = 1/√(LC)",
                    value: String(format: "%.2f rad/s", omega0))
            Readout(label: "X_L = ωL",
                    value: String(format: "%.2f Ω", omega * L))
            Readout(label: "X_C = 1/(ωC)",
                    value: String(format: "%.2f Ω", 1 / (omega * C)))
            let XL = omega * L, XC = 1 / (omega * C)
            let Z = sqrt(R * R + (XL - XC) * (XL - XC))
            let phi = atan2(XL - XC, R)
            Readout(label: "|Z|", value: String(format: "%.2f Ω", Z))
            Readout(label: "위상 φ", value: String(format: "%+.2f°", phi * 180 / .pi))
            Readout(label: "전류 i(t)",
                    value: String(format: "%+.2f A",
                                  state(at: max(0, Date().timeIntervalSince(startTime))).i))
        }
    }

    // MARK: - 닫힌 해

    private var omega0: Double { 1 / sqrt(L * C) }
    private var zeta: Double  { 0.5 * R * sqrt(C / L) }    // ≡ c/(2√(km)) with k=1/C, m=L

    /// q(t), i(t) — 정상상태 + 과도상태의 닫힌 해.
    private func state(at t: Double) -> (q: Double, i: Double) {
        // Spring 과 같은 식으로, m←L, c←R, k←1/C, F₀←V₀.
        let m = L, c = R, k = 1 / C
        let F0 = V0
        let ω = omega
        let ω0 = omega0
        let ζ  = zeta

        let denom = sqrt(pow(k - m * ω * ω, 2) + pow(c * ω, 2))
        let Q  = denom > 1e-9 ? F0 / denom : 0
        let φ  = atan2(c * ω, k - m * ω * ω)

        // 정상상태.
        let qp = Q * cos(ω * t - φ)
        let ip = -Q * ω * sin(ω * t - φ)        // 미분.

        // 동차해 계수 (q(0)=0, i(0)=q̇(0)=0).
        let qp0 = Q * cos(φ)
        let ip0 = Q * ω * sin(φ)

        let qh: Double, ih: Double
        if ζ < 1 - 1e-6 {
            // 소감쇠.
            let ωn = ω0 * sqrt(1 - ζ * ζ)
            let A = -qp0
            let B = -(ζ * ω0 * qp0 + ip0) / ωn
            let env = exp(-ζ * ω0 * t)
            qh = env * (A * cos(ωn * t) + B * sin(ωn * t))
            // ih = d/dt qh.
            //  qh = e^{-ζω₀t} (A cos + B sin)
            //  qh' = -ζω₀·qh + e^{-ζω₀t}·(-A·ωn·sin + B·ωn·cos)
            ih = -ζ * ω0 * qh
                + env * (B * ωn * cos(ωn * t) - A * ωn * sin(ωn * t))
        } else if abs(ζ - 1) <= 1e-6 {
            // 임계감쇠.
            let A = -qp0
            let B = ω0 * A - ip0
            let env = exp(-ω0 * t)
            qh = env * (A + B * t)
            // qh' = -ω0·env·(A+Bt) + env·B
            ih = -ω0 * qh + env * B
        } else {
            // 과감쇠.
            let s = sqrt(ζ * ζ - 1)
            let λ1 = -ω0 * (ζ - s)
            let λ2 = -ω0 * (ζ + s)
            let A = (λ2 * qp0 - ip0) / (λ1 - λ2)
            let B = -qp0 - A
            qh = A * exp(λ1 * t) + B * exp(λ2 * t)
            ih = A * λ1 * exp(λ1 * t) + B * λ2 * exp(λ2 * t)
        }
        return (q: qh + qp, i: ih + ip)
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.55)
        let botRect = CGRect(x: 0, y: topRect.maxY, width: size.width,
                             height: size.height - topRect.maxY)
        drawCurrentTrace(ctx: ctx, in: topRect, tNow: t)
        drawImpedance(ctx: ctx, in: botRect)
    }

    private func drawCurrentTrace(ctx: GraphicsContext, in r: CGRect, tNow: Double) {
        var axis = Path()
        axis.move(to: CGPoint(x: r.minX + 8, y: r.midY))
        axis.addLine(to: CGPoint(x: r.maxX - 8, y: r.midY))
        ctx.stroke(axis, with: .color(.white.opacity(0.25)), lineWidth: 1)

        // 시간 윈도우: 최근 6 주기 (구동 또는 고유 진동수 중 더 긴 것 기준).
        let period = 2 * .pi / max(0.5, min(omega, omega0))
        let window = 6 * period
        let tStart = max(0, tNow - window)
        let n = 240
        var samples: [Double] = []
        for i in 0...n {
            let f = Double(i) / Double(n)
            let tt = tStart + f * (tNow - tStart)
            samples.append(state(at: tt).i)
        }
        let absMax = max(0.001, samples.map(abs).max() ?? 0.001)
        var p = Path()
        for (k, v) in samples.enumerated() {
            let f = CGFloat(k) / CGFloat(n)
            let px = r.minX + 8 + f * (r.width - 16)
            let py = r.midY - CGFloat(v / absMax) * (r.height * 0.4)
            if k == 0 { p.move(to: CGPoint(x: px, y: py)) }
            else { p.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(p, with: .color(.green), lineWidth: 1.6)
        ctx.draw(Text("i(t) — 분석해").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 70, y: r.minY + 12))
    }

    private func drawImpedance(ctx: GraphicsContext, in r: CGRect) {
        let omegaMax = max(omega * 1.4, omega0 * 2.5)
        var p = Path()
        let n = 200
        var zs: [Double] = []
        for k in 0...n {
            let w = omegaMax * Double(k) / Double(n)
            let XL = w * L; let XC = w > 1e-6 ? 1 / (w * C) : 1e9
            let Z = sqrt(R * R + (XL - XC) * (XL - XC))
            zs.append(Z)
        }
        // 1/|Z| 곡선이 더 직관적.
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

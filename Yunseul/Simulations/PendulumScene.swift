import SwiftUI

/// 단진자 — **닫힌 해 (analytical)**.
///
/// 두 진자를 같은 화면에 그려 비교한다:
///
/// 1) **선형 진자** (작은-각 근사)  — 감쇠 포함 닫힌 해
///    - 무감쇠/소감쇠:  θ_L(t) = θ_max · e^{−γt/2} · cos(ω_d t),  ω_d = √(ω₀² − γ²/4)
///    - 임계감쇠 (γ = 2ω₀): θ_L(t) = θ_max · (1 + γt/2) · e^{−γt/2}
///    - 과감쇠:  지수 두 항의 합 (초기조건으로 풀림)
///
/// 2) **비선형 진자** (감쇠 없음) — Jacobi 타원함수 cn 으로 정확한 닫힌 해
///    - k = sin(θ_max/2),  ω₀ = √(g/L)
///    - θ_NL(t) = 2 · arcsin(k · cn(ω₀ t,  k))
///    - 주기 T = 4·K(k) / ω₀  (작은 각이면 K → π/2, T → 2π/ω₀)
///
/// 적분 없음 — 시각 t 가 주어지면 위 식으로 직접 계산.
struct PendulumScene: View {
    @State private var length: Double = 1.5      // m
    @State private var gravity: Double = 9.81    // m/s²
    @State private var damping: Double = 0.0     // 1/s — 선형 진자에만 적용
    @State private var initialAngleDeg: Double = 60
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "노란색은 비선형 (Jacobi cn 닫힌 해), 회색은 작은-각 선형 근사. 진폭이 커질수록 둘은 점점 어긋난다 — 비선형의 주기가 더 길다.",
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
            LabeledSlider(title: "줄 길이 L", value: $length, range: 0.3...3.0,
                          format: "%.2f", unit: "m",
                          onEditingChanged: onSliderEnd)
            LabeledSlider(title: "중력", value: $gravity, range: 1.62...24.79,
                          format: "%.2f", unit: "m/s²",
                          onEditingChanged: onSliderEnd)
            LabeledSlider(title: "감쇠 γ (선형 진자에만)", value: $damping,
                          range: 0...1.5, format: "%.2f", unit: "1/s",
                          onEditingChanged: onSliderEnd)
            LabeledSlider(title: "초기 각도", value: $initialAngleDeg,
                          range: 1...170, step: 1, format: "%.2f", unit: "°",
                          onEditingChanged: onSliderEnd)
            PlayResetBar(running: $running,
                         onReset: { startTime = Date() },
                         resetLabel: "처음부터")
            Divider()
            let ω0 = sqrt(gravity / length)
            let T0 = 2 * .pi / ω0
            let θmax = initialAngleDeg * .pi / 180
            let k = sin(θmax / 2)
            let TNL = 4 * ellipticK(k: k) / ω0
            Readout(label: "고유진동수 ω₀ = √(g/L)",
                    value: String(format: "%.2f rad/s", ω0))
            Readout(label: "선형 주기 T₀ = 2π/ω₀",
                    value: String(format: "%.2f s", T0))
            Readout(label: "비선형 주기 T = 4·K(k)/ω₀",
                    value: String(format: "%.2f s", TNL))
            Readout(label: "차이 ΔT / T₀",
                    value: String(format: "%+.2f %%", (TNL - T0) / T0 * 100))
            let t = max(0, Date().timeIntervalSince(startTime))
            Readout(label: "비선형 θ(t)",
                    value: String(format: "%+.2f°", nonlinearTheta(at: t) * 180 / .pi))
            Readout(label: "선형 θ(t)",
                    value: String(format: "%+.2f°", linearTheta(at: t) * 180 / .pi))
        }
    }

    // MARK: - 닫힌 해

    /// 비선형 무감쇠 — Jacobi cn 닫힌 해.
    private func nonlinearTheta(at t: Double) -> Double {
        let θmax = initialAngleDeg * .pi / 180
        let k = sin(θmax / 2)
        let ω0 = sqrt(gravity / length)
        // cn 은 주기 4·K(k). 큰 t 의 정밀 손실 방지 위해 mod 처리.
        let K4 = 4 * ellipticK(k: k)
        let u = (ω0 * t).truncatingRemainder(dividingBy: K4)
        let cn = jacobiSnCnDn(u: u, k: k).cn
        let arg = max(-1.0, min(1.0, k * cn))
        return 2 * asin(arg)
    }

    /// 선형 (작은-각) 닫힌 해 — 감쇠 케이스 분기.
    private func linearTheta(at t: Double) -> Double {
        let θmax = initialAngleDeg * .pi / 180
        let ω0 = sqrt(gravity / length)
        let γ = damping

        // 무감쇠.
        if γ < 1e-9 { return θmax * cos(ω0 * t) }

        let critical = 2 * ω0
        if γ < critical - 1e-6 {
            // 소감쇠.
            let ωd = sqrt(ω0 * ω0 - γ * γ / 4)
            return θmax * exp(-γ * t / 2) * cos(ωd * t)
        } else if γ > critical + 1e-6 {
            // 과감쇠.
            let s = sqrt(γ * γ / 4 - ω0 * ω0)
            let λ1 = -γ / 2 + s
            let λ2 = -γ / 2 - s
            // θ(0) = θmax, θ̇(0) = 0  ⇒  A = -λ2·θmax/(λ1−λ2),  B = λ1·θmax/(λ1−λ2)
            let A = -λ2 * θmax / (λ1 - λ2)
            let B =  λ1 * θmax / (λ1 - λ2)
            return A * exp(λ1 * t) + B * exp(λ2 * t)
        } else {
            // 임계감쇠 — θ(t) = θmax · (1 + γt/2) · exp(−γt/2).
            return θmax * (1 + γ * t / 2) * exp(-γ * t / 2)
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let world = CGRect(x: -2.0, y: -2.0, width: 4.0, height: 3.0)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 천장.
        let pivotPx = map.point(x: 0, y: 1.0)
        var ceil = Path()
        ceil.move(to: CGPoint(x: pivotPx.x - 60, y: pivotPx.y))
        ceil.addLine(to: CGPoint(x: pivotPx.x + 60, y: pivotPx.y))
        ctx.stroke(ceil, with: .color(.white.opacity(0.5)), lineWidth: 2)

        drawBob(ctx: ctx, map: map, pivot: Vec2(x: 0, y: 1.0),
                theta: linearTheta(at: t), color: .gray, alpha: 0.55)
        drawBob(ctx: ctx, map: map, pivot: Vec2(x: 0, y: 1.0),
                theta: nonlinearTheta(at: t), color: .yellow, alpha: 1.0)
    }

    private func drawBob(ctx: GraphicsContext, map: CanvasMap, pivot: Vec2,
                         theta: Double, color: Color, alpha: Double) {
        let bob = Vec2(x: pivot.x + length * sin(theta),
                       y: pivot.y - length * cos(theta))
        var line = Path()
        line.move(to: map.point(pivot))
        line.addLine(to: map.point(bob))
        ctx.stroke(line, with: .color(color.opacity(alpha)), lineWidth: 2)

        let pt = map.point(bob)
        let r: CGFloat = 12
        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                        width: r * 2, height: r * 2)),
                 with: .color(color.opacity(alpha)))
    }
}

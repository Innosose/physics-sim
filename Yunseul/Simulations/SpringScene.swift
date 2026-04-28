import SwiftUI

/// 감쇠·구동 단진동 — **닫힌 해 (analytical)**.
///
///  m·ẍ + c·ẋ + k·x = F₀·cos(ω_d t)
///
/// 해는 정상상태(특수해) + 과도상태(동차해) 의 합:
///
///  • 정상상태: x_p(t) = X·cos(ω_d t − φ),
///       X = F₀ / √((k − mω_d²)² + (cω_d)²),
///       φ = atan2(cω_d, k − mω_d²)
///
///  • 과도상태: 감쇠비 ζ = c / (2√(km)) 에 따라 분기.
///     - ζ < 1 (소감쇠):  x_h = e^{-ζω₀t}(A cos ω_n t + B sin ω_n t),  ω_n = ω₀√(1−ζ²)
///     - ζ = 1 (임계감쇠): x_h = e^{-ω₀t}(A + B t)
///     - ζ > 1 (과감쇠):   x_h = A·e^{λ₁t} + B·e^{λ₂t},  λ₁,₂ = -ω₀(ζ ∓ √(ζ²−1))
///
/// 초기조건 x(0)=0, ẋ(0)=0 으로 A, B 를 닫힌 형태로 결정.
/// **적분 없음** — 시각 t 가 주어지면 위 식으로 직접 계산.
struct SpringScene: View {
    @State private var mass: Double = 1.0
    @State private var stiffness: Double = 25.0
    @State private var damping: Double = 0.6
    @State private var driveAmp: Double = 5.0
    @State private var driveOmega: Double = 5.0
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "감쇠 진동의 닫힌 해. 구동 진동수 ω_d 를 고유진동수 √(k/m) 근처로 맞추면 정상상태 진폭 X 가 최대 — 공명.",
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
            LabeledSlider(title: "질량 m", value: $mass, range: 0.2...5.0,
                          format: "%.2f", unit: "kg",
                          onEditingChanged: onSliderEnd)
            LabeledSlider(title: "강성 k", value: $stiffness, range: 1.0...80.0,
                          format: "%.2f", unit: "N/m",
                          onEditingChanged: onSliderEnd)
            LabeledSlider(title: "감쇠 c", value: $damping, range: 0...4,
                          format: "%.2f", unit: "N·s/m",
                          onEditingChanged: onSliderEnd)
            LabeledSlider(title: "외력 진폭 F₀", value: $driveAmp, range: 0...20,
                          format: "%.2f", unit: "N",
                          onEditingChanged: onSliderEnd)
            LabeledSlider(title: "구동 ω_d", value: $driveOmega, range: 0.1...15,
                          format: "%.2f", unit: "rad/s",
                          onEditingChanged: onSliderEnd)
            PlayResetBar(running: $running,
                         onReset: { startTime = Date() },
                         resetLabel: "처음부터")
            Divider()
            Readout(label: "고유진동수 ω₀",
                    value: String(format: "%.2f rad/s", omega0))
            Readout(label: "감쇠비 ζ",
                    value: String(format: "%.2f  (%@)", zeta, dampingRegimeLabel))
            Readout(label: "정상상태 진폭 X",
                    value: String(format: "%.2f m", steadyAmplitude))
            Readout(label: "현재 위치 x(t)",
                    value: String(format: "%+.2f m", state(at: max(0, Date().timeIntervalSince(startTime)))))
        }
    }

    // MARK: - 닫힌 해 매개변수

    private var omega0: Double { sqrt(stiffness / mass) }
    private var zeta: Double  { damping / (2 * sqrt(stiffness * mass)) }

    private var steadyAmplitude: Double {
        let denom = sqrt(pow(stiffness - mass * driveOmega * driveOmega, 2)
                         + pow(damping * driveOmega, 2))
        return denom > 1e-9 ? driveAmp / denom : 0
    }

    private var steadyPhase: Double {
        atan2(damping * driveOmega, stiffness - mass * driveOmega * driveOmega)
    }

    private var dampingRegimeLabel: String {
        if zeta < 1 - 1e-6 { return "소감쇠" }
        if zeta > 1 + 1e-6 { return "과감쇠" }
        return "임계감쇠"
    }

    /// x(t) — 정상상태 + 과도상태의 닫힌 해.
    private func state(at t: Double) -> Double {
        let X = steadyAmplitude
        let φ = steadyPhase
        let ω = driveOmega

        // 정상상태.
        let xp = X * cos(ω * t - φ)

        // 초기조건 x(0)=0, ẋ(0)=0 을 위한 동차해 계수.
        let xp0 = X * cos(φ)
        let vp0 = X * ω * sin(φ)

        let xh: Double
        if zeta < 1 - 1e-6 {
            // 소감쇠.
            let ωn = omega0 * sqrt(1 - zeta * zeta)
            let A = -xp0
            let B = -(zeta * omega0 * xp0 + vp0) / ωn
            xh = exp(-zeta * omega0 * t) * (A * cos(ωn * t) + B * sin(ωn * t))
        } else if abs(zeta - 1) <= 1e-6 {
            // 임계감쇠.
            let A = -xp0
            let B = omega0 * A - vp0
            xh = exp(-omega0 * t) * (A + B * t)
        } else {
            // 과감쇠.
            // x_h(0) = A + B = −xp0,  ẋ_h(0) = λ₁A + λ₂B = −vp0
            //   B = −xp0 − A,  대입:  (λ₁ − λ₂)A = −vp0 + λ₂·xp0
            //   →  A = (λ₂·xp0 − vp0) / (λ₁ − λ₂)
            let s = sqrt(zeta * zeta - 1)
            let λ1 = -omega0 * (zeta - s)
            let λ2 = -omega0 * (zeta + s)
            let A = (λ2 * xp0 - vp0) / (λ1 - λ2)
            let B = -xp0 - A
            xh = A * exp(λ1 * t) + B * exp(λ2 * t)
        }
        return xh + xp
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.45)
        let midRect = CGRect(x: 0, y: topRect.maxY, width: size.width,
                             height: size.height * 0.30)
        let botRect = CGRect(x: 0, y: midRect.maxY, width: size.width,
                             height: size.height - midRect.maxY)
        let xNow = state(at: t)
        drawSpringMass(ctx: ctx, in: topRect, x: xNow)
        drawTrace(ctx: ctx, in: midRect, tNow: t)
        drawResonance(ctx: ctx, in: botRect)
    }

    private func drawSpringMass(ctx: GraphicsContext, in r: CGRect, x: Double) {
        let cy = r.midY
        let wallX = r.minX + 30
        let restLen: CGFloat = 220
        let scale: CGFloat = 60
        let endX = wallX + restLen + CGFloat(x) * scale
        var wall = Path()
        wall.move(to: CGPoint(x: wallX, y: cy - 40))
        wall.addLine(to: CGPoint(x: wallX, y: cy + 40))
        ctx.stroke(wall, with: .color(.white.opacity(0.5)), lineWidth: 2)
        var spring = Path()
        let coils = 14
        spring.move(to: CGPoint(x: wallX, y: cy))
        for i in 0...coils {
            let f = CGFloat(i) / CGFloat(coils)
            let px = wallX + f * (endX - wallX)
            let py = cy + (i % 2 == 0 ? -10 : 10)
            spring.addLine(to: CGPoint(x: px, y: py))
        }
        spring.addLine(to: CGPoint(x: endX, y: cy))
        ctx.stroke(spring, with: .color(.cyan), lineWidth: 1.5)
        let box = CGRect(x: endX, y: cy - 20, width: 40, height: 40)
        ctx.fill(Path(box), with: .color(.yellow))
        ctx.stroke(Path(box), with: .color(.white.opacity(0.4)), lineWidth: 1)
        var eq = Path()
        eq.move(to: CGPoint(x: wallX + restLen, y: cy + 50))
        eq.addLine(to: CGPoint(x: wallX + restLen, y: cy + 64))
        ctx.stroke(eq, with: .color(.white.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }

    private func drawTrace(ctx: GraphicsContext, in r: CGRect, tNow: Double) {
        var axis = Path()
        axis.move(to: CGPoint(x: r.minX, y: r.midY))
        axis.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        ctx.stroke(axis, with: .color(.white.opacity(0.25)), lineWidth: 1)

        // 시간 윈도우: 최근 10·(2π/ω₀) 정도. 분석해를 직접 샘플.
        let window = max(8 * .pi / max(0.5, omega0), 6.0)
        let tStart = max(0, tNow - window)
        let n = 240
        var samples: [(t: Double, x: Double)] = []
        for i in 0...n {
            let f = Double(i) / Double(n)
            let tt = tStart + f * (tNow - tStart)
            samples.append((tt, state(at: tt)))
        }
        let absMax = max(0.5, samples.map { abs($0.x) }.max() ?? 0.5)
        var path = Path()
        for (i, s) in samples.enumerated() {
            let f = CGFloat(i) / CGFloat(n)
            let px = r.minX + f * r.width
            let py = r.midY - CGFloat(s.x / absMax) * (r.height * 0.45)
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(.green), lineWidth: 1.6)
        ctx.draw(Text("x(t) — 분석해").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 70, y: r.minY + 12))
    }

    private func drawResonance(ctx: GraphicsContext, in r: CGRect) {
        let omegaMax: Double = max(omega0 * 2.5, 12)
        var path = Path()
        let n = 220
        var maxAmp = 0.0
        var amps = [Double]()
        for i in 0...n {
            let omega = omegaMax * Double(i) / Double(n)
            let denom = sqrt(pow(stiffness - mass * omega * omega, 2)
                             + pow(damping * omega, 2))
            let A = denom > 1e-9 ? driveAmp / denom : driveAmp / 1e-9
            amps.append(A); maxAmp = max(maxAmp, A)
        }
        let yScale = (r.height - 24) / max(0.001, maxAmp)
        for (i, A) in amps.enumerated() {
            let omega = omegaMax * Double(i) / Double(n)
            let px = r.minX + CGFloat(omega / omegaMax) * r.width
            let py = r.maxY - 8 - CGFloat(A) * yScale
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(.orange), lineWidth: 1.6)
        let xω0 = r.minX + CGFloat(omega0 / omegaMax) * r.width
        var natLine = Path()
        natLine.move(to: CGPoint(x: xω0, y: r.minY))
        natLine.addLine(to: CGPoint(x: xω0, y: r.maxY))
        ctx.stroke(natLine, with: .color(.white.opacity(0.3)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        let xωd = r.minX + CGFloat(min(driveOmega, omegaMax) / omegaMax) * r.width
        var nowLine = Path()
        nowLine.move(to: CGPoint(x: xωd, y: r.minY))
        nowLine.addLine(to: CGPoint(x: xωd, y: r.maxY))
        ctx.stroke(nowLine, with: .color(.red.opacity(0.7)), lineWidth: 1.2)
        ctx.draw(Text("|X(ω)|").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 26, y: r.minY + 12))
        ctx.draw(Text("ω₀").font(.caption2).foregroundStyle(.secondary),
                 at: CGPoint(x: xω0 + 12, y: r.minY + 12))
    }
}

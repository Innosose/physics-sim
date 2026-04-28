import SwiftUI

/// 단진자 — 비선형 ODE 와 작은-각 근사 비교.
///
/// 비선형:  d²θ/dt² = -(g/L) sin θ  − γ·dθ/dt
/// 선형:    d²θ/dt² = -(g/L) θ      − γ·dθ/dt
/// RK4 적분.
struct PendulumScene: View {
    /// 초등용 모드 — 슬라이더와 측정값을 줄이고, 작은-각 비교 진자도 숨긴다.
    var simpleMode: Bool = false

    @State private var length: Double = 1.5      // m
    @State private var gravity: Double = 9.81    // m/s²
    @State private var damping: Double = 0.0     // 1/s
    @State private var initialAngleDeg: Double = 60
    @State private var running = true

    // 두 진자의 (각, 각속도) — 비선형 / 선형.
    @State private var nlState = (theta: 0.0, omega: 0.0)
    @State private var linState = (theta: 0.0, omega: 0.0)
    @State private var lastTime: TimeInterval? = nil

    var body: some View {
        SimChrome(
                  blurb: simpleMode
                      ? "줄이 길어지면 천천히 흔들리고, 무거워도 주기는 변하지 않아요. 직접 줄 길이를 바꿔 보세요."
                      : "노란색은 정확한 비선형 해, 회색은 작은-각 근사. 진폭이 커질수록 둘은 점점 어긋난다.",
                  canvas: { canvas },
                  controls: { controls })
            .onAppear { reset() }
    }

    /// 슬라이더에서 손을 뗄 때만 호출 — 드래그 중 깜빡임 방지.
    private func onSliderEnd(_ editing: Bool) { if !editing { reset() } }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { ctx in
            Canvas { gctx, size in
                advance(to: ctx.date.timeIntervalSinceReferenceDate)
                draw(ctx: gctx, size: size)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "줄 길이 L", value: $length, range: 0.3...3.0,
                          format: "%.2f", unit: "m",
                          onEditingChanged: onSliderEnd)
            if !simpleMode {
                LabeledSlider(title: "중력", value: $gravity, range: 1.62...24.79,
                              format: "%.2f", unit: "m/s²")
                LabeledSlider(title: "감쇠 γ", value: $damping, range: 0...1.5,
                              format: "%.2f", unit: "1/s")
            }
            LabeledSlider(title: "초기 각도", value: $initialAngleDeg, range: 1...170,
                          step: 1, format: "%.0f", unit: "°",
                          onEditingChanged: onSliderEnd)
            PlayResetBar(running: $running, onReset: reset)
            Divider()
            Readout(label: simpleMode ? "흔들리는 한 번 시간 (주기)" : "주기 (작은각) T₀",
                    value: String(format: "%.3f s", 2 * .pi * sqrt(length / gravity)))
            if !simpleMode {
                Readout(label: "비선형 θ",
                        value: String(format: "%.1f°", nlState.theta * 180 / .pi))
                Readout(label: "선형   θ",
                        value: String(format: "%.1f°", linState.theta * 180 / .pi))
            }
        }
    }

    // MARK: - 통합

    private func reset() {
        nlState = (theta: initialAngleDeg * .pi / 180, omega: 0)
        linState = (theta: initialAngleDeg * .pi / 180, omega: 0)
        lastTime = nil
    }

    private func advance(to now: TimeInterval) {
        guard running else { lastTime = now; return }
        guard let last = lastTime else { lastTime = now; return }
        var dt = now - last
        if dt > 0.1 { dt = 0.1 }   // 큰 hitch 방지
        // 고정 서브스텝.
        let sub = max(1, Int((dt / 0.002).rounded()))
        let h = dt / Double(sub)
        for _ in 0..<sub {
            nlState  = rk4(state: nlState,  h: h, accel: { -gravity / length * sin($0) - damping * $1 })
            linState = rk4(state: linState, h: h, accel: { -gravity / length * $0       - damping * $1 })
        }
        lastTime = now
    }

    private func rk4(state s: (theta: Double, omega: Double),
                     h: Double,
                     accel: (Double, Double) -> Double) -> (theta: Double, omega: Double) {
        // y = (θ, ω). dθ/dt = ω, dω/dt = accel(θ, ω).
        let k1t = s.omega
        let k1o = accel(s.theta, s.omega)
        let k2t = s.omega + 0.5 * h * k1o
        let k2o = accel(s.theta + 0.5 * h * k1t, s.omega + 0.5 * h * k1o)
        let k3t = s.omega + 0.5 * h * k2o
        let k3o = accel(s.theta + 0.5 * h * k2t, s.omega + 0.5 * h * k2o)
        let k4t = s.omega + h * k3o
        let k4o = accel(s.theta + h * k3t, s.omega + h * k3o)
        return (theta: s.theta + h / 6 * (k1t + 2 * k2t + 2 * k3t + k4t),
                omega: s.omega + h / 6 * (k1o + 2 * k2o + 2 * k3o + k4o))
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let world = CGRect(x: -2.0, y: -2.0, width: 4.0, height: 3.0)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 천장.
        let pivotPx = map.point(x: 0, y: 1.0)
        var ceil = Path()
        ceil.move(to: CGPoint(x: pivotPx.x - 60, y: pivotPx.y))
        ceil.addLine(to: CGPoint(x: pivotPx.x + 60, y: pivotPx.y))
        ctx.stroke(ceil, with: .color(.white.opacity(0.5)), lineWidth: 2)

        // 두 진자 그리기.
        if !simpleMode {
            drawBob(ctx: ctx, map: map, pivot: Vec2(x: 0, y: 1.0),
                    theta: linState.theta, color: .gray, alpha: 0.55, label: nil)
        }
        drawBob(ctx: ctx, map: map, pivot: Vec2(x: 0, y: 1.0),
                theta: nlState.theta, color: .yellow, alpha: 1.0, label: "비선형")
    }

    private func drawBob(ctx: GraphicsContext, map: CanvasMap, pivot: Vec2,
                         theta: Double, color: Color, alpha: Double, label: String?) {
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

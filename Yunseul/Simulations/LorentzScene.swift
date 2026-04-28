import SwiftUI

/// 자기장 속 하전입자 — **닫힌 해 (analytical)**.
///
///  m·dv/dt = q (E + v × B),    B = B_z·ẑ (지면 밖 +)
///
/// 닫힌 해는 [E×B 표류 속도] + [사이클로트론 원운동] 의 합이다.
///
///  • ω_c = q·B_z / m                    (사이클로트론 각진동수, 부호 포함)
///  • v_d = (E×B) / B² = (E_y / B_z, −E_x / B_z)
///  • u(t) = v(t) − v_d  →  드리프트계에서 순수 원운동
///  • r(t) = r(0) + v_d·t + (1/ω_c)·∫u dτ                  (닫힌 형태)
///
/// B = 0 일 때는 단순 등가속도: r(t) = v(0)·t + ½·(qE/m)·t².
/// 적분 없음 — 시각 t 가 주어지면 위 식으로 직접 계산.
struct LorentzScene: View {
    @State private var Bz: Double = 1.0
    @State private var Ex: Double = 0.0
    @State private var Ey: Double = 0.0
    @State private var charge: Double = 1.0
    @State private var mass: Double = 1.0
    @State private var initialVx: Double = 1.5
    @State private var initialVy: Double = 0.0
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "B 만 있으면 원운동 (반지름 r = mv/|qB|). E 도 있으면 E×B 방향으로 일정 속도 표류 (v_d = E×B / B²).",
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
            LabeledSlider(title: "B_z (지면 밖 +)", value: $Bz, range: -2...2,
                          format: "%.2f", unit: "T", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "E_x", value: $Ex, range: -2...2,
                          format: "%.2f", unit: "V/m", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "E_y", value: $Ey, range: -2...2,
                          format: "%.2f", unit: "V/m", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "전하 q", value: $charge, range: -2...2,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "질량 m", value: $mass, range: 0.2...3,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "초기 v_x", value: $initialVx, range: -3...3,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "초기 v_y", value: $initialVy, range: -3...3,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            PlayResetBar(running: $running,
                         onReset: { startTime = Date() },
                         resetLabel: "처음부터")
            Divider()
            let omegaC = charge * Bz / mass
            let vd = driftVelocity
            let v0 = Vec2(x: initialVx, y: initialVy)
            let r = abs(omegaC) > 1e-6
                ? (v0 - vd).length / abs(omegaC)
                : .infinity
            Readout(label: "사이클로트론 ω_c",
                    value: String(format: "%+.2f rad/s", omegaC))
            Readout(label: "자이로 반지름",
                    value: r.isFinite ? String(format: "%.2f m", r) : "∞")
            Readout(label: "표류 속도 v_d",
                    value: String(format: "(%+.2f, %+.2f) m/s", vd.x, vd.y))
            let p = position(at: max(0, Date().timeIntervalSince(startTime)))
            Readout(label: "현재 r(t)",
                    value: String(format: "(%+.2f, %+.2f) m", p.x, p.y))
        }
    }

    // MARK: - 닫힌 해

    /// E×B 표류 속도. B_z = 0 이면 정의되지 않으므로 0 반환.
    private var driftVelocity: Vec2 {
        if abs(Bz) < 1e-9 { return .zero }
        return Vec2(x: Ey / Bz, y: -Ex / Bz)
    }

    /// 시각 t 에서의 위치. r(0) = (0, 0).
    private func position(at t: Double) -> Vec2 {
        let v0 = Vec2(x: initialVx, y: initialVy)
        if abs(Bz) < 1e-9 {
            // 자기장 없음 — 단순 등가속도.
            let a = Vec2(x: charge * Ex / mass, y: charge * Ey / mass)
            return v0 * t + a * (0.5 * t * t)
        }
        let ωc = charge * Bz / mass
        let vd = driftVelocity
        let u0 = v0 - vd
        let s = sin(ωc * t)
        let c1 = 1 - cos(ωc * t)
        // ∫₀ᵗ u(τ) dτ in closed form.
        let dx = ( u0.x * s + u0.y * c1) / ωc
        let dy = (-u0.x * c1 + u0.y * s) / ωc
        return vd * t + Vec2(x: dx, y: dy)
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let pos = position(at: t)
        let extent = max(6.0, max(abs(pos.x), abs(pos.y)) * 1.2 + 2)
        let world = CGRect(x: -extent, y: -extent,
                           width: 2 * extent, height: 2 * extent)
        let map = CanvasMap(view: size, world: world, padding: 8)

        drawBField(ctx: ctx, map: map, world: world)

        // 자취 — 분석해를 시간 0..t 까지 샘플링 (적분 없음).
        let samples = max(2, min(800, Int(t * 60) + 2))
        var path = Path()
        for i in 0...samples {
            let τ = Double(i) / Double(samples) * t
            let p = position(at: τ)
            let pt = map.point(p)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        ctx.stroke(path, with: .color(.cyan.opacity(0.85)), lineWidth: 1.4)

        // 현재 입자.
        let pt = map.point(pos)
        let r: CGFloat = 7
        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                        width: r * 2, height: r * 2)),
                 with: .color(charge >= 0 ? .red : .blue))
    }

    private func drawBField(ctx: GraphicsContext, map: CanvasMap, world: CGRect) {
        let step: Double = 1.5
        let outOfPage = Bz > 0
        var x = Double(world.minX) + 0.5
        while x <= Double(world.maxX) {
            var y = Double(world.minY) + 0.5
            while y <= Double(world.maxY) {
                let pt = map.point(x: x, y: y)
                let r: CGFloat = 6
                let circle = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                ctx.stroke(Path(ellipseIn: circle),
                           with: .color(.white.opacity(0.18)), lineWidth: 0.8)
                if outOfPage {
                    let dr: CGFloat = 1.6
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dr, y: pt.y - dr,
                                                    width: dr * 2, height: dr * 2)),
                             with: .color(.white.opacity(0.25)))
                } else {
                    var c = Path()
                    c.move(to: CGPoint(x: pt.x - 3, y: pt.y - 3))
                    c.addLine(to: CGPoint(x: pt.x + 3, y: pt.y + 3))
                    c.move(to: CGPoint(x: pt.x - 3, y: pt.y + 3))
                    c.addLine(to: CGPoint(x: pt.x + 3, y: pt.y - 3))
                    ctx.stroke(c, with: .color(.white.opacity(0.22)), lineWidth: 1)
                }
                y += step
            }
            x += step
        }
    }
}

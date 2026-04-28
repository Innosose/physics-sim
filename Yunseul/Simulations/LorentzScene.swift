import SwiftUI

/// 자기장 속 하전입자 — 사이클로트론과 E×B 표류.
///
///  m·dv/dt = q (E + v × B)
///
/// B 는 화면 평면에 수직 (z 방향), E 는 화면 안 임의 방향.
/// 2D: v×B 의 평면 성분 = (v_y·B, -v_x·B). 부호는 B_z 에 의해 결정.
struct LorentzScene: View {
    @State private var Bz: Double = 1.0       // T 단위 (임의)
    @State private var Ex: Double = 0.0
    @State private var Ey: Double = 0.0
    @State private var charge: Double = 1.0
    @State private var mass: Double = 1.0
    @State private var initialVx: Double = 1.5
    @State private var initialVy: Double = 0
    @State private var running = true

    @State private var pos = Vec2(x: 0, y: 0)
    @State private var vel = Vec2(x: 1.5, y: 0)
    @State private var trail: [Vec2] = []
    private let trailMax = 800
    @State private var lastTime: TimeInterval? = nil

    var body: some View {
        SimChrome(
                  blurb: "B 만 있으면 원운동 (반지름 r = mv/|qB|). E 도 있으면 E×B 방향으로 일정 속도 표류 (v_d = E×B / B²).",
                  canvas: { canvas },
                  controls: { controls })
            .onAppear { reset() }
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
            LabeledSlider(title: "B_z (지면 밖 +)", value: $Bz, range: -2...2, format: "%.2f", unit: "T")
            LabeledSlider(title: "E_x", value: $Ex, range: -2...2, format: "%.2f", unit: "V/m")
            LabeledSlider(title: "E_y", value: $Ey, range: -2...2, format: "%.2f", unit: "V/m")
            LabeledSlider(title: "전하 q", value: $charge, range: -2...2, format: "%.2f")
            LabeledSlider(title: "질량 m", value: $mass, range: 0.2...3, format: "%.2f")
            LabeledSlider(title: "초기 v_x", value: $initialVx, range: -3...3, format: "%.2f")
            LabeledSlider(title: "초기 v_y", value: $initialVy, range: -3...3, format: "%.2f")
            PlayResetBar(running: $running, onReset: reset)
            Divider()
            let omegaC = abs(charge * Bz / mass)
            let speed = vel.length
            let r = abs(Bz) > 1e-6 ? mass * speed / abs(charge * Bz) : .infinity
            let vd = abs(Bz) > 1e-6
                ? Vec2(x: Ey / Bz, y: -Ex / Bz) : Vec2.zero
            Readout(label: "사이클로트론 진동수 ω_c",
                    value: String(format: "%.2f rad/s", omegaC))
            Readout(label: "자이로 반지름",
                    value: r.isFinite ? String(format: "%.2f", r) : "∞")
            Readout(label: "표류 속도 v_d",
                    value: String(format: "(%.2f, %.2f)", vd.x, vd.y))
        }
    }

    // MARK: - 동역학

    private func reset() {
        pos = Vec2(x: 0, y: 0)
        vel = Vec2(x: initialVx, y: initialVy)
        trail.removeAll()
        lastTime = nil
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now
        let sub = 80
        let h = dt / Double(sub)
        for _ in 0..<sub {
            // F = q (E + v × B), B = B_z ẑ → v×B = (v_y·B_z, -v_x·B_z, 0)
            let fx = charge * (Ex + vel.y * Bz)
            let fy = charge * (Ey - vel.x * Bz)
            vel.x += fx / mass * h
            vel.y += fy / mass * h
            pos += vel * h
        }
        trail.append(pos)
        if trail.count > trailMax { trail.removeFirst(trail.count - trailMax) }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let extent = max(6.0, max(abs(pos.x), abs(pos.y)) * 1.4 + 2)
        let world = CGRect(x: -extent, y: -extent, width: 2 * extent, height: 2 * extent)
        let map = CanvasMap(view: size, world: world, padding: 8)

        // B 표시: 화면 가득 동그라미 점/엑스 패턴.
        drawBField(ctx: ctx, map: map, world: world)

        // 자취.
        var path = Path()
        for (i, p) in trail.enumerated() {
            let pt = map.point(p)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        ctx.stroke(path, with: .color(.cyan.opacity(0.85)), lineWidth: 1.4)

        // 입자.
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
                    // 점 (·).
                    let dr: CGFloat = 1.6
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dr, y: pt.y - dr,
                                                    width: dr * 2, height: dr * 2)),
                             with: .color(.white.opacity(0.25)))
                } else {
                    // ✕.
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

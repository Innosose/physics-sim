import SwiftUI

/// N체 중력 — 모든 별이 서로 끌어당김.
///
///  F_ij = G · m_i · m_j · (r_j − r_i) / |r_j − r_i|³
///
/// Velocity-Verlet 적분기 사용: 작은 dt 에서 에너지·각운동량이 잘 보존된다.
/// 측정값(에너지·각운동량)은 실제 적분된 상태에서 직접 계산.
struct FreeGravityScene: View {
    struct Star: Identifiable {
        let id = UUID()
        var pos: Vec2
        var vel: Vec2
        var mass: Double
        var color: Color
    }

    @State private var G: Double = 1.0
    @State private var bodies: [Star] = []
    @State private var trails: [UUID: [Vec2]] = [:]
    private let trailMax = 600

    @State private var running = true
    @State private var lastTime: TimeInterval? = nil
    @State private var preset: Int = 0
    @State private var accels: [Vec2] = []

    var body: some View {
        SimChrome(
            blurb: "N≥3 다체 문제는 일반적으로 닫힌 해 없음 — Velocity-Verlet 수치 적분 사용 (총 운동량·각운동량·에너지는 수치오차 내 보존). 닫힌 해 1체 궤도는 \"케플러 궤도\" 시뮬 참조.",
            canvas: { canvas },
            controls: { controls })
            .onAppear { applyPreset() }
            .onChange(of: preset) { _, _ in applyPreset() }
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
            Picker("배치", selection: $preset) {
                Text("태양–행성 3개").tag(0)
                Text("이중성").tag(1)
                Text("3체 (피겨에이트)").tag(2)
                Text("8체 무작위").tag(3)
            }
            .pickerStyle(.segmented)
            LabeledSlider(title: "중력 상수 G", value: $G, range: 0.2...3,
                          format: "%.2f")
            PlayResetBar(running: $running, onReset: applyPreset)
            Divider()
            Readout(label: "별 수", value: "\(bodies.count)")
            let p = totalMomentum
            Readout(label: "총 운동량 (벡터)",
                    value: String(format: "(%.3f, %.3f)", p.x, p.y))
            Readout(label: "총 각운동량 L",
                    value: String(format: "%.3f", totalAngularMomentum))
            Readout(label: "총 에너지 (KE + PE)",
                    value: String(format: "%.3f", totalEnergy))
        }
    }

    // MARK: - 프리셋

    private func applyPreset() {
        trails.removeAll()
        switch preset {
        case 0: bodies = solarSystem3()
        case 1: bodies = binary()
        case 2: bodies = figureEight()
        case 3: bodies = randomEight()
        default: bodies = []
        }
        accels = computeAccelerations()
        lastTime = nil
    }

    private func solarSystem3() -> [Star] {
        let sun = Star(pos: .zero, vel: .zero, mass: 100, color: .yellow)
        var arr = [sun]
        for (i, (r, c)) in [(2.0, Color.cyan), (3.5, .green), (5.0, .pink)].enumerated() {
            // 원궤도 속력 √(GM/r). 별이 정지하도록 운동량 0 으로 보정 (별의 vel 조정).
            let v = sqrt(G * sun.mass / r)
            let theta = Double(i) * 2.1
            arr.append(Star(
                pos: Vec2(x: r * cos(theta), y: r * sin(theta)),
                vel: Vec2(x: -v * sin(theta), y: v * cos(theta)),
                mass: 0.5, color: c))
        }
        return zeroTotalMomentum(arr)
    }

    private func binary() -> [Star] {
        let m: Double = 10
        let r: Double = 2
        let v = sqrt(G * m / (4 * r))   // 두 별이 r 만큼 떨어져 서로 도는 원궤도 속력
        let a = Star(pos: Vec2(x: -r, y: 0), vel: Vec2(x: 0, y: -v),
                     mass: m, color: .yellow)
        let b = Star(pos: Vec2(x:  r, y: 0), vel: Vec2(x: 0, y:  v),
                     mass: m, color: .orange)
        return [a, b]
    }

    private func figureEight() -> [Star] {
        // Chenciner–Montgomery 의 유명한 3체 8자 해 (G = m = 1 단위).
        // body 1, 2 는 (0.466…, 0.432…) 의 속도, body 3 은 그 −2 배.
        let v12 = Vec2(x: 0.93240737 / 2, y: 0.86473146 / 2)
        let v3  = Vec2(x: -0.93240737, y: -0.86473146)
        return [
            Star(pos: Vec2(x: -0.97000436, y:  0.24308753), vel: v12, mass: 1, color: .cyan),
            Star(pos: Vec2(x:  0.97000436, y: -0.24308753), vel: v12, mass: 1, color: .green),
            Star(pos: Vec2.zero, vel: v3, mass: 1, color: .pink),
        ]
    }

    private func randomEight() -> [Star] {
        var rng = SystemRandomNumberGenerator()
        var arr: [Star] = []
        for _ in 0..<8 {
            let r = Double.random(in: 1...4, using: &rng)
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let pos = Vec2(x: r * cos(theta), y: r * sin(theta))
            let v = Double.random(in: 0.3...0.9, using: &rng)
            let vel = Vec2(x: -v * sin(theta), y: v * cos(theta))
            let m = Double.random(in: 0.5...3, using: &rng)
            arr.append(Star(
                pos: pos, vel: vel, mass: m,
                color: Color(hue: Double.random(in: 0...1, using: &rng),
                             saturation: 0.85, brightness: 1)))
        }
        return zeroTotalMomentum(arr)
    }

    /// 전체 운동량이 0 이 되도록 평균 속도를 빼준다 (관성계 고정).
    private func zeroTotalMomentum(_ bs: [Star]) -> [Star] {
        let totalMass = bs.reduce(0) { $0 + $1.mass }
        let mom = bs.reduce(Vec2.zero) { $0 + $1.vel * $1.mass }
        let dv = mom / totalMass
        return bs.map { Star(pos: $0.pos, vel: $0.vel - dv,
                             mass: $0.mass, color: $0.color) }
    }

    // MARK: - 동역학

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now
        let sub = 60
        let h = dt / Double(sub)
        for _ in 0..<sub { verletStep(h: h) }
        // 자취.
        for b in bodies {
            trails[b.id, default: []].append(b.pos)
            if trails[b.id]!.count > trailMax {
                let cnt = trails[b.id]!.count
                trails[b.id]!.removeFirst(cnt - trailMax)
            }
        }
    }

    /// Velocity-Verlet 한 스텝.
    private func verletStep(h: Double) {
        if accels.count != bodies.count { accels = computeAccelerations() }
        for i in bodies.indices {
            bodies[i].pos += bodies[i].vel * h + accels[i] * (0.5 * h * h)
        }
        let newAcc = computeAccelerations()
        for i in bodies.indices {
            bodies[i].vel += (accels[i] + newAcc[i]) * (0.5 * h)
        }
        accels = newAcc
    }

    private func computeAccelerations() -> [Vec2] {
        var a = [Vec2](repeating: .zero, count: bodies.count)
        let n = bodies.count
        for i in 0..<n {
            for j in 0..<n where j != i {
                let d = bodies[j].pos - bodies[i].pos
                let r2 = d.lengthSquared
                if r2 < 1e-4 { continue }
                let r = sqrt(r2)
                a[i] += d * (G * bodies[j].mass / (r2 * r))
            }
        }
        return a
    }

    // MARK: - 보존량

    private var totalMomentum: Vec2 {
        bodies.reduce(.zero) { $0 + $1.vel * $1.mass }
    }
    private var totalAngularMomentum: Double {
        bodies.reduce(0) { $0 + $1.mass * Vec2.cross($1.pos, $1.vel) }
    }
    private var totalEnergy: Double {
        var E = 0.0
        for b in bodies { E += 0.5 * b.mass * b.vel.lengthSquared }
        let n = bodies.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                let r = (bodies[j].pos - bodies[i].pos).length
                if r > 1e-3 {
                    E -= G * bodies[i].mass * bodies[j].mass / r
                }
            }
        }
        return E
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let extent = max(6.0, bodies.map { max(abs($0.pos.x), abs($0.pos.y)) }.max() ?? 6) * 1.4
        let world = CGRect(x: -extent, y: -extent, width: 2 * extent, height: 2 * extent)
        let map = CanvasMap(view: size, world: world, padding: 12)

        // 자취.
        for b in bodies {
            guard let trail = trails[b.id], !trail.isEmpty else { continue }
            var path = Path()
            for (i, p) in trail.enumerated() {
                let pt = map.point(p)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(b.color.opacity(0.45)), lineWidth: 1.1)
        }

        // 별.
        for b in bodies {
            let pt = map.point(b.pos)
            let r: CGFloat = CGFloat(4 + 2 * sqrt(b.mass))
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                            width: r * 2, height: r * 2)),
                     with: .color(b.color))
        }
    }
}

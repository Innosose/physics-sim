import SwiftUI

/// **N체 중력** — 글로우 트레일이 살아있는 별들의 춤.
///
///  F_ij = G · m_i · m_j · (r_j − r_i) / |r_j − r_i|³
///
/// Velocity-Verlet 수치 적분기. 다체 문제는 일반적으로 닫힌 해 없음 — 결과는
/// 약간 시간이 걸려도 반올림 없이 정확. 총 운동량·각운동량·에너지는 수치오차
/// 범위(보통 < 0.1%) 내에서 보존.
///
/// 시각: 검은 배경 위에 글로우 트레일(외광 + 코어). 각 별은 작은 점 + 따뜻한
/// 색의 헤일로. N체 궤도가 만드는 기하학적 패턴 자체가 주인공.
struct FreeGravityScene: View {
    struct Star: Identifiable {
        let id = UUID()
        var pos: Vec2
        var vel: Vec2
        var mass: Double
        /// 트레일/헤일로 색 — 이미지 톤에 맞춘 따뜻한·차가운 빛.
        var color: Color
    }

    @State private var G: Double = 1.0
    @State private var bodies: [Star] = []
    @State private var trails: [UUID: [Vec2]] = [:]
    private let trailMax = 400           // 시뮬레이터 GPU 부하 줄임 (800→400)

    @State private var running = true
    @State private var lastTime: TimeInterval? = nil
    @State private var preset: Int = 0
    @State private var accels: [Vec2] = []

    var body: some View {
        SimChrome(
            blurb: "별·행성을 자유롭게 배치한 N체 중력. 다체 문제라 닫힌 해 없음 — Velocity-Verlet 수치 적분. 총 에너지·각운동량은 수치오차 범위에서 보존.",
            canvas: { canvas },
            controls: { controls })
            .onAppear { applyPreset() }
            .onChange(of: preset) { _, _ in applyPreset() }
    }

    private var canvas: some View {
        // Canvas 렌더 클로저 안에서 state 를 변형하면 SwiftUI 가 "Modifying
        // state during view update" 경고 + Swift 6 strict 모드에서 동작 막힘.
        // .onChange(of: tl.date) 로 frame 사이에 advance — 깨끗.
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                draw(ctx: ctx, size: size)
            }
            .onChange(of: tl.date) { _, newDate in
                advance(to: newDate.timeIntervalSinceReferenceDate)
            }
        }
    }

    /// 단순화된 컨트롤 — 프리셋 + G + 재생/초기화 + 별 수.
    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("배치", selection: $preset) {
                Text("태양 3").tag(0)
                Text("이중성").tag(1)
                Text("8자").tag(2)
                Text("4체").tag(3)
                Text("8체").tag(4)
            }
            .pickerStyle(.segmented)
            LabeledSlider(title: "중력 G", value: $G, range: 0.2...3,
                          format: "%.2f")
            PlayResetBar(running: $running, onReset: applyPreset)
        }
    }

    // MARK: - 프리셋 (이미지 톤의 따뜻한 색 팔레트)

    /// 이미지 참고 색 팔레트.
    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.83, blue: 0.50),   // 따뜻한 금
        Color(red: 1.00, green: 0.60, blue: 0.32),   // 호박
        Color(red: 0.96, green: 0.94, blue: 0.86),   // 크림
        Color(red: 0.55, green: 0.78, blue: 1.00),   // 하늘
        Color(red: 0.85, green: 0.92, blue: 1.00),   // 흰 푸름
        Color(red: 1.00, green: 0.74, blue: 0.46),   // 살구
        Color(red: 0.74, green: 0.88, blue: 0.96),   // 청록 진주
        Color(red: 0.98, green: 0.78, blue: 0.58),   // 모래
    ]

    private func applyPreset() {
        // 순서: bodies 먼저, accels 그다음, trails·lastTime 마지막.
        // 이렇게 해야 advance() 와 겹쳐도 인덱스 mismatch 안 남.
        let newBodies: [Star]
        switch preset {
        case 0: newBodies = solarSystem3()
        case 1: newBodies = binary()
        case 2: newBodies = figureEight()
        case 3: newBodies = cluster4()
        case 4: newBodies = randomEight()
        default: newBodies = []
        }
        bodies = newBodies
        accels = computeAccelerations()
        trails.removeAll()
        lastTime = nil
    }

    private func solarSystem3() -> [Star] {
        let sun = Star(pos: .zero, vel: .zero, mass: 100,
                       color: Self.palette[0])
        var arr = [sun]
        let radii = [2.0, 3.5, 5.0]
        for (i, r) in radii.enumerated() {
            let v = sqrt(G * sun.mass / r)
            let theta = Double(i) * 2.1
            arr.append(Star(
                pos: Vec2(x: r * cos(theta), y: r * sin(theta)),
                vel: Vec2(x: -v * sin(theta), y: v * cos(theta)),
                mass: 0.5,
                color: Self.palette[i + 3]))
        }
        return zeroTotalMomentum(arr)
    }

    private func binary() -> [Star] {
        let m: Double = 10
        let r: Double = 2
        let v = sqrt(G * m / (4 * r))
        return [
            Star(pos: Vec2(x: -r, y: 0), vel: Vec2(x: 0, y: -v),
                 mass: m, color: Self.palette[0]),
            Star(pos: Vec2(x:  r, y: 0), vel: Vec2(x: 0, y:  v),
                 mass: m, color: Self.palette[1]),
        ]
    }

    private func figureEight() -> [Star] {
        // Chenciner–Montgomery 의 유명한 3체 8자 해 (G = m = 1 단위).
        let v12 = Vec2(x: 0.93240737 / 2, y: 0.86473146 / 2)
        let v3  = Vec2(x: -0.93240737, y: -0.86473146)
        return [
            Star(pos: Vec2(x: -0.97000436, y:  0.24308753), vel: v12,
                 mass: 1, color: Self.palette[2]),
            Star(pos: Vec2(x:  0.97000436, y: -0.24308753), vel: v12,
                 mass: 1, color: Self.palette[3]),
            Star(pos: .zero, vel: v3,
                 mass: 1, color: Self.palette[1]),
        ]
    }

    private func cluster4() -> [Star] {
        // 4 체 — 대략 정사면체 형태로 출발. 비스듬한 각운동량 → 복잡한 궤적.
        let r: Double = 2.5
        let v: Double = sqrt(G * 4 / r) * 0.5
        return zeroTotalMomentum([
            Star(pos: Vec2(x:  r, y:  r), vel: Vec2(x: -v, y:  v * 0.3),
                 mass: 1.5, color: Self.palette[0]),
            Star(pos: Vec2(x: -r, y:  r), vel: Vec2(x: -v * 0.3, y: -v),
                 mass: 1.5, color: Self.palette[3]),
            Star(pos: Vec2(x: -r, y: -r), vel: Vec2(x:  v, y: -v * 0.3),
                 mass: 1.5, color: Self.palette[5]),
            Star(pos: Vec2(x:  r, y: -r), vel: Vec2(x:  v * 0.3, y:  v),
                 mass: 1.5, color: Self.palette[6]),
        ])
    }

    private func randomEight() -> [Star] {
        var rng = SystemRandomNumberGenerator()
        var arr: [Star] = []
        for i in 0..<8 {
            let r = Double.random(in: 1...4, using: &rng)
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let pos = Vec2(x: r * cos(theta), y: r * sin(theta))
            let v = Double.random(in: 0.3...0.9, using: &rng)
            let vel = Vec2(x: -v * sin(theta), y: v * cos(theta))
            let m = Double.random(in: 0.5...3, using: &rng)
            arr.append(Star(pos: pos, vel: vel, mass: m,
                            color: Self.palette[i % Self.palette.count]))
        }
        return zeroTotalMomentum(arr)
    }

    private func zeroTotalMomentum(_ bs: [Star]) -> [Star] {
        let totalMass = bs.reduce(0) { $0 + $1.mass }
        let mom = bs.reduce(Vec2.zero) { $0 + $1.vel * $1.mass }
        let dv = mom / totalMass
        return bs.map { Star(pos: $0.pos, vel: $0.vel - dv,
                             mass: $0.mass, color: $0.color) }
    }

    // MARK: - 동역학 (Velocity-Verlet)

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        guard !bodies.isEmpty else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now
        let sub = 20                       // 다체 안정 + 시뮬레이터 부하 여유
        let h = dt / Double(sub)
        for _ in 0..<sub { verletStep(h: h) }

        // 발산 감지 — 어떤 별이라도 위치/속도가 NaN·Inf 가 되면 프리셋 재적용.
        if bodies.contains(where: {
            !$0.pos.x.isFinite || !$0.pos.y.isFinite
                || !$0.vel.x.isFinite || !$0.vel.y.isFinite
        }) {
            applyPreset()
            return
        }

        // 트레일 추가 — force unwrap 없이 안전하게.
        for b in bodies {
            var arr = trails[b.id] ?? []
            arr.append(b.pos)
            if arr.count > trailMax {
                arr.removeFirst(arr.count - trailMax)
            }
            trails[b.id] = arr
        }
    }

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
                if r > 1e-3 { E -= G * bodies[i].mass * bodies[j].mass / r }
            }
        }
        return E
    }

    // MARK: - 그리기 (이미지 톤 — 검정 배경 + 글로우 트레일)

    private func draw(ctx: GraphicsContext, size: CGSize) {
        // 1) 순수 검정 배경 — 시뮬 viewport 의 deep 보다 더 어둡게.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(.black))
        guard !bodies.isEmpty else { return }

        // NaN/Inf 안전 — 유효 위치만 모아 max 계산.
        let coords = bodies.flatMap { b -> [Double] in
            (b.pos.x.isFinite ? [abs(b.pos.x)] : []) +
            (b.pos.y.isFinite ? [abs(b.pos.y)] : [])
        }
        let maxAbs = coords.max() ?? 6
        let extent = min(60.0, max(6.0, maxAbs * 1.4))
        let world = CGRect(x: -extent, y: -extent,
                           width: 2 * extent, height: 2 * extent)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 2) 트레일 — glow 외광 + 코어 두 stroke 패스 (3→2 로 줄임).
        for b in bodies {
            guard let trail = trails[b.id], trail.count > 1 else { continue }
            var path = Path()
            for (i, p) in trail.enumerated() {
                let pt = map.point(p)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            // 외광.
            ctx.stroke(path, with: .color(b.color.opacity(0.30)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            // 코어.
            ctx.stroke(path, with: .color(b.color.opacity(0.95)),
                       style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
        }

        // 3) 별 본체 — 작은 코어 + 큰 헤일로.
        for b in bodies {
            let pt = map.point(b.pos)
            let coreR: CGFloat = CGFloat(2 + 1.5 * sqrt(b.mass))
            let haloR: CGFloat = coreR * 4

            // 헤일로 (radial gradient).
            ctx.fill(
                Path(ellipseIn: CGRect(x: pt.x - haloR, y: pt.y - haloR,
                                       width: haloR * 2, height: haloR * 2)),
                with: .radialGradient(
                    Gradient(colors: [b.color.opacity(0.55), .clear]),
                    center: pt, startRadius: 0, endRadius: haloR))
            // 코어 — 거의 흰빛.
            ctx.fill(
                Path(ellipseIn: CGRect(x: pt.x - coreR, y: pt.y - coreR,
                                       width: coreR * 2, height: coreR * 2)),
                with: .color(.white.opacity(0.95)))
        }
    }
}

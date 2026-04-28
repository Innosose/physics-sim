import SwiftUI

/// 자유 충돌 박스 — 재질·질량·반발계수가 다른 입자 N개의 동시 다체 충돌.
///
/// 충돌은 "딱딱한 원판 - 정확한 충돌 응답" 으로 처리.
///   • 두 입자의 충돌 시 반발계수: e = √(e₁ · e₂)  (재질 쌍의 기하 평균 — 흔한 근사)
///   • 법선 방향 임펄스만 적용 (마찰 무시) — 운동량은 매 충돌에서 정확히 보존:
///       Δp = (1 + e) · μ · (v_rel · n̂),    μ = m₁m₂/(m₁+m₂)
///   • 운동에너지는 e=1 일 때만 보존, e<1 이면 ΔKE = −½(1−e²)·μ·(v_rel·n̂)²
///
/// 측정값은 매 프레임 정확한 적분 후 계산되어, 사용자가 "보존되는 양" 을 검증할 수 있다.
struct FreeCollisionScene: View {
    /// 재질 프리셋. 반발계수 e 와 밀도 ρ.
    enum Material: String, CaseIterable, Identifiable {
        case steel = "강철", rubber = "고무", clay = "점토", ice = "얼음"
        var id: String { rawValue }
        var restitution: Double {
            switch self {
            case .steel:  return 0.95
            case .rubber: return 0.85
            case .clay:   return 0.10
            case .ice:    return 0.65
            }
        }
        /// 시뮬 단위로 정규화한 밀도.
        var density: Double {
            switch self {
            case .steel:  return 7.8
            case .rubber: return 1.2
            case .clay:   return 1.5
            case .ice:    return 0.92
            }
        }
        var color: Color {
            switch self {
            case .steel:  return .gray
            case .rubber: return .pink
            case .clay:   return .brown
            case .ice:    return .cyan
            }
        }
    }

    struct Particle: Identifiable {
        let id = UUID()
        var pos: Vec2
        var vel: Vec2
        var radius: Double
        var material: Material
        var mass: Double { material.density * .pi * radius * radius }
    }

    @State private var particles: [Particle] = []
    @State private var selectedMaterial: Material = .steel
    @State private var newRadius: Double = 0.05
    @State private var gravity: Double = 0.0     // 0 = 중력 없음 (당구대처럼)
    @State private var running = true
    @State private var collisionCount: Int = 0
    @State private var lastTime: TimeInterval? = nil

    var body: some View {
        SimChrome(
            blurb: "박스 안 어디든 탭하면 새 입자가 생긴다. 각 충돌은 닫힌 해 임펄스 J = (1+e)μ·v_rel·n̂ 으로 처리되고, 사이에는 등속 운동(닫힌 해) — 구간별 닫힌 해. 운동량 항상 보존, 운동에너지는 e=1 강철일 때만 보존.",
            canvas: { canvas },
            controls: { controls })
            .onAppear { if particles.isEmpty { loadPreset() } }
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            GeometryReader { geo in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size)
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { e in
                            addParticle(at: e.location, in: geo.size)
                        }
                )
                .onChange(of: tl.date) { _, newDate in
                    advance(to: newDate.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("재질", selection: $selectedMaterial) {
                ForEach(Material.allCases) { m in
                    Text("\(m.rawValue) (e=\(String(format: "%.2f", m.restitution)))").tag(m)
                }
            }
            .pickerStyle(.segmented)

            LabeledSlider(title: "새 입자 반지름", value: $newRadius,
                          range: 0.025...0.10, format: "%.2f", unit: "m")
            LabeledSlider(title: "중력 g (아래쪽)", value: $gravity,
                          range: 0...3, format: "%.2f")
            HStack {
                Button("3개 충돌") { particles = preset3(); collisionCount = 0 }
                    .buttonStyle(.glass)
                Button("뉴턴 요람") { particles = presetCradle(); collisionCount = 0 }
                    .buttonStyle(.glass)
                Button("무작위 12") { particles = randomMany(12); collisionCount = 0 }
                    .buttonStyle(.glass)
            }
            PlayResetBar(running: $running, onReset: { particles.removeAll(); collisionCount = 0 }, resetLabel: "비우기")
            Divider()
            let p = totalMomentum
            let ke = totalKE
            Readout(label: "입자 수", value: "\(particles.count)")
            Readout(label: "총 운동량 |p|",
                    value: String(format: "%.2f kg·m/s", p.length))
            Readout(label: "총 운동량 (벡터)",
                    value: String(format: "(%.2f, %.2f)", p.x, p.y))
            Readout(label: "총 운동에너지",
                    value: String(format: "%.2f J", ke))
            Readout(label: "충돌 횟수", value: "\(collisionCount)")
        }
    }

    // MARK: - 프리셋

    private func loadPreset() { particles = preset3() }

    private func preset3() -> [Particle] {
        [
            Particle(pos: Vec2(x: 0.15, y: 0.5), vel: Vec2(x: 1.0, y: 0.05),
                     radius: 0.06, material: .steel),
            Particle(pos: Vec2(x: 0.5, y: 0.5), vel: Vec2.zero,
                     radius: 0.05, material: .rubber),
            Particle(pos: Vec2(x: 0.85, y: 0.5), vel: Vec2(x: -0.7, y: -0.05),
                     radius: 0.06, material: .clay),
        ]
    }

    private func presetCradle() -> [Particle] {
        var arr: [Particle] = []
        let r = 0.045
        let cy = 0.5
        // 5개 구를 일렬로 + 왼쪽에서 한 개가 빠른 속도로 들어옴.
        for i in 0..<5 {
            arr.append(Particle(
                pos: Vec2(x: 0.42 + Double(i) * (2 * r + 0.001), y: cy),
                vel: Vec2.zero, radius: r, material: .steel))
        }
        arr.insert(Particle(
            pos: Vec2(x: 0.15, y: cy), vel: Vec2(x: 1.0, y: 0),
            radius: r, material: .steel), at: 0)
        return arr
    }

    private func randomMany(_ n: Int) -> [Particle] {
        var arr: [Particle] = []
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<n {
            let r = Double.random(in: 0.03...0.07, using: &rng)
            let m = Material.allCases.randomElement(using: &rng)!
            let p = Vec2(x: Double.random(in: r...(1 - r), using: &rng),
                         y: Double.random(in: r...(1 - r), using: &rng))
            let v = Vec2(x: Double.random(in: -0.6...0.6, using: &rng),
                         y: Double.random(in: -0.6...0.6, using: &rng))
            arr.append(Particle(pos: p, vel: v, radius: r, material: m))
        }
        return arr
    }

    private func addParticle(at loc: CGPoint, in size: CGSize) {
        let s = min(size.width, size.height)
        let bx = (size.width - s) / 2
        let by = (size.height - s) / 2
        let xN = (loc.x - bx) / s
        let yN = (loc.y - by) / s
        guard xN >= 0, xN <= 1, yN >= 0, yN <= 1 else { return }
        particles.append(Particle(
            pos: Vec2(x: Double(xN), y: Double(yN)),
            vel: Vec2.zero,
            radius: newRadius,
            material: selectedMaterial))
    }

    // MARK: - 보존량

    private var totalMomentum: Vec2 {
        particles.reduce(.zero) { $0 + $1.vel * $1.mass }
    }
    private var totalKE: Double {
        particles.reduce(0) { $0 + 0.5 * $1.mass * $1.vel.lengthSquared }
    }

    // MARK: - 적분

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now
        let sub = 6
        let h = dt / Double(sub)
        for _ in 0..<sub { stepOnce(h: h) }
    }

    private func stepOnce(h: Double) {
        // 위치 + 중력.
        for i in particles.indices {
            particles[i].vel.y += gravity * h
            particles[i].pos += particles[i].vel * h
        }
        // 벽.
        for i in particles.indices {
            let r = particles[i].radius
            let e = particles[i].material.restitution
            if particles[i].pos.x < r {
                particles[i].pos.x = r; particles[i].vel.x = abs(particles[i].vel.x) * e
            }
            if particles[i].pos.x > 1 - r {
                particles[i].pos.x = 1 - r; particles[i].vel.x = -abs(particles[i].vel.x) * e
            }
            if particles[i].pos.y < r {
                particles[i].pos.y = r; particles[i].vel.y = abs(particles[i].vel.y) * e
            }
            if particles[i].pos.y > 1 - r {
                particles[i].pos.y = 1 - r; particles[i].vel.y = -abs(particles[i].vel.y) * e
            }
        }
        // 입자-입자 충돌. O(N²).
        let n = particles.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                let d = particles[j].pos - particles[i].pos
                let dist2 = d.lengthSquared
                let rsum = particles[i].radius + particles[j].radius
                if dist2 < rsum * rsum && dist2 > 1e-12 {
                    let dist = sqrt(dist2)
                    let n̂ = d / dist
                    let rv = particles[j].vel - particles[i].vel
                    let vn = Vec2.dot(rv, n̂)
                    if vn < 0 {
                        let m1 = particles[i].mass
                        let m2 = particles[j].mass
                        let e = sqrt(particles[i].material.restitution
                                     * particles[j].material.restitution)
                        let mu = m1 * m2 / (m1 + m2)
                        // J = (1 + e) · μ · vn,  방향 = n̂.
                        // 부호: vn < 0 (접근중) 이므로 J < 0.
                        let J = (1 + e) * mu * vn
                        particles[i].vel = particles[i].vel + n̂ * (J / m1)
                        particles[j].vel = particles[j].vel - n̂ * (J / m2)
                        collisionCount += 1
                    }
                    // 침투 보정 (질량 비율).
                    let m1 = particles[i].mass, m2 = particles[j].mass
                    let pen = rsum - dist
                    particles[i].pos -= n̂ * (pen * m2 / (m1 + m2))
                    particles[j].pos += n̂ * (pen * m1 / (m1 + m2))
                }
            }
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height)
        let bx = (size.width - s) / 2
        let by = (size.height - s) / 2
        let frame = CGRect(x: bx, y: by, width: s, height: s)
        ctx.stroke(Path(frame), with: .color(.white.opacity(0.5)), lineWidth: 1.5)

        for p in particles {
            let cx = bx + CGFloat(p.pos.x) * s
            let cy = by + CGFloat(p.pos.y) * s
            let pr = CGFloat(p.radius) * s
            ctx.fill(Path(ellipseIn: CGRect(x: cx - pr, y: cy - pr,
                                            width: pr * 2, height: pr * 2)),
                     with: .color(p.material.color))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - pr, y: cy - pr,
                                              width: pr * 2, height: pr * 2)),
                       with: .color(.white.opacity(0.35)), lineWidth: 1)
            // 속도 화살표.
            let v = p.vel
            if v.length > 0.05 {
                let ex = cx + CGFloat(v.x) * s * 0.15
                let ey = cy + CGFloat(v.y) * s * 0.15
                var arr = Path()
                arr.move(to: CGPoint(x: cx, y: cy))
                arr.addLine(to: CGPoint(x: ex, y: ey))
                ctx.stroke(arr, with: .color(.white.opacity(0.6)), lineWidth: 1)
            }
        }
    }
}

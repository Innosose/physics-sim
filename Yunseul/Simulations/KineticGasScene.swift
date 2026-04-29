import SwiftUI

/// 2D 기체 분자 운동.
///
/// N 개의 딱딱한 원판이 박스 안에서 탄성 충돌. 박스 충돌 + 입자 간 충돌 모두 처리.
/// 우측 그래프에 속력의 분포를 누적해 표시 → 시간이 지나면 맥스웰–볼츠만에 수렴.
struct KineticGasScene: View {
    @State private var N: Double = 80
    @State private var temperatureScale: Double = 1.0   // 초기 속력 스케일
    @State private var heaterOn: Bool = false           // 왼쪽 벽이 뜨거우면 가속 (rough thermostat)
    @State private var running = true

    /// 물리 상태는 reference type 에 보관 — N체와 같은 패턴.
    /// `@State` 로 두면 입자·히스토그램이 매 advance 마다 SwiftUI diff 를 트리거
    /// → 입자 수·bin 수가 늘면 부하 폭증. Canvas 는 TimelineView tick 으로 재실행되므로
    /// 관찰 불필요.
    private final class World {
        var particles: [Particle] = []
        var histAcc: [Double] = []
        var lastTime: TimeInterval? = nil
        var baselineKE: Double = 0
        /// readout 갱신 throttle 용 카운터.
        var framesSinceDisplayBump: Int = 0
    }

    @State private var world = World()
    /// reset/preset 로 Canvas 를 강제 재생성할 때 .id() 에 묶음 — 애니메이션 중엔 변하지 않음.
    @State private var redrawTick: Int = 0
    /// controls 패널의 readout(평균 속력·KE·ΔE) 을 ~10 Hz 로 갱신하기 위한 tick.
    /// world 가 class 라 내부 mutation 만으로는 SwiftUI 재렌더가 안 일어남 — 이 값을
    /// throttled 로 bump 해 body 재계산을 유도.
    @State private var displayTick: Int = 0

    private let radius = 0.012
    private let mass = 1.0
    private let histBins = 30

    struct Particle { var pos: Vec2; var vel: Vec2 }

    var body: some View {
        // displayTick 을 명시적으로 read — SwiftUI 가 이 @State 의 변경을 의존성으로
        // 잡아 controls 패널의 readout 을 ~10 Hz 로 갱신하도록 보장.
        let _ = displayTick
        return SimChrome(
                  blurb: "초기에 모두 같은 속력이라도, 충돌만으로 속력 분포는 맥스웰–볼츠만 모양으로 수렴. 각 충돌은 닫힌 해 임펄스, 사이는 등속 — 구간별 닫힌 해. 평형 분포 자체는 통계역학의 닫힌 해.",
                  canvas: { canvas },
                  controls: { controls })
            .onAppear { reset() }
    }

    private func onSliderEnd(_ editing: Bool) { if !editing { reset() } }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                draw(ctx: ctx, size: size)
            }
            .onChange(of: tl.date) { _, newDate in
                advance(to: newDate.timeIntervalSinceReferenceDate)
            }
        }
        .id(redrawTick)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "입자 수 N", value: $N, range: 20...300, step: 1,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "초기 속력 스케일", value: $temperatureScale, range: 0.2...3,
                          format: "%.2f")
            Toggle("왼쪽 벽 가열 (열 흐름 관찰)", isOn: $heaterOn)
            PlayResetBar(running: $running, onReset: reset)
            Divider()
            let speeds = world.particles.map { $0.vel.length }
            let mean = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
            let ke = world.particles.reduce(0) { $0 + 0.5 * mass * $1.vel.lengthSquared }
            Readout(label: "평균 속력 ⟨|v|⟩", value: String(format: "%.2f", mean))
            Readout(label: "총 운동에너지", value: String(format: "%.2f", ke))
            // 보존량 검증 — 벽은 탄성 (heaterOn 제외) 이라 ΔE/E₀ ≈ 0 이어야 정상.
            // heaterOn 일 때는 왼쪽 벽이 매 충돌 ×1.02 → KE 가 단조 증가해야 함.
            if world.baselineKE > 1e-6 {
                let dke = (ke - world.baselineKE) / world.baselineKE * 100
                Readout(label: heaterOn ? "에너지 증가 (가열)" : "에너지 변화 ΔE/E₀",
                        value: String(format: "%+.2f %%", dke))
            }
        }
    }

    // MARK: - 초기화 & 적분

    private func reset() {
        let n = Int(N)
        var rng = SystemRandomNumberGenerator()
        var arr: [Particle] = []
        arr.reserveCapacity(n)
        // grid 배치로 겹침 방지.
        let cols = max(1, Int(Double(n).squareRoot().rounded(.up)))
        let cell = (1 - 4 * radius) / Double(cols)
        var i = 0
        for ix in 0..<cols {
            for iy in 0..<cols {
                if i >= n { break }
                let x = 2 * radius + cell * (Double(ix) + 0.5)
                let y = 2 * radius + cell * (Double(iy) + 0.5)
                // 임의 방향, 동일 속력 (스케일 적용).
                let theta = Double.random(in: 0...(2 * .pi), using: &rng)
                let speed = 0.4 * temperatureScale
                arr.append(Particle(pos: Vec2(x: x, y: y),
                                    vel: Vec2(x: speed * cos(theta),
                                              y: speed * sin(theta))))
                i += 1
            }
        }
        world.particles = arr
        world.histAcc = [Double](repeating: 0, count: histBins)
        world.lastTime = nil
        world.baselineKE = arr.reduce(0) { $0 + 0.5 * mass * $1.vel.lengthSquared }
        redrawTick &+= 1
    }

    private func advance(to now: TimeInterval) {
        guard let last = world.lastTime else { world.lastTime = now; return }
        guard running else { world.lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        world.lastTime = now

        let sub = 4
        let h = dt / Double(sub)
        for _ in 0..<sub {
            stepOnce(h: h)
        }

        // 히스토그램 누적.
        let maxV = 1.5
        for p in world.particles {
            let bin = min(histBins - 1, Int(p.vel.length / maxV * Double(histBins)))
            world.histAcc[bin] += 1
        }

        // readout 갱신 — 6 프레임마다 (≈ 10 Hz). 매 프레임 bump 하면 reference type
        // 으로 옮긴 의미가 사라지고, 안 bump 하면 controls 패널이 얼어붙음.
        world.framesSinceDisplayBump += 1
        if world.framesSinceDisplayBump >= 6 {
            world.framesSinceDisplayBump = 0
            displayTick &+= 1
        }
    }

    private func stepOnce(h: Double) {
        // 위치 업데이트.
        for i in world.particles.indices {
            world.particles[i].pos += world.particles[i].vel * h
        }
        // 박스 벽 충돌.
        for i in world.particles.indices {
            if world.particles[i].pos.x < radius {
                world.particles[i].pos.x = radius
                world.particles[i].vel.x = abs(world.particles[i].vel.x)
                if heaterOn { world.particles[i].vel = world.particles[i].vel * 1.02 }
            }
            if world.particles[i].pos.x > 1 - radius {
                world.particles[i].pos.x = 1 - radius
                world.particles[i].vel.x = -abs(world.particles[i].vel.x)
            }
            if world.particles[i].pos.y < radius {
                world.particles[i].pos.y = radius
                world.particles[i].vel.y = abs(world.particles[i].vel.y)
            }
            if world.particles[i].pos.y > 1 - radius {
                world.particles[i].pos.y = 1 - radius
                world.particles[i].vel.y = -abs(world.particles[i].vel.y)
            }
        }
        // O(N²) 페어 충돌. N≤300 이면 충분.
        let n = world.particles.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                let d = world.particles[j].pos - world.particles[i].pos
                let dist2 = d.lengthSquared
                let r2 = (2 * radius) * (2 * radius)
                if dist2 < r2 && dist2 > 1e-12 {
                    let dist = sqrt(dist2)
                    let n̂ = d / dist
                    let rv = world.particles[j].vel - world.particles[i].vel
                    let vn = Vec2.dot(rv, n̂)
                    if vn < 0 {
                        // 동일 질량 탄성: 법선 성분만 교환.
                        let imp = vn
                        world.particles[i].vel = world.particles[i].vel + n̂ * imp
                        world.particles[j].vel = world.particles[j].vel - n̂ * imp
                    }
                    // 침투 보정.
                    let pen = 2 * radius - dist
                    world.particles[i].pos -= n̂ * (pen / 2)
                    world.particles[j].pos += n̂ * (pen / 2)
                }
            }
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        // 좌측: 박스, 우측: 히스토그램.
        let split = size.width * 0.62
        let boxRect = CGRect(x: 8, y: 8, width: split - 16, height: size.height - 16)
        let histRect = CGRect(x: split + 8, y: 8,
                              width: size.width - split - 16, height: size.height - 16)
        drawBox(ctx: ctx, in: boxRect)
        drawHistogram(ctx: ctx, in: histRect)
    }

    private func drawBox(ctx: GraphicsContext, in r: CGRect) {
        // 가능하면 정사각형.
        let s = min(r.width, r.height)
        let bx = r.minX + (r.width - s) / 2
        let by = r.minY + (r.height - s) / 2
        let frame = CGRect(x: bx, y: by, width: s, height: s)
        // 배경 + 테두리.
        if heaterOn {
            // 왼쪽 벽 살짝 빨갛게.
            let grad = Gradient(colors: [Color.red.opacity(0.15), Color.clear])
            ctx.fill(Path(frame),
                     with: .linearGradient(grad,
                                           startPoint: CGPoint(x: frame.minX, y: frame.midY),
                                           endPoint: CGPoint(x: frame.minX + 60, y: frame.midY)))
        }
        ctx.stroke(Path(frame), with: .color(.white.opacity(0.5)), lineWidth: 1.5)

        let pr = CGFloat(radius) * s
        for p in world.particles {
            let cx = bx + CGFloat(p.pos.x) * s
            let cy = by + CGFloat(p.pos.y) * s
            let speed = p.vel.length
            let hue = max(0, min(0.7, 0.7 - speed * 0.5))    // 빠를수록 빨강
            ctx.fill(Path(ellipseIn: CGRect(x: cx - pr, y: cy - pr,
                                            width: pr * 2, height: pr * 2)),
                     with: .color(Color(hue: hue, saturation: 0.85, brightness: 1)))
        }
    }

    private func drawHistogram(ctx: GraphicsContext, in r: CGRect) {
        ctx.draw(Text("속력 분포 (누적)").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 60, y: r.minY + 10))
        var axis = Path()
        axis.move(to: CGPoint(x: r.minX + 4, y: r.maxY - 14))
        axis.addLine(to: CGPoint(x: r.maxX - 4, y: r.maxY - 14))
        ctx.stroke(axis, with: .color(.white.opacity(0.3)), lineWidth: 1)

        let bw = (r.width - 8) / CGFloat(histBins)
        let maxBin = max(0.001, world.histAcc.max() ?? 0.001)
        for (i, v) in world.histAcc.enumerated() {
            let h = CGFloat(v / maxBin) * (r.height - 40)
            let x = r.minX + 4 + CGFloat(i) * bw
            let bar = CGRect(x: x + 1, y: r.maxY - 14 - h,
                             width: bw - 2, height: h)
            ctx.fill(Path(bar), with: .color(.green.opacity(0.7)))
        }
        // 맥스웰–볼츠만 (2D) 이론 곡선: f(v) ∝ v · exp(-v²/(2σ²)).
        let speeds = world.particles.map { $0.vel.length }
        guard !speeds.isEmpty else { return }
        let mean2 = speeds.reduce(0) { $0 + $1 * $1 } / Double(speeds.count)
        let sigma2 = mean2 / 2
        // 모든 입자가 정지(σ²=0) 면 분포 자체가 정의 안됨 — 이론 곡선 생략.
        guard sigma2 > 1e-9 else { return }
        var theory = Path()
        let n = 200
        let vmax = 1.5
        var maxF = 0.0
        var fs = [Double]()
        for i in 0...n {
            let v = vmax * Double(i) / Double(n)
            let fv = v / sigma2 * exp(-v * v / (2 * sigma2))
            fs.append(fv); maxF = max(maxF, fv)
        }
        for (i, fv) in fs.enumerated() {
            let f = CGFloat(i) / CGFloat(n)
            let px = r.minX + 4 + f * (r.width - 8)
            let py = r.maxY - 14 - CGFloat(fv / maxF) * (r.height - 40)
            if i == 0 { theory.move(to: CGPoint(x: px, y: py)) }
            else { theory.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(theory, with: .color(.orange), lineWidth: 1.5)
    }
}

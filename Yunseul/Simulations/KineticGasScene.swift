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

    @State private var particles: [Particle] = []
    @State private var lastTime: TimeInterval? = nil

    private let radius = 0.012
    private let mass = 1.0
    private let histBins = 30
    @State private var histAcc = [Double](repeating: 0, count: 30)

    struct Particle { var pos: Vec2; var vel: Vec2 }

    var body: some View {
        SimChrome(
                  blurb: "초기에 모두 같은 속력이라도, 입자 간 충돌만으로 속력 분포는 맥스웰–볼츠만 모양으로 가까워진다.",
                  canvas: { canvas },
                  controls: { controls })
            .onAppear { reset() }
    }

    private func onSliderEnd(_ editing: Bool) { if !editing { reset() } }

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
            LabeledSlider(title: "입자 수 N", value: $N, range: 20...300, step: 1,
                          format: "%.0f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "초기 속력 스케일", value: $temperatureScale, range: 0.2...3,
                          format: "%.2f")
            Toggle("왼쪽 벽 가열 (열 흐름 관찰)", isOn: $heaterOn)
            PlayResetBar(running: $running, onReset: reset)
            Divider()
            let speeds = particles.map { $0.vel.length }
            let mean = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
            let ke = particles.reduce(0) { $0 + 0.5 * mass * $1.vel.lengthSquared }
            Readout(label: "평균 속력 ⟨|v|⟩", value: String(format: "%.3f", mean))
            Readout(label: "총 운동에너지", value: String(format: "%.2f", ke))
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
        particles = arr
        histAcc = [Double](repeating: 0, count: histBins)
        lastTime = nil
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now

        let sub = 4
        let h = dt / Double(sub)
        for _ in 0..<sub {
            stepOnce(h: h)
        }

        // 히스토그램 누적.
        let maxV = 1.5
        for p in particles {
            let bin = min(histBins - 1, Int(p.vel.length / maxV * Double(histBins)))
            histAcc[bin] += 1
        }
    }

    private func stepOnce(h: Double) {
        // 위치 업데이트.
        for i in particles.indices {
            particles[i].pos += particles[i].vel * h
        }
        // 박스 벽 충돌.
        for i in particles.indices {
            if particles[i].pos.x < radius {
                particles[i].pos.x = radius
                particles[i].vel.x = abs(particles[i].vel.x)
                if heaterOn { particles[i].vel = particles[i].vel * 1.02 }   // 가열
            }
            if particles[i].pos.x > 1 - radius {
                particles[i].pos.x = 1 - radius; particles[i].vel.x = -abs(particles[i].vel.x)
            }
            if particles[i].pos.y < radius {
                particles[i].pos.y = radius; particles[i].vel.y = abs(particles[i].vel.y)
            }
            if particles[i].pos.y > 1 - radius {
                particles[i].pos.y = 1 - radius; particles[i].vel.y = -abs(particles[i].vel.y)
            }
        }
        // O(N²) 페어 충돌. N≤300 이면 충분.
        let n = particles.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                let d = particles[j].pos - particles[i].pos
                let dist2 = d.lengthSquared
                let r2 = (2 * radius) * (2 * radius)
                if dist2 < r2 && dist2 > 1e-12 {
                    let dist = sqrt(dist2)
                    let n̂ = d / dist
                    // 접근중인지.
                    let rv = particles[j].vel - particles[i].vel
                    let vn = Vec2.dot(rv, n̂)
                    if vn < 0 {
                        // 동일 질량 탄성: 법선 성분만 교환.
                        let imp = vn   // 동일 질량 m=1
                        particles[i].vel = particles[i].vel + n̂ * imp
                        particles[j].vel = particles[j].vel - n̂ * imp
                    }
                    // 침투 보정.
                    let pen = 2 * radius - dist
                    particles[i].pos -= n̂ * (pen / 2)
                    particles[j].pos += n̂ * (pen / 2)
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
        for p in particles {
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
        let maxBin = max(0.001, histAcc.max() ?? 0.001)
        for (i, v) in histAcc.enumerated() {
            let h = CGFloat(v / maxBin) * (r.height - 40)
            let x = r.minX + 4 + CGFloat(i) * bw
            let bar = CGRect(x: x + 1, y: r.maxY - 14 - h,
                             width: bw - 2, height: h)
            ctx.fill(Path(bar), with: .color(.green.opacity(0.7)))
        }
        // 맥스웰–볼츠만 (2D) 이론 곡선: f(v) ∝ v · exp(-v²/(2σ²)).
        let speeds = particles.map { $0.vel.length }
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

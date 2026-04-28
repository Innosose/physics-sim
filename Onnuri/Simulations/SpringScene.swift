import SwiftUI

/// 감쇠·구동 단진동.
///
///  m·ẍ + c·ẋ + k·x = F₀·cos(ω_d t)
///
/// 우측 패널에 정상상태 진폭 |X(ω)| 의 공명 곡선과 현재 ω_d 위치를 표시.
struct SpringScene: View {
    @State private var mass: Double = 1.0          // kg
    @State private var stiffness: Double = 25.0    // N/m
    @State private var damping: Double = 0.6       // N·s/m
    @State private var driveAmp: Double = 5.0      // N
    @State private var driveOmega: Double = 5.0    // rad/s
    @State private var running = true

    @State private var x: Double = 0.0
    @State private var v: Double = 0.0
    @State private var t: Double = 0.0
    @State private var lastTime: TimeInterval? = nil

    /// 위치 시계열 (그래프용). 최근 N 점.
    @State private var trace: [Double] = []
    private let traceLen = 360

    var body: some View {
        SimChrome(
                  blurb: "감쇠 진동의 시간 응답과 공명 곡선. 구동 진동수 ω_d 를 고유진동수 √(k/m) 근처로 맞추면 진폭이 최대가 된다.",
                  canvas: { canvas },
                  controls: { controls })
            .onChange(of: mass) { _, _ in restart() }
            .onChange(of: stiffness) { _, _ in restart() }
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
            LabeledSlider(title: "질량 m", value: $mass, range: 0.2...5.0,
                          format: "%.2f", unit: "kg")
            LabeledSlider(title: "강성 k", value: $stiffness, range: 1.0...80.0,
                          format: "%.1f", unit: "N/m")
            LabeledSlider(title: "감쇠 c", value: $damping, range: 0...4,
                          format: "%.2f", unit: "N·s/m")
            LabeledSlider(title: "외력 진폭 F₀", value: $driveAmp, range: 0...20,
                          format: "%.1f", unit: "N")
            LabeledSlider(title: "구동 ω_d", value: $driveOmega, range: 0.1...15,
                          format: "%.2f", unit: "rad/s")
            HStack {
                Button(running ? "일시정지" : "재생") { running.toggle() }
                Button("초기화") { restart() }
            }
            Divider()
            let omega0 = sqrt(stiffness / mass)
            let zeta = damping / (2 * sqrt(stiffness * mass))
            Readout(label: "고유진동수 ω₀", value: String(format: "%.2f rad/s", omega0))
            Readout(label: "감쇠비 ζ",       value: String(format: "%.3f", zeta))
            Readout(label: "위치 x",        value: String(format: "%.3f m", x))
        }
    }

    // MARK: - ODE

    private func restart() {
        x = 0; v = 0; t = 0; trace.removeAll(); lastTime = nil
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.1 { dt = 0.1 }
        let sub = max(1, Int((dt / 0.001).rounded()))
        let h = dt / Double(sub)
        for _ in 0..<sub {
            // 반-내포 Euler (symplectic).
            let force = driveAmp * cos(driveOmega * t) - stiffness * x - damping * v
            v += force / mass * h
            x += v * h
            t += h
        }
        trace.append(x)
        if trace.count > traceLen { trace.removeFirst(trace.count - traceLen) }
        lastTime = now
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        // 위쪽 절반: 용수철 + 질량. 아래쪽 절반: 변위 시계열 + 공명 곡선.
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.45)
        let midRect = CGRect(x: 0, y: topRect.maxY, width: size.width, height: size.height * 0.30)
        let botRect = CGRect(x: 0, y: midRect.maxY, width: size.width, height: size.height - midRect.maxY)

        drawSpringMass(ctx: ctx, in: topRect)
        drawTrace(ctx: ctx, in: midRect)
        drawResonance(ctx: ctx, in: botRect)
    }

    private func drawSpringMass(ctx: GraphicsContext, in r: CGRect) {
        let cy = r.midY
        let wallX = r.minX + 30
        let restLen: CGFloat = 220
        let scale: CGFloat = 60   // 픽셀 / 미터
        let endX = wallX + restLen + CGFloat(x) * scale
        // 벽.
        var wall = Path()
        wall.move(to: CGPoint(x: wallX, y: cy - 40))
        wall.addLine(to: CGPoint(x: wallX, y: cy + 40))
        ctx.stroke(wall, with: .color(.white.opacity(0.5)), lineWidth: 2)
        // 용수철 (지그재그).
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
        // 질량.
        let box = CGRect(x: endX, y: cy - 20, width: 40, height: 40)
        ctx.fill(Path(box), with: .color(.yellow))
        ctx.stroke(Path(box), with: .color(.white.opacity(0.4)), lineWidth: 1)
        // 평형 표시.
        var eq = Path()
        eq.move(to: CGPoint(x: wallX + restLen, y: cy + 50))
        eq.addLine(to: CGPoint(x: wallX + restLen, y: cy + 64))
        ctx.stroke(eq, with: .color(.white.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }

    private func drawTrace(ctx: GraphicsContext, in r: CGRect) {
        // 0 축.
        var axis = Path()
        axis.move(to: CGPoint(x: r.minX, y: r.midY))
        axis.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        ctx.stroke(axis, with: .color(.white.opacity(0.25)), lineWidth: 1)
        guard !trace.isEmpty else { return }
        let maxAbs = max(0.5, trace.map(abs).max() ?? 1)
        var path = Path()
        for (i, val) in trace.enumerated() {
            let f = CGFloat(i) / CGFloat(traceLen - 1)
            let px = r.minX + f * r.width
            let py = r.midY - CGFloat(val / maxAbs) * (r.height * 0.45)
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(.green), lineWidth: 1.6)
        ctx.draw(Text("x(t)").font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 18, y: r.minY + 12))
    }

    private func drawResonance(ctx: GraphicsContext, in r: CGRect) {
        // |X(ω)| = F₀ / sqrt((k - mω²)² + (cω)²).
        let omega0 = sqrt(stiffness / mass)
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
            amps.append(A)
            maxAmp = max(maxAmp, A)
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
        // ω₀ 표시.
        let xω0 = r.minX + CGFloat(omega0 / omegaMax) * r.width
        var natLine = Path()
        natLine.move(to: CGPoint(x: xω0, y: r.minY))
        natLine.addLine(to: CGPoint(x: xω0, y: r.maxY))
        ctx.stroke(natLine, with: .color(.white.opacity(0.3)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        // 현재 ω_d 마커.
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

import SwiftUI

/// 포물선 운동 — 공기 저항 (선형 drag) 의 유무에 따른 자취 비교.
///
/// 운동방정식:
///   dv/dt = (0, -g) - k·v
/// k = 0 이면 이상적 포물선, k > 0 이면 종단속도가 존재.
struct ProjectileScene: View {
    @State private var angle: Double = 55      // 도
    @State private var speed: Double = 22      // m/s
    @State private var gravity: Double = 9.81  // m/s²
    @State private var drag: Double = 0.10     // 1/s (선형 감쇠 계수)
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(title: "포물선 운동",
                  blurb: "검정 자취는 공기 저항이 있을 때, 회색 점선은 진공일 때. 공기 저항은 포물선을 비대칭으로 만든다.",
                  canvas: { canvas },
                  controls: { controls })
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(startTime)
                draw(ctx: ctx, size: size, t: t)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "발사각", value: $angle, range: 0...89,
                          step: 1, format: "%.0f", unit: "°")
            LabeledSlider(title: "초속력", value: $speed, range: 5...50,
                          format: "%.1f", unit: "m/s")
            LabeledSlider(title: "중력가속도", value: $gravity, range: 1.62...24.79,
                          format: "%.2f", unit: "m/s²")
            LabeledSlider(title: "공기 저항 k", value: $drag, range: 0...0.6,
                          format: "%.2f", unit: "1/s")
            HStack {
                Button(running ? "일시정지" : "재생") { running.toggle() }
                Button("다시 발사") { startTime = Date(); running = true }
            }
            Divider()
            let tt = Date().timeIntervalSince(startTime)
            let p = trajectoryPoint(t: tt, drag: drag)
            Readout(label: "비행시간 t", value: String(format: "%.2f s", tt))
            Readout(label: "x (m)", value: String(format: "%.2f", p.x))
            Readout(label: "y (m)", value: String(format: "%.2f", p.y))
        }
    }

    // MARK: - 물리

    private func trajectoryPoint(t: Double, drag k: Double) -> Vec2 {
        let r = angle * .pi / 180
        let v0 = Vec2(x: speed * cos(r), y: speed * sin(r))
        if k < 1e-6 {
            return Vec2(x: v0.x * t, y: v0.y * t - 0.5 * gravity * t * t)
        }
        // 선형 drag 해석해:
        // x(t) = (v0x/k)(1 - e^{-kt})
        // y(t) = ((v0y + g/k)/k)(1 - e^{-kt}) - (g/k)·t
        let e = 1 - exp(-k * t)
        let x = v0.x / k * e
        let y = (v0.y + gravity / k) / k * e - gravity / k * t
        return Vec2(x: x, y: y)
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        // 월드 사각형: 0..R(예상 사거리) × 0..H. 두 자취가 모두 들어가도록 동적으로.
        let r = angle * .pi / 180
        let v0y = speed * sin(r)
        let v0x = speed * cos(r)
        let tFlight = max(2.0, 2 * v0y / gravity)
        let R = max(8.0, v0x * tFlight)
        let H = max(4.0, v0y * v0y / (2 * gravity))
        let world = CGRect(x: -1, y: -1, width: R + 2, height: H * 1.4 + 2)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 바닥 + 그리드.
        drawGrid(ctx: ctx, map: map, world: world)

        // 진공 자취 (회색 점선).
        let vacPath = trajectoryPath(map: map, drag: 0, until: tFlight)
        ctx.stroke(vacPath, with: .color(.white.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

        // 실제 자취 (drag).
        let curT = max(0, min(t, tFlight * 1.2))
        let realPath = trajectoryPath(map: map, drag: drag, until: curT)
        ctx.stroke(realPath, with: .color(.cyan), lineWidth: 2)

        // 현재 입자.
        let p = trajectoryPoint(t: curT, drag: drag)
        if p.y >= 0 {
            let r0: CGFloat = 6
            let pt = map.point(p)
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r0, y: pt.y - r0,
                                            width: r0 * 2, height: r0 * 2)),
                     with: .color(.yellow))
        }
    }

    private func trajectoryPath(map: CanvasMap, drag k: Double, until: Double) -> Path {
        var path = Path()
        let n = 200
        for i in 0...n {
            let tt = until * Double(i) / Double(n)
            let p = trajectoryPoint(t: tt, drag: k)
            if p.y < 0 { break }
            let pt = map.point(p)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    private func drawGrid(ctx: GraphicsContext, map: CanvasMap, world: CGRect) {
        let step = niceStep(world.width / 10)
        var path = Path()
        var x = (world.minX / step).rounded(.down) * step
        while x <= world.maxX {
            path.move(to: map.point(x: x, y: 0))
            path.addLine(to: map.point(x: x, y: Double(world.maxY)))
            x += step
        }
        var y = 0.0
        while y <= world.maxY {
            path.move(to: map.point(x: 0, y: y))
            path.addLine(to: map.point(x: Double(world.maxX), y: y))
            y += step
        }
        ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)

        // 바닥선.
        var floor = Path()
        floor.move(to: map.point(x: Double(world.minX), y: 0))
        floor.addLine(to: map.point(x: Double(world.maxX), y: 0))
        ctx.stroke(floor, with: .color(.white.opacity(0.4)), lineWidth: 1.2)
    }
}

/// 그리드 간격을 1/2/5·10ⁿ 으로 반올림.
func niceStep(_ raw: Double) -> Double {
    guard raw > 0 else { return 1 }
    let exp = floor(log10(raw))
    let base = pow(10, exp)
    let f = raw / base
    let nice: Double
    if f < 1.5 { nice = 1 }
    else if f < 3.5 { nice = 2 }
    else if f < 7.5 { nice = 5 }
    else { nice = 10 }
    return nice * base
}

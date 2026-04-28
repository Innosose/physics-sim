import SwiftUI
import RealityKit
import UIKit         // SimpleMaterial 의 UIColor 명시 import

/// 포물선 운동 — 공기 저항 (선형 drag) 의 유무에 따른 자취 비교.
///
/// 운동방정식:
///   dv/dt = (0, -g) - k·v
/// k = 0 이면 이상적 포물선, k > 0 이면 종단속도가 존재. **닫힌 해**.
///
/// 2D / 3D 보기 토글:
/// - **2D**: SwiftUI Canvas — 자취·진공 비교·그리드
/// - **3D**: RealityKit `RealityView` — 같은 닫힌 해를 3D 공간에서 시점 조작 가능
///   (드래그 = 궤도, 핀치 = 줌). 처음 시도하는 3D 실험.
struct ProjectileScene: View {
    enum ViewMode: String, CaseIterable, Identifiable {
        case twoD = "2D", threeD = "3D"
        var id: String { rawValue }
    }

    @State private var viewMode: ViewMode = .twoD

    @State private var angle: Double = 55      // 도
    @State private var speed: Double = 22      // m/s
    @State private var gravity: Double = 9.81  // m/s²
    @State private var drag: Double = 0.10     // 1/s (선형 감쇠 계수)
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "노란 공의 자취가 포물선. 공기 저항이 있으면 비대칭. 우상단에서 2D ↔ 3D 전환 가능 — 3D 에서는 드래그로 시점을 돌려 볼 수 있다.",
            canvas: { canvas },
            controls: { controls })
    }

    @ViewBuilder
    private var canvas: some View {
        switch viewMode {
        case .twoD:   canvas2D
        case .threeD: canvas3D
        }
    }

    // MARK: - 2D

    private var canvas2D: some View {
        TimelineView(.animation(paused: !running)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(startTime)
                draw2D(ctx: ctx, size: size, t: t)
            }
        }
    }

    // MARK: - 3D

    /// 3D 보기 — TimelineView 가 매 프레임 현재 위치(닫힌 해) 를 계산해서
    /// `Projectile3DView` 에 props 로 흘림. RealityView 의 `update` 가
    /// ball 엔티티 transform 만 갱신.
    private var canvas3D: some View {
        TimelineView(.animation(paused: !running)) { tl in
            let t = max(0, tl.date.timeIntervalSince(startTime))
            let p = trajectoryPoint(t: t, drag: drag)
            Projectile3DView(position: p, range: estimatedRange)
        }
    }

    /// 카메라/지면 크기 결정용 — 예상 비행 사거리.
    private var estimatedRange: Double {
        let r = angle * .pi / 180
        let v0y = speed * sin(r)
        let v0x = speed * cos(r)
        let tF = max(2.0, 2 * v0y / gravity)
        return max(8.0, v0x * tF)
    }

    // MARK: - 컨트롤

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("보기", selection: $viewMode) {
                ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            LabeledSlider(title: "발사각", value: $angle, range: 0...89,
                          step: 1, format: "%.0f", unit: "°")
            LabeledSlider(title: "초속력", value: $speed, range: 5...50,
                          format: "%.1f", unit: "m/s")
            LabeledSlider(title: "중력가속도", value: $gravity, range: 1.62...24.79,
                          format: "%.2f", unit: "m/s²")
            LabeledSlider(title: "공기 저항 k", value: $drag, range: 0...0.6,
                          format: "%.2f", unit: "1/s")
            PlayResetBar(running: $running,
                         onReset: { startTime = Date(); running = true },
                         resetLabel: "다시 발사")
            Divider()
            let tt = Date().timeIntervalSince(startTime)
            let p = trajectoryPoint(t: tt, drag: drag)
            Readout(label: "비행시간 t", value: String(format: "%.2f s", tt))
            Readout(label: "x (m)", value: String(format: "%.2f", p.x))
            Readout(label: "y (m)", value: String(format: "%.2f", p.y))
        }
    }

    // MARK: - 물리 (닫힌 해)

    private func trajectoryPoint(t: Double, drag k: Double) -> Vec2 {
        let r = angle * .pi / 180
        let v0 = Vec2(x: speed * cos(r), y: speed * sin(r))
        if k < 1e-6 {
            return Vec2(x: v0.x * t, y: v0.y * t - 0.5 * gravity * t * t)
        }
        // 선형 drag 해석해:
        //   x(t) = (v0x/k)·(1 − e^{−kt})
        //   y(t) = ((v0y + g/k)/k)·(1 − e^{−kt}) − (g/k)·t
        let e = 1 - exp(-k * t)
        let x = v0.x / k * e
        let y = (v0.y + gravity / k) / k * e - gravity / k * t
        return Vec2(x: x, y: y)
    }

    // MARK: - 2D 그리기

    private func draw2D(ctx: GraphicsContext, size: CGSize, t: Double) {
        let r = angle * .pi / 180
        let v0y = speed * sin(r)
        let v0x = speed * cos(r)
        let tFlight = max(2.0, 2 * v0y / gravity)
        let R = max(8.0, v0x * tFlight)
        let H = max(4.0, v0y * v0y / (2 * gravity))
        let world = CGRect(x: -1, y: -1, width: R + 2, height: H * 1.4 + 2)
        let map = CanvasMap(view: size, world: world, padding: 16)

        drawGrid(ctx: ctx, map: map, world: world)

        let vacPath = trajectoryPath(map: map, drag: 0, until: tFlight)
        ctx.stroke(vacPath, with: .color(.white.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

        let curT = max(0, min(t, tFlight * 1.2))
        let realPath = trajectoryPath(map: map, drag: drag, until: curT)
        ctx.stroke(realPath, with: .color(.cyan), lineWidth: 2)

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

        var floor = Path()
        floor.move(to: map.point(x: Double(world.minX), y: 0))
        floor.addLine(to: map.point(x: Double(world.maxX), y: 0))
        ctx.stroke(floor, with: .color(.white.opacity(0.4)), lineWidth: 1.2)
    }
}

// MARK: - 3D 보기

/// RealityKit 기반 3D 뷰. 공·지면·라이트·카메라를 첫 프레임에 한 번 셋업하고,
/// 매 프레임 update 에서 공의 위치만 갱신.  드래그(궤도) / 핀치(줌) 가능.
private struct Projectile3DView: View {
    let position: Vec2     // 닫힌 해로 계산된 현재 ball 위치 (m, m)
    let range: Double      // 카메라 위치 잡기 위한 예상 사거리

    var body: some View {
        RealityView { content in
            // ───── 지면 ─────
            // generatePlane 은 XZ 평면에 width × depth 크기로 생성. y=0 이 바닥.
            let groundSize: Float = max(40, Float(range) * 1.5)
            let ground = ModelEntity(
                mesh: .generatePlane(width: groundSize, depth: 30),
                materials: [SimpleMaterial(color: UIColor(white: 0.18, alpha: 1),
                                            isMetallic: false)]
            )
            ground.transform.translation = [Float(range) / 2, 0, 0]
            content.add(ground)

            // ───── 그리드 라인 (얇은 박스 여러 개) ─────
            let lineMat = SimpleMaterial(color: UIColor(white: 1, alpha: 0.18),
                                          isMetallic: false)
            for i in stride(from: 0.0, through: range + 1, by: max(1, range / 10)) {
                let line = ModelEntity(
                    mesh: .generateBox(size: [0.05, 0.001, 30]),
                    materials: [lineMat])
                line.transform.translation = [Float(i), 0.001, 0]
                content.add(line)
            }

            // ───── 공 ─────
            let ball = ModelEntity(
                mesh: .generateSphere(radius: 0.4),
                materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
            )
            ball.name = "ball"
            content.add(ball)

            // ───── 라이트 ─────
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.transform.translation = [10, 20, 10]
            light.look(at: [Float(range)/2, 0, 0], from: [10, 20, 10],
                       relativeTo: nil)
            content.add(light)

            // ───── 카메라 ─────
            let camPos: SIMD3<Float> = [Float(range) / 2,
                                         Float(range) / 4 + 5,
                                         Float(range) / 1.2]
            let camTarget: SIMD3<Float> = [Float(range) / 2,
                                            Float(range) / 12,
                                            0]
            let camera = PerspectiveCamera()
            camera.transform.translation = camPos
            camera.look(at: camTarget, from: camPos, relativeTo: nil)
            content.add(camera)
        } update: { content in
            // 매 프레임 — 공 위치만 갱신.
            if let ball = content.entities.first(where: { $0.name == "ball" }) {
                ball.transform.translation = [
                    Float(position.x),
                    max(0, Float(position.y) + 0.4),  // 반지름만큼 띄움 — 지면 관통 방지
                    0
                ]
            }
        }
        .realityViewCameraControls(.orbit)
    }
}

// MARK: - 그리드 보조 함수

/// 그리드 간격을 1/2/5·10ⁿ 으로 반올림. ProjectileScene·FreeFallScene 공용.
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

import SwiftUI

/// 통합 월드의 2D Canvas 렌더.
///
/// 자유낙하·포물선·진자·스프링·케플러·1차원 충돌·기체·Lorentz·E-field 등
/// 평면에서 충분한 시뮬에 사용. World 엔진은 3D 와 동일 (XY 평면 사용, z=0).
/// N체·자유충돌 같은 진정한 3D 케이스만 `MechanicsViewport` (RealityKit) 가 사용.
struct Mechanics2DViewport: View {
    let preset: Preset

    @State private var world = World()
    @State private var lastTick: TimeInterval? = nil
    @State private var running = true
    @State private var redrawTick: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(paused: !running)) { tl in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size)
                }
                .onChange(of: tl.date) { _, newDate in
                    advance(to: newDate.timeIntervalSinceReferenceDate)
                }
            }
            .id(redrawTick)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )

            controls
        }
        .onAppear { reset() }
        .onChange(of: preset.id) { _, _ in reset() }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                running.toggle()
            } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.glow)

            Button {
                reset()
            } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    private func reset() {
        world.bodies.removeAll()
        world.springs.removeAll()
        world.bounds = nil
        world.gravity = .zero
        world.magneticB = .zero
        world.electricE = .zero
        world.drag = 0
        world.pairwiseGravity = false
        world.pairwiseCoulomb = false
        world.hardSphereCollisions = false
        world.restitution = 1.0
        world.G = 1.0
        world.kCoulomb = 1.0
        world.time = 0
        preset.load(world)
        lastTick = nil
        redrawTick &+= 1
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTick else { lastTick = now; return }
        guard running else { lastTick = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTick = now
        let sub = 8
        let h = dt / Double(sub)
        for _ in 0..<sub { world.step(dt: h) }
        if world.bodies.contains(where: {
            !$0.pos.isFinite || !$0.vel.isFinite
        }) {
            reset()
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let extent = computeExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let scale = min(size.width / worldW, size.height / worldH) * 0.9
        let cx = size.width / 2
        let cy = size.height / 2

        // bounds 사각형.
        if let b = world.bounds {
            let x0 = cx + CGFloat(b.min.x - extent.center.x) * scale
            let x1 = cx + CGFloat(b.max.x - extent.center.x) * scale
            let y0 = cy - CGFloat(b.max.y - extent.center.y) * scale
            let y1 = cy - CGFloat(b.min.y - extent.center.y) * scale
            ctx.stroke(Path(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)),
                       with: .color(.white.opacity(0.4)), lineWidth: 1.2)
        }

        // 자기장 (XY 평면 외부 향함) — 작은 점·×.
        if abs(world.magneticB.z) > 1e-6 {
            drawFieldGrid(ctx: ctx, size: size, outward: world.magneticB.z > 0)
        }

        // 스프링.
        for s in world.springs {
            guard let a = world.bodies.first(where: { $0.id == s.aId }),
                  let b = world.bodies.first(where: { $0.id == s.bId }),
                  a.pos.isFinite, b.pos.isFinite
            else { continue }
            let pa = mapPoint(a.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            let pb = mapPoint(b.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)
            ctx.stroke(path,
                       with: .color(.white.opacity(s.rigid ? 0.7 : 0.5)),
                       lineWidth: s.rigid ? 2 : 1.5)
        }

        // 입자.
        for body in world.bodies {
            guard body.pos.isFinite else { continue }
            let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            let pr = max(2, CGFloat(body.radius) * scale)
            guard pr.isFinite else { continue }
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr,
                                       width: pr * 2, height: pr * 2)),
                with: .color(body.color))
            ctx.stroke(
                Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr,
                                       width: pr * 2, height: pr * 2)),
                with: .color(.white.opacity(0.4)), lineWidth: 0.8)
        }
    }

    private func mapPoint(_ p: Vec3, scale: CGFloat, cx: CGFloat, cy: CGFloat,
                          ext: CGPoint) -> CGPoint {
        CGPoint(x: cx + CGFloat(p.x - ext.x) * scale,
                y: cy - CGFloat(p.y - ext.y) * scale)
    }

    private func drawFieldGrid(ctx: GraphicsContext, size: CGSize, outward: Bool) {
        let step: CGFloat = 36
        var x: CGFloat = step / 2
        while x < size.width {
            var y: CGFloat = step / 2
            while y < size.height {
                if outward {
                    let r: CGFloat = 1.5
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                                     width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.20)))
                } else {
                    var c = Path()
                    c.move(to: CGPoint(x: x - 3, y: y - 3))
                    c.addLine(to: CGPoint(x: x + 3, y: y + 3))
                    c.move(to: CGPoint(x: x - 3, y: y + 3))
                    c.addLine(to: CGPoint(x: x + 3, y: y - 3))
                    ctx.stroke(c, with: .color(.white.opacity(0.18)), lineWidth: 1)
                }
                y += step
            }
            x += step
        }
    }

    /// 화면 중앙에 놓을 월드 중심 + 범위 절반.
    private struct Extent { var center: CGPoint; var x: Double; var y: Double }

    private func computeExtent() -> Extent {
        if let b = world.bounds {
            return Extent(
                center: CGPoint(x: (b.min.x + b.max.x) / 2,
                                y: (b.min.y + b.max.y) / 2),
                x: max(0.5, (b.max.x - b.min.x) / 2),
                y: max(0.5, (b.max.y - b.min.y) / 2))
        }
        let xs = world.bodies.compactMap { $0.pos.x.isFinite ? $0.pos.x : nil }
        let ys = world.bodies.compactMap { $0.pos.y.isFinite ? $0.pos.y : nil }
        let mx = xs.map { abs($0) }.max() ?? 5
        let my = ys.map { abs($0) }.max() ?? 5
        return Extent(center: .zero,
                      x: max(5, mx * 1.4),
                      y: max(5, my * 1.4))
    }
}

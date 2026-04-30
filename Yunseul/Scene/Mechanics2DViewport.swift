import SwiftUI

enum NBodyVariant: String, CaseIterable, Identifiable {
    case solar = "태양계"
    case threeBody = "3체"
    var id: String { rawValue }
}

struct Mechanics2DViewport: View {
    let preset: Preset

    @State private var world = World()
    @State private var lastTick: TimeInterval? = nil
    @State private var running = false
    @State private var redrawTick: Int = 0
    @State private var nBodyVariant: NBodyVariant = .solar

    var body: some View {
        VStack(spacing: 10) {
            if preset.id == "nbody" {
                Picker("", selection: $nBodyVariant) {
                    ForEach(NBodyVariant.allCases) { v in
                        Text(v.rawValue).tag(v)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: nBodyVariant) { _, _ in reset() }
            }

            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size)
                }
                .onChange(of: tl.date) { _, newDate in
                    advance(to: newDate.timeIntervalSinceReferenceDate)
                }
            }
            .id(redrawTick)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.deep)
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
                if !running && allBodiesAtRest() { reset() }
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

    private func allBodiesAtRest() -> Bool {
        guard !world.pairwiseGravity, world.time > 0.3 else { return false }
        let dissipative = world.drag > 0
            || world.springs.contains { $0.damping > 0 }
            || (world.bounds.map { $0.restitution < 0.99 } ?? false)
            || (world.hardSphereCollisions && world.restitution < 0.99)
        guard dissipative else { return false }
        let nonPinned = world.bodies.filter { !$0.pinned }
        guard !nonPinned.isEmpty else { return false }
        let maxV = nonPinned.map { $0.vel.length }.max() ?? 0
        return maxV < 1e-3
    }

    private func reset() {
        world.bodies.removeAll()
        world.springs.removeAll()
        world.trails.removeAll()
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
        world.trailEnabled = false
        world.trailMax = 60
        world.time = 0
        if preset.id == "nbody" {
            switch nBodyVariant {
            case .solar:     MechanicsPresets.solarSystem(world)
            case .threeBody: MechanicsPresets.threeBody(world)
            }
        } else {
            preset.load(world)
        }
        lastTick = nil
        running = false
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
        if allBodiesAtRest() { running = false }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let extent = computeExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let scale = min(size.width / worldW, size.height / worldH) * 0.9
        let cx = size.width / 2
        let cy = size.height / 2

        if let b = world.bounds {
            let x0 = cx + CGFloat(b.min.x - extent.center.x) * scale
            let x1 = cx + CGFloat(b.max.x - extent.center.x) * scale
            let y0 = cy - CGFloat(b.max.y - extent.center.y) * scale
            let y1 = cy - CGFloat(b.min.y - extent.center.y) * scale
            ctx.stroke(Path(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)),
                       with: .color(Theme.ink.opacity(0.4)), lineWidth: 1.2)
        }

        if abs(world.magneticB.z) > 1e-6 {
            drawFieldGrid(ctx: ctx, size: size, outward: world.magneticB.z > 0)
        }

        if world.bodies.contains(where: { $0.charge != 0 }) {
            drawEFieldLines(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }

        // 네온 자취 — 본체보다 먼저 그려서 본체 아래 깔리게.
        if world.trailEnabled {
            for body in world.bodies {
                guard let pts = world.trails[body.id], pts.count > 1 else { continue }
                var path = Path()
                var first = true
                for p in pts {
                    guard p.isFinite else { continue }
                    let pt = mapPoint(p, scale: scale, cx: cx, cy: cy, ext: extent.center)
                    if first { path.move(to: pt); first = false }
                    else     { path.addLine(to: pt) }
                }
                guard !first else { continue }
                let col = body.color
                // 외광 (가장 두껍고 흐림) → 중간 → 코어 (얇고 진함). 네온 효과.
                ctx.stroke(path, with: .color(col.opacity(0.10)),
                           style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                ctx.stroke(path, with: .color(col.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                ctx.stroke(path, with: .color(col.opacity(0.65)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ctx.stroke(path, with: .color(.white.opacity(0.8)),
                           style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round))
            }
        }

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
                       with: .color(Theme.ink.opacity(s.rigid ? 0.7 : 0.5)),
                       lineWidth: s.rigid ? 2 : 1.5)
        }

        for body in world.bodies {
            guard body.pos.isFinite else { continue }
            let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            let pr = max(2, CGFloat(body.radius) * scale)
            guard pr.isFinite else { continue }
            // 자취 있는 입자에는 작은 글로우 헤일로.
            if world.trailEnabled {
                let halo = pr * 3
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo,
                                           width: halo * 2, height: halo * 2)),
                    with: .radialGradient(
                        Gradient(colors: [body.color.opacity(0.55), .clear]),
                        center: p, startRadius: 0, endRadius: halo))
            }
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr,
                                       width: pr * 2, height: pr * 2)),
                with: .color(body.color))
            ctx.stroke(
                Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr,
                                       width: pr * 2, height: pr * 2)),
                with: .color(.white.opacity(0.5)), lineWidth: 0.8)
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
                             with: .color(Theme.ink.opacity(0.20)))
                } else {
                    var c = Path()
                    c.move(to: CGPoint(x: x - 3, y: y - 3))
                    c.addLine(to: CGPoint(x: x + 3, y: y + 3))
                    c.move(to: CGPoint(x: x - 3, y: y + 3))
                    c.addLine(to: CGPoint(x: x + 3, y: y - 3))
                    ctx.stroke(c, with: .color(Theme.ink.opacity(0.18)), lineWidth: 1)
                }
                y += step
            }
            x += step
        }
    }

    private func drawEFieldLines(ctx: GraphicsContext, scale: CGFloat,
                                 cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let charges = world.bodies.filter { $0.charge != 0 && $0.pos.isFinite }
        let positives = charges.filter { $0.charge > 0 }
        guard !positives.isEmpty else { return }

        let nLines = 14
        let stepSize: Double = 0.06
        let maxSteps = 400

        for c in positives {
            for i in 0..<nLines {
                let θ = Double(i) / Double(nLines) * 2 * .pi
                let r0 = c.radius * 1.6
                var p = Vec3(x: c.pos.x + r0 * cos(θ),
                             y: c.pos.y + r0 * sin(θ), z: 0)
                var path = Path()
                path.move(to: mapPoint(p, scale: scale, cx: cx, cy: cy, ext: ext))

                var stopped = false
                for _ in 0..<maxSteps {
                    var Ex: Double = 0, Ey: Double = 0
                    for q in charges {
                        let dx = p.x - q.pos.x
                        let dy = p.y - q.pos.y
                        let r2 = dx * dx + dy * dy
                        if r2 < 1e-6 { stopped = true; break }
                        let r = r2.squareRoot()
                        let f = q.charge / (r2 * r)
                        Ex += f * dx
                        Ey += f * dy
                    }
                    if stopped { break }
                    let mag = (Ex * Ex + Ey * Ey).squareRoot()
                    if mag < 1e-9 { break }
                    p.x += stepSize * Ex / mag
                    p.y += stepSize * Ey / mag
                    path.addLine(to: mapPoint(p, scale: scale, cx: cx, cy: cy, ext: ext))
                    for q in charges where q.charge < 0 {
                        let dx = p.x - q.pos.x
                        let dy = p.y - q.pos.y
                        if dx * dx + dy * dy < q.radius * q.radius * 2.5 {
                            stopped = true; break
                        }
                    }
                    if stopped { break }
                    if abs(p.x) > 50 || abs(p.y) > 50 { break }
                }
                ctx.stroke(path, with: .color(Theme.glow.opacity(0.55)), lineWidth: 1.1)
            }
        }
    }

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

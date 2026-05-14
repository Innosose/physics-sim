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
    @State private var canvasSize: CGSize = .zero
    @State private var vectorsOn: Bool = false
    @State private var energyOn: Bool = false
    @State private var dragBodyId: UUID? = nil

    private var tapEnabled: Bool { preset.id == "freecollide" }

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
            .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in handleDrag(at: value.location, start: value.startLocation) }
                    .onEnded { _ in dragBodyId = nil }
            )
            .onTapGesture { location in
                guard tapEnabled else { return }
                spawnParticle(at: location)
            }
            .overlay(alignment: .bottomTrailing) {
                hintLabel
            }

            toggleRow
            controls
        }
        .onAppear { reset() }
        .onChange(of: preset.id) { _, _ in reset() }
    }

    @ViewBuilder
    private var hintLabel: some View {
        let text: String? = {
            if !running && dragBodyId == nil && hasMovableBody { return "일시정지 중 — 입자를 끌어 위치 변경" }
            if tapEnabled { return "탭 → 입자 추가" }
            return nil
        }()
        if let t = text {
            Text(t)
                .font(.caption2)
                .foregroundStyle(Theme.mist.opacity(0.7))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.surface.opacity(0.5))
                .clipShape(Capsule())
                .padding(10)
                .allowsHitTesting(false)
        }
    }

    private var hasMovableBody: Bool { world.bodies.contains { !$0.pinned } }

    private var toggleRow: some View {
        HStack(spacing: 8) {
            Button { vectorsOn.toggle() } label: {
                Label("벡터", systemImage: "arrow.up.right")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(vectorsOn ? Theme.glow : Theme.mist)

            Button { energyOn.toggle() } label: {
                Label("에너지", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(energyOn ? Theme.glow : Theme.mist)
        }
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
        world.integrator = .velocityVerlet
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

    private func viewScale() -> CGFloat {
        let extent = computeExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        return min(canvasSize.width / worldW, canvasSize.height / worldH) * 0.9
    }

    private func screenToWorld(_ pt: CGPoint) -> Vec3 {
        let extent = computeExtent()
        let scale = viewScale()
        let cx = canvasSize.width / 2, cy = canvasSize.height / 2
        let wx = Double((pt.x - cx) / scale) + extent.center.x
        let wy = -Double((pt.y - cy) / scale) + extent.center.y
        return Vec3(x: wx, y: wy, z: 0)
    }

    private func spawnParticle(at screenPt: CGPoint) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        let p = screenToWorld(screenPt)
        if let b = world.bounds {
            guard p.x > b.min.x && p.x < b.max.x && p.y > b.min.y && p.y < b.max.y else { return }
        }
        let palette: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .mint, .teal]
        let color = palette[world.bodies.count % palette.count]
        let r = Double.random(in: 0.06...0.13)
        let speed = Double.random(in: 0.3...0.8)
        let angle = Double.random(in: 0...(2 * .pi))
        world.bodies.append(PhysicsBody(
            pos: p,
            vel: Vec3(x: speed * cos(angle), y: speed * sin(angle), z: 0),
            mass: .random(in: 0.8...2.5), radius: r, color: color))
        if !running { running = true }
    }

    private func handleDrag(at screenPt: CGPoint, start: CGPoint) {
        guard !running, canvasSize.width > 0 else { return }
        if dragBodyId == nil {
            dragBodyId = pickBody(at: start)
        }
        guard let id = dragBodyId,
              let idx = world.bodies.firstIndex(where: { $0.id == id }) else { return }
        let newPos = screenToWorld(screenPt)
        world.bodies[idx].pos = newPos
        world.bodies[idx].vel = .zero
    }

    private func pickBody(at screenPt: CGPoint) -> UUID? {
        let worldPt = screenToWorld(screenPt)
        let scale = max(viewScale(), 1)
        let minHit = 22.0 / Double(scale)
        var bestId: UUID? = nil
        var bestDist = Double.infinity
        for body in world.bodies where !body.pinned {
            let d = (body.pos - worldPt).length
            let hit = max(body.radius * 1.6, minHit)
            if d < hit && d < bestDist {
                bestDist = d
                bestId = body.id
            }
        }
        return bestId
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

        if vectorsOn {
            drawVectors(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }
        if energyOn {
            drawEnergyPanel(ctx: ctx, in: CGRect(origin: .zero, size: size))
        }
    }

    private func drawVectors(ctx: GraphicsContext, scale: CGFloat,
                              cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let accels = world.accelerations()
        let movable = world.bodies.indices.filter { !world.bodies[$0].pinned }
        guard !movable.isEmpty else { return }
        let maxV = max(movable.map { world.bodies[$0].vel.length }.max() ?? 1, 0.001)
        let maxF = max(movable.map { (accels[$0] * world.bodies[$0].mass).length }.max() ?? 1, 0.001)
        let avgR = max(movable.map { world.bodies[$0].radius }.reduce(0, +)
                       / Double(movable.count), 0.1)
        let vWorld = 4.0 * avgR / maxV
        let fWorld = 4.0 * avgR / maxF

        for i in movable {
            let body = world.bodies[i]
            guard body.pos.isFinite else { continue }
            let start = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: ext)
            if body.vel.lengthSquared > 1e-9 {
                let end = mapPoint(body.pos + body.vel * vWorld,
                                   scale: scale, cx: cx, cy: cy, ext: ext)
                drawArrow(ctx: ctx, from: start, to: end, color: .green)
            }
            let F = accels[i] * body.mass
            if F.lengthSquared > 1e-9 {
                let end = mapPoint(body.pos + F * fWorld,
                                   scale: scale, cx: cx, cy: cy, ext: ext)
                drawArrow(ctx: ctx, from: start, to: end, color: .orange)
            }
        }
    }

    private func drawArrow(ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 1.5 else { return }
        var shaft = Path()
        shaft.move(to: from); shaft.addLine(to: to)
        ctx.stroke(shaft, with: .color(color.opacity(0.9)), lineWidth: 1.6)
        let nx = dx / len, ny = dy / len
        let s = min(CGFloat(8), len * 0.5)
        var head = Path()
        head.move(to: to)
        head.addLine(to: CGPoint(x: to.x - nx * s - ny * s * 0.45,
                                  y: to.y - ny * s + nx * s * 0.45))
        head.move(to: to)
        head.addLine(to: CGPoint(x: to.x - nx * s + ny * s * 0.45,
                                  y: to.y - ny * s - nx * s * 0.45))
        ctx.stroke(head, with: .color(color.opacity(0.95)), lineWidth: 1.6)
    }

    private func drawEnergyPanel(ctx: GraphicsContext, in r: CGRect) {
        let e = world.energyBreakdown()
        let total = e.kinetic + e.potential
        let scale = max(abs(e.kinetic), abs(e.potential), abs(total), 0.001)

        let panelW: CGFloat = 138, panelH: CGFloat = 64
        let panel = CGRect(x: r.maxX - panelW - 8, y: r.minY + 8,
                           width: panelW, height: panelH)
        ctx.fill(Path(roundedRect: panel, cornerRadius: 8),
                 with: .color(Theme.deep.opacity(0.78)))
        ctx.stroke(Path(roundedRect: panel, cornerRadius: 8),
                   with: .color(Theme.stroke), lineWidth: 1)

        let entries: [(String, Double, Color)] = [
            ("KE", e.kinetic, .green),
            ("PE", e.potential, .orange),
            ("ΣE", total, .yellow),
        ]
        let labelW: CGFloat = 22, valueW: CGFloat = 46
        let barW = panel.width - labelW - valueW - 12
        for (i, item) in entries.enumerated() {
            let y = panel.minY + 8 + CGFloat(i) * 18
            ctx.draw(Text(item.0).font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.mist),
                     at: CGPoint(x: panel.minX + 4 + labelW / 2, y: y + 5))
            let bg = CGRect(x: panel.minX + 4 + labelW, y: y + 2,
                            width: barW, height: 6)
            ctx.stroke(Path(roundedRect: bg, cornerRadius: 2),
                       with: .color(Theme.ink.opacity(0.35)), lineWidth: 0.6)
            // 0 마크
            var zero = Path()
            zero.move(to: CGPoint(x: bg.midX, y: bg.minY))
            zero.addLine(to: CGPoint(x: bg.midX, y: bg.maxY))
            ctx.stroke(zero, with: .color(Theme.ink.opacity(0.3)), lineWidth: 0.6)
            // 부호 막대 (중앙 기준)
            let frac = max(-1.0, min(1.0, item.1 / scale))
            let halfW = bg.width / 2
            let fillW = CGFloat(abs(frac)) * halfW
            let fillX = frac >= 0 ? bg.midX : bg.midX - fillW
            ctx.fill(Path(roundedRect: CGRect(x: fillX, y: bg.minY,
                                               width: fillW, height: bg.height),
                          cornerRadius: 2),
                     with: .color(item.2.opacity(0.8)))
            ctx.draw(Text(String(format: "%+.2f", item.1))
                        .font(.caption2.monospacedDigit()).foregroundStyle(Theme.glow),
                     at: CGPoint(x: panel.maxX - valueW / 2 - 4, y: y + 5))
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
                var pts: [CGPoint] = [mapPoint(p, scale: scale, cx: cx, cy: cy, ext: ext)]

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
                    pts.append(mapPoint(p, scale: scale, cx: cx, cy: cy, ext: ext))
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

                guard pts.count > 1 else { continue }
                var path = Path()
                path.move(to: pts[0])
                for pt in pts.dropFirst() { path.addLine(to: pt) }
                ctx.stroke(path, with: .color(Theme.glow.opacity(0.55)), lineWidth: 1.1)

                let midIdx = pts.count / 2
                if midIdx >= 1 && midIdx < pts.count {
                    drawArrowhead(ctx: ctx,
                                  from: pts[midIdx - 1],
                                  to: pts[midIdx],
                                  color: Theme.glow.opacity(0.85))
                }
            }
        }
    }

    private func drawArrowhead(ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                               color: Color) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0.001 else { return }
        let nx = dx / len, ny = dy / len
        let size: CGFloat = 5
        var head = Path()
        head.move(to: b)
        head.addLine(to: CGPoint(x: b.x - nx * size - ny * size * 0.5,
                                  y: b.y - ny * size + nx * size * 0.5))
        head.move(to: b)
        head.addLine(to: CGPoint(x: b.x - nx * size + ny * size * 0.5,
                                  y: b.y - ny * size - nx * size * 0.5))
        ctx.stroke(head, with: .color(color), lineWidth: 1.2)
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

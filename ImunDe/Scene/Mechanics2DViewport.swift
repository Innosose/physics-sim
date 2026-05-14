import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var trailsOn: Bool = false
    @State private var graphsOn: Bool = false
    @State private var rulerOn: Bool = false
    @State private var rulerStart: Vec3 = Vec3(x: -1.5, y: 0, z: 0)
    @State private var rulerEnd: Vec3 = Vec3(x: 1.5, y: 0, z: 0)
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dragMode: DragMode = .none
    @State private var motionHistory: [UUID: [MotionSample]] = [:]
    @State private var timeScale: Double = 1.0
    @State private var inspectedId: UUID? = nil
    @State private var energyHistory: [World.EnergyBreakdown] = []
    @State private var lorentzB: Double = 1.0
    @State private var autoStopped = false
    @State private var initialExtent: CGSize = CGSize(width: 5, height: 5)
    @State private var maxObservedExtent: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0
    @AppStorage("hasDraggedBody") private var hasDraggedBody = false
    @Environment(\.colorScheme) private var colorScheme

    private let energyHistMax = 240
    private let motionHistMax = 240
    private var tapEnabled: Bool { preset.id == "freecollide" }

    var body: some View {
        VStack(spacing: 10) {
            if preset.id == "nbody" {
                PaperPicker(selection: $nBodyVariant,
                            options: NBodyVariant.allCases) { $0.rawValue }
                    .onChange(of: nBodyVariant) { _, _ in reset() }
            }

            ZStack {
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        draw(ctx: ctx, size: size)
                    }
                    .id(colorScheme)
                    .onChange(of: tl.date) { _, newDate in
                        advance(to: newDate.timeIntervalSinceReferenceDate)
                    }
                }
                .id(redrawTick)
                CharcoalGrain().allowsHitTesting(false)
            }
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
                    .onEnded { _ in dragMode = .none }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinchDelta) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        zoomScale = min(max(zoomScale * value.magnification, 0.3), 8.0)
                    }
            )
            .onTapGesture { location in
                handleTap(at: location)
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.45)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        if case .second(true, let drag?) = value {
                            handleLongPress(at: drag.startLocation)
                        }
                    }
            )
            .overlay(alignment: .topLeading) { zoomBadge }
            .overlay(alignment: .topTrailing) { miniMapOverlay }
            .overlay(alignment: .bottomTrailing) { hintLabel }
            .overlay(alignment: .bottom) { transportBar }
            .overlay(alignment: .bottomLeading) { settledBadge }

            toggleRow
            presetParameterRow
            timeScaleRow
            presetDerivedRow
        }
        .onAppear { reset() }
        .onChange(of: preset.id) { _, _ in reset() }
    }

    @ViewBuilder
    private var hintLabel: some View {
        let text: String? = {
            if tapEnabled { return "탭 → 입자 추가 · 길게 누르면 삭제" }
            if !hasDraggedBody && hasMovableBody { return "입자를 끌어 위치 변경" }
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

    private struct ChipMask {
        var vectors = true
        var energy = true
        var trails = true
        var graphs = true
        var ruler = true
    }

    private var chipMask: ChipMask {
        switch preset.id {
        case "kinetic":
            // 많은 입자 — 자취/그래프/벡터는 화면을 어지럽힘
            return ChipMask(vectors: false, trails: false, graphs: false)
        case "freecollide":
            return ChipMask(trails: false, graphs: false)
        case "efield":
            // 전기력선이 이미 그려짐, 자취 중복
            return ChipMask(trails: false)
        default:
            return ChipMask()
        }
    }

    private var toggleRow: some View {
        let mask = chipMask
        return HStack(spacing: 5) {
            if mask.vectors {
                ChipToggle(title: "벡터", systemImage: "arrow.up.right", isOn: vectorsOn) {
                    vectorsOn.toggle(); haptic(.light)
                }
            }
            if mask.energy {
                ChipToggle(title: "에너지", systemImage: "chart.bar.fill", isOn: energyOn) {
                    energyOn.toggle(); haptic(.light)
                }
            }
            if mask.trails {
                ChipToggle(title: "자취", systemImage: "scribble", isOn: trailsOn) {
                    trailsOn.toggle(); haptic(.light)
                    world.trailEnabled = trailsOn
                    if !trailsOn { world.trails.removeAll() }
                }
            }
            if mask.graphs {
                ChipToggle(title: "그래프", systemImage: "chart.xyaxis.line", isOn: graphsOn) {
                    graphsOn.toggle(); haptic(.light)
                    if !graphsOn { motionHistory.removeAll() }
                }
            }
            if mask.ruler {
                ChipToggle(title: "자", systemImage: "ruler", isOn: rulerOn) {
                    rulerOn.toggle(); haptic(.light)
                }
            }
        }
    }

    @ViewBuilder
    private var miniMapOverlay: some View {
        if needsMiniMap {
            Canvas { ctx, size in
                drawMiniMap(ctx: ctx, size: size)
            }
            .frame(width: 96, height: 72)
            .background(Theme.surface.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(10)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func drawMiniMap(ctx: GraphicsContext, size: CGSize) {
        let extent = miniMapExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let scale = min(size.width / worldW, size.height / worldH) * 0.84
        let cx = size.width / 2
        let cy = size.height / 2

        // Indicate the main canvas's currently visible world rectangle.
        // Accounts for live pinch-zoom and pan.
        let mainScale = viewScale()
        if mainScale > 0, canvasSize.width > 0, canvasSize.height > 0 {
            let visibleW = Double(canvasSize.width) / Double(mainScale)
            let visibleH = Double(canvasSize.height) / Double(mainScale)
            let mainExtent = computeExtent()
            let centerWX = mainExtent.center.x - Double(panOffset.width) / Double(mainScale)
            let centerWY = mainExtent.center.y + Double(panOffset.height) / Double(mainScale)
            let rectW = CGFloat(visibleW) * scale
            let rectH = CGFloat(visibleH) * scale
            let rectCX = cx + CGFloat(centerWX - extent.center.x) * scale
            let rectCY = cy - CGFloat(centerWY - extent.center.y) * scale
            let rect = CGRect(
                x: rectCX - rectW / 2, y: rectCY - rectH / 2,
                width: rectW, height: rectH)
            ctx.stroke(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(Theme.glow.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1.0, dash: [3, 2]))
        }

        // Bodies — small filled dots, slightly enlarged so they're visible.
        for body in world.bodies {
            guard body.pos.isFinite else { continue }
            let p = CGPoint(
                x: cx + CGFloat(body.pos.x - extent.center.x) * scale,
                y: cy - CGFloat(body.pos.y - extent.center.y) * scale)
            let r = max(1.6, CGFloat(body.radius) * scale * 0.6)
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: p.x - r, y: p.y - r,
                    width: r * 2, height: r * 2)),
                with: .color(body.color))
        }
    }

    @ViewBuilder
    private var zoomBadge: some View {
        let live = zoomScale * pinchDelta
        if abs(live - 1.0) > 0.01 || panOffset != .zero {
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    zoomScale = 1.0
                    panOffset = .zero
                }
                haptic(.light)
            } label: {
                Label(String(format: "%.2fx", live),
                      systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.glow)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.surface.opacity(0.75))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private func chipToggle(_ title: String, systemImage: String, on: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.surface : Theme.mist)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? Theme.ink : Theme.crest.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(on ? Color.clear : Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.chipPress)
    }

    @ViewBuilder
    private var presetDerivedRow: some View {
        if let text = derivedValueText() {
            HStack {
                Text(text)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.surface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.ink.opacity(0.22), lineWidth: 0.8)
                    )
            )
        }
    }

    private func derivedValueText() -> String? {
        switch preset.id {
        case "freefall":
            guard let bob = world.bodies.first(where: { !$0.pinned }),
                  bob.pos.isFinite, bob.vel.isFinite else { return nil }
            let y = bob.pos.y, vy = bob.vel.y
            let g = -world.gravity.y
            guard g > 0 else { return nil }
            let disc = vy * vy + 2 * g * y
            guard disc >= 0 else { return nil }
            let tHit = (vy + disc.squareRoot()) / g
            let vHit = disc.squareRoot()
            return String(format: "남은 비행 %.2fs   충돌 속도 %.2f m/s", tHit, vHit)

        case "projectile":
            guard let proj = world.bodies.first(where: { !$0.pinned }),
                  proj.pos.isFinite, proj.vel.isFinite else { return nil }
            let y = proj.pos.y, vx = proj.vel.x, vy = proj.vel.y
            let g = -world.gravity.y
            guard g > 0 else { return nil }
            let disc = vy * vy + 2 * g * y
            guard disc >= 0 else { return nil }
            let tHit = (vy + disc.squareRoot()) / g
            let xPredict = proj.pos.x + vx * tHit
            return String(format: "남은 시간 %.2fs   예상 사거리 %.2f m", tHit, xPredict)

        case "pendulum":
            guard let pivot = world.bodies.first(where: { $0.pinned }),
                  let bob   = world.bodies.first(where: { !$0.pinned }),
                  pivot.pos.isFinite, bob.pos.isFinite else { return nil }
            let L = (bob.pos - pivot.pos).length
            let g = -world.gravity.y
            guard g > 0, L > 1e-6 else { return nil }
            let T0 = 2 * .pi * (L / g).squareRoot()
            let dx = bob.pos.x - pivot.pos.x
            let dy = pivot.pos.y - bob.pos.y
            let θ = atan2(dx, dy)
            let θ2 = θ * θ, θ4 = θ2 * θ2
            let corr = 1 + θ2 / 16 + 11 * θ4 / 3072
            return String(format: "T₀ = %.3fs   T(θ) = %.3fs", T0, T0 * corr)

        case "collision1d":
            let nonPinned = world.bodies.filter { !$0.pinned }
            guard nonPinned.count >= 2 else { return nil }
            let p = nonPinned.map { $0.mass * $0.vel.x }.reduce(0, +)
            let ke = nonPinned.map { 0.5 * $0.mass * $0.vel.lengthSquared }.reduce(0, +)
            return String(format: "운동량 p = %.2f   운동에너지 KE = %.2f", p, ke)

        case "kepler", "nbody":
            guard let star = world.bodies.first(where: { $0.kind == .star || $0.pinned }),
                  let planet = world.bodies.first(where: { !$0.pinned && $0.kind != .star }),
                  star.pos.isFinite, planet.pos.isFinite else { return nil }
            let mu = world.G * star.mass
            let dr = planet.pos - star.pos
            let r = dr.length
            let v = planet.vel.length
            guard r > 1e-6 else { return nil }
            let E = 0.5 * v * v - mu / r
            if E >= 0 {
                return "탈출 궤도 (E ≥ 0)"
            }
            let a = -mu / (2 * E)
            let h = abs(dr.x * planet.vel.y - dr.y * planet.vel.x)
            let eSq = max(0, 1 + 2 * E * h * h / (mu * mu))
            let e = eSq.squareRoot()
            let T = 2 * .pi * (a * a * a / mu).squareRoot()
            return String(format: "a=%.2f  e=%.3f  T=%.2f", a, e, T)

        default:
            return nil
        }
    }

    @ViewBuilder
    private var presetParameterRow: some View {
        if preset.id == "lorentz" {
            HStack(spacing: 8) {
                Text("B_z").font(.caption).foregroundStyle(Theme.mist)
                PaperSlider(value: $lorentzB, in: -3...3)
                Text(String(format: "%+.2f T", lorentzB))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .frame(width: 64, alignment: .trailing)
            }
            .onChange(of: lorentzB) { _, v in
                world.magneticB = Vec3(x: 0, y: 0, z: v)
            }
        }
    }

    private var timeScaleRow: some View {
        HStack(spacing: 6) {
            Text(String(format: "t=%.2fs", world.time))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.mist)
                .frame(width: 62, alignment: .leading)
            PaperSlider(value: $timeScale, in: 0.25...4)
            Text(String(format: "%.2fx", timeScale))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private var transportBar: some View {
        HStack(spacing: 10) {
            Button {
                if !running && allBodiesAtRest() { reset() }
                running.toggle()
                if running { autoStopped = false }
                haptic(.medium)
            } label: {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(running ? Theme.glow : Theme.surface.opacity(0.92)))
                    .overlay(Circle().stroke(Theme.ink.opacity(running ? 0.85 : 0.55), lineWidth: 1.1))
            }
            .buttonStyle(.plain)

            Button {
                stepOnce()
                haptic(.light)
            } label: {
                Image(systemName: "forward.frame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(running ? Theme.mist : Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.surface.opacity(0.88)))
                    .overlay(Circle().stroke(Theme.ink.opacity(running ? 0.3 : 0.5), lineWidth: 1.0))
            }
            .buttonStyle(.plain)
            .disabled(running)

            Button {
                reset()
                haptic(.medium)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.surface.opacity(0.88)))
                    .overlay(Circle().stroke(Theme.ink.opacity(0.5), lineWidth: 1.0))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var settledBadge: some View {
        if autoStopped {
            Text("정지됨")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.mist)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.surface.opacity(0.78))
                .clipShape(Capsule())
                .padding(.leading, 8).padding(.bottom, 8)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: autoStopped)
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
        autoStopped = false
        inspectedId = nil
        energyHistory.removeAll()
        motionHistory.removeAll()
        dragMode = .none
        zoomScale = 1.0
        panOffset = .zero
        rulerStart = Vec3(x: -1.5, y: 0, z: 0)
        rulerEnd = Vec3(x: 1.5, y: 0, z: 0)
        trailsOn = world.trailEnabled
        lorentzB = world.magneticB.z
        captureInitialExtent()
        redrawTick &+= 1
    }

    private func stepOnce() {
        let dt = (1.0 / 60.0) * timeScale
        let sub = 8
        let h = dt / Double(sub)
        for _ in 0..<sub { world.step(dt: h) }
        recordEnergy()
        recordMotion()
        updateMaxObservedExtent()
        if world.bodies.contains(where: { !$0.pos.isFinite || !$0.vel.isFinite }) {
            reset()
        }
    }

    private func recordEnergy() {
        guard energyOn else { return }
        energyHistory.append(world.energyBreakdown())
        if energyHistory.count > energyHistMax {
            energyHistory.removeFirst(energyHistory.count - energyHistMax)
        }
    }

    private func recordMotion() {
        guard graphsOn else { return }
        let t = world.time
        for body in world.bodies where !body.pinned {
            var arr = motionHistory[body.id] ?? []
            arr.append(MotionSample(t: t, pos: body.pos, vel: body.vel))
            if arr.count > motionHistMax {
                arr.removeFirst(arr.count - motionHistMax)
            }
            motionHistory[body.id] = arr
        }
        // Drop history of removed bodies
        let alive = Set(world.bodies.map { $0.id })
        let stale = motionHistory.keys.filter { !alive.contains($0) }
        for id in stale { motionHistory.removeValue(forKey: id) }
    }

    private func graphTargetBody() -> PhysicsBody? {
        if let id = inspectedId,
           let b = world.bodies.first(where: { $0.id == id }), !b.pinned {
            return b
        }
        return world.bodies.first { !$0.pinned }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    private func viewScale() -> CGFloat {
        let extent = computeExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let base = min(canvasSize.width / worldW, canvasSize.height / worldH) * 0.9
        return base * zoomScale * pinchDelta
    }

    private func screenToWorld(_ pt: CGPoint) -> Vec3 {
        let extent = computeExtent()
        let scale = viewScale()
        let cx = canvasSize.width / 2 + panOffset.width
        let cy = canvasSize.height / 2 + panOffset.height
        let wx = Double((pt.x - cx) / scale) + extent.center.x
        let wy = -Double((pt.y - cy) / scale) + extent.center.y
        return Vec3(x: wx, y: wy, z: 0)
    }

    private func handleTap(at screenPt: CGPoint) {
        if let id = pickBody(at: screenPt, requireMovable: false) {
            inspectedId = (inspectedId == id) ? nil : id
            haptic(.light)
            return
        }
        if tapEnabled {
            spawnParticle(at: screenPt)
            return
        }
        inspectedId = nil
    }

    private func handleLongPress(at screenPt: CGPoint) {
        guard tapEnabled,
              let id = pickBody(at: screenPt, requireMovable: true),
              let idx = world.bodies.firstIndex(where: { $0.id == id }) else { return }
        world.bodies.remove(at: idx)
        if inspectedId == id { inspectedId = nil }
        haptic(.medium)
    }

    private func spawnParticle(at screenPt: CGPoint) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        let p = screenToWorld(screenPt)
        if let b = world.bounds {
            guard p.x > b.min.x && p.x < b.max.x && p.y > b.min.y && p.y < b.max.y else { return }
        }
        let color = Theme.bodyPalette[world.bodies.count % Theme.bodyPalette.count]
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
        guard canvasSize.width > 0 else { return }
        if case .none = dragMode {
            if rulerOn, let end = pickRulerHandle(at: start) {
                dragMode = (end == .start) ? .rulerStart : .rulerEnd
                haptic(.light)
            } else if !running, let id = pickBody(at: start, requireMovable: true) {
                dragMode = .body(id)
                if !hasDraggedBody { hasDraggedBody = true }
                haptic(.light)
            } else {
                dragMode = .pan(initial: panOffset)
            }
        }
        switch dragMode {
        case .body(let id):
            guard !running,
                  let idx = world.bodies.firstIndex(where: { $0.id == id }) else { return }
            let target = screenToWorld(screenPt)
            world.bodies[idx].pos = constrainDragPosition(id: id, target: target)
            world.bodies[idx].vel = .zero
            inspectedId = id
        case .pan(let initial):
            let dx = screenPt.x - start.x
            let dy = screenPt.y - start.y
            panOffset = CGSize(width: initial.width + dx, height: initial.height + dy)
        case .rulerStart:
            rulerStart = screenToWorld(screenPt)
        case .rulerEnd:
            rulerEnd = screenToWorld(screenPt)
        case .none:
            break
        }
    }

    private func pickRulerHandle(at screenPt: CGPoint) -> RulerEnd? {
        let extent = computeExtent()
        let scale = viewScale()
        let cx = canvasSize.width / 2 + panOffset.width
        let cy = canvasSize.height / 2 + panOffset.height
        let s = CGPoint(x: cx + CGFloat(rulerStart.x - extent.center.x) * scale,
                        y: cy - CGFloat(rulerStart.y - extent.center.y) * scale)
        let e = CGPoint(x: cx + CGFloat(rulerEnd.x - extent.center.x) * scale,
                        y: cy - CGFloat(rulerEnd.y - extent.center.y) * scale)
        let dS = hypot(screenPt.x - s.x, screenPt.y - s.y)
        let dE = hypot(screenPt.x - e.x, screenPt.y - e.y)
        let threshold: CGFloat = 32
        if dS <= dE && dS < threshold { return .start }
        if dE < threshold { return .end }
        return nil
    }

    private func constrainDragPosition(id: UUID, target: Vec3) -> Vec3 {
        for s in world.springs where s.rigid {
            let otherId: UUID? = s.aId == id ? s.bId : (s.bId == id ? s.aId : nil)
            guard let oid = otherId,
                  let other = world.bodies.first(where: { $0.id == oid }),
                  other.pinned else { continue }
            let d = target - other.pos
            let dist = d.length
            guard dist > 1e-9 else { return target }
            return other.pos + d * (s.restLength / dist)
        }
        return target
    }

    private func pickBody(at screenPt: CGPoint, requireMovable: Bool) -> UUID? {
        let worldPt = screenToWorld(screenPt)
        let scale = max(viewScale(), 1)
        let minHit = 22.0 / Double(scale)
        var bestId: UUID? = nil
        var bestDist = Double.infinity
        for body in world.bodies {
            if requireMovable && body.pinned { continue }
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
        var dt = (now - last) * timeScale
        let dtCap = 0.05 * max(timeScale, 1)
        if dt > dtCap { dt = dtCap }
        lastTick = now
        let sub = 8
        let h = dt / Double(sub)
        for _ in 0..<sub { world.step(dt: h) }
        recordEnergy()
        recordMotion()
        updateMaxObservedExtent()
        if world.bodies.contains(where: {
            !$0.pos.isFinite || !$0.vel.isFinite
        }) {
            reset()
        }
        if allBodiesAtRest() { running = false; autoStopped = true }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let extent = computeExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let scale = min(size.width / worldW, size.height / worldH) * 0.9 * zoomScale * pinchDelta
        let cx = size.width / 2 + panOffset.width
        let cy = size.height / 2 + panOffset.height

        if let b = world.bounds {
            let x0 = cx + CGFloat(b.min.x - extent.center.x) * scale
            let x1 = cx + CGFloat(b.max.x - extent.center.x) * scale
            let y0 = cy - CGFloat(b.max.y - extent.center.y) * scale
            let y1 = cy - CGFloat(b.min.y - extent.center.y) * scale
            Sketchy.rect(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
                         ctx: ctx, color: Theme.ink,
                         lineWidth: 1.4, passes: 2, jitter: 1.4)
        }

        if abs(world.magneticB.z) > 1e-6 {
            drawFieldGrid(ctx: ctx, size: size, outward: world.magneticB.z > 0)
        }

        if world.bodies.contains(where: { $0.charge != 0 }) {
            drawEFieldLines(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }

        // 연필 자취 — 단일 sketchy 폴리라인.
        if world.trailEnabled {
            for body in world.bodies {
                guard let pts = world.trails[body.id], pts.count > 1 else { continue }
                let screenPts: [CGPoint] = pts.compactMap { p in
                    guard p.isFinite else { return nil }
                    return mapPoint(p, scale: scale, cx: cx, cy: cy, ext: extent.center)
                }
                Sketchy.polyline(screenPts, ctx: ctx, color: body.color,
                                 lineWidth: 1.4, passes: 1, jitter: 0.35)
            }
        }

        for s in world.springs {
            guard let a = world.bodies.first(where: { $0.id == s.aId }),
                  let b = world.bodies.first(where: { $0.id == s.bId }),
                  a.pos.isFinite, b.pos.isFinite
            else { continue }
            let pa = mapPoint(a.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            let pb = mapPoint(b.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            Sketchy.line(from: pa, to: pb, ctx: ctx,
                         color: Theme.ink,
                         lineWidth: s.rigid ? 1.8 : 1.3,
                         passes: s.rigid ? 2 : 1,
                         jitter: s.rigid ? 0.7 : 0.4)
        }

        for body in world.bodies {
            guard body.pos.isFinite else { continue }
            let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            let pr = max(2, CGFloat(body.radius) * scale)
            guard pr.isFinite else { continue }
            // 연필 톤 — 옅은 색연필 칠 위에 sketchy 잉크 윤곽.
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr,
                                       width: pr * 2, height: pr * 2)),
                with: .color(body.color.opacity(0.55)))
            Sketchy.circle(center: p, radius: pr, ctx: ctx,
                            color: Theme.ink, lineWidth: 1.3, passes: 2,
                            jitter: 0.025)
        }

        if vectorsOn {
            drawVectors(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }
        drawBodyLabels(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        if rulerOn {
            drawRuler(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }
        if energyOn {
            drawEnergyPanel(ctx: ctx, in: CGRect(origin: .zero, size: size))
        }
        if graphsOn {
            drawGraphsPanel(ctx: ctx, in: CGRect(origin: .zero, size: size))
        }
        if let id = inspectedId,
           let body = world.bodies.first(where: { $0.id == id }) {
            drawInspector(ctx: ctx, in: CGRect(origin: .zero, size: size),
                          body: body, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }
    }

    private func drawBodyLabels(ctx: GraphicsContext, scale: CGFloat,
                                 cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        for body in world.bodies {
            guard let name = body.name, body.pos.isFinite else { continue }
            let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: ext)
            let pr = max(2, CGFloat(body.radius) * scale)
            ctx.draw(
                Text(name).font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.mist.opacity(0.9)),
                at: CGPoint(x: p.x, y: p.y - pr - 8))
        }
    }

    private func drawInspector(ctx: GraphicsContext, in r: CGRect,
                                body: PhysicsBody, scale: CGFloat,
                                cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let accels = world.accelerations()
        let idx = world.bodies.firstIndex(where: { $0.id == body.id }) ?? 0
        let a = idx < accels.count ? accels[idx] : .zero
        let ke = body.pinned ? 0 : 0.5 * body.mass * body.vel.lengthSquared
        let lines: [String] = [
            body.name ?? (body.kind.rawValue),
            String(format: "m = %.2f", body.mass),
            String(format: "|v| = %.3f", body.vel.length),
            String(format: "|a| = %.3f", a.length),
            String(format: "KE = %.3f", ke),
        ]

        let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: ext)
        let pr = max(2, CGFloat(body.radius) * scale)
        Sketchy.circle(center: p, radius: pr + 5, ctx: ctx,
                        color: Theme.glow, lineWidth: 1.4, passes: 2, jitter: 0.04)

        let panelW: CGFloat = max(112, min(132, r.width * 0.34))
        let panelH: CGFloat = max(74, min(86, r.height * 0.28))

        // Place to the side opposite of the body's screen position so we
        // stay inside the canvas. Then nudge away from other open panels.
        var pX = (p.x < r.midX) ? p.x + pr + 10 : p.x - pr - 10 - panelW
        var pY = p.y - panelH / 2
        pX = min(max(pX, r.minX + 6), r.maxX - panelW - 6)
        pY = min(max(pY, r.minY + 6), r.maxY - panelH - 6)

        // Avoid energy panel (top-right, ~228 × 100)
        if energyOn {
            let energyZone = CGRect(x: r.maxX - 240, y: r.minY,
                                    width: 240, height: 108)
            if energyZone.intersects(CGRect(x: pX, y: pY,
                                            width: panelW, height: panelH)) {
                pY = max(pY, energyZone.maxY + 6)
                pY = min(pY, r.maxY - panelH - 6)
            }
        }
        // Avoid graphs panel (bottom-left, ~228 × 148)
        if graphsOn {
            let graphsZone = CGRect(x: r.minX, y: r.maxY - 160,
                                    width: 240, height: 160)
            if graphsZone.intersects(CGRect(x: pX, y: pY,
                                            width: panelW, height: panelH)) {
                pY = min(pY, graphsZone.minY - panelH - 6)
                pY = max(pY, r.minY + 6)
            }
        }

        let panel = CGRect(x: pX, y: pY, width: panelW, height: panelH)
        ctx.fill(Path(roundedRect: panel, cornerRadius: 8),
                 with: .color(Theme.surface.opacity(0.94)))
        ctx.stroke(Path(roundedRect: panel, cornerRadius: 8),
                   with: .color(Theme.ink.opacity(0.7)), lineWidth: 1.1)
        for (i, line) in lines.enumerated() {
            let font: Font = i == 0 ? .caption.weight(.bold) : .caption2.monospacedDigit()
            let color: Color = i == 0 ? Theme.ink : Theme.mist
            ctx.draw(Text(line).font(font).foregroundStyle(color),
                     at: CGPoint(x: panel.minX + 8, y: panel.minY + 10 + CGFloat(i) * 14),
                     anchor: .leading)
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
                drawArrow(ctx: ctx, from: start, to: end, color: Theme.ink, dashed: false)
            }
            let F = accels[i] * body.mass
            if F.lengthSquared > 1e-9 {
                let end = mapPoint(body.pos + F * fWorld,
                                   scale: scale, cx: cx, cy: cy, ext: ext)
                drawArrow(ctx: ctx, from: start, to: end, color: Theme.ink, dashed: true)
            }
        }
    }

    private func drawArrow(ctx: GraphicsContext, from: CGPoint, to: CGPoint,
                            color: Color, dashed: Bool = false) {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 1.5 else { return }
        Sketchy.line(from: from, to: to, ctx: ctx, color: color,
                     lineWidth: 1.5, passes: 1, jitter: 0.5,
                     dash: dashed ? [4, 3] : nil)
        let nx = dx / len, ny = dy / len
        let s = min(CGFloat(9), len * 0.5)
        let h1 = CGPoint(x: to.x - nx * s - ny * s * 0.45,
                         y: to.y - ny * s + nx * s * 0.45)
        let h2 = CGPoint(x: to.x - nx * s + ny * s * 0.45,
                         y: to.y - ny * s - nx * s * 0.45)
        Sketchy.line(from: to, to: h1, ctx: ctx, color: color,
                     lineWidth: 1.5, passes: 1, jitter: 0.3)
        Sketchy.line(from: to, to: h2, ctx: ctx, color: color,
                     lineWidth: 1.5, passes: 1, jitter: 0.3)
    }

    private func drawEnergyPanel(ctx: GraphicsContext, in r: CGRect) {
        let panelW = max(150, min(220, r.width * 0.42))
        let panelH = max(74, min(96, r.height * 0.30))
        let panel = CGRect(x: r.maxX - panelW - 8, y: r.minY + 8,
                           width: panelW, height: panelH)
        ctx.fill(Path(roundedRect: panel, cornerRadius: 8),
                 with: .color(Theme.surface.opacity(0.92)))
        ctx.stroke(Path(roundedRect: panel, cornerRadius: 8),
                   with: .color(Theme.ink.opacity(0.7)), lineWidth: 1.1)

        let e = world.energyBreakdown()
        let total = e.total
        // 헤더
        ctx.draw(Text(String(format: "KE %.2f  PE %+.2f  ΣE %+.2f",
                              e.kinetic, e.potential, total))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: panel.midX, y: panel.minY + 10))

        let plot = panel.insetBy(dx: 8, dy: 8)
            .offsetBy(dx: 0, dy: 6)
        let plotR = CGRect(x: plot.minX, y: plot.minY + 6,
                           width: plot.width, height: plot.height - 6)
        ctx.stroke(Path(roundedRect: plotR, cornerRadius: 4),
                   with: .color(Theme.ink.opacity(0.25)), lineWidth: 0.6)

        guard energyHistory.count > 1 else {
            ctx.draw(Text("재생 중 에너지 추이 기록")
                        .font(.caption2).foregroundStyle(Theme.mist.opacity(0.6)),
                     at: CGPoint(x: plotR.midX, y: plotR.midY))
            return
        }

        let allValues = energyHistory.flatMap { [$0.kinetic, $0.potential, $0.total] }
        let lo = allValues.min() ?? 0
        let hi = allValues.max() ?? 1
        let span = max(hi - lo, 0.001)

        // 0 기준선
        if lo < 0 && hi > 0 {
            let zeroY = plotR.maxY - CGFloat((0 - lo) / span) * plotR.height
            var z = Path()
            z.move(to: CGPoint(x: plotR.minX, y: zeroY))
            z.addLine(to: CGPoint(x: plotR.maxX, y: zeroY))
            ctx.stroke(z, with: .color(Theme.ink.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }

        let entries: [(KeyPath<World.EnergyBreakdown, Double>, [CGFloat]?, CGFloat, Color)] = [
            (\.kinetic,   nil,    1.4, Theme.ink),  // solid ink
            (\.potential, [4, 3], 1.2, Theme.ink),  // dashed ink
            (\.total,     nil,    1.8, Theme.glow), // solid cream — emphasis
        ]
        for (kp, dash, lw, color) in entries {
            var path = Path()
            for (i, e) in energyHistory.enumerated() {
                let f = CGFloat(i) / CGFloat(max(energyHistMax - 1, 1))
                let px = plotR.minX + f * plotR.width
                let py = plotR.maxY - CGFloat((e[keyPath: kp] - lo) / span) * plotR.height
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else      { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            let style: StrokeStyle = dash == nil
                ? StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
                : StrokeStyle(lineWidth: lw, lineCap: .round,
                              lineJoin: .round, dash: dash!)
            ctx.stroke(path, with: .color(color), style: style)
        }
        // Legend
        ctx.draw(Text("실선 KE   점선 PE   굵선 ΣE")
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(Theme.mist),
                 at: CGPoint(x: plotR.midX, y: plotR.maxY - 6))
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
                    let r: CGFloat = 1.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                                     width: r * 2, height: r * 2)),
                             with: .color(Theme.ink.opacity(0.45)))
                } else {
                    Sketchy.line(from: CGPoint(x: x - 3, y: y - 3),
                                  to: CGPoint(x: x + 3, y: y + 3),
                                  ctx: ctx, color: Theme.ink.opacity(0.55),
                                  lineWidth: 0.9, passes: 1, jitter: 0.15)
                    Sketchy.line(from: CGPoint(x: x - 3, y: y + 3),
                                  to: CGPoint(x: x + 3, y: y - 3),
                                  ctx: ctx, color: Theme.ink.opacity(0.55),
                                  lineWidth: 0.9, passes: 1, jitter: 0.15)
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
                Sketchy.polyline(pts, ctx: ctx, color: Theme.ink.opacity(0.65),
                                 lineWidth: 1.1, passes: 1, jitter: 0.3)

                let midIdx = pts.count / 2
                if midIdx >= 1 && midIdx < pts.count {
                    drawArrowhead(ctx: ctx,
                                  from: pts[midIdx - 1],
                                  to: pts[midIdx],
                                  color: Theme.ink)
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
        let h1 = CGPoint(x: b.x - nx * size - ny * size * 0.5,
                         y: b.y - ny * size + nx * size * 0.5)
        let h2 = CGPoint(x: b.x - nx * size + ny * size * 0.5,
                         y: b.y - ny * size - nx * size * 0.5)
        Sketchy.line(from: b, to: h1, ctx: ctx, color: color,
                     lineWidth: 1.2, passes: 1, jitter: 0.2)
        Sketchy.line(from: b, to: h2, ctx: ctx, color: color,
                     lineWidth: 1.2, passes: 1, jitter: 0.2)
    }

    private struct Extent { var center: CGPoint; var x: Double; var y: Double }

    private var hasFixedBounds: Bool { world.bounds != nil }

    /// The world region drawn on the main canvas. For bounded sims this is
    /// the world bounds. For unbounded sims (kepler/nbody/lorentz) this is
    /// pinned to `initialExtent` so the view doesn't zoom in/out as bodies
    /// orbit — bodies that go off-screen show up on the mini-map instead.
    private func computeExtent() -> Extent {
        if let b = world.bounds {
            return Extent(
                center: CGPoint(x: (b.min.x + b.max.x) / 2,
                                y: (b.min.y + b.max.y) / 2),
                x: max(0.5, (b.max.x - b.min.x) / 2),
                y: max(0.5, (b.max.y - b.min.y) / 2))
        }
        return Extent(center: .zero,
                      x: max(5, Double(initialExtent.width)),
                      y: max(5, Double(initialExtent.height)))
    }

    /// The extent covering every body's farthest reach so far — used to
    /// scale the mini-map so distant bodies are always visible there.
    private func miniMapExtent() -> Extent {
        if let b = world.bounds {
            return Extent(
                center: CGPoint(x: (b.min.x + b.max.x) / 2,
                                y: (b.min.y + b.max.y) / 2),
                x: max(0.5, (b.max.x - b.min.x) / 2),
                y: max(0.5, (b.max.y - b.min.y) / 2))
        }
        return Extent(center: .zero,
                      x: max(5, Double(maxObservedExtent.width)),
                      y: max(5, Double(maxObservedExtent.height)))
    }

    private func captureInitialExtent() {
        guard !hasFixedBounds else { return }
        let xs = world.bodies.compactMap { $0.pos.x.isFinite ? $0.pos.x : nil }
        let ys = world.bodies.compactMap { $0.pos.y.isFinite ? $0.pos.y : nil }
        let mx = (xs.map { abs($0) }.max() ?? 5) * 1.6
        let my = (ys.map { abs($0) }.max() ?? 5) * 1.6
        initialExtent = CGSize(width: max(5, CGFloat(mx)),
                                height: max(5, CGFloat(my)))
        maxObservedExtent = initialExtent
    }

    private func updateMaxObservedExtent() {
        guard !hasFixedBounds else { return }
        let xs = world.bodies.compactMap { $0.pos.x.isFinite ? $0.pos.x : nil }
        let ys = world.bodies.compactMap { $0.pos.y.isFinite ? $0.pos.y : nil }
        let mx = (xs.map { abs($0) }.max() ?? 5) * 1.4
        let my = (ys.map { abs($0) }.max() ?? 5) * 1.4
        maxObservedExtent.width = max(maxObservedExtent.width, CGFloat(mx))
        maxObservedExtent.height = max(maxObservedExtent.height, CGFloat(my))
    }

    private var needsMiniMap: Bool {
        // Show mini-map for unbounded sims where bodies can wander
        // far from the locked initial view.
        guard !hasFixedBounds else { return false }
        let extX = max(1, maxObservedExtent.width)
        let extY = max(1, maxObservedExtent.height)
        // Reveal once the world has expanded ≥ ~25% beyond the locked view.
        return extX > initialExtent.width * 1.25
            || extY > initialExtent.height * 1.25
    }

    private func drawGraphsPanel(ctx: GraphicsContext, in r: CGRect) {
        let panelW = max(160, min(228, r.width * 0.50))
        let panelH = max(108, min(150, r.height * 0.42))
        let panel = CGRect(x: r.minX + 8,
                           y: r.maxY - panelH - 8,
                           width: panelW, height: panelH)
        ctx.fill(Path(roundedRect: panel, cornerRadius: 8),
                 with: .color(Theme.surface.opacity(0.92)))
        ctx.stroke(Path(roundedRect: panel, cornerRadius: 8),
                   with: .color(Theme.ink.opacity(0.7)), lineWidth: 1.1)

        guard let body = graphTargetBody(),
              let history = motionHistory[body.id], history.count > 1 else {
            ctx.draw(Text("재생 중 위치·속도 추이 기록")
                        .font(.caption2).foregroundStyle(Theme.mist.opacity(0.65)),
                     at: CGPoint(x: panel.midX, y: panel.midY))
            return
        }

        let title = body.name ?? "선택 입자"
        ctx.draw(Text("\(title) — x·y(m) ⏐ vₓ·v_y(m/s)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: panel.midX, y: panel.minY + 10))

        let inner = panel.insetBy(dx: 8, dy: 8).offsetBy(dx: 0, dy: 6)
        let subH = (inner.height - 6) / 2
        let posR = CGRect(x: inner.minX, y: inner.minY,
                          width: inner.width, height: subH - 2)
        let velR = CGRect(x: inner.minX, y: inner.minY + subH + 4,
                          width: inner.width, height: subH - 2)

        drawTwoCurve(ctx: ctx, in: posR, history: history,
                     keyA: { $0.pos.x }, keyB: { $0.pos.y },
                     leftLabel: "x", rightLabel: "y")
        drawTwoCurve(ctx: ctx, in: velR, history: history,
                     keyA: { $0.vel.x }, keyB: { $0.vel.y },
                     leftLabel: "vₓ", rightLabel: "v_y")
    }

    private func drawTwoCurve(ctx: GraphicsContext, in r: CGRect,
                              history: [MotionSample],
                              keyA: (MotionSample) -> Double,
                              keyB: (MotionSample) -> Double,
                              leftLabel: String, rightLabel: String) {
        let valsA = history.map(keyA)
        let valsB = history.map(keyB)
        let lo = min(valsA.min() ?? 0, valsB.min() ?? 0)
        let hi = max(valsA.max() ?? 1, valsB.max() ?? 1)
        let span = max(hi - lo, 0.001)

        ctx.stroke(Path(roundedRect: r, cornerRadius: 4),
                   with: .color(Theme.ink.opacity(0.35)), lineWidth: 0.7)

        if lo < 0 && hi > 0 {
            let zeroY = r.maxY - CGFloat((0 - lo) / span) * r.height
            var z = Path()
            z.move(to: CGPoint(x: r.minX, y: zeroY))
            z.addLine(to: CGPoint(x: r.maxX, y: zeroY))
            ctx.stroke(z, with: .color(Theme.ink.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }

        // A: solid, B: dashed
        for (vals, dashed) in [(valsA, false), (valsB, true)] {
            var p = Path()
            for (i, v) in vals.enumerated() {
                let f = CGFloat(i) / CGFloat(max(motionHistMax - 1, 1))
                let px = r.minX + f * r.width
                let py = r.maxY - CGFloat((v - lo) / span) * r.height
                if i == 0 { p.move(to: CGPoint(x: px, y: py)) }
                else      { p.addLine(to: CGPoint(x: px, y: py)) }
            }
            let style: StrokeStyle = dashed
                ? StrokeStyle(lineWidth: 1.1, lineCap: .round,
                              lineJoin: .round, dash: [4, 3])
                : StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            ctx.stroke(p, with: .color(Theme.ink), style: style)
        }

        // Current value labels at right edge
        let last = history.last
        let a = last.map(keyA) ?? 0
        let b = last.map(keyB) ?? 0
        ctx.draw(Text("\(leftLabel) \(String(format: "%+.2f", a))")
                    .font(.system(size: 8).monospaced())
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: r.maxX - 4, y: r.minY + 6), anchor: .trailing)
        ctx.draw(Text("\(rightLabel) \(String(format: "%+.2f", b))")
                    .font(.system(size: 8).monospaced())
                    .foregroundStyle(Theme.mist),
                 at: CGPoint(x: r.maxX - 4, y: r.minY + 16), anchor: .trailing)
    }

    private func drawRuler(ctx: GraphicsContext, scale: CGFloat,
                           cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let s = mapPoint(rulerStart, scale: scale, cx: cx, cy: cy, ext: ext)
        let e = mapPoint(rulerEnd, scale: scale, cx: cx, cy: cy, ext: ext)

        // Main rod
        Sketchy.line(from: s, to: e, ctx: ctx, color: Theme.ink,
                     lineWidth: 1.7, passes: 2, jitter: 0.6)

        // Tick marks every 0.5 m
        let dxW = rulerEnd.x - rulerStart.x
        let dyW = rulerEnd.y - rulerStart.y
        let distW = (dxW * dxW + dyW * dyW).squareRoot()
        let lineLen = hypot(e.x - s.x, e.y - s.y)
        if distW > 0.2, lineLen > 4 {
            let tickStep = 0.5
            let nTicks = min(Int(distW / tickStep), 80)
            let perpX = -(e.y - s.y) / lineLen
            let perpY =  (e.x - s.x) / lineLen
            for i in 0...nTicks {
                let t = CGFloat(Double(i) * tickStep / distW)
                let xC = s.x + (e.x - s.x) * t
                let yC = s.y + (e.y - s.y) * t
                let isMajor = (i % 2 == 0)
                let tl: CGFloat = isMajor ? 5 : 3
                Sketchy.line(from: CGPoint(x: xC - perpX * tl, y: yC - perpY * tl),
                              to: CGPoint(x: xC + perpX * tl, y: yC + perpY * tl),
                              ctx: ctx, color: Theme.ink,
                              lineWidth: 0.9, passes: 1, jitter: 0.2)
            }
        }

        // Endpoint handles (larger for easier grabbing)
        for pt in [s, e] {
            Sketchy.fillCircle(center: pt, radius: 10, ctx: ctx,
                                fill: Theme.surface, stroke: Theme.ink,
                                strokeWidth: 1.6)
        }

        // Label
        let mid = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
        let label = String(format: "%.2f m", distW)
        var ox: CGFloat = 0, oy: CGFloat = -14
        if lineLen > 0.5 {
            let nx = (e.y - s.y) / lineLen
            let ny = -(e.x - s.x) / lineLen
            ox = nx * 14; oy = ny * 14
        }
        let lblPt = CGPoint(x: mid.x + ox, y: mid.y + oy)
        let bg = CGRect(x: lblPt.x - 32, y: lblPt.y - 9, width: 64, height: 18)
        ctx.fill(Path(roundedRect: bg, cornerRadius: 4),
                 with: .color(Theme.surface.opacity(0.92)))
        Sketchy.rect(bg, ctx: ctx, color: Theme.ink,
                     lineWidth: 0.9, passes: 1, jitter: 0.3)
        ctx.draw(Text(label).font(.caption2.monospacedDigit()).foregroundStyle(Theme.ink),
                 at: lblPt)
    }

    fileprivate struct MotionSample {
        let t: Double
        let pos: Vec3
        let vel: Vec3
    }

    fileprivate enum RulerEnd { case start, end }

    fileprivate enum DragMode {
        case none
        case body(UUID)
        case pan(initial: CGSize)
        case rulerStart
        case rulerEnd
    }
}

import SwiftUI
import RealityKit
import UIKit

enum NBodyVariant: String, CaseIterable, Identifiable {
    case solar = "태양계"
    case threeBody = "3체"
    var id: String { rawValue }
}

struct MechanicsViewport: View {
    let preset: Preset

    @State private var world = World()
    @State private var lastTick: TimeInterval? = nil
    @State private var running = true
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

            TimelineView(.animation(paused: !running)) { tl in
                MechanicsRealityView(world: world, tick: tl.date)
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
        .padding(.horizontal, 4)
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
}

private struct MechanicsRealityView: View {
    let world: World
    let tick: Date

    var body: some View {
        RealityView { content in
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.transform.translation = [10, 20, 10]
            light.look(at: [0, 0, 0], from: [10, 20, 10], relativeTo: nil)
            content.add(light)

            let camera = PerspectiveCamera()
            let extent = estimatedExtent()
            let camPos = SIMD3<Float>(Float(extent * 0.9),
                                      Float(extent * 0.5),
                                      Float(extent * 1.3))
            camera.transform.translation = camPos
            camera.look(at: .zero, from: camPos, relativeTo: nil)
            content.add(camera)

            if let b = world.bounds, b.min.y > -5 {
                let groundSize = Float(max(b.max.x - b.min.x, b.max.z - b.min.z) + 4)
                let ground = ModelEntity(
                    mesh: .generatePlane(width: groundSize, depth: groundSize),
                    materials: [SimpleMaterial(color: UIColor(white: 0.18, alpha: 1),
                                                isMetallic: false)])
                ground.transform.translation = [0, Float(b.min.y), 0]
                content.add(ground)
            }

            for pb in world.bodies {
                let mat = bodyMaterial(pb)
                let mesh: MeshResource = .generateSphere(radius: Float(pb.radius))
                let entity = ModelEntity(mesh: mesh, materials: [mat])
                entity.name = "body-\(pb.id.uuidString)"
                entity.transform.translation = pb.pos.simd
                content.add(entity)

                if world.trailEnabled {
                    let trailRadius = Float(pb.radius * 0.45)
                    let trailMesh: MeshResource = .generateSphere(radius: trailRadius)
                    var trailMat = SimpleMaterial(color: UIColor(pb.color).withAlphaComponent(0.55),
                                                   isMetallic: false)
                    trailMat.roughness = 0.6
                    for k in 0..<world.trailMax {
                        let dot = ModelEntity(mesh: trailMesh, materials: [trailMat])
                        dot.name = "trail-\(pb.id.uuidString)-\(k)"
                        dot.isEnabled = false
                        content.add(dot)
                    }
                }
            }
        } update: { content in
            _ = tick
            for pb in world.bodies {
                let name = "body-\(pb.id.uuidString)"
                if let entity = content.entities.first(where: { $0.name == name }) {
                    if pb.pos.isFinite {
                        entity.transform.translation = pb.pos.simd
                    }
                }
                if world.trailEnabled {
                    let pts = world.trails[pb.id] ?? []
                    for k in 0..<world.trailMax {
                        let nm = "trail-\(pb.id.uuidString)-\(k)"
                        guard let dot = content.entities.first(where: { $0.name == nm })
                        else { continue }
                        if k < pts.count, pts[k].isFinite {
                            dot.isEnabled = true
                            dot.transform.translation = pts[k].simd
                            let f = Float(k) / Float(max(1, pts.count - 1))
                            dot.transform.scale = SIMD3<Float>(repeating: 0.2 + 0.8 * f)
                        } else {
                            dot.isEnabled = false
                        }
                    }
                }
            }
        }
        .realityViewCameraControls(.orbit)
    }

    private func bodyMaterial(_ b: PhysicsBody) -> SimpleMaterial {
        let ui = UIColor(b.color)
        var m = SimpleMaterial(color: ui, isMetallic: false)
        m.roughness = 0.4
        return m
    }

    private func estimatedExtent() -> Double {
        if let b = world.bounds {
            return max(b.max.x - b.min.x, b.max.y - b.min.y, b.max.z - b.min.z)
        }
        let maxR = world.bodies.compactMap { $0.pos.isFinite ? $0.pos.length : nil }.max() ?? 1
        return max(2.0, maxR * 2.2)
    }
}

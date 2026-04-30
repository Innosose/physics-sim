import SwiftUI
import RealityKit
import UIKit

struct MechanicsViewport: View {
    let preset: Preset

    @State private var world = World()
    @State private var lastTick: TimeInterval? = nil
    @State private var running = true
    @State private var redrawTick: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(paused: !running)) { tl in
                MechanicsRealityView(world: world)
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
        .padding(.horizontal, 4)
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
}

private struct MechanicsRealityView: View {
    let world: World

    var body: some View {
        RealityView { content in
            let light = DirectionalLight()
            light.light.intensity = 5000
            light.transform.translation = [10, 20, 10]
            light.look(at: [0, 0, 0], from: [10, 20, 10], relativeTo: nil)
            content.add(light)

            let camera = PerspectiveCamera()
            let extent = max(8.0, estimatedExtent())
            let camPos = SIMD3<Float>(Float(extent * 1.2),
                                      Float(extent * 0.6),
                                      Float(extent * 1.6))
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
            }
        } update: { content in
            for pb in world.bodies {
                let name = "body-\(pb.id.uuidString)"
                if let entity = content.entities.first(where: { $0.name == name }) {
                    if pb.pos.isFinite {
                        entity.transform.translation = pb.pos.simd
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
        return 1 + (world.bodies.map { abs($0.pos.x) + abs($0.pos.y) + abs($0.pos.z) }.max() ?? 5)
    }
}

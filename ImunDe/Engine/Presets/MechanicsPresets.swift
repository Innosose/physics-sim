import SwiftUI

enum MechanicsPresets {

    static func freeFall(_ w: World) {
        w.integrator = .velocityVerlet
        w.gravity = Vec3(x: 0, y: -9.81, z: 0)
        w.bounds = Bounds(min: Vec3(x: -6, y: 0, z: -2),
                          max: Vec3(x: 6, y: 50, z: 2),
                          restitution: 0)
        w.trailEnabled = true
        w.trailMax = 300
        w.bodies = [
            PhysicsBody(pos: Vec3(x: 0, y: 48, z: 0),
                        vel: .zero,
                        mass: 1, radius: 0.4,
                        color: Theme.bodyPalette[0])
        ]
    }

    static func projectile(_ w: World) {
        w.integrator = .velocityVerlet
        let θ = 55.0 * .pi / 180
        let v0 = 22.0
        w.gravity = Vec3(x: 0, y: -9.81, z: 0)
        w.drag = 0.10
        w.bounds = Bounds(min: Vec3(x: -2, y: 0, z: -3),
                          max: Vec3(x: 80, y: 40, z: 3),
                          restitution: 0)
        w.trailEnabled = true
        w.trailMax = 500
        w.bodies = [
            PhysicsBody(pos: Vec3(x: 0, y: 0.5, z: 0),
                        vel: Vec3(x: v0 * cos(θ), y: v0 * sin(θ), z: 0),
                        mass: 1, radius: 0.3, color: Theme.bodyPalette[0])
        ]
    }

    static func collision1D(_ w: World) {
        w.integrator = .velocityVerlet
        w.gravity = .zero
        w.hardSphereCollisions = true
        w.restitution = 1.0
        w.bounds = Bounds(min: Vec3(x: -8, y: -1, z: -2),
                          max: Vec3(x: 8, y: 4, z: 2),
                          restitution: 0)
        w.bodies = [
            PhysicsBody(pos: Vec3(x: -3, y: 0.5, z: 0),
                        vel: Vec3(x: 3, y: 0, z: 0),
                        mass: 2, radius: 0.5, color: Theme.bodyPalette[0]),
            PhysicsBody(pos: Vec3(x: 3, y: 0.5, z: 0),
                        vel: Vec3(x: -1, y: 0, z: 0),
                        mass: 1, radius: 0.4, color: Theme.bodyPalette[4]),
        ]
    }

    static func pendulum(_ w: World) {
        w.integrator = .velocityVerlet
        w.gravity = Vec3(x: 0, y: -9.81, z: 0)
        let pivot = PhysicsBody(pos: Vec3(x: 0, y: 3, z: 0),
                                mass: 1e9, radius: 0.1,
                                color: Theme.mist, pinned: true, kind: .anchor)
        let θ0 = 60.0 * .pi / 180
        let L = 1.5
        let bob = PhysicsBody(pos: Vec3(x: pivot.pos.x + L * sin(θ0),
                                        y: pivot.pos.y - L * cos(θ0),
                                        z: 0),
                              mass: 1, radius: 0.18,
                              color: Theme.bodyPalette[0])
        w.bodies = [pivot, bob]
        w.springs = [
            Spring(aId: pivot.id, bId: bob.id,
                   restLength: L, stiffness: 0, damping: 0, rigid: true)
        ]
    }

    static func spring(_ w: World) {
        w.integrator = .velocityVerlet
        w.gravity = .zero
        let wall = PhysicsBody(pos: Vec3(x: -3, y: 1, z: 0),
                               mass: 1e9, radius: 0.2,
                               color: Theme.mist, pinned: true, kind: .anchor)
        let mass = PhysicsBody(pos: Vec3(x: 0, y: 1, z: 0),
                               vel: Vec3(x: 1, y: 0, z: 0),
                               mass: 1, radius: 0.3, color: Theme.bodyPalette[0])
        w.bodies = [wall, mass]
        w.springs = [
            Spring(aId: wall.id, bId: mass.id,
                   restLength: 3, stiffness: 25, damping: 0.6, rigid: false)
        ]
    }

    static func kepler(_ w: World) {
        w.integrator = .velocityVerlet
        w.pairwiseGravity = true
        w.G = 1.0
        w.trailEnabled = true
        w.trailMax = 500
        let sun = PhysicsBody(pos: .zero, mass: 200, radius: 0.6,
                              color: Theme.bodyPalette[0],
                              pinned: true, kind: .star)
        let r = 5.0
        let v = (w.G * sun.mass / r).squareRoot()
        let planet = PhysicsBody(pos: Vec3(x: r, y: 0, z: 0),
                                 vel: Vec3(x: 0, y: v, z: 0),
                                 mass: 1, radius: 0.2,
                                 color: Theme.bodyPalette[3],
                                 kind: .planet)
        w.bodies = [sun, planet]
    }

    static func freeCollision(_ w: World) {
        w.integrator = .velocityVerlet
        w.gravity = .zero
        w.hardSphereCollisions = true
        w.restitution = 0.95
        w.bounds = Bounds(min: Vec3(x: -1, y: -1, z: -1),
                          max: Vec3(x: 1, y: 1, z: 1),
                          restitution: 0.95)
        w.bodies = [
            PhysicsBody(pos: Vec3(x: -0.7, y: 0, z: 0),
                        vel: Vec3(x: 1, y: 0.05, z: 0),
                        mass: 2.5, radius: 0.12, color: Theme.bodyPalette[0]),
            PhysicsBody(pos: Vec3(x: 0, y: 0, z: 0),
                        mass: 1.0, radius: 0.10, color: Theme.bodyPalette[3]),
            PhysicsBody(pos: Vec3(x: 0.7, y: 0, z: 0),
                        vel: Vec3(x: -0.7, y: -0.05, z: 0),
                        mass: 2.0, radius: 0.12, color: Theme.bodyPalette[6]),
        ]
    }

    static func solarSystem(_ w: World) {
        w.integrator = .velocityVerlet
        w.pairwiseGravity = true
        w.G = 1.0
        w.trailEnabled = true
        w.trailMax = 400
        var sun = PhysicsBody(pos: .zero, mass: 300, radius: 0.55,
                              color: Theme.bodyPalette[0],
                              pinned: true, kind: .star)
        sun.name = "태양"
        let planets: [(name: String, r: Double, size: Double, color: Color)] = [
            ("수성", 1.4, 0.08, Theme.bodyPalette[5]),
            ("금성", 2.2, 0.13, Theme.bodyPalette[2]),
            ("지구", 3.0, 0.14, Theme.bodyPalette[7]),
            ("화성", 3.9, 0.11, Theme.bodyPalette[4]),
            ("목성", 5.5, 0.30, Theme.bodyPalette[6]),
            ("토성", 7.5, 0.24, Theme.bodyPalette[9]),
        ]
        var arr: [PhysicsBody] = [sun]
        for p in planets {
            let v = (w.G * sun.mass / p.r).squareRoot()
            var body = PhysicsBody(
                pos: Vec3(x: p.r, y: 0, z: 0),
                vel: Vec3(x: 0, y: v, z: 0),
                mass: 0.5, radius: p.size, color: p.color,
                kind: .planet)
            body.name = p.name
            arr.append(body)
        }
        w.bodies = arr
    }

    static func threeBody(_ w: World) {
        w.integrator = .velocityVerlet
        w.pairwiseGravity = true
        w.G = 1.0
        w.trailEnabled = true
        w.trailMax = 500
        let v12 = Vec3(x: 0.93240737 / 2, y: 0.86473146 / 2, z: 0)
        let v3  = Vec3(x: -0.93240737, y: -0.86473146, z: 0)
        var b1 = PhysicsBody(pos: Vec3(x: -0.97000436, y:  0.24308753, z: 0),
                             vel: v12, mass: 1, radius: 0.08,
                             color: Theme.bodyPalette[0], kind: .star)
        var b2 = PhysicsBody(pos: Vec3(x:  0.97000436, y: -0.24308753, z: 0),
                             vel: v12, mass: 1, radius: 0.08,
                             color: Theme.bodyPalette[3], kind: .star)
        var b3 = PhysicsBody(pos: .zero,
                             vel: v3,  mass: 1, radius: 0.08,
                             color: Theme.bodyPalette[6], kind: .star)
        b1.name = "A"; b2.name = "B"; b3.name = "C"
        w.bodies = [b1, b2, b3]
    }

    static func lorentz(_ w: World) {
        w.integrator = .rk4
        w.magneticB = Vec3(x: 0, y: 0, z: 1)
        w.electricE = .zero
        w.trailEnabled = true
        w.trailMax = 400
        w.bodies = [
            PhysicsBody(pos: Vec3(x: -2, y: 0, z: 0),
                        vel: Vec3(x: 1.5, y: 0, z: 0),
                        mass: 1, radius: 0.2, charge: 1,
                        color: Theme.bodyPalette[0], kind: .charge)
        ]
    }

    static func eField(_ w: World) {
        w.integrator = .rk4
        w.pairwiseCoulomb = true
        w.kCoulomb = 1.0
        w.bodies = [
            PhysicsBody(pos: Vec3(x: -2, y: 0, z: 0),
                        mass: 1, radius: 0.25, charge: 1,
                        color: Theme.bodyPalette[0],
                        pinned: true, kind: .charge),
            PhysicsBody(pos: Vec3(x: 2, y: 0, z: 0),
                        mass: 1, radius: 0.25, charge: -1,
                        color: Theme.bodyPalette[5],
                        pinned: true, kind: .charge),
        ]
    }

}

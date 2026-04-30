import Foundation

final class World {
    var bodies: [PhysicsBody] = []
    var springs: [Spring] = []
    var bounds: Bounds? = nil

    var gravity: Vec3 = .zero
    var magneticB: Vec3 = .zero
    var electricE: Vec3 = .zero
    var drag: Double = 0

    var pairwiseGravity: Bool = false
    var G: Double = 1.0
    var pairwiseCoulomb: Bool = false
    var kCoulomb: Double = 1.0
    var hardSphereCollisions: Bool = false
    var restitution: Double = 1.0

    var time: Double = 0

    func step(dt: Double) {
        guard !bodies.isEmpty else { time += dt; return }
        let n = bodies.count
        var acc = [Vec3](repeating: .zero, count: n)
        computeAccelerations(into: &acc)

        for i in 0..<n where !bodies[i].pinned {
            bodies[i].pos += bodies[i].vel * dt + acc[i] * (0.5 * dt * dt)
        }

        var newAcc = [Vec3](repeating: .zero, count: n)
        computeAccelerations(into: &newAcc)

        for i in 0..<n where !bodies[i].pinned {
            bodies[i].vel += (acc[i] + newAcc[i]) * (0.5 * dt)
        }

        applyRigidConstraints(iterations: 4)
        applyBounds()
        if hardSphereCollisions { applyPairCollisions() }

        time += dt
    }

    private func computeAccelerations(into a: inout [Vec3]) {
        let n = bodies.count
        for i in 0..<n {
            guard !bodies[i].pinned else { a[i] = .zero; continue }
            var f = Vec3.zero
            f += gravity * bodies[i].mass
            f += electricE * bodies[i].charge
            if magneticB.lengthSquared > 1e-18 {
                f += Vec3.cross(bodies[i].vel, magneticB) * bodies[i].charge
            }
            if drag > 0 { f -= bodies[i].vel * (drag * bodies[i].mass) }

            if pairwiseGravity {
                for j in 0..<n where j != i {
                    let d = bodies[j].pos - bodies[i].pos
                    let r2 = d.lengthSquared
                    if r2 < 1e-6 { continue }
                    let r = r2.squareRoot()
                    f += d * (G * bodies[i].mass * bodies[j].mass / (r2 * r))
                }
            }
            if pairwiseCoulomb {
                for j in 0..<n where j != i {
                    let d = bodies[i].pos - bodies[j].pos
                    let r2 = d.lengthSquared
                    if r2 < 1e-6 { continue }
                    let r = r2.squareRoot()
                    f += d * (kCoulomb * bodies[i].charge * bodies[j].charge / (r2 * r))
                }
            }
            for s in springs {
                if s.aId == bodies[i].id || s.bId == bodies[i].id {
                    let other = s.aId == bodies[i].id ? s.bId : s.aId
                    guard let j = bodies.firstIndex(where: { $0.id == other }) else { continue }
                    let d = bodies[j].pos - bodies[i].pos
                    let dist = d.length
                    guard dist > 1e-9 else { continue }
                    let n̂ = d / dist
                    let stretch = dist - s.restLength
                    let relV = Vec3.dot(bodies[j].vel - bodies[i].vel, n̂)
                    f += n̂ * (s.stiffness * stretch + s.damping * relV)
                }
            }

            a[i] = f / bodies[i].mass
        }
    }

    private func applyRigidConstraints(iterations: Int) {
        for _ in 0..<iterations {
            for s in springs where s.rigid {
                guard let i = bodies.firstIndex(where: { $0.id == s.aId }),
                      let j = bodies.firstIndex(where: { $0.id == s.bId })
                else { continue }
                let d = bodies[j].pos - bodies[i].pos
                let dist = d.length
                guard dist > 1e-9 else { continue }
                let diff = (dist - s.restLength) / dist
                let wA = bodies[i].pinned ? 0 : 1.0 / bodies[i].mass
                let wB = bodies[j].pinned ? 0 : 1.0 / bodies[j].mass
                let total = wA + wB
                guard total > 1e-12 else { continue }
                bodies[i].pos += d * (diff * wA / total)
                bodies[j].pos -= d * (diff * wB / total)
            }
        }
    }

    private func applyBounds() {
        guard let b = bounds else { return }
        let dead = b.restitution < 0.05
        for i in bodies.indices where !bodies[i].pinned {
            let r = bodies[i].radius
            var hit = false
            if bodies[i].pos.x < b.min.x + r {
                bodies[i].pos.x = b.min.x + r
                bodies[i].vel.x = abs(bodies[i].vel.x) * b.restitution
                hit = true
            }
            if bodies[i].pos.x > b.max.x - r {
                bodies[i].pos.x = b.max.x - r
                bodies[i].vel.x = -abs(bodies[i].vel.x) * b.restitution
                hit = true
            }
            if bodies[i].pos.y < b.min.y + r {
                bodies[i].pos.y = b.min.y + r
                bodies[i].vel.y = abs(bodies[i].vel.y) * b.restitution
                hit = true
            }
            if bodies[i].pos.y > b.max.y - r {
                bodies[i].pos.y = b.max.y - r
                bodies[i].vel.y = -abs(bodies[i].vel.y) * b.restitution
                hit = true
            }
            if bodies[i].pos.z < b.min.z + r {
                bodies[i].pos.z = b.min.z + r
                bodies[i].vel.z = abs(bodies[i].vel.z) * b.restitution
                hit = true
            }
            if bodies[i].pos.z > b.max.z - r {
                bodies[i].pos.z = b.max.z - r
                bodies[i].vel.z = -abs(bodies[i].vel.z) * b.restitution
                hit = true
            }
            if hit && dead { bodies[i].vel = .zero }
        }
    }

    private func applyPairCollisions() {
        let n = bodies.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                let d = bodies[j].pos - bodies[i].pos
                let dist2 = d.lengthSquared
                let rsum = bodies[i].radius + bodies[j].radius
                if dist2 < rsum * rsum && dist2 > 1e-12 {
                    let dist = dist2.squareRoot()
                    let n̂ = d / dist
                    let rv = bodies[j].vel - bodies[i].vel
                    let vn = Vec3.dot(rv, n̂)
                    if vn < 0 {
                        let m1 = bodies[i].mass
                        let m2 = bodies[j].mass
                        let mu = m1 * m2 / (m1 + m2)
                        let J = (1 + restitution) * mu * vn
                        if !bodies[i].pinned { bodies[i].vel += n̂ * (J / m1) }
                        if !bodies[j].pinned { bodies[j].vel -= n̂ * (J / m2) }
                    }
                    let pen = rsum - dist
                    let m1 = bodies[i].mass
                    let m2 = bodies[j].mass
                    if !bodies[i].pinned { bodies[i].pos -= n̂ * (pen * m2 / (m1 + m2)) }
                    if !bodies[j].pinned { bodies[j].pos += n̂ * (pen * m1 / (m1 + m2)) }
                }
            }
        }
    }
}

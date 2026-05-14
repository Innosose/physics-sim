import Foundation
import Observation

enum Integrator { case euler, velocityVerlet, rk4 }

@Observable
final class World {
    var bodies: [PhysicsBody] = []
    var springs: [Spring] = []
    var bounds: Bounds? = nil

    var gravity: Vec3 = .zero
    var magneticB: Vec3 = .zero
    var electricE: Vec3 = .zero
    var drag: Double = 0
    var integrator: Integrator = .velocityVerlet

    var pairwiseGravity: Bool = false
    var G: Double = 1.0
    var pairwiseCoulomb: Bool = false
    var kCoulomb: Double = 1.0
    var hardSphereCollisions: Bool = false
    var restitution: Double = 1.0

    var time: Double = 0

    var trails: [UUID: [Vec3]] = [:]
    var trailEnabled: Bool = false
    var trailMax: Int = 60

    /// NaN/Inf 가 step 안에서 발생해 위치/속도가 sanitize 된 경우 true.
    /// View 가 이 플래그를 보고 `running = false` 로 일시정지 + 사용자에게
    /// 발산 알림. View 가 한 번 처리한 뒤 false 로 리셋한다.
    var didRecoverFromNaN: Bool = false

    func step(dt: Double) {
        guard !bodies.isEmpty else { time += dt; return }
        // NaN/Inf sanitize at step START — 이전 step 잔재가 computeAccel
        // 로 들어가 Inf 폭주하는 것 방지. 발견 시 didRecoverFromNaN 플래그를
        // 세워 View 가 sim 을 일시정지하고 사용자에게 알림.
        for i in bodies.indices where !(bodies[i].pos.isFinite && bodies[i].vel.isFinite) {
            bodies[i].pos = .zero
            bodies[i].vel = .zero
            didRecoverFromNaN = true
        }
        switch integrator {
        case .euler:          stepEuler(dt: dt)
        case .velocityVerlet: stepVelocityVerlet(dt: dt)
        case .rk4:            stepRK4(dt: dt)
        }
        applyRigidConstraints(iterations: 4)
        applyBounds()
        if hardSphereCollisions { applyPairCollisions() }
        if trailEnabled {
            for b in bodies {
                guard b.pos.isFinite else { continue }
                var arr = trails[b.id] ?? []
                arr.append(b.pos)
                if arr.count > trailMax { arr.removeFirst(arr.count - trailMax) }
                trails[b.id] = arr
            }
            // orphan trails 청소 — body 가 삭제된 뒤에도 dict 엔트리가 남아
            // 세션 동안 누수되던 문제 (60 samples × 24B ≈ 1.5KB / 삭제 body).
            if trails.count > bodies.count {
                let alive = Set(bodies.map { $0.id })
                trails = trails.filter { alive.contains($0.key) }
            }
        }
        // step END 의 second sanitize — 한 프레임 NaN 좌표가 Canvas 로
        // 새어나가는 것 차단. computeAccel/Verlet 이 r²→0 근처에서 만든
        // Inf 가 trails/bounds 통과 후 여기서 잡힘.
        for i in bodies.indices where !(bodies[i].pos.isFinite && bodies[i].vel.isFinite) {
            bodies[i].pos = .zero
            bodies[i].vel = .zero
            didRecoverFromNaN = true
        }
        time += dt
    }

    // MARK: - Integrators

    private func stepEuler(dt: Double) {
        let n = bodies.count
        let pos = bodies.map { $0.pos }
        let vel = bodies.map { $0.vel }
        let a = computeAccel(pos: pos, vel: vel)
        for i in 0..<n where !bodies[i].pinned {
            bodies[i].pos = pos[i] + vel[i] * dt
            bodies[i].vel = vel[i] + a[i] * dt
        }
    }

    private func stepVelocityVerlet(dt: Double) {
        let n = bodies.count
        let pos0 = bodies.map { $0.pos }
        let vel0 = bodies.map { $0.vel }
        let a0 = computeAccel(pos: pos0, vel: vel0)
        var pos1 = pos0
        for i in 0..<n where !bodies[i].pinned {
            pos1[i] = pos0[i] + vel0[i] * dt + a0[i] * (0.5 * dt * dt)
        }
        let a1 = computeAccel(pos: pos1, vel: vel0)
        for i in 0..<n where !bodies[i].pinned {
            bodies[i].pos = pos1[i]
            bodies[i].vel = vel0[i] + (a0[i] + a1[i]) * (0.5 * dt)
        }
    }

    private func stepRK4(dt: Double) {
        let n = bodies.count
        let p0 = bodies.map { $0.pos }
        let v0 = bodies.map { $0.vel }
        let h = dt / 2

        let k1a = computeAccel(pos: p0, vel: v0)

        let p1 = (0..<n).map { i in bodies[i].pinned ? p0[i] : p0[i] + v0[i] * h }
        let v1 = (0..<n).map { i in bodies[i].pinned ? v0[i] : v0[i] + k1a[i] * h }
        let k2a = computeAccel(pos: p1, vel: v1)

        let p2 = (0..<n).map { i in bodies[i].pinned ? p0[i] : p0[i] + v1[i] * h }
        let v2 = (0..<n).map { i in bodies[i].pinned ? v0[i] : v0[i] + k2a[i] * h }
        let k3a = computeAccel(pos: p2, vel: v2)

        let p3 = (0..<n).map { i in bodies[i].pinned ? p0[i] : p0[i] + v2[i] * dt }
        let v3 = (0..<n).map { i in bodies[i].pinned ? v0[i] : v0[i] + k3a[i] * dt }
        let k4a = computeAccel(pos: p3, vel: v3)

        let w6 = dt / 6
        for i in 0..<n where !bodies[i].pinned {
            bodies[i].pos = p0[i] + (v0[i] + v1[i] * 2 + v2[i] * 2 + v3[i]) * w6
            bodies[i].vel = v0[i] + (k1a[i] + k2a[i] * 2 + k3a[i] * 2 + k4a[i]) * w6
        }
    }

    // MARK: - Diagnostics (for visualization)

    struct EnergyBreakdown {
        var kinetic: Double
        var potential: Double
        var total: Double { kinetic + potential }
    }

    func accelerations() -> [Vec3] {
        let pos = bodies.map { $0.pos }
        let vel = bodies.map { $0.vel }
        return computeAccel(pos: pos, vel: vel)
    }

    func energyBreakdown() -> EnergyBreakdown {
        var ke: Double = 0
        var pe: Double = 0
        for b in bodies where !b.pinned {
            ke += 0.5 * b.mass * b.vel.lengthSquared
        }
        if gravity.lengthSquared > 1e-12 {
            for b in bodies where !b.pinned {
                pe += -b.mass * Vec3.dot(gravity, b.pos)
            }
        }
        // Plummer-softened PE — computeAccel 와 일관.
        let softening2: Double = 1e-4
        if pairwiseGravity {
            let n = bodies.count
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let r = ((bodies[j].pos - bodies[i].pos).lengthSquared + softening2).squareRoot()
                    pe -= G * bodies[i].mass * bodies[j].mass / r
                }
            }
        }
        for s in springs where !s.rigid {
            if let i = bodies.firstIndex(where: { $0.id == s.aId }),
               let j = bodies.firstIndex(where: { $0.id == s.bId }) {
                let d = (bodies[j].pos - bodies[i].pos).length
                let stretch = d - s.restLength
                pe += 0.5 * s.stiffness * stretch * stretch
            }
        }
        if pairwiseCoulomb {
            let n = bodies.count
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let r = ((bodies[j].pos - bodies[i].pos).lengthSquared + softening2).squareRoot()
                    pe += kCoulomb * bodies[i].charge * bodies[j].charge / r
                }
            }
        }
        return EnergyBreakdown(kinetic: ke, potential: pe)
    }

    // MARK: - Force computation

    private func computeAccel(pos: [Vec3], vel: [Vec3]) -> [Vec3] {
        let n = bodies.count
        var a = [Vec3](repeating: .zero, count: n)
        for i in 0..<n {
            guard !bodies[i].pinned else { continue }
            var f = Vec3.zero
            f += gravity * bodies[i].mass
            f += electricE * bodies[i].charge
            if magneticB.lengthSquared > 1e-18 {
                f += Vec3.cross(vel[i], magneticB) * bodies[i].charge
            }
            // 선형 점성 항력: F = -bv (힘) — 단위질량당이 아닌 진짜 힘.
            // 옛 (drag * mass) 곱셈은 a = -drag·v 가 되어 질량과 무관,
            // 종단속도 추론(F_drag = mg → v_∞ = mg/b)을 깨뜨림.
            if drag > 0 { f -= vel[i] * drag }
            // Plummer softening: f ∝ d / (r² + ε²)^(3/2). 옛 hard-cutoff
            // (r²<1e-3 skip) 은 figure-8 같이 r≈0 근처를 통과하는 canonical
            // 궤도를 깨뜨림. ε² = 1e-4 (ε ≈ 1cm) 로 매우 작아 r>0.1m 에선
            // 1/r² 와 거의 동일, 근접에선 부드럽게 bounded.
            let softening2: Double = 1e-4
            if pairwiseGravity {
                for j in 0..<n where j != i {
                    let d = pos[j] - pos[i]
                    let r2 = d.lengthSquared + softening2
                    let inv = pow(r2, -1.5)
                    f += d * (G * bodies[i].mass * bodies[j].mass * inv)
                }
            }
            if pairwiseCoulomb {
                for j in 0..<n where j != i {
                    let d = pos[i] - pos[j]
                    let r2 = d.lengthSquared + softening2
                    let inv = pow(r2, -1.5)
                    f += d * (kCoulomb * bodies[i].charge * bodies[j].charge * inv)
                }
            }
            for s in springs where !s.rigid {
                if s.aId == bodies[i].id || s.bId == bodies[i].id {
                    let other = s.aId == bodies[i].id ? s.bId : s.aId
                    guard let j = bodies.firstIndex(where: { $0.id == other }) else { continue }
                    let d = pos[j] - pos[i]
                    let dist = d.length
                    guard dist > 1e-9 else { continue }
                    let n̂ = d / dist
                    let stretch = dist - s.restLength
                    let relV = Vec3.dot(vel[j] - vel[i], n̂)
                    f += n̂ * (s.stiffness * stretch + s.damping * relV)
                }
            }
            a[i] = f / bodies[i].mass
        }
        return a
    }

    // MARK: - Constraints & collisions

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
                // 속도 정사영 — 위치만 projection 하면 다음 step 에서
                // 방사방향 속도 성분이 다시 거리오류를 만들어 진자 주기가
                // 분석해 2π√(L/g)·(1+θ²/16) 와 어긋남. 상대 속도 중
                // 제약 법선(n̂) 성분을 0 으로 만드는 impulse 적용.
                let n̂ = d / dist
                let vRel = Vec3.dot(bodies[j].vel - bodies[i].vel, n̂)
                let lambda = vRel / total
                if !bodies[i].pinned { bodies[i].vel += n̂ * (lambda * wA) }
                if !bodies[j].pinned { bodies[j].vel -= n̂ * (lambda * wB) }
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

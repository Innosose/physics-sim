import Foundation

/// 통합 3D 물리 월드 — 모든 역학·전자기 시뮬의 공통 엔진.
///
/// 상태 보유는 reference type — SwiftUI `@State` 로 두면 매 프레임 diff 가
/// 폭발하므로 `World` 인스턴스를 `@State` 의 reference 로만 보관. 시각화
/// (RealityView) 는 `TimelineView` tick 으로 자체 재실행되어 관찰이 불필요.
///
/// 적분: Velocity-Verlet. 닫힌 해가 있는 케이스 (자유낙하·진자 cn 등) 도 같은
/// 적분기로 처리해 일관성 유지 — 정확도가 충분하면 학습용으로 차이 무시 가능.
final class World {
    var bodies: [PhysicsBody] = []
    var springs: [Spring] = []
    var bounds: Bounds? = nil

    // MARK: - Force fields (균일)

    /// 균일 중력 가속도 (m/s²). 일반적으로 (0, -g, 0).
    var gravity: Vec3 = .zero
    /// 균일 자기장 (T). Lorentz 힘 F = qv×B.
    var magneticB: Vec3 = .zero
    /// 균일 전기장 (V/m). F = qE.
    var electricE: Vec3 = .zero
    /// 선형 항력 계수 (1/s). F = -k m v.
    var drag: Double = 0

    // MARK: - 페어 상호작용

    /// 입자 사이 만유인력. ON 이면 모든 페어가 1/r² 끌림.
    var pairwiseGravity: Bool = false
    /// 만유인력 상수 (사용자 단위).
    var G: Double = 1.0
    /// 입자 사이 쿨롱 힘. ON 이면 charge 간 1/r².
    var pairwiseCoulomb: Bool = false
    /// 쿨롱 상수 (사용자 단위).
    var kCoulomb: Double = 1.0
    /// 입자 간 딱딱한 구 충돌. ON 이면 충돌 시 임펄스.
    var hardSphereCollisions: Bool = false
    /// 입자 충돌 반발계수 (모든 쌍 공통).
    var restitution: Double = 1.0

    // MARK: - 시간

    /// 시뮬 누적 시간 (s).
    var time: Double = 0

    // MARK: - 적분

    /// dt 만큼 진행. 큰 dt 는 안정성 떨어지므로 호출자가 sub-step 분할.
    func step(dt: Double) {
        guard !bodies.isEmpty else { time += dt; return }
        let n = bodies.count
        var acc = [Vec3](repeating: .zero, count: n)
        computeAccelerations(into: &acc)

        // x ← x + v dt + ½ a dt²
        for i in 0..<n where !bodies[i].pinned {
            bodies[i].pos += bodies[i].vel * dt + acc[i] * (0.5 * dt * dt)
        }

        var newAcc = [Vec3](repeating: .zero, count: n)
        computeAccelerations(into: &newAcc)

        // v ← v + ½ (a_old + a_new) dt
        for i in 0..<n where !bodies[i].pinned {
            bodies[i].vel += (acc[i] + newAcc[i]) * (0.5 * dt)
        }

        // 강체 거리 구속 (펜듈럼 등) — 위치 직접 보정.
        applyRigidConstraints(iterations: 4)

        // 박스 충돌.
        applyBounds()

        // 입자 간 충돌.
        if hardSphereCollisions { applyPairCollisions() }

        time += dt
    }

    /// 모든 힘을 합산해 각 body 의 가속도 채움.
    private func computeAccelerations(into a: inout [Vec3]) {
        let n = bodies.count
        for i in 0..<n {
            guard !bodies[i].pinned else { a[i] = .zero; continue }
            var f = Vec3.zero
            // 균일장.
            f += gravity * bodies[i].mass
            f += electricE * bodies[i].charge
            // Lorentz: F = q v × B.
            if magneticB.lengthSquared > 1e-18 {
                f += Vec3.cross(bodies[i].vel, magneticB) * bodies[i].charge
            }
            // 선형 항력 (단위 시상수).
            if drag > 0 { f -= bodies[i].vel * (drag * bodies[i].mass) }

            // 페어 만유인력.
            if pairwiseGravity {
                for j in 0..<n where j != i {
                    let d = bodies[j].pos - bodies[i].pos
                    let r2 = d.lengthSquared
                    if r2 < 1e-6 { continue }
                    let r = r2.squareRoot()
                    f += d * (G * bodies[i].mass * bodies[j].mass / (r2 * r))
                }
            }
            // 페어 쿨롱.
            if pairwiseCoulomb {
                for j in 0..<n where j != i {
                    let d = bodies[i].pos - bodies[j].pos      // 같은 부호끼리는 밀어냄
                    let r2 = d.lengthSquared
                    if r2 < 1e-6 { continue }
                    let r = r2.squareRoot()
                    f += d * (kCoulomb * bodies[i].charge * bodies[j].charge / (r2 * r))
                }
            }
            // 스프링.
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

    /// 강체 거리 (rigid spring) 위치 직접 보정 — Verlet 적분 후 호출.
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
        for i in bodies.indices where !bodies[i].pinned {
            let r = bodies[i].radius
            if bodies[i].pos.x < b.min.x + r {
                bodies[i].pos.x = b.min.x + r
                bodies[i].vel.x = abs(bodies[i].vel.x) * b.restitution
            }
            if bodies[i].pos.x > b.max.x - r {
                bodies[i].pos.x = b.max.x - r
                bodies[i].vel.x = -abs(bodies[i].vel.x) * b.restitution
            }
            if bodies[i].pos.y < b.min.y + r {
                bodies[i].pos.y = b.min.y + r
                bodies[i].vel.y = abs(bodies[i].vel.y) * b.restitution
            }
            if bodies[i].pos.y > b.max.y - r {
                bodies[i].pos.y = b.max.y - r
                bodies[i].vel.y = -abs(bodies[i].vel.y) * b.restitution
            }
            if bodies[i].pos.z < b.min.z + r {
                bodies[i].pos.z = b.min.z + r
                bodies[i].vel.z = abs(bodies[i].vel.z) * b.restitution
            }
            if bodies[i].pos.z > b.max.z - r {
                bodies[i].pos.z = b.max.z - r
                bodies[i].vel.z = -abs(bodies[i].vel.z) * b.restitution
            }
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
                    // 침투 보정.
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

import SwiftUI

/// 역학 계열 프리셋 — 통합 World 엔진을 사용. 모두 같은 `step(dt:)` 으로 적분.
enum MechanicsPresets {

    // MARK: - 자유낙하·연직 던지기

    static func freeFall(_ w: World) {
        w.gravity = Vec3(x: 0, y: -9.81, z: 0)
        w.bounds = Bounds(min: Vec3(x: -10, y: 0, z: -2),
                          max: Vec3(x: 10, y: 60, z: 2),
                          restitution: 0.5)
        w.bodies = [
            Body(pos: Vec3(x: 0, y: 20, z: 0),
                 vel: Vec3(x: 0, y: 5, z: 0),
                 mass: 1, radius: 0.4,
                 color: .yellow)
        ]
    }

    // MARK: - 등속 vs 등가속도 비교

    static func motionGraph(_ w: World) {
        // 두 카트가 같은 시각에 출발.
        w.gravity = .zero
        w.bounds = Bounds(min: Vec3(x: 0, y: -1, z: -2),
                          max: Vec3(x: 60, y: 4, z: 2),
                          restitution: 0)
        // 등속 카트.
        var c1 = Body(pos: Vec3(x: 0, y: 0.5, z: 0.6),
                      vel: Vec3(x: 5, y: 0, z: 0),
                      mass: 1, radius: 0.3, color: .cyan)
        c1.kind = .particle
        // 등가속도 카트 — 가속도 a 를 균일중력 흉내로 줄 순 없으니 항력으로 근사.
        // 단순화: 두 입자 모두 외부 힘 없이 초기속도만 — 가속도는 사용자가 spawner
        // 로 추가할 수 있도록 비워둠. 학습용으로 부족하면 별도 graph 모드.
        let c2 = Body(pos: Vec3(x: 0, y: 0.5, z: -0.6),
                      vel: Vec3(x: 0, y: 0, z: 0),
                      mass: 1, radius: 0.3, color: .orange)
        w.bodies = [c1, c2]
    }

    // MARK: - 포물선 운동

    static func projectile(_ w: World) {
        let θ = 55.0 * .pi / 180
        let v0 = 22.0
        w.gravity = Vec3(x: 0, y: -9.81, z: 0)
        w.drag = 0.10                // 선형 항력
        w.bounds = Bounds(min: Vec3(x: -2, y: 0, z: -3),
                          max: Vec3(x: 80, y: 40, z: 3),
                          restitution: 0)
        w.bodies = [
            Body(pos: Vec3(x: 0, y: 0.5, z: 0),
                 vel: Vec3(x: v0 * cos(θ), y: v0 * sin(θ), z: 0),
                 mass: 1, radius: 0.3, color: .yellow)
        ]
    }

    // MARK: - 1차원 충돌

    static func collision1D(_ w: World) {
        w.gravity = .zero
        w.hardSphereCollisions = true
        w.restitution = 1.0          // 완전탄성 — 사용자가 슬라이더로 조절.
        w.bounds = Bounds(min: Vec3(x: -8, y: -1, z: -2),
                          max: Vec3(x: 8, y: 4, z: 2),
                          restitution: 1.0)
        w.bodies = [
            Body(pos: Vec3(x: -3, y: 0.5, z: 0),
                 vel: Vec3(x: 3, y: 0, z: 0),
                 mass: 2, radius: 0.5, color: .yellow),
            Body(pos: Vec3(x: 3, y: 0.5, z: 0),
                 vel: Vec3(x: -1, y: 0, z: 0),
                 mass: 1, radius: 0.4, color: .cyan),
        ]
    }

    // MARK: - 단진자

    static func pendulum(_ w: World) {
        w.gravity = Vec3(x: 0, y: -9.81, z: 0)
        // 천장 anchor (pinned) + 추.
        let pivot = Body(pos: Vec3(x: 0, y: 3, z: 0),
                         mass: 1e9, radius: 0.1,
                         color: .gray, pinned: true, kind: .anchor)
        let θ0 = 60.0 * .pi / 180
        let L = 1.5
        let bob = Body(pos: Vec3(x: pivot.pos.x + L * sin(θ0),
                                 y: pivot.pos.y - L * cos(θ0),
                                 z: 0),
                       mass: 1, radius: 0.18,
                       color: .yellow)
        w.bodies = [pivot, bob]
        w.springs = [
            Spring(aId: pivot.id, bId: bob.id,
                   restLength: L, stiffness: 0, damping: 0, rigid: true)
        ]
    }

    // MARK: - 스프링 (감쇠·구동) — 구동력은 시간 함수, 별도 외력 모듈 필요.

    static func spring(_ w: World) {
        w.gravity = .zero
        let wall = Body(pos: Vec3(x: -3, y: 1, z: 0),
                        mass: 1e9, radius: 0.2,
                        color: .gray, pinned: true, kind: .anchor)
        let mass = Body(pos: Vec3(x: 0, y: 1, z: 0),
                        vel: Vec3(x: 1, y: 0, z: 0),
                        mass: 1, radius: 0.3, color: .yellow)
        w.bodies = [wall, mass]
        w.springs = [
            Spring(aId: wall.id, bId: mass.id,
                   restLength: 3, stiffness: 25, damping: 0.6, rigid: false)
        ]
    }

    // MARK: - 케플러 궤도

    static func kepler(_ w: World) {
        w.pairwiseGravity = true
        w.G = 1.0
        let sun = Body(pos: .zero, mass: 200, radius: 0.6,
                       color: Color(red: 1.0, green: 0.74, blue: 0.40),
                       pinned: true, kind: .star)
        let r = 5.0
        let v = (w.G * sun.mass / r).squareRoot()
        let planet = Body(pos: Vec3(x: r, y: 0, z: 0),
                          vel: Vec3(x: 0, y: v, z: 0),
                          mass: 1, radius: 0.2,
                          color: Color(red: 0.74, green: 0.88, blue: 0.96),
                          kind: .planet)
        w.bodies = [sun, planet]
    }

    // MARK: - 자유 충돌 박스 (재질·다체)

    static func freeCollision(_ w: World) {
        w.gravity = .zero
        w.hardSphereCollisions = true
        w.restitution = 0.95
        w.bounds = Bounds(min: Vec3(x: -1, y: -1, z: -1),
                          max: Vec3(x: 1, y: 1, z: 1),
                          restitution: 0.95)
        w.bodies = [
            Body(pos: Vec3(x: -0.7, y: 0, z: 0),
                 vel: Vec3(x: 1, y: 0.05, z: 0),
                 mass: 2.5, radius: 0.12, color: .gray),
            Body(pos: Vec3(x: 0, y: 0, z: 0),
                 mass: 1.0, radius: 0.10, color: .pink),
            Body(pos: Vec3(x: 0.7, y: 0, z: 0),
                 vel: Vec3(x: -0.7, y: -0.05, z: 0),
                 mass: 2.0, radius: 0.12, color: .brown),
        ]
    }

    // MARK: - N체 중력

    static func nBody(_ w: World) {
        w.pairwiseGravity = true
        w.G = 1.0
        let sun = Body(pos: .zero, mass: 100, radius: 0.5,
                       color: Color(red: 1.00, green: 0.83, blue: 0.50),
                       kind: .star)
        var arr = [sun]
        let radii = [2.0, 3.5, 5.0]
        let colors: [Color] = [
            Color(red: 0.55, green: 0.78, blue: 1.00),
            Color(red: 0.85, green: 0.92, blue: 1.00),
            Color(red: 1.00, green: 0.74, blue: 0.46),
        ]
        for (i, r) in radii.enumerated() {
            let v = (w.G * sun.mass / r).squareRoot()
            let θ = Double(i) * 2.1
            arr.append(Body(
                pos: Vec3(x: r * cos(θ), y: r * sin(θ), z: 0),
                vel: Vec3(x: -v * sin(θ), y: v * cos(θ), z: 0),
                mass: 0.5, radius: 0.18, color: colors[i],
                kind: .planet))
        }
        // 운동량 0 보정.
        let totalMass = arr.reduce(0) { $0 + $1.mass }
        let mom = arr.reduce(Vec3.zero) { $0 + $1.vel * $1.mass }
        let dv = mom / totalMass
        for i in arr.indices { arr[i].vel -= dv }
        w.bodies = arr
    }

    // MARK: - 자기장 속 하전입자 (Lorentz)

    static func lorentz(_ w: World) {
        w.magneticB = Vec3(x: 0, y: 0, z: 1)        // 화면 안쪽 +z
        w.electricE = .zero
        w.bodies = [
            Body(pos: Vec3(x: -2, y: 0, z: 0),
                 vel: Vec3(x: 1.5, y: 0, z: 0),
                 mass: 1, radius: 0.2, charge: 1,
                 color: .red, kind: .charge)
        ]
    }

    // MARK: - 전기력선 (점전하 배치)

    static func eField(_ w: World) {
        w.pairwiseCoulomb = true
        w.kCoulomb = 1.0
        // 두 전하는 pinned (정적 dipole) — 학습용. 자유 spawner 로 추가 가능.
        w.bodies = [
            Body(pos: Vec3(x: -2, y: 0, z: 0),
                 mass: 1, radius: 0.25, charge: 1, color: .red,
                 pinned: true, kind: .charge),
            Body(pos: Vec3(x: 2, y: 0, z: 0),
                 mass: 1, radius: 0.25, charge: -1, color: .blue,
                 pinned: true, kind: .charge),
        ]
    }

    // MARK: - 열전달 (입자 단일·단순 지수 감쇠) — graph 렌더에 위임.

    static func heatTransfer(_ w: World) {
        // 통합 엔진에 직접 안 맞음 — graph kind 로 별도 렌더.
        w.bodies = []
    }
}

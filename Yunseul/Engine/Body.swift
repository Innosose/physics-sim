import SwiftUI

/// 통합 월드의 물리 객체.
///
/// 한 타입이 모든 역할 — 입자·행성·전하·카트·봅 (펜듈럼 추) 까지.
/// 어떤 힘이 작용할지는 `World` 의 force field 설정과 `kind` 가 함께 결정.
struct PhysicsBody: Identifiable {
    let id = UUID()
    var pos: Vec3
    var vel: Vec3 = .zero
    var mass: Double = 1.0
    var radius: Double = 0.1
    var charge: Double = 0
    var color: Color = .yellow
    /// true 면 적분 단계에서 위치·속도 변하지 않음 (벽·앵커·렌즈 중심 등).
    var pinned: Bool = false
    /// 시각·연관 물리 힌트.
    var kind: Kind = .particle

    enum Kind: String, Hashable {
        case particle, planet, star, charge, photon, anchor
    }
}

/// 펜듈럼·스프링 등 두 객체 사이의 강한 구속을 표현.
struct Spring: Identifiable {
    let id = UUID()
    var aId: UUID
    var bId: UUID
    var restLength: Double
    var stiffness: Double      // k (N/m)
    var damping: Double = 0    // c (N·s/m)
    /// true 면 강체-거리 (펜듈럼) 처럼 동작 — Verlet 위치 보정 반복.
    var rigid: Bool = false
}

/// 박스 경계 — 안쪽으로 입자를 가둬 두는 데 사용.
struct Bounds {
    var min: Vec3
    var max: Vec3
    /// 벽 충돌 시 반발계수 (0..1).
    var restitution: Double = 1.0
}

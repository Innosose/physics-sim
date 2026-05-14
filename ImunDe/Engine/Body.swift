import SwiftUI

struct PhysicsBody: Identifiable {
    let id = UUID()
    var pos: Vec3
    var vel: Vec3 = .zero
    var mass: Double = 1.0
    var radius: Double = 0.1
    var charge: Double = 0
    var color: Color = .yellow
    var pinned: Bool = false
    var kind: Kind = .particle
    var name: String? = nil

    enum Kind: String, Hashable {
        case particle, planet, star, charge, photon, anchor
    }
}

struct Spring: Identifiable {
    let id = UUID()
    var aId: UUID
    var bId: UUID
    var restLength: Double
    var stiffness: Double
    var damping: Double = 0
    var rigid: Bool = false
}

struct Bounds {
    var min: Vec3
    var max: Vec3
    var restitution: Double = 1.0
}

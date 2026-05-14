import CoreGraphics
import Foundation

struct Vec3: Equatable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vec3(x: 0, y: 0, z: 0)

    init(x: Double, y: Double, z: Double) {
        self.x = x; self.y = y; self.z = z
    }

    init(x: Double, y: Double) { self.init(x: x, y: y, z: 0) }

    var length: Double { (x * x + y * y + z * z).squareRoot() }
    var lengthSquared: Double { x * x + y * y + z * z }
    var normalized: Vec3 {
        let l = length
        return l > 0 ? self / l : .zero
    }

    static func + (a: Vec3, b: Vec3) -> Vec3 {
        Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
    }
    static func - (a: Vec3, b: Vec3) -> Vec3 {
        Vec3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)
    }
    static func * (a: Vec3, s: Double) -> Vec3 {
        Vec3(x: a.x * s, y: a.y * s, z: a.z * s)
    }
    static func * (s: Double, a: Vec3) -> Vec3 { a * s }
    static func / (a: Vec3, s: Double) -> Vec3 {
        Vec3(x: a.x / s, y: a.y / s, z: a.z / s)
    }
    static func += (a: inout Vec3, b: Vec3) { a = a + b }
    static func -= (a: inout Vec3, b: Vec3) { a = a - b }
    static prefix func - (a: Vec3) -> Vec3 { Vec3(x: -a.x, y: -a.y, z: -a.z) }

    static func dot(_ a: Vec3, _ b: Vec3) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        Vec3(x: a.y * b.z - a.z * b.y,
             y: a.z * b.x - a.x * b.z,
             z: a.x * b.y - a.y * b.x)
    }

    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

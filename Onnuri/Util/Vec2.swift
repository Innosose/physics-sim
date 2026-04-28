import CoreGraphics
import Foundation

/// 2D 벡터. 시뮬레이션 전반에서 공유.
struct Vec2: Equatable {
    var x: Double
    var y: Double

    static let zero = Vec2(x: 0, y: 0)

    init(x: Double, y: Double) { self.x = x; self.y = y }
    init(_ p: CGPoint) { self.x = Double(p.x); self.y = Double(p.y) }

    var length: Double { (x * x + y * y).squareRoot() }
    var lengthSquared: Double { x * x + y * y }
    var normalized: Vec2 {
        let l = length
        return l > 0 ? Vec2(x: x / l, y: y / l) : .zero
    }

    static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: Vec2, s: Double) -> Vec2 { Vec2(x: a.x * s, y: a.y * s) }
    static func * (s: Double, a: Vec2) -> Vec2 { a * s }
    static func / (a: Vec2, s: Double) -> Vec2 { Vec2(x: a.x / s, y: a.y / s) }
    static func += (a: inout Vec2, b: Vec2) { a = a + b }
    static func -= (a: inout Vec2, b: Vec2) { a = a - b }
    static prefix func - (a: Vec2) -> Vec2 { Vec2(x: -a.x, y: -a.y) }

    static func dot(_ a: Vec2, _ b: Vec2) -> Double { a.x * b.x + a.y * b.y }
    /// 2D 외적의 z 성분.
    static func cross(_ a: Vec2, _ b: Vec2) -> Double { a.x * b.y - a.y * b.x }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

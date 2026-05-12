import SwiftUI

enum PresetCatalog {

    static let all: [Preset] = [
        Preset(id: "freefall",
               title: "자유낙하·연직 던지기",
               curriculum: .middle, category: .mechanics,
               calculatorTopic: .freefall,
               kind: .mechanics2D,
               load: MechanicsPresets.freeFall),

        Preset(id: "motiongraph",
               title: "등속 vs 등가속도",
               curriculum: .middle, category: .mechanics,
               calculatorTopic: nil,
               kind: .graph,
               load: { _ in }),

        Preset(id: "reflection",
               title: "빛의 반사·굴절",
               curriculum: .middle, category: .optics,
               calculatorTopic: .refraction,
               kind: .optics(.reflection),
               load: { _ in }),

        Preset(id: "circuit",
               title: "직렬·병렬 회로",
               curriculum: .middle, category: .electromagnetism,
               calculatorTopic: .ohm,
               kind: .circuit(.circuit),
               load: { _ in }),

        Preset(id: "heat",
               title: "열전달과 평형",
               curriculum: .middle, category: .waveThermo,
               calculatorTopic: nil,
               kind: .graph,
               load: { _ in }),

        Preset(id: "collision1d",
               title: "1차원 충돌",
               curriculum: .middle, category: .mechanics,
               calculatorTopic: .collision,
               kind: .mechanics2D,
               load: MechanicsPresets.collision1D),

        Preset(id: "projectile",
               title: "포물선 운동",
               curriculum: .high, category: .mechanics,
               calculatorTopic: .projectile,
               kind: .mechanics2D,
               load: MechanicsPresets.projectile),

        Preset(id: "pendulum",
               title: "단진자",
               curriculum: .high, category: .mechanics,
               calculatorTopic: .pendulum,
               kind: .mechanics2D,
               load: MechanicsPresets.pendulum),

        Preset(id: "spring",
               title: "감쇠·구동 진동자",
               curriculum: .high, category: .mechanics,
               calculatorTopic: nil,
               kind: .mechanics2D,
               load: MechanicsPresets.spring),

        Preset(id: "kepler",
               title: "케플러 궤도",
               curriculum: .high, category: .mechanics,
               calculatorTopic: .kepler,
               kind: .mechanics2D,
               load: MechanicsPresets.kepler),

        Preset(id: "wavesum",
               title: "파동의 중첩",
               curriculum: .high, category: .waveThermo,
               calculatorTopic: nil,
               kind: .wave(.waveSum),
               load: { _ in }),

        Preset(id: "doppler",
               title: "도플러 효과",
               curriculum: .high, category: .waveThermo,
               calculatorTopic: .doppler,
               kind: .wave(.doppler),
               load: { _ in }),

        Preset(id: "kinetic",
               title: "기체 분자 운동",
               curriculum: .high, category: .waveThermo,
               calculatorTopic: nil,
               kind: .mechanics2D,
               load: { w in
                   w.gravity = .zero
                   w.hardSphereCollisions = true
                   w.restitution = 1.0
                   w.bounds = Bounds(min: Vec3(x: -1, y: -1, z: -1),
                                     max: Vec3(x: 1, y: 1, z: 1),
                                     restitution: 1.0)
                   var rng = SystemRandomNumberGenerator()
                   var bs: [PhysicsBody] = []
                   let n = 80, r = 0.04, speed = 0.4
                   let cols = max(1, Int(Double(n).squareRoot().rounded(.up)))
                   let cell = (1 - 4 * r) / Double(cols)
                   var i = 0
                   for ix in 0..<cols {
                       for iy in 0..<cols {
                           if i >= n { break }
                           let x = -0.5 + 2 * r + cell * (Double(ix) + 0.5)
                           let y = -0.5 + 2 * r + cell * (Double(iy) + 0.5)
                           let θ = Double.random(in: 0...(2 * .pi), using: &rng)
                           bs.append(PhysicsBody(
                               pos: Vec3(x: x, y: y, z: 0),
                               vel: Vec3(x: speed * cos(θ), y: speed * sin(θ), z: 0),
                               mass: 1, radius: r,
                               color: .cyan))
                           i += 1
                       }
                   }
                   w.bodies = bs
               }),

        Preset(id: "efield",
               title: "전기력선",
               curriculum: .high, category: .electromagnetism,
               calculatorTopic: nil,
               kind: .mechanics2D,
               load: MechanicsPresets.eField),

        Preset(id: "lorentz",
               title: "자기장 속 하전입자",
               curriculum: .high, category: .electromagnetism,
               calculatorTopic: nil,
               kind: .mechanics2D,
               load: MechanicsPresets.lorentz),

        Preset(id: "rlc",
               title: "직렬 RLC 회로",
               curriculum: .high, category: .electromagnetism,
               calculatorTopic: nil,
               kind: .circuit(.rlc),
               load: { _ in }),

        Preset(id: "doubleslit",
               title: "이중 슬릿",
               curriculum: .high, category: .optics,
               calculatorTopic: .slit,
               kind: .optics(.doubleSlit),
               load: { _ in }),

        Preset(id: "lens",
               title: "얇은 렌즈 결상",
               curriculum: .high, category: .optics,
               calculatorTopic: .lens,
               kind: .optics(.lens),
               load: { _ in }),

        Preset(id: "freecollide",
               title: "자유 충돌 박스",
               curriculum: .free, category: .sandbox,
               calculatorTopic: nil,
               kind: .mechanics2D,
               load: MechanicsPresets.freeCollision),

        Preset(id: "nbody",
               title: "N체 중력",
               curriculum: .free, category: .sandbox,
               calculatorTopic: nil,
               kind: .mechanics2D,
               load: MechanicsPresets.solarSystem),
    ]

    static func preset(_ id: String) -> Preset? {
        all.first { $0.id == id }
    }

    static func curriculum(of preset: Preset) -> Curriculum { preset.curriculum }

    static func items(for c: Curriculum) -> [Preset] {
        all.filter { $0.curriculum == c }
    }

    static func grouped(for c: Curriculum) -> [(SimCategory, [Preset])] {
        let items = items(for: c)
        var dict: [SimCategory: [Preset]] = [:]
        for it in items { dict[it.category, default: []].append(it) }
        return SimCategory.allCases.compactMap { cat in
            dict[cat].map { (cat, $0) }
        }
    }

    static func preset(forTopic t: CalculatorTopic) -> Preset? {
        all.first { $0.calculatorTopic == t }
    }
}

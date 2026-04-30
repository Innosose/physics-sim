import SwiftUI

/// 모든 프리셋의 단일 등록처. 사이드바·계산기 매핑·기능별 그룹화에 사용.
enum PresetCatalog {

    static let all: [Preset] = [
        // ─── 중학교 ───
        Preset(id: "freefall",
               title: "자유낙하·연직 던지기",
               curriculum: .middle, category: .mechanics,
               curriculumLabel: "중3 과학 · 운동과 에너지",
               blurb: "공의 위치와 속도는 시간의 1·2차 함수. 위로 던지면 v=0 인 최고점에서 내려옴.",
               calculatorTopic: .freefall,
               kind: .mechanics,
               load: MechanicsPresets.freeFall),

        Preset(id: "motiongraph",
               title: "등속 vs 등가속도",
               curriculum: .middle, category: .mechanics,
               curriculumLabel: "중3 과학 · 운동의 표현",
               blurb: "두 카트가 같은 시각에 출발 — 한 쪽은 등속, 한 쪽은 등가속도.",
               calculatorTopic: nil,
               kind: .graph,
               load: MechanicsPresets.motionGraph),

        Preset(id: "reflection",
               title: "빛의 반사·굴절",
               curriculum: .middle, category: .optics,
               curriculumLabel: "중1 과학 · 빛과 파동",
               blurb: "두 매질 경계에서 빛은 일부 반사, 일부 굴절. 큰 매질→작은 매질 일 때 임계각 너머로 전반사.",
               calculatorTopic: .refraction,
               kind: .optics(.reflection),
               load: { _ in }),

        Preset(id: "circuit",
               title: "직렬·병렬 회로",
               curriculum: .middle, category: .electromagnetism,
               curriculumLabel: "중2 과학 · 전기와 자기",
               blurb: "직렬은 전류 같고 전압 나뉨, 병렬은 전압 같고 전류 나뉨.",
               calculatorTopic: .ohm,
               kind: .circuit(.circuit),
               load: { _ in }),

        Preset(id: "heat",
               title: "열전달과 평형",
               curriculum: .middle, category: .waveThermo,
               curriculumLabel: "중1 과학 · 열과 우리 생활",
               blurb: "두 물체가 닿으면 따뜻한 쪽에서 차가운 쪽으로 열이 흘러 같아진다.",
               calculatorTopic: nil,
               kind: .graph,
               load: MechanicsPresets.heatTransfer),

        Preset(id: "collision1d",
               title: "1차원 충돌",
               curriculum: .middle, category: .mechanics,
               curriculumLabel: "중3 / 물리Ⅰ · 운동량과 충돌",
               blurb: "운동량은 항상 보존, 운동에너지는 e=1 일 때만 보존.",
               calculatorTopic: .collision,
               kind: .mechanics,
               load: MechanicsPresets.collision1D),

        // ─── 고등학교 ───
        Preset(id: "projectile",
               title: "포물선 운동",
               curriculum: .high, category: .mechanics,
               curriculumLabel: "물리Ⅰ · 등가속도 운동",
               blurb: "공기 저항이 있을 때와 없을 때의 자취 비교. 3D 시점 자유 회전.",
               calculatorTopic: .projectile,
               kind: .mechanics,
               load: MechanicsPresets.projectile),

        Preset(id: "pendulum",
               title: "단진자",
               curriculum: .high, category: .mechanics,
               curriculumLabel: "물리Ⅰ / 물리Ⅱ · 진자·역학적 진동",
               blurb: "강체 거리 구속 — 작은-각이면 단순조화, 큰 진폭이면 비선형 효과.",
               calculatorTopic: .pendulum,
               kind: .mechanics,
               load: MechanicsPresets.pendulum),

        Preset(id: "spring",
               title: "감쇠·구동 진동자",
               curriculum: .high, category: .mechanics,
               curriculumLabel: "물리Ⅱ · 역학적 진동",
               blurb: "감쇠비 ζ — 소·임계·과감쇠. 구동 진동수 ω_d 가 ω₀ 근처면 공명.",
               calculatorTopic: nil,
               kind: .mechanics,
               load: MechanicsPresets.spring),

        Preset(id: "kepler",
               title: "케플러 궤도",
               curriculum: .high, category: .mechanics,
               curriculumLabel: "물리Ⅰ · 만유인력과 행성 운동",
               blurb: "역제곱 중심력. 접선속력에 따라 원·타원·포물선·쌍곡선.",
               calculatorTopic: .kepler,
               kind: .mechanics,
               load: MechanicsPresets.kepler),

        Preset(id: "wavesum",
               title: "파동의 중첩",
               curriculum: .high, category: .waveThermo,
               curriculumLabel: "물리Ⅰ · 파동과 정보 통신",
               blurb: "두 사인파의 합 — 가까운 진동수면 맥놀이, 반대방향이면 정상파.",
               calculatorTopic: nil,
               kind: .wave(.waveSum),
               load: { _ in }),

        Preset(id: "doppler",
               title: "도플러 효과",
               curriculum: .high, category: .waveThermo,
               curriculumLabel: "물리Ⅰ · 파동",
               blurb: "움직이는 음원이 만드는 파면 — 앞은 빽빽, 뒤는 듬성.",
               calculatorTopic: .doppler,
               kind: .wave(.doppler),
               load: { _ in }),

        Preset(id: "kinetic",
               title: "기체 분자 운동",
               curriculum: .high, category: .waveThermo,
               curriculumLabel: "물리Ⅱ · 열역학",
               blurb: "딱딱한 원판들의 충돌만으로 속력 분포가 맥스웰–볼츠만 모양으로 수렴.",
               calculatorTopic: nil,
               kind: .mechanics,
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
               curriculumLabel: "물리Ⅱ · 전기장과 가우스 법칙",
               blurb: "양·음 점전하 배치가 만드는 전기력선. 양에서 음으로.",
               calculatorTopic: nil,
               kind: .mechanics,
               load: MechanicsPresets.eField),

        Preset(id: "lorentz",
               title: "자기장 속 하전입자",
               curriculum: .high, category: .electromagnetism,
               curriculumLabel: "물리Ⅱ · 자기장과 운동",
               blurb: "F = q(E + v×B). B 만 있으면 원운동, E 도 있으면 E×B 표류.",
               calculatorTopic: nil,
               kind: .mechanics,
               load: MechanicsPresets.lorentz),

        Preset(id: "rlc",
               title: "직렬 RLC 회로",
               curriculum: .high, category: .electromagnetism,
               curriculumLabel: "물리Ⅱ · 교류 회로",
               blurb: "공명 ω₀ = 1/√(LC) 에서 |Z| 최소·전류 최대.",
               calculatorTopic: nil,
               kind: .circuit(.rlc),
               load: { _ in }),

        Preset(id: "doubleslit",
               title: "이중 슬릿",
               curriculum: .high, category: .optics,
               curriculumLabel: "물리Ⅰ · 빛의 간섭과 회절",
               blurb: "간섭 ⊗ 단일슬릿 회절의 합성 패턴.",
               calculatorTopic: .slit,
               kind: .optics(.doubleSlit),
               load: { _ in }),

        Preset(id: "lens",
               title: "얇은 렌즈 결상",
               curriculum: .high, category: .optics,
               curriculumLabel: "중1 / 물리Ⅰ · 빛의 굴절·렌즈",
               blurb: "1/f = 1/p + 1/q 와 광선 추적.",
               calculatorTopic: .lens,
               kind: .optics(.lens),
               load: { _ in }),

        // ─── 샌드박스 ───
        Preset(id: "freecollide",
               title: "자유 충돌 박스",
               curriculum: .free, category: .sandbox,
               curriculumLabel: "물리Ⅰ · 운동량 보존 (확장)",
               blurb: "재질·질량·반발계수가 다른 입자 N개의 동시 충돌.",
               calculatorTopic: nil,
               kind: .mechanics,
               load: MechanicsPresets.freeCollision),

        Preset(id: "freegravity",
               title: "N체 중력",
               curriculum: .free, category: .sandbox,
               curriculumLabel: "물리Ⅰ · 만유인력 (다체)",
               blurb: "별과 행성을 자유롭게 배치하고 궤도를 본다.",
               calculatorTopic: nil,
               kind: .mechanics,
               load: MechanicsPresets.nBody),
    ]

    static func preset(_ id: String) -> Preset {
        all.first { $0.id == id }!
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

    /// 계산기 토픽으로부터 짝 시뮬 프리셋.
    static func preset(forTopic t: CalculatorTopic) -> Preset? {
        all.first { $0.calculatorTopic == t }
    }
}

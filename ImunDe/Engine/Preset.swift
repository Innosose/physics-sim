import SwiftUI

struct Preset: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let title: String
    let curriculum: Curriculum
    let category: SimCategory
    let calculatorTopic: CalculatorTopic?
    let kind: Kind
    let load: (World) -> Void
    var subtitle: String { Preset.descriptions[id] ?? "" }

    private static let descriptions: [String: String] = [
        "freefall":    "중력만으로 떨어지는 물체의 위치·속도 변화",
        "motiongraph": "등속과 등가속도 카트의 x-t 그래프 비교",
        "reflection":  "스넬의 법칙으로 굴절각, 임계각 관찰",
        "circuit":     "직렬·병렬에서 R_eq, I, P 계산",
        "heat":        "열용량이 다른 두 물체의 평형 도달",
        "collision1d": "탄성 충돌의 운동량·에너지 보존",
        "projectile":  "공기저항을 포함한 비스듬한 던지기",
        "pendulum":    "줄 길이 1.5m, 60° 초기각 단진자",
        "spring":      "감쇠와 함께 진동하는 용수철 질량",
        "kepler":      "타원·원 궤도와 케플러 제2·3법칙",
        "wavesum":     "두 사인파의 중첩, 맥놀이, 정상파",
        "doppler":     "이동하는 음원의 파면 압축·팽창",
        "kinetic":     "기체 분자의 무작위 충돌과 평형",
        "efield":      "양·음 점전하 사이의 전기력선",
        "lorentz":     "자기장 속 하전입자의 원·나선 운동",
        "rlc":         "주파수에 따른 임피던스 공명 곡선",
        "faraday":     "코일 속 자석 진동으로 유도되는 EMF",
        "solenoid":    "솔레노이드 내부 균일장과 외부 쌍극자장",
        "doubleslit":  "이중·단일 슬릿 회절·간섭 강도 분포",
        "lens":        "얇은 렌즈 공식과 상의 위치·배율",
        "freecollide": "탄성 박스 안에서 자유롭게 충돌하는 입자들",
        "nbody":       "태양계와 안정 8자 3체 궤도",
    ]

    enum Kind: Hashable {
        case mechanics2D
        case optics(OpticsScene)
        case wave(WaveScene)
        case circuit(CircuitScene)
        case graph
    }

    enum OpticsScene: Hashable { case reflection, lens, doubleSlit }
    enum WaveScene: Hashable   { case waveSum, doppler }
    enum CircuitScene: Hashable { case circuit, rlc, faraday, solenoid }

    static func == (a: Preset, b: Preset) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

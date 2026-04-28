import SwiftUI

/// 시뮬 분류.
enum SimCategory: String, CaseIterable, Identifiable {
    case mechanics = "역학"
    case waveThermo = "파동·열"
    case electromagnetism = "전자기"
    case optics = "광학"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .mechanics:        return "scope"
        case .waveThermo:       return "waveform.path"
        case .electromagnetism: return "bolt.fill"
        case .optics:           return "eye"
        }
    }
}

/// 시뮬 메타데이터.
struct SimulationItem: Identifiable, Hashable {
    let id: String
    let title: String          // 한국어 제목
    let subtitle: String       // 한 줄 설명
    let category: SimCategory
    let level: String          // 난이도/학년 표시

    static func == (a: SimulationItem, b: SimulationItem) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum SimulationCatalog {
    static let all: [SimulationItem] = [
        // 역학
        .init(id: "projectile", title: "포물선 운동",
              subtitle: "공기 저항이 있을 때와 없을 때의 자취 비교",
              category: .mechanics, level: "1학년"),
        .init(id: "pendulum", title: "단진자",
              subtitle: "선형 근사와 비선형 해의 차이",
              category: .mechanics, level: "1학년"),
        .init(id: "spring", title: "감쇠·구동 진동자",
              subtitle: "감쇠와 외력이 만드는 공명 곡선",
              category: .mechanics, level: "2학년"),
        .init(id: "collision1d", title: "1차원 충돌",
              subtitle: "탄성·비탄성 충돌의 운동량과 에너지",
              category: .mechanics, level: "1학년"),
        .init(id: "kepler", title: "케플러 궤도",
              subtitle: "역제곱 중심력에서의 타원 궤도",
              category: .mechanics, level: "2학년"),

        // 파동·열
        .init(id: "wavesum", title: "파동의 중첩",
              subtitle: "두 사인파의 합 — 맥놀이와 정상파",
              category: .waveThermo, level: "1학년"),
        .init(id: "doppler", title: "도플러 효과",
              subtitle: "움직이는 음원이 만드는 파면",
              category: .waveThermo, level: "1학년"),
        .init(id: "kinetic", title: "기체 분자 운동",
              subtitle: "딱딱한 원판 충돌과 맥스웰–볼츠만 분포",
              category: .waveThermo, level: "2학년"),

        // 전자기
        .init(id: "efield", title: "전기력선",
              subtitle: "점전하 배치가 만드는 전기장",
              category: .electromagnetism, level: "2학년"),
        .init(id: "lorentz", title: "자기장 속 하전입자",
              subtitle: "사이클로트론 운동과 표류 속도",
              category: .electromagnetism, level: "2학년"),
        .init(id: "rlc", title: "RLC 회로",
              subtitle: "직렬 RLC 의 공명과 위상",
              category: .electromagnetism, level: "2학년"),

        // 광학
        .init(id: "doubleslit", title: "이중 슬릿",
              subtitle: "간섭과 단일슬릿 회절의 합성 패턴",
              category: .optics, level: "2학년"),
        .init(id: "lens", title: "얇은 렌즈 결상",
              subtitle: "1/f = 1/p + 1/q 와 광선 추적",
              category: .optics, level: "1학년"),
    ]

    static var byCategory: [(SimCategory, [SimulationItem])] {
        SimCategory.allCases.map { cat in
            (cat, all.filter { $0.category == cat })
        }
    }

    @ViewBuilder
    static func view(for item: SimulationItem) -> some View {
        switch item.id {
        case "projectile":  ProjectileScene()
        case "pendulum":    PendulumScene()
        case "spring":      SpringScene()
        case "collision1d": CollisionScene()
        case "kepler":      KeplerScene()
        case "wavesum":     WaveSumScene()
        case "doppler":     DopplerScene()
        case "kinetic":     KineticGasScene()
        case "efield":      ElectricFieldScene()
        case "lorentz":     LorentzScene()
        case "rlc":         RLCScene()
        case "doubleslit":  DoubleSlitScene()
        case "lens":        LensScene()
        default:            Text("준비 중")
        }
    }
}

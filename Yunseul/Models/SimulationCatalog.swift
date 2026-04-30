import SwiftUI

/// 시뮬 분류 (커리큘럼 안에서의 소분류).
enum SimCategory: String, CaseIterable, Identifiable, Hashable {
    case mechanics = "역학"
    case waveThermo = "파동·열"
    case electromagnetism = "전자기"
    case optics = "광학"
    case sandbox  = "샌드박스"

    var id: String { rawValue }
}

/// 시뮬 메타데이터.
///
/// `curriculum` 은 한국 교육과정과의 연계 (학년·교과·단원).
/// 핵심 공식·정확한 수치는 별도로 노출하지 않음 — 시뮬은 보는 용도.
struct SimulationItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: SimCategory
    let curriculum: String

    static func == (a: SimulationItem, b: SimulationItem) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 모든 시뮬은 한 곳에서 정의하고, 커리큘럼별 카탈로그는 ID 로 참조.
enum SimulationCatalog {
    // MARK: - 시뮬 사전

    static let allItems: [SimulationItem] = [
        // ────── 중학교 ──────
        .init(id: "freefall",
              title: "자유낙하·연직 던지기",
              subtitle: "위로 던진 공이 멈추고 다시 떨어지는 자취",
              category: .mechanics,
              curriculum: "중3 과학 · 운동과 에너지"),
        .init(id: "motiongraph",
              title: "등속 vs 등가속도",
              subtitle: "위치-시간 / 속도-시간 그래프 비교",
              category: .mechanics,
              curriculum: "중3 과학 · 운동의 표현"),
        .init(id: "reflection",
              title: "빛의 반사·굴절",
              subtitle: "두 매질 경계에서 빛은 어떻게 나뉘는가",
              category: .optics,
              curriculum: "중1 과학 · 빛과 파동"),
        .init(id: "circuit",
              title: "직렬·병렬 회로",
              subtitle: "옴의 법칙으로 전류·전압을 정확히 계산",
              category: .electromagnetism,
              curriculum: "중2 과학 · 전기와 자기"),
        .init(id: "heat",
              title: "열전달과 평형",
              subtitle: "두 물체의 온도가 같아질 때까지 열이 흐른다",
              category: .waveThermo,
              curriculum: "중1 과학 · 열과 우리 생활"),
        .init(id: "collision1d",
              title: "1차원 충돌",
              subtitle: "운동량 보존, 반발계수 e 에 따른 에너지 변화",
              category: .mechanics,
              curriculum: "중3 / 물리Ⅰ · 운동량과 충돌"),

        // ────── 고등학교 ──────
        .init(id: "projectile",
              title: "포물선 운동",
              subtitle: "공기 저항이 있을 때와 없을 때의 자취 비교",
              category: .mechanics,
              curriculum: "물리Ⅰ · 등가속도 운동"),
        .init(id: "pendulum",
              title: "단진자 (비선형)",
              subtitle: "RK4 비선형 해와 작은-각 근사의 차이",
              category: .mechanics,
              curriculum: "물리Ⅰ / 물리Ⅱ · 진자·역학적 진동"),
        .init(id: "spring",
              title: "감쇠·구동 진동자",
              subtitle: "감쇠비 ζ 와 공명 곡선 |X(ω)|",
              category: .mechanics,
              curriculum: "물리Ⅱ · 역학적 진동"),
        .init(id: "kepler",
              title: "케플러 궤도",
              subtitle: "역제곱 중심력 — 타원·포물선·쌍곡선",
              category: .mechanics,
              curriculum: "물리Ⅰ · 만유인력과 행성 운동"),
        .init(id: "wavesum",
              title: "파동의 중첩",
              subtitle: "두 사인파의 합 — 맥놀이와 정상파",
              category: .waveThermo,
              curriculum: "물리Ⅰ · 파동과 정보 통신"),
        .init(id: "doppler",
              title: "도플러 효과",
              subtitle: "움직이는 음원이 만드는 파면",
              category: .waveThermo,
              curriculum: "물리Ⅰ · 파동"),
        .init(id: "kinetic",
              title: "기체 분자 운동",
              subtitle: "딱딱한 원판 충돌과 맥스웰–볼츠만 분포",
              category: .waveThermo,
              curriculum: "물리Ⅱ · 열역학"),
        .init(id: "efield",
              title: "전기력선",
              subtitle: "점전하 배치가 만드는 전기장",
              category: .electromagnetism,
              curriculum: "물리Ⅱ · 전기장과 가우스 법칙"),
        .init(id: "lorentz",
              title: "자기장 속 하전입자",
              subtitle: "사이클로트론 운동과 표류 속도",
              category: .electromagnetism,
              curriculum: "물리Ⅱ · 자기장과 운동"),
        .init(id: "rlc",
              title: "직렬 RLC 회로",
              subtitle: "공명 ω₀ = 1/√(LC), 위상, 임피던스",
              category: .electromagnetism,
              curriculum: "물리Ⅱ · 교류 회로"),
        .init(id: "doubleslit",
              title: "이중 슬릿",
              subtitle: "간섭 ⊗ 단일슬릿 회절의 합성 패턴",
              category: .optics,
              curriculum: "물리Ⅰ · 빛의 간섭과 회절"),
        .init(id: "lens",
              title: "얇은 렌즈 결상",
              subtitle: "1/f = 1/p + 1/q 와 광선 추적",
              category: .optics,
              curriculum: "중1 / 물리Ⅰ · 빛의 굴절·렌즈"),

        // ────── 자유 ──────
        .init(id: "freecollide",
              title: "자유 충돌 박스",
              subtitle: "재질·질량·반발계수가 다른 입자 N개의 동시 충돌",
              category: .sandbox,
              curriculum: "물리Ⅰ · 운동량 보존 (확장)"),
        .init(id: "freegravity",
              title: "N체 중력",
              subtitle: "별과 행성을 자유롭게 배치하고 궤도를 보기",
              category: .sandbox,
              curriculum: "물리Ⅰ · 만유인력 (다체)"),
    ]

    static func item(_ id: String) -> SimulationItem {
        allItems.first { $0.id == id }!
    }

    /// 시뮬이 속한 커리큘럼 — sidebar 선택을 동기화할 때 사용.
    static func curriculum(of item: SimulationItem) -> Curriculum? {
        for c in Curriculum.allCases where items(for: c).contains(where: { $0.id == item.id }) {
            return c
        }
        return nil
    }

    // MARK: - 커리큘럼별 목록

    static func items(for c: Curriculum) -> [SimulationItem] {
        let ids: [String]
        switch c {
        case .middle:
            ids = ["freefall", "motiongraph", "reflection",
                   "circuit", "heat", "collision1d"]
        case .high:
            ids = ["projectile", "pendulum", "spring", "collision1d", "kepler",
                   "wavesum", "doppler", "kinetic",
                   "efield", "lorentz", "rlc",
                   "doubleslit", "lens"]
        case .free:
            ids = ["freecollide", "freegravity"]
        }
        return ids.map { item($0) }
    }

    /// 커리큘럼 안에서 소분류별로 묶기.
    static func grouped(for c: Curriculum) -> [(SimCategory, [SimulationItem])] {
        let items = items(for: c)
        var dict: [SimCategory: [SimulationItem]] = [:]
        for it in items { dict[it.category, default: []].append(it) }
        return SimCategory.allCases.compactMap { cat in
            dict[cat].map { (cat, $0) }
        }
    }

    // MARK: - id → View 매핑

    @ViewBuilder
    static func view(for id: String) -> some View {
        switch id {
        // 중등
        case "freefall":     FreeFallScene()
        case "motiongraph":  MotionGraphScene()
        case "reflection":   ReflectionScene()
        case "circuit":      CircuitScene()
        case "heat":         HeatTransferScene()

        // 고등
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

        // 자유
        case "freecollide": FreeCollisionScene()
        case "freegravity": FreeGravityScene()

        default: Text("준비 중")
        }
    }
}

// MARK: - 시뮬 ↔ 계산기 매핑

extension SimulationItem {
    /// 이 시뮬과 짝이 되는 계산기 토픽이 있으면 반환.
    /// 매핑의 단일 소스는 `CalculatorTopic.simulationId` — 여기서는 역방향 조회.
    var calculatorTopic: CalculatorTopic? {
        CalculatorTopic.allCases.first { $0.simulationId == id }
    }

    /// 시뮬의 계산 종류 — 닫힌 해 / 이벤트 기반 / 수치.
    /// ConceptCard 에 작은 배지로 노출.
    var calcKind: SimCalcKind {
        switch id {
        case "kinetic", "freecollide": return .eventBased
        case "freegravity":            return .numerical
        default:                       return .closed
        }
    }
}

/// 시뮬이 결과를 어떻게 계산하는지의 분류.
enum SimCalcKind {
    /// 모든 시간에서 분석해 (예: 포물선·진자 cn·렌즈·스넬·도플러 등).
    case closed
    /// 사건(충돌) 기반 — 사건 사이에는 닫힌 해(등속 운동), 사건 시 닫힌 해 임펄스.
    /// 시간 흐름은 작은 dt 로 사건을 검출하기 때문에 "엄밀 닫힌 해" 와 구분.
    case eventBased
    /// 수치 적분 (Verlet 등) — N체 중력 다체 문제 등 닫힌 해 부재 영역.
    case numerical

    var label: String {
        switch self {
        case .closed:     return "닫힌 해"
        case .eventBased: return "이벤트 기반"
        case .numerical:  return "수치"
        }
    }

    var badgeColor: Color {
        switch self {
        case .closed:     return Color(red: 0.42, green: 0.79, blue: 0.45)   // 박하
        case .eventBased: return Color(red: 0.55, green: 0.45, blue: 0.95)   // 자수정
        case .numerical:  return Color(red: 0.95, green: 0.66, blue: 0.30)   // 호박
        }
    }
}

// MARK: - Environment

/// 시뮬 화면이 자기 자신의 메타데이터를 알 수 있도록 환경 값으로 흘림.
private struct CurrentSimulationKey: EnvironmentKey {
    static let defaultValue: SimulationItem? = nil
}

extension EnvironmentValues {
    var simulationItem: SimulationItem? {
        get { self[CurrentSimulationKey.self] }
        set { self[CurrentSimulationKey.self] = newValue }
    }
}

// MARK: - 계산기 열기 액션

/// 시뮬에서 짝이 되는 계산기로 점프할 때 호출하는 환경 액션.
/// `SwiftUI.OpenURLAction` 패턴을 따름 — `callAsFunction(_:)` 으로 호출.
///
/// `@unchecked Sendable`: 실제로는 항상 MainActor 에서만 생성·호출되므로
/// 동시성 안전. Swift 6 엄격 검사를 통과시키기 위한 명시.
struct OpenCalculatorAction: @unchecked Sendable {
    let action: ((CalculatorTopic) -> Void)?

    func callAsFunction(_ topic: CalculatorTopic) {
        action?(topic)
    }
}

private struct OpenCalculatorKey: EnvironmentKey {
    static let defaultValue = OpenCalculatorAction(action: nil)
}

extension EnvironmentValues {
    var openCalculator: OpenCalculatorAction {
        get { self[OpenCalculatorKey.self] }
        set { self[OpenCalculatorKey.self] = newValue }
    }
}

// MARK: - 시뮬 열기 액션 (계산기 → 시뮬)

/// 계산기에서 짝이 되는 시뮬로 점프할 때 호출하는 환경 액션.
/// `OpenCalculatorAction` 의 거울짝 — 계산기에서 "이 시뮬로 보기" 버튼이 호출.
struct OpenSimulationAction: @unchecked Sendable {
    let action: ((SimulationItem) -> Void)?

    func callAsFunction(_ item: SimulationItem) {
        action?(item)
    }
}

private struct OpenSimulationKey: EnvironmentKey {
    static let defaultValue = OpenSimulationAction(action: nil)
}

extension EnvironmentValues {
    var openSimulation: OpenSimulationAction {
        get { self[OpenSimulationKey.self] }
        set { self[OpenSimulationKey.self] = newValue }
    }
}

import SwiftUI

/// 시뮬 분류 (커리큘럼 안에서의 소분류).
enum SimCategory: String, CaseIterable, Identifiable, Hashable {
    case mechanics = "역학"
    case waveThermo = "파동·열"
    case electromagnetism = "전자기"
    case optics = "광학"
    case everyday = "일상 속 물리"
    case sandbox  = "샌드박스"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .mechanics:        return "scope"
        case .waveThermo:       return "waveform.path"
        case .electromagnetism: return "bolt.fill"
        case .optics:           return "eye"
        case .everyday:         return "house.fill"
        case .sandbox:          return "wand.and.stars"
        }
    }
}

/// 시뮬 메타데이터.
///
/// `curriculum` 은 한국 교육과정과의 연계 (학년·교과·단원),
/// `formula` 는 그 시뮬에서 다루는 핵심 공식 (시뮬 패널 상단에 모노스페이스 박스로 노출).
struct SimulationItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: SimCategory
    let curriculum: String
    let formula: String

    static func == (a: SimulationItem, b: SimulationItem) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 모든 시뮬은 한 곳에서 정의하고, 커리큘럼별 카탈로그는 ID 로 참조.
enum SimulationCatalog {
    // MARK: - 시뮬 사전

    static let allItems: [SimulationItem] = [
        // ────── 초등학교 ──────
        .init(id: "magnet",
              title: "자석의 인력과 반발",
              subtitle: "두 자석을 끌어서 같은 극·다른 극의 힘을 느껴 보기",
              category: .everyday,
              curriculum: "초등 3학년 · 자석의 이용",
              formula: "F  ∝  1 / r²"),
        .init(id: "lever",
              title: "지렛대",
              subtitle: "받침점에서의 거리 × 무게가 같으면 균형",
              category: .everyday,
              curriculum: "초등 6학년 · 도구의 원리",
              formula: "w₁ · d₁  =  w₂ · d₂"),
        .init(id: "buoyancy",
              title: "부력",
              subtitle: "물체의 밀도가 액체보다 작으면 뜬다",
              category: .everyday,
              curriculum: "초등 5학년 · 물체의 무게",
              formula: "F_부력  =  ρ_액체 · g · V_잠긴부분"),
        .init(id: "shadow",
              title: "빛과 그림자",
              subtitle: "광원이 가까울수록 그림자가 커진다",
              category: .optics,
              curriculum: "초등 4학년 · 그림자와 거울",
              formula: "h_그림자 / h_물체  =  D_스크린 / D_물체  (닮음)"),
        .init(id: "pendulumSimple",
              title: "그네 (진자)",
              subtitle: "줄이 길수록 천천히 흔들린다",
              category: .everyday,
              curriculum: "초등 5학년 · 물체의 운동",
              formula: "T  =  2π √(L / g)"),

        // ────── 중학교 ──────
        .init(id: "freefall",
              title: "자유낙하·연직 던지기",
              subtitle: "위로 던진 공이 멈추고 다시 떨어지는 자취",
              category: .mechanics,
              curriculum: "중3 과학 · 운동과 에너지",
              formula: "y(t)  =  y₀ + v₀ t − ½ g t²"),
        .init(id: "motiongraph",
              title: "등속 vs 등가속도",
              subtitle: "위치-시간 / 속도-시간 그래프 비교",
              category: .mechanics,
              curriculum: "중3 과학 · 운동의 표현",
              formula: "x₁ = v t,    x₂ = v₀ t + ½ a t²"),
        .init(id: "reflection",
              title: "빛의 반사·굴절",
              subtitle: "두 매질 경계에서 빛은 어떻게 나뉘는가",
              category: .optics,
              curriculum: "중1 과학 · 빛과 파동",
              formula: "n₁ sinθ₁  =  n₂ sinθ₂"),
        .init(id: "circuit",
              title: "직렬·병렬 회로",
              subtitle: "옴의 법칙으로 전류·전압을 정확히 계산",
              category: .electromagnetism,
              curriculum: "중2 과학 · 전기와 자기",
              formula: "V = I R,    R_eq = R₁+R₂  (직렬)    1/R_eq = 1/R₁+1/R₂  (병렬)"),
        .init(id: "heat",
              title: "열전달과 평형",
              subtitle: "두 물체의 온도가 같아질 때까지 열이 흐른다",
              category: .everyday,
              curriculum: "중1 과학 · 열과 우리 생활",
              formula: "T_eq  =  (m₁c₁ T₁ + m₂c₂ T₂) / (m₁c₁ + m₂c₂)"),
        .init(id: "collision1d",
              title: "1차원 충돌",
              subtitle: "운동량 보존, 반발계수 e 에 따른 에너지 변화",
              category: .mechanics,
              curriculum: "중3 / 물리Ⅰ · 운동량과 충돌",
              formula: "p = m v  보존,    e = −(v₂′ − v₁′) / (v₂ − v₁)"),

        // ────── 고등학교 ──────
        .init(id: "projectile",
              title: "포물선 운동",
              subtitle: "공기 저항이 있을 때와 없을 때의 자취 비교",
              category: .mechanics,
              curriculum: "물리Ⅰ · 등가속도 운동",
              formula: "x = v₀ cosθ · t,    y = v₀ sinθ · t − ½ g t²"),
        .init(id: "pendulum",
              title: "단진자 (비선형)",
              subtitle: "RK4 비선형 해와 작은-각 근사의 차이",
              category: .mechanics,
              curriculum: "물리Ⅰ / 물리Ⅱ · 진자·역학적 진동",
              formula: "θ̈  =  −(g / L) sinθ"),
        .init(id: "spring",
              title: "감쇠·구동 진동자",
              subtitle: "감쇠비 ζ 와 공명 곡선 |X(ω)|",
              category: .mechanics,
              curriculum: "물리Ⅱ · 역학적 진동",
              formula: "m ẍ + c ẋ + k x  =  F₀ cos(ω t)"),
        .init(id: "kepler",
              title: "케플러 궤도",
              subtitle: "역제곱 중심력 — 타원·포물선·쌍곡선",
              category: .mechanics,
              curriculum: "물리Ⅰ · 만유인력과 행성 운동",
              formula: "F  =  G M m / r²"),
        .init(id: "wavesum",
              title: "파동의 중첩",
              subtitle: "두 사인파의 합 — 맥놀이와 정상파",
              category: .waveThermo,
              curriculum: "물리Ⅰ · 파동과 정보 통신",
              formula: "y  =  y₁ + y₂  =  A₁ sin(k₁ x − ω₁ t)  +  A₂ sin(k₂ x − ω₂ t)"),
        .init(id: "doppler",
              title: "도플러 효과",
              subtitle: "움직이는 음원이 만드는 파면",
              category: .waveThermo,
              curriculum: "물리Ⅰ · 파동",
              formula: "f′  =  f · c / (c ∓ v_s)"),
        .init(id: "kinetic",
              title: "기체 분자 운동",
              subtitle: "딱딱한 원판 충돌과 맥스웰–볼츠만 분포",
              category: .waveThermo,
              curriculum: "물리Ⅱ · 열역학",
              formula: "P V = N k_B T,    ½ m ⟨v²⟩  =  ³⁄₂ k_B T"),
        .init(id: "efield",
              title: "전기력선",
              subtitle: "점전하 배치가 만드는 전기장",
              category: .electromagnetism,
              curriculum: "물리Ⅱ · 전기장과 가우스 법칙",
              formula: "E(p)  =  k Σᵢ qᵢ (p − rᵢ) / |p − rᵢ|³"),
        .init(id: "lorentz",
              title: "자기장 속 하전입자",
              subtitle: "사이클로트론 운동과 표류 속도",
              category: .electromagnetism,
              curriculum: "물리Ⅱ · 자기장과 운동",
              formula: "F  =  q (E + v × B)"),
        .init(id: "rlc",
              title: "직렬 RLC 회로",
              subtitle: "공명 ω₀ = 1/√(LC), 위상, 임피던스",
              category: .electromagnetism,
              curriculum: "물리Ⅱ · 교류 회로",
              formula: "L q̈ + R q̇ + q / C  =  V₀ cos(ω t)"),
        .init(id: "doubleslit",
              title: "이중 슬릿",
              subtitle: "간섭 ⊗ 단일슬릿 회절의 합성 패턴",
              category: .optics,
              curriculum: "물리Ⅰ · 빛의 간섭과 회절",
              formula: "Δy  =  λ D / d"),
        .init(id: "lens",
              title: "얇은 렌즈 결상",
              subtitle: "1/f = 1/p + 1/q 와 광선 추적",
              category: .optics,
              curriculum: "중1 / 물리Ⅰ · 빛의 굴절·렌즈",
              formula: "1/f  =  1/p + 1/q,    m = − q / p"),

        // ────── 자유 ──────
        .init(id: "freecollide",
              title: "자유 충돌 박스",
              subtitle: "재질·질량·반발계수가 다른 입자 N개의 동시 충돌",
              category: .sandbox,
              curriculum: "물리Ⅰ · 운동량 보존 (확장)",
              formula: "Δp  =  (1 + e) μ (v_rel · n̂),    μ = m₁m₂ / (m₁+m₂)"),
        .init(id: "freegravity",
              title: "N체 중력",
              subtitle: "별과 행성을 자유롭게 배치하고 궤도를 보기",
              category: .sandbox,
              curriculum: "물리Ⅰ · 만유인력 (다체)",
              formula: "F_ij  =  G m_i m_j (r_j − r_i) / |r_j − r_i|³"),
    ]

    static func item(_ id: String) -> SimulationItem {
        allItems.first { $0.id == id }!
    }

    // MARK: - 커리큘럼별 목록

    static func items(for c: Curriculum) -> [SimulationItem] {
        let ids: [String]
        switch c {
        case .elementary:
            ids = ["magnet", "lever", "buoyancy", "shadow", "pendulumSimple"]
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
        // 초등
        case "magnet":         MagnetScene()
        case "lever":          LeverScene()
        case "buoyancy":       BuoyancyScene()
        case "shadow":         ShadowScene()
        case "pendulumSimple": PendulumScene(simpleMode: true)

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

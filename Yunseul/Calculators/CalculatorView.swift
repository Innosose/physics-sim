import SwiftUI

/// 계산기 한 토픽의 입력·출력 화면. 토픽에 따라 분기.
///
/// 모든 계산기는 닫힌 해 (analytical) 만 사용 — 입력값이 바뀌면 즉시 결과 갱신.
struct CalculatorView: View {
    let topic: CalculatorTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // ConceptCard 와 같은 톤의 헤더 — 단원·공식.
                CalcHeader(topic: topic)

                // 토픽별 본체.
                Group {
                    switch topic {
                    case .freefall:   FreeFallCalculator()
                    case .projectile: ProjectileCalculator()
                    case .pendulum:   PendulumCalculator()
                    case .collision:  CollisionCalculator()
                    case .kepler:     KeplerCalculator()
                    case .ohm:        OhmCalculator()
                    case .doppler:    DopplerCalculator()
                    case .refraction: RefractionCalculator()
                    case .lens:       LensCalculator()
                    case .slit:       DoubleSlitCalculator()
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themeCard(cornerRadius: 16)
            }
            .padding(16)
            .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity)
        .background(YunseulBackground(topGlow: Theme.glow.opacity(0.06)))
        .navigationTitle(topic.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 계산기 공통 컴포넌트

/// 토픽 헤더 — ConceptCard 와 같은 톤.
private struct CalcHeader: View {
    let topic: CalculatorTopic
    @Environment(\.openSimulation) private var openSimulation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .imageScale(.small)
                    .foregroundStyle(Theme.glow)
                    .accessibilityHidden(true)
                Text(topic.curriculum)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                if let simId = topic.simulationId {
                    let item = SimulationCatalog.item(simId)
                    Button {
                        openSimulation(item)
                    } label: {
                        Label("시뮬로 보기", systemImage: "play.rectangle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("이 계산기의 시뮬 — \(item.title) 열기")
                }
            }
            Text(topic.formula)
                .font(.system(.footnote, design: .monospaced).weight(.medium))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.crest.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.glow.opacity(0.22), lineWidth: 1)
                )
                .accessibilityLabel("핵심 공식: \(topic.formula)")
            Text(topic.subtitle)
                .font(.callout)
                .foregroundStyle(Theme.mist)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(cornerRadius: 16)
    }
}

/// 입력 행 — 라벨 + 숫자 TextField + 단위.
struct CalcInputField: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.themeLabel)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                TextField("", value: $value,
                          format: .number.precision(.fractionLength(0...4)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.themeMono)
                    .frame(maxWidth: 180)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.themeMono)
                        .foregroundStyle(Theme.mist)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 출력 행 — 라벨 + 모노스페이스 값 + 단위.
struct CalcOutput: View {
    let label: String
    let value: String
    var emphasis: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout)
                .foregroundStyle(Theme.mist)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.callout, design: .monospaced).weight(emphasis ? .heavy : .semibold))
                .foregroundStyle(emphasis ? Theme.glow : Theme.ink)
                .textSelection(.enabled)
        }
        .padding(.vertical, 3)
    }
}

/// 섹션 — "입력값" / "결과" 헤더 + 내용.
struct CalcSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.themeHeader)
                .foregroundStyle(Theme.mist)
                .padding(.bottom, 2)
            VStack(alignment: .leading, spacing: 4) { content() }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 자유낙하

struct FreeFallCalculator: View {
    @State private var h0: Double = 20
    @State private var v0: Double = 5
    @State private var g: Double  = 9.81

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "처음 높이 h₀", value: $h0, unit: "m")
                CalcInputField(title: "처음 속도 v₀ (위 +)", value: $v0, unit: "m/s")
                CalcInputField(title: "중력가속도 g", value: $g, unit: "m/s²")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                if v0 > 0 {
                    let tApex = v0 / g
                    let yApex = h0 + v0 * v0 / (2 * g)
                    CalcOutput(label: "최고점 시각 t_apex = v₀ / g",
                               value: String(format: "%.2f s", tApex))
                    CalcOutput(label: "최고점 높이 y_apex",
                               value: String(format: "%.2f m", yApex), emphasis: true)
                }
                let disc = v0 * v0 + 2 * g * h0
                if disc >= 0 {
                    let tGround = (v0 + sqrt(disc)) / g
                    let vImpact = sqrt(disc)
                    CalcOutput(label: "바닥 도달 시각 t_ground",
                               value: String(format: "%.2f s", tGround), emphasis: true)
                    CalcOutput(label: "충격 속도 |v_impact| = √(v₀² + 2gh₀)",
                               value: String(format: "%.2f m/s", vImpact))
                    CalcOutput(label: "충격 운동에너지 (단위질량당)",
                               value: String(format: "%.2f J/kg", 0.5 * vImpact * vImpact))
                } else {
                    Text("입력값이 비물리적 (g·h₀ + v₀²/2 < 0)")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - 포물선 운동

struct ProjectileCalculator: View {
    @State private var angleDeg: Double = 45
    @State private var speed: Double = 20
    @State private var h0: Double = 0
    @State private var g: Double = 9.81

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "발사각 θ", value: $angleDeg, unit: "°")
                CalcInputField(title: "초속력 v₀", value: $speed, unit: "m/s")
                CalcInputField(title: "발사 높이 h₀", value: $h0, unit: "m")
                CalcInputField(title: "중력가속도 g", value: $g, unit: "m/s²")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let θ = angleDeg * .pi / 180
                let v0x = speed * cos(θ)
                let v0y = speed * sin(θ)
                // 비행시간: ½ g T² − v₀y T − h₀ = 0 양의 해
                let disc = v0y * v0y + 2 * g * h0
                if disc < 0 {
                    Text("입력값 오류")
                        .font(.footnote).foregroundStyle(.orange)
                } else {
                    let T = (v0y + sqrt(disc)) / g
                    let R = v0x * T
                    let H = h0 + v0y * v0y / (2 * g)
                    let vyImpact = v0y - g * T          // 음수 — 아래로 향함
                    let vImpact = sqrt(v0x * v0x + vyImpact * vyImpact)
                    let impactAngle = atan2(-vyImpact, v0x) * 180 / .pi
                    CalcOutput(label: "비행시간 T",
                               value: String(format: "%.2f s", T), emphasis: true)
                    CalcOutput(label: "사거리 R = v₀ cosθ · T",
                               value: String(format: "%.2f m", R), emphasis: true)
                    CalcOutput(label: "최고점 H = h₀ + v₀²sin²θ / 2g",
                               value: String(format: "%.2f m", H))
                    CalcOutput(label: "최고점 시각 t_apex = v₀ sinθ / g",
                               value: String(format: "%.2f s", v0y / g))
                    CalcOutput(label: "충격 속도 |v|",
                               value: String(format: "%.2f m/s", vImpact))
                    CalcOutput(label: "  · 수평 v_x (= v₀ cosθ)",
                               value: String(format: "%+.2f m/s", v0x))
                    CalcOutput(label: "  · 수직 v_y (= v₀ sinθ − gT)",
                               value: String(format: "%+.2f m/s", vyImpact))
                    CalcOutput(label: "  · 입사각 (수평 기준 아래쪽)",
                               value: String(format: "%.2f°", impactAngle))
                }
            }
        }
    }
}

// MARK: - 옴의 법칙 + 직렬·병렬

struct OhmCalculator: View {
    enum Mode: String, CaseIterable, Identifiable {
        case single = "단일", series = "직렬", parallel = "병렬"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .single
    @State private var V: Double = 12
    @State private var R1: Double = 4
    @State private var R2: Double = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "연결 방식") {
                Picker("연결", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            CalcSection(title: "입력값") {
                CalcInputField(title: "전압 V", value: $V, unit: "V")
                CalcInputField(title: mode == .single ? "저항 R" : "저항 R₁",
                               value: $R1, unit: "Ω")
                if mode != .single {
                    CalcInputField(title: "저항 R₂", value: $R2, unit: "Ω")
                }
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let result = computed
                CalcOutput(label: "합성 저항 R_eq",
                           value: String(format: "%.2f Ω", result.Req))
                CalcOutput(label: "총 전류 I = V / R_eq",
                           value: String(format: "%.2f A", result.I), emphasis: true)
                CalcOutput(label: "총 전력 P = V·I",
                           value: String(format: "%.2f W", V * result.I))
                if mode == .series {
                    CalcOutput(label: "V₁ = I·R₁",
                               value: String(format: "%.2f V", result.I * R1))
                    CalcOutput(label: "V₂ = I·R₂",
                               value: String(format: "%.2f V", result.I * R2))
                } else if mode == .parallel {
                    CalcOutput(label: "I₁ (R₁ 통과)",
                               value: String(format: "%.2f A", V / R1))
                    CalcOutput(label: "I₂ (R₂ 통과)",
                               value: String(format: "%.2f A", V / R2))
                }
            }
        }
    }

    private var computed: (Req: Double, I: Double) {
        switch mode {
        case .single:   let R = R1; return (R, V / R)
        case .series:   let R = R1 + R2; return (R, V / R)
        case .parallel: let R = (R1 * R2) / (R1 + R2); return (R, V / R)
        }
    }
}

// MARK: - 굴절 (스넬)

struct RefractionCalculator: View {
    @State private var theta1Deg: Double = 30
    @State private var n1: Double = 1.0     // 공기
    @State private var n2: Double = 1.5     // 유리

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "입사각 θ₁", value: $theta1Deg, unit: "°")
                CalcInputField(title: "n₁ (입사 매질)", value: $n1)
                CalcInputField(title: "n₂ (굴절 매질)", value: $n2)
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let θ1 = theta1Deg * .pi / 180
                let sin2 = n1 * sin(θ1) / n2
                CalcOutput(label: "n₁ sinθ₁",
                           value: String(format: "%.2f", n1 * sin(θ1)))
                if abs(sin2) <= 1 {
                    let θ2 = asin(sin2)
                    CalcOutput(label: "굴절각 θ₂ = arcsin(n₁ sinθ₁ / n₂)",
                               value: String(format: "%.2f°", θ2 * 180 / .pi),
                               emphasis: true)
                    CalcOutput(label: "굴절 광선 존재", value: "예")
                } else {
                    CalcOutput(label: "굴절 광선", value: "없음 — 전반사",
                               emphasis: true)
                }
                if n1 > n2 {
                    let θc = asin(n2 / n1) * 180 / .pi
                    CalcOutput(label: "임계각 θ_c = arcsin(n₂ / n₁)",
                               value: String(format: "%.2f°", θc))
                } else {
                    CalcOutput(label: "임계각", value: "없음 (n₁ ≤ n₂)")
                }
            }
        }
    }
}

// MARK: - 얇은 렌즈

struct LensCalculator: View {
    @State private var f: Double  = 2.0
    @State private var p: Double  = 5.0
    @State private var ho: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "초점거리 f (수렴렌즈 +, 발산렌즈 −)",
                               value: $f, unit: "m")
                CalcInputField(title: "물체 거리 p (>0)",
                               value: $p, unit: "m")
                CalcInputField(title: "물체 높이 h_o",
                               value: $ho, unit: "m")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let denom = p - f
                if abs(denom) < 1e-9 {
                    CalcOutput(label: "상거리 q", value: "∞ (물체가 초점에 위치)",
                               emphasis: true)
                    CalcOutput(label: "상", value: "평행광 — 상 형성 안됨")
                } else {
                    let q = p * f / denom
                    let m = -q / p
                    let hi = m * ho
                    CalcOutput(label: "상거리 q = pf/(p−f)",
                               value: String(format: "%+.2f m", q), emphasis: true)
                    CalcOutput(label: "배율 m = −q/p",
                               value: String(format: "%+.2f", m))
                    CalcOutput(label: "상 높이 h_i = m·h_o",
                               value: String(format: "%+.2f m", hi))
                    let real = q > 0
                    let inverted = m < 0
                    let enlarged = abs(m) > 1
                    let kind = (real ? "실상" : "허상") + " · " +
                               (inverted ? "도립" : "정립") + " · " +
                               (enlarged ? "확대" : "축소")
                    CalcOutput(label: "상의 종류", value: kind, emphasis: true)
                }
            }
        }
    }
}

// MARK: - 단진자 주기

struct PendulumCalculator: View {
    @State private var L: Double  = 1.0
    @State private var g: Double  = 9.81
    @State private var thetaDeg: Double = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "줄 길이 L", value: $L, unit: "m")
                CalcInputField(title: "중력가속도 g", value: $g, unit: "m/s²")
                CalcInputField(title: "최대 각도 θ_max", value: $thetaDeg, unit: "°")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let T0 = 2 * .pi * sqrt(L / g)
                CalcOutput(label: "작은-각 주기 T₀ = 2π√(L/g)",
                           value: String(format: "%.2f s", T0), emphasis: true)

                // 진폭 보정 — 큰 각에서의 주기 (멱급수 근사, 정확):
                //   T(θ_max) = T₀ · (1 + θ²/16 + 11·θ⁴/3072 + 173·θ⁶/737280 + …)
                // 5차 항까지 — θ_max ≤ 170° 까지 < 1% 오차.
                let θ = thetaDeg * .pi / 180
                let θ2 = θ * θ
                let θ4 = θ2 * θ2
                let θ6 = θ4 * θ2
                let correction = 1 + θ2 / 16 + 11 * θ4 / 3072 + 173 * θ6 / 737280
                let T = T0 * correction
                CalcOutput(label: "정확한 주기 T(θ_max) (멱급수 5차)",
                           value: String(format: "%.2f s", T), emphasis: true)
                CalcOutput(label: "보정 비율 T / T₀",
                           value: String(format: "%.2f", correction))
                CalcOutput(label: "차이 ΔT / T₀",
                           value: String(format: "%+.2f %%", (correction - 1) * 100))
                CalcOutput(label: "고유진동수 ω₀ = √(g/L)",
                           value: String(format: "%.2f rad/s", sqrt(g / L)))
            }
            Text("작은 각 근사는 θ ≪ 1 일 때 유효. 60°에서 약 7%, 90°에서 약 18% 더 김.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
    }
}

// MARK: - 1차원 충돌

struct CollisionCalculator: View {
    @State private var m1: Double = 2.0
    @State private var v1: Double = 3.0
    @State private var m2: Double = 1.0
    @State private var v2: Double = -1.0
    @State private var e: Double  = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "질량 m₁", value: $m1, unit: "kg")
                CalcInputField(title: "초속 v₁", value: $v1, unit: "m/s")
                CalcInputField(title: "질량 m₂", value: $m2, unit: "kg")
                CalcInputField(title: "초속 v₂", value: $v2, unit: "m/s")
                CalcInputField(title: "반발계수 e (0..1)", value: $e)
            }
            PropertyDivider()
            CalcSection(title: "결과 — 충돌 후") {
                let M = m1 + m2
                let v1p = ((m1 - e * m2) * v1 + (1 + e) * m2 * v2) / M
                let v2p = ((m2 - e * m1) * v2 + (1 + e) * m1 * v1) / M
                CalcOutput(label: "v₁′",
                           value: String(format: "%+.2f m/s", v1p), emphasis: true)
                CalcOutput(label: "v₂′",
                           value: String(format: "%+.2f m/s", v2p), emphasis: true)
                CalcOutput(label: "운동량 p (전·후)",
                           value: String(format: "%.2f → %.2f", m1*v1+m2*v2, m1*v1p+m2*v2p))
                let KE  = 0.5 * (m1*v1*v1 + m2*v2*v2)
                let KE2 = 0.5 * (m1*v1p*v1p + m2*v2p*v2p)
                CalcOutput(label: "운동에너지 KE (전 → 후)",
                           value: String(format: "%.2f → %.2f J", KE, KE2))
                CalcOutput(label: "ΔKE",
                           value: String(format: "%+.2f J  (%+.2f %%)",
                                          KE2 - KE,
                                          KE > 1e-9 ? (KE2 - KE) / KE * 100 : 0))
                let label: String =
                    abs(e - 1) < 1e-6 ? "완전탄성 (KE 보존)"
                    : (e < 1e-6 ? "완전비탄성 (서로 같은 속도)"
                                : "부분탄성")
                CalcOutput(label: "분류", value: label)
            }
        }
    }
}

// MARK: - 케플러 궤도 매개변수

struct KeplerCalculator: View {
    @State private var GM: Double = 3.986e14   // 지구 GM (m³/s²)
    @State private var r: Double  = 6.78e6     // 저궤도 (m)
    @State private var v: Double  = 7700       // m/s
    /// v 와 r (반경방향) 사이 각도. 90° = 순수 접선속력 (근/원일점), 0° = 순수 반경 = 자유낙하.
    @State private var gammaDeg: Double = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값 (현재 위치·속도)") {
                CalcInputField(title: "GM (중심체)", value: $GM, unit: "m³/s²")
                CalcInputField(title: "현재 거리 r", value: $r, unit: "m")
                CalcInputField(title: "현재 속력 v", value: $v, unit: "m/s")
                CalcInputField(title: "v 와 r 사이 각도 γ (90° = 접선)",
                               value: $gammaDeg, unit: "°")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                if r <= 0 || GM <= 0 {
                    Text("입력값 오류 — r, GM 은 양수")
                        .font(.footnote).foregroundStyle(.orange)
                } else {
                    let γ = gammaDeg * .pi / 180
                    let vTangential = v * sin(γ)
                    let vRadial     = v * cos(γ)
                    let E = 0.5 * v * v - GM / r        // 비-에너지 (단위질량당)
                    let escape = sqrt(2 * GM / r)
                    CalcOutput(label: "접선 v_t = v sinγ",
                               value: String(format: "%.2f m/s", vTangential))
                    CalcOutput(label: "반경 v_r = v cosγ",
                               value: String(format: "%.2f m/s", vRadial))
                    CalcOutput(label: "탈출속력 v_esc = √(2GM/r)",
                               value: String(format: "%.2f m/s", escape))
                    CalcOutput(label: "비-에너지 ε = ½v² − GM/r",
                               value: String(format: "%.2e J/kg", E))
                    if E >= 0 {
                        CalcOutput(label: "궤도 종류", value: "탈출 (E ≥ 0) — 포물선/쌍곡선",
                                   emphasis: true)
                    } else {
                        let a = -GM / (2 * E)
                        // 일반 궤도의 각운동량은 접선속력에서만 — L = r · v_t.
                        let L = r * vTangential
                        let term = max(0, 1 + 2 * E * L * L / (GM * GM))
                        let ecc = sqrt(term)
                        let T = 2 * .pi * sqrt(pow(a, 3) / GM)
                        let rPeri = a * (1 - ecc)
                        let rApo  = a * (1 + ecc)
                        CalcOutput(label: "장반경 a = −GM / (2ε)",
                                   value: String(format: "%.2e m", a), emphasis: true)
                        CalcOutput(label: "이심률 e (γ 반영)",
                                   value: String(format: "%.2f", ecc))
                        CalcOutput(label: "공전주기 T = 2π √(a³/GM)",
                                   value: String(format: "%.2f s  (%.2f h)", T, T / 3600),
                                   emphasis: true)
                        CalcOutput(label: "근일점 r_peri = a(1−e)",
                                   value: String(format: "%.2e m", rPeri))
                        CalcOutput(label: "원일점 r_apo  = a(1+e)",
                                   value: String(format: "%.2e m", rApo))
                    }
                }
            }
            Text("γ = 90° 이면 현재 위치가 근일점 또는 원일점. 다른 각도는 일반 궤도 위.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
    }
}

// MARK: - 도플러 효과

struct DopplerCalculator: View {
    enum Mode: String, CaseIterable, Identifiable {
        case sourceOnly = "음원만", observerOnly = "관측자만", both = "둘 다"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .both
    @State private var f0: Double = 440        // Hz
    @State private var c: Double  = 343        // m/s (공기, 20°C)
    @State private var vs: Double = 0          // 음원 속력 (관측자에게 다가가면 +)
    @State private var vo: Double = 0          // 관측자 속력 (음원에게 다가가면 +)

    /// 선택된 모드에 따라 사용할 효과 속도. 토글된 쪽은 0 으로 강제.
    private var effectiveVs: Double { mode == .observerOnly ? 0 : vs }
    private var effectiveVo: Double { mode == .sourceOnly ? 0 : vo }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "운동 주체") {
                Picker("운동 주체", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            CalcSection(title: "입력값") {
                CalcInputField(title: "원래 진동수 f", value: $f0, unit: "Hz")
                CalcInputField(title: "음속 c", value: $c, unit: "m/s")
                if mode != .observerOnly {
                    CalcInputField(title: "음원 속력 v_s (관측자 향함 +)",
                                   value: $vs, unit: "m/s")
                }
                if mode != .sourceOnly {
                    CalcInputField(title: "관측자 속력 v_o (음원 향함 +)",
                                   value: $vo, unit: "m/s")
                }
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let evs = effectiveVs
                let evo = effectiveVo
                if c - evs <= 1e-9 {
                    CalcOutput(label: "f′",
                               value: "정의되지 않음 — 음원이 음속 이상",
                               emphasis: true)
                    Text("v_s ≥ c — 충격파(마하 콘) 발생 영역.")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    let fp = f0 * (c + evo) / (c - evs)
                    CalcOutput(label: "관측 진동수 f′ = f · (c + v_o)/(c − v_s)",
                               value: String(format: "%.2f Hz", fp), emphasis: true)
                    CalcOutput(label: "주기 T′ = 1 / f′",
                               value: String(format: "%.2f s", 1 / fp))
                    CalcOutput(label: "f′ / f",
                               value: String(format: "%.2f", fp / f0))
                    CalcOutput(label: "음정 변화",
                               value: String(format: "%+.2f cents",
                                              1200 * log2(fp / f0)))
                    CalcOutput(label: "마하 수 v_s / c",
                               value: String(format: "%.2f", evs / c))
                }
            }
            Text("부호 규약: 다가가는 방향이 +. 멀어지면 −. 빛(상대론) 도플러는 별도 공식.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
    }
}

// MARK: - 이중 슬릿

struct DoubleSlitCalculator: View {
    @State private var lambdaNm: Double = 550   // nm
    @State private var dUm: Double      = 50    // μm — 슬릿 간격
    @State private var aUm: Double      = 8     // μm — 슬릿 폭
    @State private var D: Double        = 1.5   // m — 막까지 거리

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "파장 λ", value: $lambdaNm, unit: "nm")
                CalcInputField(title: "슬릿 간격 d", value: $dUm, unit: "μm")
                CalcInputField(title: "슬릿 폭 a", value: $aUm, unit: "μm")
                CalcInputField(title: "막까지 거리 D", value: $D, unit: "m")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let λ = lambdaNm * 1e-9
                let d = dUm * 1e-6
                let a = aUm * 1e-6
                if d <= 0 || λ <= 0 {
                    Text("입력값 오류 — d, λ 는 양수")
                        .font(.footnote).foregroundStyle(.orange)
                } else {
                    let dy = λ * D / d
                    let ya = λ * D / a
                    CalcOutput(label: "이웃 무늬 간격 Δy = λ·D / d",
                               value: String(format: "%.2f mm", dy * 1000),
                               emphasis: true)
                    CalcOutput(label: "회절 첫 영점 위치 y_a = λ·D / a",
                               value: String(format: "%.2f mm", ya * 1000))
                    // 봉투 안에 들어가는 보강무늬의 대략적 개수 — 정수가 자연스러움.
                    CalcOutput(label: "봉투 안의 보강 무늬 수 (대략 2·d/a)",
                               value: "\(Int((2 * d / a).rounded())) 개")
                    let θ1 = asin(min(1, λ / d))
                    CalcOutput(label: "첫 보강 회절각 θ₁ = arcsin(λ/d)",
                               value: String(format: "%.2f° (%.2f rad)",
                                              θ1 * 180 / .pi, θ1))
                }
            }
        }
    }
}

#Preview {
    NavigationStack { CalculatorView(topic: .pendulum) }
}

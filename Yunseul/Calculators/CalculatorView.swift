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
                    case .ohm:        OhmCalculator()
                    case .refraction: RefractionCalculator()
                    case .lens:       LensCalculator()
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
        .background(YunseulBackground(topGlow: Theme.glow.opacity(0.06), stars: false))
        .navigationTitle(topic.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 계산기 공통 컴포넌트

/// 토픽 헤더 — ConceptCard 와 같은 톤.
private struct CalcHeader: View {
    let topic: CalculatorTopic

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
        .themeCard(cornerRadius: 16, marker: false)
    }
}

/// 입력 행 — 라벨 + 숫자 TextField + 단위.
struct CalcInputField: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""
    var range: ClosedRange<Double>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.themeLabel)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                TextField("값", value: $value, format: .number.precision(.fractionLength(0...4)))
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
                               value: String(format: "%.3f s", tApex))
                    CalcOutput(label: "최고점 높이 y_apex",
                               value: String(format: "%.3f m", yApex), emphasis: true)
                }
                let disc = v0 * v0 + 2 * g * h0
                if disc >= 0 {
                    let tGround = (v0 + sqrt(disc)) / g
                    let vImpact = sqrt(disc)
                    CalcOutput(label: "바닥 도달 시각 t_ground",
                               value: String(format: "%.3f s", tGround), emphasis: true)
                    CalcOutput(label: "충격 속도 |v_impact| = √(v₀² + 2gh₀)",
                               value: String(format: "%.3f m/s", vImpact))
                    CalcOutput(label: "충격 운동에너지 (단위질량당)",
                               value: String(format: "%.3f J/kg", 0.5 * vImpact * vImpact))
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
                CalcInputField(title: "발사각 θ", value: $angleDeg, unit: "°",
                               range: 0...90)
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
                guard disc >= 0 else {
                    Text("입력값 오류"); return
                }
                let T = (v0y + sqrt(disc)) / g
                let R = v0x * T
                let H = h0 + v0y * v0y / (2 * g)
                let vImpact = sqrt(v0x * v0x + (v0y - g * T) * (v0y - g * T))
                CalcOutput(label: "비행시간 T",
                           value: String(format: "%.3f s", T), emphasis: true)
                CalcOutput(label: "사거리 R = v₀ cosθ · T",
                           value: String(format: "%.3f m", R), emphasis: true)
                CalcOutput(label: "최고점 H = h₀ + v₀²sin²θ / 2g",
                           value: String(format: "%.3f m", H))
                CalcOutput(label: "최고점 시각 t_apex = v₀ sinθ / g",
                           value: String(format: "%.3f s", v0y / g))
                CalcOutput(label: "충격 속도",
                           value: String(format: "%.3f m/s", vImpact))
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
                           value: String(format: "%.3f Ω", result.Req))
                CalcOutput(label: "총 전류 I = V / R_eq",
                           value: String(format: "%.3f A", result.I), emphasis: true)
                CalcOutput(label: "총 전력 P = V·I",
                           value: String(format: "%.3f W", V * result.I))
                if mode == .series {
                    CalcOutput(label: "V₁ = I·R₁",
                               value: String(format: "%.3f V", result.I * R1))
                    CalcOutput(label: "V₂ = I·R₂",
                               value: String(format: "%.3f V", result.I * R2))
                } else if mode == .parallel {
                    CalcOutput(label: "I₁ (R₁ 통과)",
                               value: String(format: "%.3f A", V / R1))
                    CalcOutput(label: "I₂ (R₂ 통과)",
                               value: String(format: "%.3f A", V / R2))
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
                CalcInputField(title: "입사각 θ₁", value: $theta1Deg, unit: "°",
                               range: 0...89.9)
                CalcInputField(title: "n₁ (입사 매질)", value: $n1)
                CalcInputField(title: "n₂ (굴절 매질)", value: $n2)
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let θ1 = theta1Deg * .pi / 180
                let sin2 = n1 * sin(θ1) / n2
                CalcOutput(label: "n₁ sinθ₁",
                           value: String(format: "%.4f", n1 * sin(θ1)))
                if abs(sin2) <= 1 {
                    let θ2 = asin(sin2)
                    CalcOutput(label: "굴절각 θ₂ = arcsin(n₁ sinθ₁ / n₂)",
                               value: String(format: "%.3f°", θ2 * 180 / .pi),
                               emphasis: true)
                    CalcOutput(label: "굴절 광선 존재", value: "예")
                } else {
                    CalcOutput(label: "굴절 광선", value: "없음 — 전반사",
                               emphasis: true)
                }
                if n1 > n2 {
                    let θc = asin(n2 / n1) * 180 / .pi
                    CalcOutput(label: "임계각 θ_c = arcsin(n₂ / n₁)",
                               value: String(format: "%.3f°", θc))
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
                               value: String(format: "%+.3f m", q), emphasis: true)
                    CalcOutput(label: "배율 m = −q/p",
                               value: String(format: "%+.3f", m))
                    CalcOutput(label: "상 높이 h_i = m·h_o",
                               value: String(format: "%+.3f m", hi))
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

#Preview {
    NavigationStack { CalculatorView(topic: .projectile) }
}

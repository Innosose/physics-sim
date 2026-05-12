import SwiftUI

struct CalculatorView: View {
    let topic: CalculatorTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let preset = PresetCatalog.preset(forTopic: topic) {
                    CalcSimButton(preset: preset)
                }

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
private struct CalcSimButton: View {
    let preset: Preset
    @Environment(\.openSimulation) private var openSimulation

    var body: some View {
        Button {
            openSimulation(preset)
        } label: {
            Label("시뮬레이션 열기", systemImage: "play.rectangle")
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }
}
struct CalcInputField: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var unit: String = ""
    var format: String = "%.2f"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.themeLabel)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(unit.isEmpty
                     ? String(format: format, value)
                     : "\(String(format: format, value)) \(unit)")
                    .font(.themeMonoBold)
                    .foregroundStyle(Theme.glow)
            }
            Slider(value: $value, in: range)
                .tint(Theme.glow)
        }
        .padding(.vertical, 2)
    }
}
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

struct FreeFallCalculator: View {
    @State private var h0: Double = 20
    @State private var v0: Double = 5
    @State private var g: Double  = 9.81

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "처음 높이 h₀", value: $h0, range: 0...100, unit: "m")
                CalcInputField(title: "처음 속도 v₀", value: $v0, range: -30...30, unit: "m/s")
                CalcInputField(title: "중력가속도 g", value: $g, range: 1.62...24.79, unit: "m/s²")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                if v0 > 0 {
                    let tApex = v0 / g
                    let yApex = h0 + v0 * v0 / (2 * g)
                    CalcOutput(label: "최고점 시각",
                               value: String(format: "%.2f s", tApex))
                    CalcOutput(label: "최고점 높이",
                               value: String(format: "%.2f m", yApex), emphasis: true)
                }
                let disc = v0 * v0 + 2 * g * h0
                if disc >= 0 {
                    let tGround = (v0 + sqrt(disc)) / g
                    let vImpact = sqrt(disc)
                    CalcOutput(label: "바닥 도달 시각",
                               value: String(format: "%.2f s", tGround), emphasis: true)
                    CalcOutput(label: "충격 속도",
                               value: String(format: "%.2f m/s", vImpact))
                    CalcOutput(label: "충격 운동에너지",
                               value: String(format: "%.2f J/kg", 0.5 * vImpact * vImpact))
                } else {
                    Text("입력값 오류")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct ProjectileCalculator: View {
    @State private var angleDeg: Double = 45
    @State private var speed: Double = 20
    @State private var h0: Double = 0
    @State private var g: Double = 9.81

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "발사각 θ", value: $angleDeg, range: 0...90, unit: "°")
                CalcInputField(title: "초속력 v₀", value: $speed, range: 0...100, unit: "m/s")
                CalcInputField(title: "발사 높이 h₀", value: $h0, range: 0...100, unit: "m")
                CalcInputField(title: "중력가속도 g", value: $g, range: 1.62...24.79, unit: "m/s²")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let θ = angleDeg * .pi / 180
                let v0x = speed * cos(θ)
                let v0y = speed * sin(θ)
                let disc = v0y * v0y + 2 * g * h0
                if disc < 0 {
                    Text("입력값 오류")
                        .font(.footnote).foregroundStyle(.orange)
                } else {
                    let T = (v0y + sqrt(disc)) / g
                    let R = v0x * T
                    let H = h0 + v0y * v0y / (2 * g)
                    let vyImpact = v0y - g * T
                    let vImpact = sqrt(v0x * v0x + vyImpact * vyImpact)
                    let impactAngle = atan2(-vyImpact, v0x) * 180 / .pi
                    CalcOutput(label: "비행시간",
                               value: String(format: "%.2f s", T), emphasis: true)
                    CalcOutput(label: "사거리",
                               value: String(format: "%.2f m", R), emphasis: true)
                    CalcOutput(label: "최고점 높이",
                               value: String(format: "%.2f m", H))
                    CalcOutput(label: "최고점 시각",
                               value: String(format: "%.2f s", v0y / g))
                    CalcOutput(label: "충격 속력",
                               value: String(format: "%.2f m/s", vImpact))
                    CalcOutput(label: "충격 입사각",
                               value: String(format: "%.2f°", impactAngle))
                }
            }
        }
    }
}

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
                CalcInputField(title: "전압 V", value: $V, range: 0...50, unit: "V")
                CalcInputField(title: mode == .single ? "저항 R" : "저항 R₁",
                               value: $R1, range: 0.5...50, unit: "Ω")
                if mode != .single {
                    CalcInputField(title: "저항 R₂", value: $R2, range: 0.5...50, unit: "Ω")
                }
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let result = computed
                CalcOutput(label: "합성 저항",
                           value: String(format: "%.2f Ω", result.Req))
                CalcOutput(label: "총 전류",
                           value: String(format: "%.2f A", result.I), emphasis: true)
                CalcOutput(label: "총 전력",
                           value: String(format: "%.2f W", V * result.I))
                if mode == .series {
                    CalcOutput(label: "V₁",
                               value: String(format: "%.2f V", result.I * R1))
                    CalcOutput(label: "V₂",
                               value: String(format: "%.2f V", result.I * R2))
                } else if mode == .parallel {
                    CalcOutput(label: "I₁",
                               value: String(format: "%.2f A", V / R1))
                    CalcOutput(label: "I₂",
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

struct RefractionCalculator: View {
    @State private var theta1Deg: Double = 30
    @State private var n1: Double = 1.0     // 공기
    @State private var n2: Double = 1.5     // 유리

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "입사각 θ₁", value: $theta1Deg, range: 0...89.9, unit: "°")
                CalcInputField(title: "n₁", value: $n1, range: 1...3)
                CalcInputField(title: "n₂", value: $n2, range: 1...3)
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let θ1 = theta1Deg * .pi / 180
                let sin2 = n1 * sin(θ1) / n2
                if abs(sin2) <= 1 {
                    let θ2 = asin(sin2)
                    CalcOutput(label: "굴절각 θ₂",
                               value: String(format: "%.2f°", θ2 * 180 / .pi),
                               emphasis: true)
                } else {
                    CalcOutput(label: "굴절 광선", value: "전반사",
                               emphasis: true)
                }
                if n1 > n2 {
                    let θc = asin(n2 / n1) * 180 / .pi
                    CalcOutput(label: "임계각 θ_c",
                               value: String(format: "%.2f°", θc))
                } else {
                    CalcOutput(label: "임계각", value: "없음")
                }
            }
        }
    }
}

struct LensCalculator: View {
    @State private var f: Double  = 2.0
    @State private var p: Double  = 5.0
    @State private var ho: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "초점거리 f", value: $f,
                               range: -10...10, unit: "m")
                CalcInputField(title: "물체 거리 p", value: $p,
                               range: 0.1...20, unit: "m")
                CalcInputField(title: "물체 높이 h_o", value: $ho,
                               range: 0.1...5, unit: "m")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let denom = p - f
                if abs(denom) < 1e-9 {
                    CalcOutput(label: "상거리 q", value: "∞", emphasis: true)
                    CalcOutput(label: "상", value: "형성 안됨")
                } else {
                    let q = p * f / denom
                    let m = -q / p
                    let hi = m * ho
                    CalcOutput(label: "상거리 q",
                               value: String(format: "%+.2f m", q), emphasis: true)
                    CalcOutput(label: "배율 m",
                               value: String(format: "%+.2f", m))
                    CalcOutput(label: "상 높이 h_i",
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

struct PendulumCalculator: View {
    @State private var L: Double  = 1.0
    @State private var g: Double  = 9.81
    @State private var thetaDeg: Double = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "줄 길이 L", value: $L, range: 0.1...10, unit: "m")
                CalcInputField(title: "중력가속도 g", value: $g, range: 1.62...24.79, unit: "m/s²")
                CalcInputField(title: "최대 각도 θ_max", value: $thetaDeg, range: 1...170, unit: "°")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let T0 = 2 * .pi * sqrt(L / g)
                CalcOutput(label: "작은-각 주기 T₀",
                           value: String(format: "%.2f s", T0), emphasis: true)

                let θ = thetaDeg * .pi / 180
                let θ2 = θ * θ
                let θ4 = θ2 * θ2
                let θ6 = θ4 * θ2
                let correction = 1 + θ2 / 16 + 11 * θ4 / 3072 + 173 * θ6 / 737280
                let T = T0 * correction
                CalcOutput(label: "정확한 주기 T",
                           value: String(format: "%.2f s", T), emphasis: true)
                CalcOutput(label: "보정 비율",
                           value: String(format: "%.2f", correction))
                CalcOutput(label: "고유진동수 ω₀",
                           value: String(format: "%.2f rad/s", sqrt(g / L)))
            }
        }
    }
}

struct CollisionCalculator: View {
    @State private var m1: Double = 2.0
    @State private var v1: Double = 3.0
    @State private var m2: Double = 1.0
    @State private var v2: Double = -1.0
    @State private var e: Double  = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "질량 m₁", value: $m1, range: 0.1...20, unit: "kg")
                CalcInputField(title: "초속 v₁", value: $v1, range: -20...20, unit: "m/s")
                CalcInputField(title: "질량 m₂", value: $m2, range: 0.1...20, unit: "kg")
                CalcInputField(title: "초속 v₂", value: $v2, range: -20...20, unit: "m/s")
                CalcInputField(title: "반발계수 e", value: $e, range: 0...1)
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
                CalcOutput(label: "운동량",
                           value: String(format: "%.2f → %.2f", m1*v1+m2*v2, m1*v1p+m2*v2p))
                let KE  = 0.5 * (m1*v1*v1 + m2*v2*v2)
                let KE2 = 0.5 * (m1*v1p*v1p + m2*v2p*v2p)
                CalcOutput(label: "운동에너지",
                           value: String(format: "%.2f → %.2f J", KE, KE2))
                CalcOutput(label: "ΔKE",
                           value: String(format: "%+.2f J", KE2 - KE))
                let label: String =
                    abs(e - 1) < 1e-6 ? "완전탄성"
                    : (e < 1e-6 ? "완전비탄성" : "부분탄성")
                CalcOutput(label: "유형", value: label)
            }
        }
    }
}

struct KeplerCalculator: View {
    @State private var GM: Double = 200
    @State private var r: Double  = 5
    @State private var v: Double  = 6
    @State private var gammaDeg: Double = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "GM", value: $GM, range: 10...500)
                CalcInputField(title: "현재 거리 r", value: $r, range: 0.5...20)
                CalcInputField(title: "현재 속력 v", value: $v, range: 0...20)
                CalcInputField(title: "v 와 r 사이 각 γ",
                               value: $gammaDeg, range: 0...180, unit: "°")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                if r <= 0 || GM <= 0 {
                    Text("입력값 오류")
                        .font(.footnote).foregroundStyle(.orange)
                } else {
                    let γ = gammaDeg * .pi / 180
                    let vTangential = v * sin(γ)
                    let vRadial     = v * cos(γ)
                    let E = 0.5 * v * v - GM / r
                    let escape = sqrt(2 * GM / r)
                    CalcOutput(label: "접선 v_t",
                               value: String(format: "%.2f", vTangential))
                    CalcOutput(label: "반경 v_r",
                               value: String(format: "%.2f", vRadial))
                    CalcOutput(label: "탈출속력 v_esc",
                               value: String(format: "%.2f", escape))
                    CalcOutput(label: "비-에너지 ε",
                               value: String(format: "%.2f", E))
                    if E >= 0 {
                        CalcOutput(label: "궤도 종류", value: "탈출 궤도",
                                   emphasis: true)
                    } else {
                        let a = -GM / (2 * E)
                        let L = r * vTangential
                        let term = max(0, 1 + 2 * E * L * L / (GM * GM))
                        let ecc = sqrt(term)
                        let T = 2 * .pi * sqrt(pow(a, 3) / GM)
                        let rPeri = a * (1 - ecc)
                        let rApo  = a * (1 + ecc)
                        CalcOutput(label: "장반경 a",
                                   value: String(format: "%.2f", a), emphasis: true)
                        CalcOutput(label: "이심률 e",
                                   value: String(format: "%.2f", ecc))
                        CalcOutput(label: "공전주기 T",
                                   value: String(format: "%.2f", T), emphasis: true)
                        CalcOutput(label: "근일점 r_peri",
                                   value: String(format: "%.2f", rPeri))
                        CalcOutput(label: "원일점 r_apo",
                                   value: String(format: "%.2f", rApo))
                    }
                }
            }
        }
    }
}

struct DopplerCalculator: View {
    enum Mode: String, CaseIterable, Identifiable {
        case sourceOnly = "음원만", observerOnly = "관측자만", both = "둘 다"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .both
    @State private var f0: Double = 440
    @State private var c: Double  = 343
    @State private var vs: Double = 0
    @State private var vo: Double = 0
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
                CalcInputField(title: "원래 진동수 f", value: $f0, range: 50...2000, unit: "Hz")
                CalcInputField(title: "음속 c", value: $c, range: 100...500, unit: "m/s")
                if mode != .observerOnly {
                    CalcInputField(title: "음원 속력 v_s",
                                   value: $vs, range: -300...300, unit: "m/s")
                }
                if mode != .sourceOnly {
                    CalcInputField(title: "관측자 속력 v_o",
                                   value: $vo, range: -300...300, unit: "m/s")
                }
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let evs = effectiveVs
                let evo = effectiveVo
                if c - evs <= 1e-9 {
                    CalcOutput(label: "f′", value: "정의되지 않음", emphasis: true)
                } else {
                    let fp = f0 * (c + evo) / (c - evs)
                    CalcOutput(label: "관측 진동수 f′",
                               value: String(format: "%.2f Hz", fp), emphasis: true)
                    CalcOutput(label: "주기 T′",
                               value: String(format: "%.2f s", 1 / fp))
                    CalcOutput(label: "f′ / f",
                               value: String(format: "%.2f", fp / f0))
                    CalcOutput(label: "음정 변화",
                               value: String(format: "%+.2f cents",
                                              1200 * log2(fp / f0)))
                    CalcOutput(label: "마하 수",
                               value: String(format: "%.2f", evs / c))
                }
            }
        }
    }
}

struct DoubleSlitCalculator: View {
    @State private var lambdaNm: Double = 550
    @State private var dUm: Double      = 50
    @State private var aUm: Double      = 8
    @State private var D: Double        = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalcSection(title: "입력값") {
                CalcInputField(title: "파장 λ", value: $lambdaNm, range: 380...780, unit: "nm")
                CalcInputField(title: "슬릿 간격 d", value: $dUm, range: 10...500, unit: "μm")
                CalcInputField(title: "슬릿 폭 a", value: $aUm, range: 1...100, unit: "μm")
                CalcInputField(title: "막까지 거리 D", value: $D, range: 0.3...5, unit: "m")
            }
            PropertyDivider()
            CalcSection(title: "결과") {
                let λ = lambdaNm * 1e-9
                let d = dUm * 1e-6
                let a = aUm * 1e-6
                if d <= 0 || λ <= 0 {
                    Text("입력값 오류")
                        .font(.footnote).foregroundStyle(.orange)
                } else {
                    let dy = λ * D / d
                    let ya = λ * D / a
                    CalcOutput(label: "이웃 무늬 간격 Δy",
                               value: String(format: "%.2f mm", dy * 1000),
                               emphasis: true)
                    CalcOutput(label: "회절 첫 영점 y_a",
                               value: String(format: "%.2f mm", ya * 1000))
                    CalcOutput(label: "보강 무늬 수",
                               value: "\(Int((2 * d / a).rounded())) 개")
                    let θ1 = asin(min(1, λ / d))
                    CalcOutput(label: "첫 보강 회절각 θ₁",
                               value: String(format: "%.2f°", θ1 * 180 / .pi))
                }
            }
        }
    }
}

#Preview {
    NavigationStack { CalculatorView(topic: .pendulum) }
}

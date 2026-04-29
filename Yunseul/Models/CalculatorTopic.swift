import SwiftUI

/// 계산기 주제 — 시뮬레이션과 별개로 "값 입력 → 닫힌 해 결과" 만 빠르게 보여주는 도구.
enum CalculatorTopic: String, CaseIterable, Identifiable, Hashable {
    // 역학
    case freefall   = "자유낙하"
    case projectile = "포물선 운동"
    case pendulum   = "단진자 주기"
    case collision  = "1차원 충돌"
    case kepler     = "케플러 궤도 매개변수"

    // 전자기
    case ohm        = "옴의 법칙"

    // 파동·광학
    case doppler    = "도플러 효과"
    case refraction = "스넬의 법칙"
    case lens       = "얇은 렌즈"
    case slit       = "이중 슬릿"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .freefall:   return "h₀, v₀, g 만 알면 비행시간·최고점·충격속도가 나온다"
        case .projectile: return "발사각·초속력·발사높이 → 사거리·체공시간·최고점"
        case .pendulum:   return "줄 길이와 진폭으로 주기 — 작은각 근사와 진폭 보정"
        case .collision:  return "두 입자의 충돌 후 속도와 에너지 변화"
        case .kepler:     return "현재 위치·속도로부터 a, e, 주기, 근/원일점"
        case .ohm:        return "전압·저항으로 전류·전력. 직렬·병렬 합성도."
        case .doppler:    return "음원·관측자 속도로 관측 진동수 f′"
        case .refraction: return "n₁ sinθ₁ = n₂ sinθ₂ — 굴절각·임계각"
        case .lens:       return "1/f = 1/p + 1/q — 상거리·배율·실상/허상"
        case .slit:       return "이중슬릿 무늬 간격과 회절 영점"
        }
    }

    var formula: String {
        switch self {
        case .freefall:
            return "y(t) = h₀ + v₀ t − ½ g t²"
        case .projectile:
            return "x(t) = v₀ cosθ · t,    y(t) = h₀ + v₀ sinθ · t − ½ g t²"
        case .pendulum:
            return "T₀ = 2π √(L/g),    T(θ_max) ≈ T₀·(1 + θ²/16 + 11θ⁴/3072 + …)"
        case .collision:
            return "v₁′ = ((m₁ − e m₂)·v₁ + (1+e)·m₂·v₂) / (m₁+m₂)"
        case .kepler:
            return "a = −GM / (2E),    E = ½v² − GM/r,    T = 2π √(a³/GM)"
        case .ohm:
            return "V = I R,    P = V I = I² R = V² / R"
        case .doppler:
            return "f′ = f · (c + v_o) / (c − v_s)"
        case .refraction:
            return "n₁ sinθ₁ = n₂ sinθ₂,    sinθ_c = n₂ / n₁"
        case .lens:
            return "1/f = 1/p + 1/q,    m = − q / p"
        case .slit:
            return "Δy = λ D / d,    회절 영점: y_a = λ D / a"
        }
    }

    var curriculum: String {
        switch self {
        case .freefall:   return "중3 / 물리Ⅰ · 운동과 에너지"
        case .projectile: return "물리Ⅰ · 등가속도 운동"
        case .pendulum:   return "물리Ⅰ / 물리Ⅱ · 단진자"
        case .collision:  return "중3 / 물리Ⅰ · 운동량과 충돌"
        case .kepler:     return "물리Ⅰ · 만유인력과 행성 운동"
        case .ohm:        return "중2 / 물리Ⅱ · 전기"
        case .doppler:    return "물리Ⅰ · 파동"
        case .refraction: return "중1 / 물리Ⅰ · 빛과 파동"
        case .lens:       return "중1 / 물리Ⅰ · 빛의 굴절·렌즈"
        case .slit:       return "물리Ⅰ · 빛의 간섭과 회절"
        }
    }

    /// 분류 — 계산기 목록에서 섹션으로 묶기 위해.
    var section: String {
        switch self {
        case .freefall, .projectile, .pendulum, .collision, .kepler:
            return "역학"
        case .ohm:
            return "전자기"
        case .doppler, .refraction, .lens, .slit:
            return "파동·광학"
        }
    }

    /// 이 계산기와 짝이 되는 시뮬레이션 ID. `SimulationCatalog.allItems` 의 id.
    /// 계산기 화면 상단에 "이 시뮬로 보기" 버튼을 노출할 때 사용.
    var simulationId: String? {
        switch self {
        case .freefall:   return "freefall"
        case .projectile: return "projectile"
        case .pendulum:   return "pendulum"
        case .collision:  return "collision1d"
        case .kepler:     return "kepler"
        case .ohm:        return "circuit"
        case .doppler:    return "doppler"
        case .refraction: return "reflection"
        case .lens:       return "lens"
        case .slit:       return "doubleslit"
        }
    }
}

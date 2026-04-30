import SwiftUI

enum CalculatorTopic: String, CaseIterable, Identifiable, Hashable {
    case freefall   = "자유낙하"
    case projectile = "포물선 운동"
    case pendulum   = "단진자 주기"
    case collision  = "1차원 충돌"
    case kepler     = "케플러 궤도 매개변수"
    case ohm        = "옴의 법칙"
    case doppler    = "도플러 효과"
    case refraction = "스넬의 법칙"
    case lens       = "얇은 렌즈"
    case slit       = "이중 슬릿"

    var id: String { rawValue }

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

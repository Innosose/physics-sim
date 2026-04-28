import SwiftUI

/// 계산기 주제 — 시뮬레이션과 별개로 "값 입력 → 닫힌 해 결과" 만 빠르게 보여주는 도구.
///
/// 각 토픽은 한국 교육과정 단원과 핵심 공식을 함께 가지고 있어, 숙제 풀 때
/// 어떤 단원의 어떤 공식을 쓰는지 같이 확인할 수 있다.
enum CalculatorTopic: String, CaseIterable, Identifiable, Hashable {
    case freefall   = "자유낙하"
    case projectile = "포물선 운동"
    case ohm        = "옴의 법칙"
    case refraction = "스넬의 법칙"
    case lens       = "얇은 렌즈"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .freefall:   return "h₀, v₀, g 만 알면 비행시간·최고점·충격속도가 나온다"
        case .projectile: return "발사각·초속력·발사높이 → 사거리·체공시간·최고점"
        case .ohm:        return "전압·저항으로 전류·전력. 직렬·병렬 합성도."
        case .refraction: return "n₁ sinθ₁ = n₂ sinθ₂ — 굴절각·임계각"
        case .lens:       return "1/f = 1/p + 1/q — 상거리·배율·실상/허상"
        }
    }

    var formula: String {
        switch self {
        case .freefall:
            return "y(t) = h₀ + v₀ t − ½ g t²"
        case .projectile:
            return "x(t) = v₀ cosθ · t,    y(t) = h₀ + v₀ sinθ · t − ½ g t²"
        case .ohm:
            return "V = I R,    P = V I = I² R = V² / R"
        case .refraction:
            return "n₁ sinθ₁ = n₂ sinθ₂,    sinθ_c = n₂ / n₁"
        case .lens:
            return "1/f = 1/p + 1/q,    m = − q / p"
        }
    }

    var curriculum: String {
        switch self {
        case .freefall:   return "중3 / 물리Ⅰ · 운동과 에너지"
        case .projectile: return "물리Ⅰ · 등가속도 운동"
        case .ohm:        return "중2 / 물리Ⅱ · 전기"
        case .refraction: return "중1 / 물리Ⅰ · 빛과 파동"
        case .lens:       return "중1 / 물리Ⅰ · 빛의 굴절·렌즈"
        }
    }
}

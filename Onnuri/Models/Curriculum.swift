import SwiftUI

/// 교육과정 단계.
enum Curriculum: String, CaseIterable, Identifiable, Hashable {
    case elementary = "초등학교"
    case middle     = "중학교"
    case high       = "고등학교"
    case free       = "자유 시뮬레이션"

    var id: String { rawValue }

    /// 시작화면 타일에 들어가는 부제.
    var subtitle: String {
        switch self {
        case .elementary: return "3–6학년 과학"
        case .middle:     return "1–3학년 과학"
        case .high:       return "물리Ⅰ·Ⅱ"
        case .free:       return "재질·다체 충돌·N체 중력"
        }
    }

    /// 큰 타일에 쓸 시각 단서.
    var iconSystemName: String {
        switch self {
        case .elementary: return "leaf.fill"
        case .middle:     return "atom"
        case .high:       return "function"
        case .free:       return "sparkles"
        }
    }

    /// 타일 강조색 — 학년이 올라갈수록 차분한 톤.
    var accent: Color {
        switch self {
        case .elementary: return Color(red: 0.95, green: 0.66, blue: 0.30)
        case .middle:     return Color(red: 0.30, green: 0.74, blue: 0.85)
        case .high:       return Color(red: 0.55, green: 0.45, blue: 0.95)
        case .free:       return Color(red: 0.98, green: 0.86, blue: 0.40)
        }
    }
}

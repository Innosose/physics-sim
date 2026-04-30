import SwiftUI

/// 교육과정 단계 — 윤슬은 **중·고등학생** 대상이고, 그 위에 자유 샌드박스가 더해진다.
enum Curriculum: String, CaseIterable, Identifiable, Hashable {
    case middle = "중학교"
    case high   = "고등학교"
    case free   = "자유 시뮬레이션"

    var id: String { rawValue }

    /// 사이드바 아래 보조 설명.
    var subtitle: String {
        switch self {
        case .middle: return "1–3학년 과학"
        case .high:   return "물리Ⅰ·Ⅱ"
        case .free:   return "값을 직접 조절"
        }
    }

    /// 강조색 — 학년이 올라갈수록 차분한 톤.
    var accent: Color {
        switch self {
        case .middle: return Color(red: 0.30, green: 0.74, blue: 0.85)
        case .high:   return Color(red: 0.55, green: 0.45, blue: 0.95)
        case .free:   return Color(red: 0.98, green: 0.86, blue: 0.40)
        }
    }
}

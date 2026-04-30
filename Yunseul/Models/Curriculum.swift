import SwiftUI

enum Curriculum: String, CaseIterable, Identifiable, Hashable {
    case middle = "중학교"
    case high   = "고등학교"
    case free   = "샌드박스"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .middle: return "1–3학년 과학"
        case .high:   return "물리Ⅰ·Ⅱ"
        case .free:   return "자유 시뮬레이션"
        }
    }

    var accent: Color {
        switch self {
        case .middle: return Color(red: 0.30, green: 0.74, blue: 0.85)
        case .high:   return Color(red: 0.55, green: 0.45, blue: 0.95)
        case .free:   return Color(red: 0.98, green: 0.86, blue: 0.40)
        }
    }
}

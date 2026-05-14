import SwiftUI

enum Curriculum: String, CaseIterable, Identifiable, Hashable {
    case middle = "중학교"
    case high   = "고등학교"
    case free   = "샌드박스"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .middle: return Color(red: 0.36, green: 0.54, blue: 0.62)  // 청회색 연필
        case .high:   return Color(red: 0.50, green: 0.42, blue: 0.62)  // 보라 연필
        case .free:   return Color(red: 0.74, green: 0.58, blue: 0.30)  // 황토 연필
        }
    }
}

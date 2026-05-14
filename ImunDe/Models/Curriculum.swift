import SwiftUI

enum Curriculum: String, CaseIterable, Identifiable, Hashable {
    case middle = "중학교"
    case high   = "고등학교"
    case free   = "샌드박스"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .middle: return "graduationcap.fill"
        case .high:   return "book.closed.fill"
        case .free:   return "play.square.fill"
        }
    }

    var accent: Color {
        switch self {
        case .middle: return Color.adaptive(light: Color(white: 0.18),
                                            dark:  Color(white: 0.90))
        case .high:   return Color.adaptive(light: Color(white: 0.42),
                                            dark:  Color(white: 0.66))
        case .free:   return Color.adaptive(light: Color(white: 0.65),
                                            dark:  Color(white: 0.40))
        }
    }
}

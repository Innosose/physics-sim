import SwiftUI

/// 시뮬 기능 (커리큘럼 안에서의 소기능).
enum SimCategory: String, CaseIterable, Identifiable, Hashable {
    case mechanics = "역학"
    case waveThermo = "파동·열"
    case electromagnetism = "전자기"
    case optics = "광학"
    case sandbox  = "샌드박스"

    var id: String { rawValue }
}

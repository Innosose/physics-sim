import SwiftUI

enum SimCategory: String, CaseIterable, Identifiable, Hashable {
    case mechanics = "역학"
    case waveThermo = "파동·열"
    case electromagnetism = "전자기"
    case optics = "광학"
    case sandbox  = "샌드박스"

    var id: String { rawValue }
}

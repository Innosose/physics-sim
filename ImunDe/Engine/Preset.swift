import SwiftUI

struct Preset: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let title: String
    let curriculum: Curriculum
    let category: SimCategory
    let calculatorTopic: CalculatorTopic?
    let kind: Kind
    let load: (World) -> Void

    enum Kind: Hashable {
        case mechanics2D
        case optics(OpticsScene)
        case wave(WaveScene)
        case circuit(CircuitScene)
        case graph
    }

    enum OpticsScene: Hashable { case reflection, lens, doubleSlit }
    enum WaveScene: Hashable   { case waveSum, doppler }
    enum CircuitScene: Hashable { case circuit, rlc, faraday, solenoid }

    static func == (a: Preset, b: Preset) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

import SwiftUI

struct OpenSimulationAction: @unchecked Sendable {
    let action: ((Preset) -> Void)?
    func callAsFunction(_ preset: Preset) { action?(preset) }
}

private struct OpenSimulationKey: EnvironmentKey {
    static let defaultValue = OpenSimulationAction(action: nil)
}

extension EnvironmentValues {
    var openSimulation: OpenSimulationAction {
        get { self[OpenSimulationKey.self] }
        set { self[OpenSimulationKey.self] = newValue }
    }
}

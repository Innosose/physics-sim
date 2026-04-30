import SwiftUI

struct OpenCalculatorAction: @unchecked Sendable {
    let action: ((CalculatorTopic) -> Void)?
    func callAsFunction(_ topic: CalculatorTopic) { action?(topic) }
}

private struct OpenCalculatorKey: EnvironmentKey {
    static let defaultValue = OpenCalculatorAction(action: nil)
}

extension EnvironmentValues {
    var openCalculator: OpenCalculatorAction {
        get { self[OpenCalculatorKey.self] }
        set { self[OpenCalculatorKey.self] = newValue }
    }
}

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

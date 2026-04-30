import SwiftUI

// MARK: - 시뮬 → 계산기 액션

/// 시뮬 화면 우상단 "계산기" 버튼이 호출하는 환경 액션.
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

// MARK: - 계산기 → 시뮬 액션

/// 계산기 헤더의 "시뮬로 보기" 버튼이 호출하는 환경 액션.
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

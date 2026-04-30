import SwiftUI

/// 통합 월드의 시작 배치. 사이드바 항목 = 프리셋.
///
/// 각 프리셋은 빈 `World` 를 받아 자기 시작 상태로 채움. 사용자는 그 위에서
/// 추가로 객체 spawn / 힘장 조절 가능 (= 자유 실험).
///
/// `@unchecked Sendable`: load 클로저는 항상 MainActor 에서만 호출되고 World 는
/// class 라 본질적으로 sendable 이 아니지만 실제 사용 패턴상 안전. Swift 6
/// strict 검사를 통과시키기 위한 명시 (OpenCalculatorAction 과 같은 결정).
struct Preset: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let title: String
    let curriculum: Curriculum
    let category: SimCategory
    let curriculumLabel: String              // "중3 과학 · 운동과 에너지"
    let blurb: String
    let calculatorTopic: CalculatorTopic?
    let kind: Kind
    /// 빈 월드를 시작 배치로 채우는 함수.
    let load: (World) -> Void

    /// 시뮬 자체를 어떤 렌더 모듈로 보여줄지.
    enum Kind: Hashable {
        /// 통합 월드 — 2D Canvas 평면 (XY) 렌더. 자유낙하·진자·케플러 등
        /// 평면에서 충분한 시뮬에 사용.
        case mechanics2D
        /// 통합 월드 — RealityKit 3D 렌더. 카메라 자유 회전이 학습에 도움이 되는
        /// 다체 (N체 중력·자유 충돌 박스) 만 사용.
        case mechanics3D
        /// 광학 — 광선 추적. 별도 렌더.
        case optics(OpticsScene)
        /// 파동 — heightfield / 파면. 별도 렌더.
        case wave(WaveScene)
        /// 회로 — 회로 다이어그램. 별도 렌더.
        case circuit(CircuitScene)
        /// 1D 그래프 (등속 vs 등가속도 등) — 입자 한두 개에 X축만.
        case graph
    }

    enum OpticsScene: Hashable { case reflection, lens, doubleSlit }
    enum WaveScene: Hashable   { case waveSum, doppler }
    enum CircuitScene: Hashable { case circuit, rlc }

    static func == (a: Preset, b: Preset) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

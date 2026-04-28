import SwiftUI

/// 케플러 궤도 — **닫힌 해 (analytical)** via Kepler 방정식.
///
/// 초기 조건: r(0) = (r₀, 0),  v(0) = (0, v₀)  (접선 방향).
///
/// 보존량으로부터 궤도 매개변수를 구하고:
///   E   = ½v₀² − GM/r₀                                (단위질량 에너지)
///   L   = r₀ · v₀                                     (단위질량 각운동량 z성분)
///   a   = −GM / (2E)                                  (반장축)
///   e   = √(1 + 2E·L² / GM²)                          (이심률)
///
/// 시간 진행은 Kepler 방정식 M = E − e·sin(E) 의 Newton 풀이 (10번 이내 수렴).
///
///  • r₀ < a : 시작점이 근일점 (E_init = 0). 근일점이 +x 축에 위치.
///  • r₀ > a : 시작점이 원일점 (E_init = π). 근일점이 −x 축에 위치 (180° 회전).
///
/// 적분 없음 — 시각 t 가 주어지면 위 식으로 직접 계산.
struct KeplerScene: View {
    @State private var GM: Double = 200.0
    @State private var r0: Double = 5.0
    @State private var v0: Double = 6.0
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "v₀ 가 작으면 길쭉한 타원, 원궤도 속도 √(GM/r) 이면 원, 더 크면 길쭉한 타원. 탈출속력을 넘으면 쌍곡선 (이 시뮬은 닫힌 궤도만 그림).",
            canvas: { canvas },
            controls: { controls })
    }

    private func onSliderEnd(_ editing: Bool) {
        if !editing { startTime = Date() }
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                let t = max(0, tl.date.timeIntervalSince(startTime))
                draw(ctx: ctx, size: size, t: t)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "GM", value: $GM, range: 50...600,
                          format: "%.0f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "초기 거리 r₀", value: $r0, range: 2...10,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "초기 접선속력 v₀", value: $v0, range: 1...12,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            PlayResetBar(running: $running,
                         onReset: { startTime = Date() },
                         resetLabel: "처음부터")
            Divider()
            let circ = sqrt(GM / r0)
            let esc  = sqrt(2 * GM / r0)
            Readout(label: "원궤도 속력",   value: String(format: "%.2f", circ))
            Readout(label: "탈출속력",     value: String(format: "%.2f", esc))
            if let p = orbitParams {
                Readout(label: "반장축 a", value: String(format: "%.2f", p.a))
                Readout(label: "이심률 e", value: String(format: "%.3f", p.e))
                let T = 2 * .pi * sqrt(p.a * p.a * p.a / GM)
                Readout(label: "주기 T",   value: String(format: "%.2f", T))
                let pos = position(at: max(0, Date().timeIntervalSince(startTime)))
                Readout(label: "현재 r",   value: String(format: "%.2f", pos.length))
            } else {
                Text("탈출 궤도 — v₀ ≥ 탈출속력")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - 닫힌 해

    /// 닫힌 궤도의 a, e (속도가 탈출속력 미만일 때만).
    private var orbitParams: (a: Double, e: Double, signFlip: Double, E_init: Double)? {
        let E_orbit = 0.5 * v0 * v0 - GM / r0
        guard E_orbit < -1e-6 else { return nil }    // 결합 궤도 아님 (포물선/쌍곡선)
        let L = r0 * v0
        let a = -GM / (2 * E_orbit)
        let e = sqrt(max(0, 1 + 2 * E_orbit * L * L / (GM * GM)))
        let flip: Double = (r0 > a) ? -1 : 1         // 시작이 원일점이면 궤도 180° 뒤집음
        let Einit: Double = (r0 > a) ? .pi : 0
        return (a: a, e: e, signFlip: flip, E_init: Einit)
    }

    /// 시각 t 에서의 위치 (focus 가 원점). 탈출 궤도는 nil.
    private func position(at t: Double) -> Vec2 {
        guard let p = orbitParams else { return Vec2(x: r0, y: 0) }
        let n = sqrt(GM / (p.a * p.a * p.a))
        let M = p.E_init + n * t
        let E = solveKepler(M: M, e: p.e)
        let x = p.signFlip * p.a * (cos(E) - p.e)
        let y = p.signFlip * p.a * sqrt(1 - p.e * p.e) * sin(E)
        return Vec2(x: x, y: y)
    }

    /// Newton 반복으로 Kepler 방정식 E − e·sin E = M 풀기.
    private func solveKepler(M: Double, e: Double) -> Double {
        var E = M     // 초기 추정 (e 작을 때 양호)
        for _ in 0..<10 {
            let f  = E - e * sin(E) - M
            let fp = 1 - e * cos(E)
            guard abs(fp) > 1e-12 else { break }
            let dE = f / fp
            E -= dE
            if abs(dE) < 1e-12 { break }
        }
        return E
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        // 화면 범위는 a·(1+e) 보다 살짝 크게.
        let halfWidth: Double
        if let p = orbitParams {
            halfWidth = p.a * (1 + p.e) + 2
        } else {
            halfWidth = max(8, abs(position(at: t).x) * 1.4 + 2)
        }
        let world = CGRect(x: -halfWidth, y: -halfWidth,
                           width: 2 * halfWidth, height: 2 * halfWidth)
        let map = CanvasMap(view: size, world: world, padding: 12)

        // 1. 전체 궤도 (분석해의 정적 곡선).
        if let p = orbitParams {
            var orbit = Path()
            let n = 240
            for i in 0...n {
                let E = 2 * .pi * Double(i) / Double(n)
                let x = p.signFlip * p.a * (cos(E) - p.e)
                let y = p.signFlip * p.a * sqrt(1 - p.e * p.e) * sin(E)
                let pt = map.point(x: x, y: y)
                if i == 0 { orbit.move(to: pt) } else { orbit.addLine(to: pt) }
            }
            ctx.stroke(orbit, with: .color(.cyan.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        // 2. 중심 질량.
        let c = map.point(.zero)
        let cr: CGFloat = 10
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - cr, y: c.y - cr,
                                        width: cr * 2, height: cr * 2)),
                 with: .color(.orange))

        // 3. 현재 행성 위치.
        let pos = position(at: t)
        let pp = map.point(pos)
        let pr: CGFloat = 6
        ctx.fill(Path(ellipseIn: CGRect(x: pp.x - pr, y: pp.y - pr,
                                        width: pr * 2, height: pr * 2)),
                 with: .color(.yellow))
    }
}

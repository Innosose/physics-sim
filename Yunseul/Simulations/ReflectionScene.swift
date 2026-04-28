import SwiftUI

/// 빛의 반사·굴절 — 평평한 경계면.
///
///  반사:  θ_반사 = θ_입사
///  굴절:  n₁ sinθ₁ = n₂ sinθ₂           (스넬 법칙)
///  임계각: sinθ_c = n₂ / n₁  (n₁ > n₂ 일 때)
///
/// 경계면은 화면 가운데 가로선. 위쪽은 매질 1 (n₁), 아래는 매질 2 (n₂).
struct ReflectionScene: View {
    @State private var incidenceDeg: Double = 30
    @State private var n1: Double = 1.00      // 공기
    @State private var n2: Double = 1.50      // 유리

    var body: some View {
        SimChrome(
            blurb: "빛이 다른 매질을 만나면 일부는 반사하고 일부는 굴절한다. n₁ sinθ₁ = n₂ sinθ₂. 큰 매질에서 작은 매질로 갈 때 임계각보다 크면 전반사가 일어난다.",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "입사각 θ₁", value: $incidenceDeg, range: 0...89,
                          step: 0.5, format: "%.2f", unit: "°")
            LabeledSlider(title: "위쪽 매질 굴절률 n₁", value: $n1, range: 1.0...2.5,
                          format: "%.2f")
            LabeledSlider(title: "아래쪽 매질 굴절률 n₂", value: $n2, range: 1.0...2.5,
                          format: "%.2f")
            Divider()
            let θ1 = incidenceDeg * .pi / 180
            let sin2 = n1 * sin(θ1) / n2
            if sin2 <= 1 + 1e-9 {
                let θ2 = asin(min(1, max(-1, sin2)))
                Readout(label: "굴절각 θ₂",
                        value: String(format: "%.2f°", θ2 * 180 / .pi))
            } else {
                Text("전반사 — 굴절광선 없음")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            if n1 > n2 {
                let θc = asin(n2 / n1) * 180 / .pi
                Readout(label: "임계각 θ_c",
                        value: String(format: "%.2f°", θc))
            } else {
                Text("n₁ ≤ n₂ — 임계각 없음 (이 방향에서는 전반사 불가)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let world = CGRect(x: -5, y: -5, width: 10, height: 10)
        let map = CanvasMap(view: size, world: world, padding: 18)

        // 매질 영역 색.
        let upper = CGRect(
            x: map.point(x: -5, y: 5).x, y: map.point(x: 0, y: 5).y,
            width: map.length(10), height: map.length(5))
        let lower = CGRect(
            x: map.point(x: -5, y: 0).x, y: map.point(x: 0, y: 0).y,
            width: map.length(10), height: map.length(5))
        ctx.fill(Path(upper), with: .color(.white.opacity(0.04)))
        ctx.fill(Path(lower), with: .color(.cyan.opacity(0.10)))

        // 경계면.
        var boundary = Path()
        boundary.move(to: map.point(x: -5, y: 0))
        boundary.addLine(to: map.point(x:  5, y: 0))
        ctx.stroke(boundary, with: .color(.white.opacity(0.6)), lineWidth: 1.5)

        // 법선.
        var normal = Path()
        normal.move(to: map.point(x: 0, y: -3.5))
        normal.addLine(to: map.point(x: 0, y:  3.5))
        ctx.stroke(normal, with: .color(.white.opacity(0.4)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // 입사 광선.
        let θ1 = incidenceDeg * .pi / 180
        let len = 4.5
        let incidentStart = Vec2(x: -len * sin(θ1), y:  len * cos(θ1))
        drawArrow(ctx: ctx, map: map,
                  from: incidentStart, to: Vec2.zero, color: .yellow)

        // 반사 광선.
        let reflectedEnd = Vec2(x: len * sin(θ1), y: len * cos(θ1))
        drawArrow(ctx: ctx, map: map,
                  from: Vec2.zero, to: reflectedEnd, color: .cyan)

        // 굴절 광선 (전반사 아니면).
        let sin2 = n1 * sin(θ1) / n2
        if sin2 <= 1 + 1e-9 {
            let θ2 = asin(min(1, max(-1, sin2)))
            let refractedEnd = Vec2(x: len * sin(θ2), y: -len * cos(θ2))
            drawArrow(ctx: ctx, map: map,
                      from: Vec2.zero, to: refractedEnd, color: .orange)
        }

        // 매질 라벨.
        ctx.draw(Text("n₁ = \(String(format: "%.2f", n1))")
                    .font(.caption).foregroundStyle(.secondary),
                 at: map.point(x: -4.4, y: 4.5))
        ctx.draw(Text("n₂ = \(String(format: "%.2f", n2))")
                    .font(.caption).foregroundStyle(.secondary),
                 at: map.point(x: -4.4, y: -4.5))
    }

    private func drawArrow(ctx: GraphicsContext, map: CanvasMap,
                           from a: Vec2, to b: Vec2, color: Color) {
        var line = Path()
        line.move(to: map.point(a)); line.addLine(to: map.point(b))
        ctx.stroke(line, with: .color(color), lineWidth: 2)
        let dir = (b - a).normalized
        let perp = Vec2(x: -dir.y, y: dir.x)
        let h1 = b - dir * 0.32 + perp * 0.18
        let h2 = b - dir * 0.32 - perp * 0.18
        var head = Path()
        head.move(to: map.point(h1)); head.addLine(to: map.point(b))
        head.addLine(to: map.point(h2))
        ctx.stroke(head, with: .color(color), lineWidth: 2)
    }
}

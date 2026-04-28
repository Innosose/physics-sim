import SwiftUI

/// 지렛대 (시소) — 받침점에서의 토크 균형.
///
///   τ = w · d.   τ_left = τ_right 이면 평형.
///   τ_left ≠ τ_right 이면 큰 쪽으로 기울어 정적 마찰이 클 때까지 회전하다 멈춤.
///
/// 시각화: 시소가 토크 차이의 부호로 작은 각도로 기울어진다 (정적 표시).
struct LeverScene: View {
    @State private var w1: Double = 4.0    // 왼쪽 무게 (kg, 시각용)
    @State private var d1: Double = 2.0    // 왼쪽 거리 (m)
    @State private var w2: Double = 2.0    // 오른쪽 무게
    @State private var d2: Double = 4.0    // 오른쪽 거리

    var body: some View {
        SimChrome(
            blurb: "지렛대가 평형이 되려면 (왼쪽 무게 × 왼쪽 거리) = (오른쪽 무게 × 오른쪽 거리). 가벼운 쪽이 더 멀리 있어야 한다.",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "왼쪽 무게 w₁", value: $w1, range: 0.5...10,
                          format: "%.1f", unit: "kg")
            LabeledSlider(title: "왼쪽 거리 d₁", value: $d1, range: 0.5...5,
                          format: "%.1f", unit: "m")
            LabeledSlider(title: "오른쪽 무게 w₂", value: $w2, range: 0.5...10,
                          format: "%.1f", unit: "kg")
            LabeledSlider(title: "오른쪽 거리 d₂", value: $d2, range: 0.5...5,
                          format: "%.1f", unit: "m")
            Divider()
            let τl = w1 * d1, τr = w2 * d2
            Readout(label: "왼쪽 회전력 τ₁ = w₁·d₁",
                    value: String(format: "%.2f", τl))
            Readout(label: "오른쪽 회전력 τ₂ = w₂·d₂",
                    value: String(format: "%.2f", τr))
            let diff = τl - τr
            let stateText: String =
                abs(diff) < 0.05 ? "평형 (τ₁ = τ₂)"
                                : diff > 0 ? "왼쪽으로 기울어짐"
                                           : "오른쪽으로 기울어짐"
            Text(stateText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(abs(diff) < 0.05 ? Color.green : Color.orange)
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let span = 12.0
        let world = CGRect(x: -span / 2, y: -3, width: span, height: 7)
        let map = CanvasMap(view: size, world: world, padding: 14)

        let pivot = Vec2(x: 0, y: 0)
        // 토크 차이에 비례한 각도. 시각용 — 평형이면 0.
        let imbalance = (w1 * d1 - w2 * d2)
        let maxAngleDeg: Double = 12
        let scale: Double = 6
        let theta = max(-maxAngleDeg, min(maxAngleDeg, imbalance / scale * maxAngleDeg)) * .pi / 180
        // 월드 좌표는 y=위. CCW 회전을 양수로 정의했으므로, imbalance > 0 (왼쪽 무거움)
        // 일 때 (-d, 0) 의 y 가 음수가 되도록 — 즉 양의 theta 로 CCW 회전하면 됨:
        //   y' = (-d)·sin(theta) → theta>0 이면 y'<0 (왼쪽이 아래로).

        // 막대.
        let halfLen = 5.0
        let leftEnd  = rotate(Vec2(x: -halfLen, y: 0), by: theta) + pivot
        let rightEnd = rotate(Vec2(x:  halfLen, y: 0), by: theta) + pivot
        var bar = Path()
        bar.move(to: map.point(leftEnd))
        bar.addLine(to: map.point(rightEnd))
        ctx.stroke(bar, with: .color(.cyan), lineWidth: 6)

        // 추 위치 (막대 위에서의 거리).
        let leftWeight  = rotate(Vec2(x: -d1, y: 0), by: theta) + pivot
        let rightWeight = rotate(Vec2(x:  d2, y: 0), by: theta) + pivot
        drawWeight(ctx: ctx, map: map, at: leftWeight,  weight: w1, color: .yellow)
        drawWeight(ctx: ctx, map: map, at: rightWeight, weight: w2, color: .pink)

        // 받침점 (삼각형).
        let pp = map.point(pivot)
        var tri = Path()
        tri.move(to: CGPoint(x: pp.x, y: pp.y))
        tri.addLine(to: CGPoint(x: pp.x - 26, y: pp.y + 38))
        tri.addLine(to: CGPoint(x: pp.x + 26, y: pp.y + 38))
        tri.closeSubpath()
        ctx.fill(tri, with: .color(.gray.opacity(0.85)))

        // 바닥.
        var ground = Path()
        ground.move(to: CGPoint(x: pp.x - 80, y: pp.y + 38))
        ground.addLine(to: CGPoint(x: pp.x + 80, y: pp.y + 38))
        ctx.stroke(ground, with: .color(.white.opacity(0.4)), lineWidth: 1.2)
    }

    private func drawWeight(ctx: GraphicsContext, map: CanvasMap,
                            at p: Vec2, weight: Double, color: Color) {
        // 추는 막대 위에 매달리듯 살짝 위로.
        let h = 0.15 + 0.08 * weight
        let center = p + Vec2(x: 0, y: h / 2 + 0.05)
        let topLeft = center + Vec2(x: -0.4, y:  h / 2)
        let rect = CGRect(
            x: map.point(topLeft).x,
            y: map.point(topLeft).y,
            width: map.length(0.8),
            height: map.length(h))
        ctx.fill(Path(rect), with: .color(color))
        ctx.draw(Text(String(format: "%.0f kg", weight))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.black),
                 at: map.point(center))
    }

    private func rotate(_ v: Vec2, by angle: Double) -> Vec2 {
        let c = cos(angle), s = sin(angle)
        return Vec2(x: c * v.x - s * v.y, y: s * v.x + c * v.y)
    }
}

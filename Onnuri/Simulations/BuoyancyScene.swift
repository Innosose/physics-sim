import SwiftUI

/// 부력 — 액체 속 직육면체.
///
/// 부력 = 밀어낸 액체의 무게.   F_buoy = ρ_liquid · g · V_submerged.
/// 정적 평형: ρ_obj · V · g = ρ_liquid · V_submerged · g
///   ⇒ V_submerged / V = ρ_obj / ρ_liquid.
///
/// • ρ_obj < ρ_liquid : 일부만 잠긴 채 평형
/// • ρ_obj = ρ_liquid : 어디에 있든 평형
/// • ρ_obj > ρ_liquid : 가라앉음 (바닥 닿음)
struct BuoyancyScene: View {
    @State private var objectDensity: Double = 600    // kg/m³
    @State private var liquidDensity: Double = 1000   // kg/m³ (물)
    @State private var objectHeight: Double = 1.0     // m

    var body: some View {
        SimChrome(
            blurb: "물체의 밀도가 액체보다 작으면 일부만 잠겨서 뜬다. 잠긴 부피의 비율 = 밀도의 비율.",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "물체 밀도 ρ", value: $objectDensity, range: 100...3000,
                          format: "%.0f", unit: "kg/m³")
            LabeledSlider(title: "액체 밀도 ρ_l", value: $liquidDensity, range: 600...2000,
                          format: "%.0f", unit: "kg/m³")
            LabeledSlider(title: "물체 높이", value: $objectHeight, range: 0.4...2.0,
                          format: "%.2f", unit: "m")
            Divider()
            let frac = submergedFraction
            Readout(label: "잠긴 부피 비율",
                    value: String(format: "%.1f %%", frac * 100))
            let g = 9.81
            let V = objectHeight * 1.0 * 1.0   // 단면 1 m²
            let buoy = liquidDensity * g * (frac * V)
            let weight = objectDensity * g * V
            Readout(label: "물체 무게 W = ρVg",
                    value: String(format: "%.0f N", weight))
            Readout(label: "부력 F_buoy",
                    value: String(format: "%.0f N", buoy))
            Text(stateText)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// 정적 평형에서의 잠긴 부피 비율 (0...1). > 1 은 완전 잠김 + 가라앉음 의미.
    private var submergedFraction: Double {
        let r = objectDensity / liquidDensity
        return min(1.0, max(0.0, r))
    }

    private var stateText: String {
        if objectDensity > liquidDensity { return "가라앉음 (밀도가 더 큼)" }
        if abs(objectDensity - liquidDensity) < 1e-3 { return "어디서나 평형 — 중립 부력" }
        return "일부만 잠겨 평형 — 떠 있음"
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let world = CGRect(x: -3, y: -1, width: 6, height: 5)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 수조.
        let tank = CGRect(
            x: map.point(x: -2.5, y: 3).x,
            y: map.point(x: 0, y: 3).y,
            width: map.length(5),
            height: map.length(3.5))
        ctx.stroke(Path(tank), with: .color(.white.opacity(0.5)), lineWidth: 2)

        // 액체.
        let waterLevelY = 2.5
        let liquid = CGRect(
            x: tank.minX,
            y: map.point(x: 0, y: waterLevelY).y,
            width: tank.width,
            height: tank.maxY - map.point(x: 0, y: waterLevelY).y)
        ctx.fill(Path(liquid), with: .color(Color(red: 0.2, green: 0.5, blue: 0.85).opacity(0.55)))

        // 물체.
        let frac = submergedFraction
        let isSinking = objectDensity > liquidDensity
        let bottomY: Double
        if isSinking {
            // 바닥에 닿아 있음.
            bottomY = -0.5    // 수조 바닥 y = -0.5 (월드 좌표)
        } else {
            // 수면 위로 (1 - frac) 만큼 떠 있음.
            bottomY = waterLevelY - frac * objectHeight
        }
        let topY = bottomY + objectHeight
        let halfW = 0.6
        let objRect = CGRect(
            x: map.point(x: -halfW, y: topY).x,
            y: map.point(x: 0, y: topY).y,
            width: map.length(2 * halfW),
            height: map.length(objectHeight))
        ctx.fill(Path(objRect), with: .color(.brown))
        ctx.stroke(Path(objRect), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // 화살표: 부력(↑), 무게(↓).
        let center = Vec2(x: 0, y: (bottomY + topY) / 2)
        if !isSinking || frac > 0 {
            drawArrow(ctx: ctx, map: map,
                      from: center, to: center + Vec2(x: 0, y: 0.7),
                      color: .cyan, label: "부력")
        }
        drawArrow(ctx: ctx, map: map,
                  from: center, to: center - Vec2(x: 0, y: 0.7),
                  color: .red, label: "무게")
    }

    private func drawArrow(ctx: GraphicsContext, map: CanvasMap,
                           from a: Vec2, to b: Vec2, color: Color, label: String) {
        var line = Path()
        line.move(to: map.point(a)); line.addLine(to: map.point(b))
        ctx.stroke(line, with: .color(color), lineWidth: 2.5)
        let dir = (b - a).normalized
        let perp = Vec2(x: -dir.y, y: dir.x)
        let h1 = b - dir * 0.18 + perp * 0.10
        let h2 = b - dir * 0.18 - perp * 0.10
        var head = Path()
        head.move(to: map.point(h1)); head.addLine(to: map.point(b))
        head.addLine(to: map.point(h2))
        ctx.stroke(head, with: .color(color), lineWidth: 2.5)
        ctx.draw(Text(label).font(.caption.weight(.semibold)).foregroundColor(color),
                 at: map.point(b + dir * 0.25))
    }
}

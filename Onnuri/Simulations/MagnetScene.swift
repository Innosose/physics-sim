import SwiftUI

/// 자석의 인력과 반발 — 초등 과학 수준의 직관적 모형.
///
/// 막대 자석 두 개를 가까이 두면, 마주보는 극의 부호가 같으면 반발, 다르면 인력.
/// 정확한 다이폴-다이폴 상호작용은 1/r⁴ 보다 빠르게 감쇠하지만, 초등 수준에서는
/// 가까운 두 점-극 사이의 1/r² 모델 (쿨롱 형태) 로 충분히 직관적이다.
///
/// F = k · q₁q₂ / r²  (q는 극의 부호, +N / −S)
struct MagnetScene: View {
    @State private var distance: Double = 4.0     // 두 자석의 중심-중심 거리 (cm)
    @State private var likePoles: Bool = false    // true 면 N–N 마주봄 (반발)
    @State private var strength: Double = 1.0     // 자석 세기 비율

    /// 시뮬 단위로 정한 비례상수. 1cm 거리에서 두 단위세기 자석 사이 힘 = strength²·k.
    private let k: Double = 1.0

    var body: some View {
        SimChrome(
            blurb: "두 막대 자석을 가까이 가져가면 같은 극끼리는 밀어내고, 다른 극끼리는 끌어당긴다. 거리가 절반이 되면 힘은 4배가 된다 (역제곱 법칙).",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("같은 극 마주보기 (N–N)", isOn: $likePoles)
            LabeledSlider(title: "두 자석 사이 거리", value: $distance,
                          range: 1.0...10.0, format: "%.1f", unit: "cm")
            LabeledSlider(title: "자석 세기", value: $strength,
                          range: 0.3...3.0, format: "%.2f")
            Divider()
            let f = forceMagnitude
            Readout(label: "힘의 크기 |F|",
                    value: String(format: "%.3f (단위)", f))
            Readout(label: "방향",
                    value: likePoles ? "서로 밀어냄 (반발)" : "서로 끌어당김 (인력)")
            Text("힘 ∝ 1 / 거리². 거리를 반으로 줄이면 힘은 4배.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var forceMagnitude: Double {
        let r = max(0.1, distance)
        return k * strength * strength / (r * r)
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let span: Double = 14
        let world = CGRect(x: -span / 2, y: -3, width: span, height: 6)
        let map = CanvasMap(view: size, world: world, padding: 12)

        let leftCenter  = Vec2(x: -distance / 2, y: 0)
        let rightCenter = Vec2(x:  distance / 2, y: 0)

        // 왼쪽 자석: 항상 N(우측)–S(좌측) 으로 둔다.
        drawBar(ctx: ctx, map: map, center: leftCenter,
                northOnRight: true)
        // 오른쪽 자석: 옵션에 따라 향을 바꿈.
        // 같은 극 마주보기 = 오른쪽 자석의 N극이 왼쪽(상대 자석 쪽)을 향함.
        drawBar(ctx: ctx, map: map, center: rightCenter,
                northOnRight: !likePoles)

        // 힘 화살표.
        drawForceArrows(ctx: ctx, map: map,
                        leftCenter: leftCenter, rightCenter: rightCenter,
                        magnitude: forceMagnitude, repulsive: likePoles)
    }

    /// 막대 자석 한 개 — N극 빨강, S극 파랑. 문자도 같이.
    private func drawBar(ctx: GraphicsContext, map: CanvasMap,
                         center: Vec2, northOnRight: Bool) {
        let halfW = 1.2, halfH = 0.6
        let northRect = CGRect(
            x: map.point(x: center.x + (northOnRight ? 0 : -halfW), y: halfH).x,
            y: map.point(x: 0, y: halfH).y,
            width:  map.length(halfW),
            height: map.length(2 * halfH))
        let southRect = CGRect(
            x: map.point(x: center.x + (northOnRight ? -halfW : 0), y: halfH).x,
            y: map.point(x: 0, y: halfH).y,
            width:  map.length(halfW),
            height: map.length(2 * halfH))
        ctx.fill(Path(northRect), with: .color(.red))
        ctx.fill(Path(southRect), with: .color(.blue))
        // 글자.
        let nx = center.x + (northOnRight ?  halfW / 2 : -halfW / 2)
        let sx = center.x + (northOnRight ? -halfW / 2 :  halfW / 2)
        ctx.draw(Text("N").font(.headline.bold()).foregroundColor(.white),
                 at: map.point(x: nx, y: 0))
        ctx.draw(Text("S").font(.headline.bold()).foregroundColor(.white),
                 at: map.point(x: sx, y: 0))
    }

    private func drawForceArrows(ctx: GraphicsContext, map: CanvasMap,
                                 leftCenter: Vec2, rightCenter: Vec2,
                                 magnitude: Double, repulsive: Bool) {
        let visualLen = min(2.0, 0.6 + 0.8 * magnitude)
        let leftStart  = leftCenter + Vec2(x: 1.4, y: 1.4)
        let rightStart = rightCenter + Vec2(x: -1.4, y: 1.4)
        let dirL: Double = repulsive ? -1 : 1     // 왼쪽 자석의 힘 방향 (+x = 오른쪽으로 끌림)
        let leftEnd  = leftStart  + Vec2(x: visualLen * dirL, y: 0)
        let rightEnd = rightStart + Vec2(x: -visualLen * dirL, y: 0)
        drawArrow(ctx: ctx, map: map, from: leftStart, to: leftEnd,
                  color: repulsive ? .orange : .green)
        drawArrow(ctx: ctx, map: map, from: rightStart, to: rightEnd,
                  color: repulsive ? .orange : .green)
    }

    private func drawArrow(ctx: GraphicsContext, map: CanvasMap,
                           from a: Vec2, to b: Vec2, color: Color) {
        var line = Path()
        line.move(to: map.point(a)); line.addLine(to: map.point(b))
        ctx.stroke(line, with: .color(color), lineWidth: 2.5)
        let dir = (b - a).normalized
        let perp = Vec2(x: -dir.y, y: dir.x)
        let h1 = b - dir * 0.25 + perp * 0.14
        let h2 = b - dir * 0.25 - perp * 0.14
        var head = Path()
        head.move(to: map.point(h1))
        head.addLine(to: map.point(b))
        head.addLine(to: map.point(h2))
        ctx.stroke(head, with: .color(color), lineWidth: 2.5)
    }
}

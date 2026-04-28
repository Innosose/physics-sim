import SwiftUI

/// 빛과 그림자 — 점광원, 가림 물체, 스크린.
///
/// 닮음 삼각형:
///   shadow_height / object_height = (D_screen − D_lamp_to_object_screen) /
///                                   (D_screen − D_lamp_to_object)... 등 — 그림 참조.
/// 점광원에서 물체 꼭대기로 그은 직선이 스크린과 만나는 위치가 그림자의 끝.
struct ShadowScene: View {
    @State private var lampX: Double = -3.0     // 광원 x
    @State private var lampY: Double = 1.2      // 광원 y
    @State private var objectHeight: Double = 1.5
    @State private var screenX: Double = 5.0    // 스크린 x

    private let objectX: Double = 0             // 물체는 원점에 고정
    private let objectBaseY: Double = 0         // 바닥에 서 있음

    var body: some View {
        SimChrome(
            blurb: "광원이 물체에 가까워질수록 그림자가 커진다. 광원과 물체와 그림자 끝은 일직선 위에 놓인다.",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "광원 가로 위치", value: $lampX, range: -6 ... -0.5,
                          format: "%.1f", unit: "m")
            LabeledSlider(title: "광원 높이",     value: $lampY, range: 0.2 ... 4.0,
                          format: "%.1f", unit: "m")
            LabeledSlider(title: "물체 높이",     value: $objectHeight, range: 0.5 ... 3.0,
                          format: "%.1f", unit: "m")
            LabeledSlider(title: "스크린까지 거리", value: $screenX, range: 1.5 ... 8.0,
                          format: "%.1f", unit: "m")
            Divider()
            Readout(label: "그림자 높이",
                    value: String(format: "%.2f m", shadowHeight))
            Readout(label: "그림자 길이 (바닥)",
                    value: String(format: "%.2f m", shadowLength))
        }
    }

    /// 광원 → 물체 꼭대기 직선이 스크린과 만나는 y 좌표 (= 그림자 윗변 높이).
    private var shadowHeight: Double {
        let dx = screenX - lampX
        let dxObj = objectX - lampX
        guard abs(dxObj) > 1e-6 else { return 0 }
        let topY = objectBaseY + objectHeight
        // y(x) = lampY + (topY − lampY) · (x − lampX) / (objectX − lampX)
        return lampY + (topY - lampY) * dx / dxObj
    }

    /// 그림자가 바닥(y=0)으로 드리울 때, 광원-물체-바닥 그림자 끝의 닮음으로 계산.
    /// 광원이 물체 위 (lampY > 0) 이면 그림자가 바닥에 생긴다.
    private var shadowLength: Double {
        guard lampY > objectBaseY else { return 0 }
        let topY = objectBaseY + objectHeight
        // 광원 → 물체 꼭대기 직선이 y=0 과 만나는 x.
        // y(x) = 0  →  x = lampX − lampY · (objectX − lampX) / (topY − lampY)
        // (topY − lampY 가 음수일 수 있으니 분기)
        let denom = topY - lampY
        if abs(denom) < 1e-6 { return 0 }
        let x0 = lampX - lampY * (objectX - lampX) / denom
        return max(0, x0 - objectX)
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let world = CGRect(x: -7, y: -1, width: 14, height: 5)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 바닥.
        var ground = Path()
        ground.move(to: map.point(x: -7, y: 0))
        ground.addLine(to: map.point(x: 7, y: 0))
        ctx.stroke(ground, with: .color(.white.opacity(0.4)), lineWidth: 1)

        // 스크린 (수직).
        var screen = Path()
        screen.move(to: map.point(x: screenX, y: 0))
        screen.addLine(to: map.point(x: screenX, y: 4))
        ctx.stroke(screen, with: .color(.white.opacity(0.7)), lineWidth: 2)

        // 광선 (광원 → 물체 꼭대기 → 스크린).
        let lamp = Vec2(x: lampX, y: lampY)
        let tip  = Vec2(x: objectX, y: objectBaseY + objectHeight)
        let screenY = shadowHeight
        let bottomShadow = Vec2(x: objectX + shadowLength, y: 0)
        // 그림자 영역.
        if shadowHeight > 0 || shadowLength > 0 {
            var shade = Path()
            shade.move(to: map.point(x: objectX, y: 0))
            shade.addLine(to: map.point(x: objectX, y: objectBaseY + objectHeight))
            shade.addLine(to: map.point(x: screenX, y: max(0, screenY)))
            shade.addLine(to: map.point(x: screenX, y: 0))
            shade.closeSubpath()
            ctx.fill(shade, with: .color(.black.opacity(0.55)))
        }
        // 광선들.
        var ray1 = Path()
        ray1.move(to: map.point(lamp))
        ray1.addLine(to: map.point(x: screenX,
                                   y: lampY + (0 - lampY) * (screenX - lampX) / max(0.001, objectX - lampX)))
        ctx.stroke(ray1, with: .color(.yellow.opacity(0.45)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        var ray2 = Path()
        ray2.move(to: map.point(lamp))
        ray2.addLine(to: map.point(tip))
        ray2.addLine(to: map.point(x: screenX, y: screenY))
        ctx.stroke(ray2, with: .color(.yellow), lineWidth: 1.4)

        // 광원.
        let lp = map.point(lamp)
        let rl: CGFloat = 10
        ctx.fill(Path(ellipseIn: CGRect(x: lp.x - rl, y: lp.y - rl,
                                        width: rl * 2, height: rl * 2)),
                 with: .color(.yellow))

        // 물체.
        let halfW = 0.25
        let objRect = CGRect(
            x: map.point(x: objectX - halfW, y: objectBaseY + objectHeight).x,
            y: map.point(x: 0, y: objectBaseY + objectHeight).y,
            width: map.length(2 * halfW),
            height: map.length(objectHeight))
        ctx.fill(Path(objRect), with: .color(.brown))

        // 바닥 그림자 길이 표시.
        if shadowLength > 0 {
            var lengthLine = Path()
            lengthLine.move(to: map.point(x: objectX, y: -0.15))
            lengthLine.addLine(to: map.point(bottomShadow + Vec2(x: 0, y: -0.15)))
            ctx.stroke(lengthLine, with: .color(.white.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
    }
}

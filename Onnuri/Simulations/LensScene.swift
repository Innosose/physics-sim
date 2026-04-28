import SwiftUI

/// 얇은 렌즈 결상 — 1/p + 1/q = 1/f.
///
/// 광축은 +x. 렌즈는 x = 0. 물체는 x < 0 (p>0 가 물체-렌즈 거리), 상은 부호에 따라 ±x.
/// 세 개의 주요 광선:
///  ① 광축에 평행 → 통과 후 후초점 F'(f, 0) 통과
///  ② 렌즈 중심 통과 → 직진
///  ③ 전초점 F(-f, 0) 통과 → 통과 후 광축에 평행
struct LensScene: View {
    @State private var focalLength: Double = 2.0    // m. 음수 가능 (오목렌즈).
    @State private var objectDist: Double = 5.0     // p (>0)
    @State private var objectHeight: Double = 1.0   // h_o
    @State private var diverging: Bool = false      // toggle for f<0

    var body: some View {
        SimChrome(
                  blurb: "p > f → 실상(뒤집힘). p < f → 허상(똑바로). 발산 렌즈는 항상 허상.",
                  canvas: { canvas },
                  controls: { controls })
    }

    private var f: Double { diverging ? -abs(focalLength) : abs(focalLength) }
    private var q: Double {
        // 1/p + 1/q = 1/f  →  q = pf / (p − f).  p == f → 무한대.
        let denom = objectDist - f
        if abs(denom) < 1e-6 { return .infinity * (denom >= 0 ? 1 : -1) }
        return objectDist * f / denom
    }
    private var imageHeight: Double { -q / objectDist * objectHeight }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("발산 렌즈 (f < 0)", isOn: $diverging)
            LabeledSlider(title: "초점거리 |f|", value: $focalLength, range: 0.5...6,
                          format: "%.2f", unit: "m")
            LabeledSlider(title: "물체 거리 p", value: $objectDist, range: 0.3...10,
                          format: "%.2f", unit: "m")
            LabeledSlider(title: "물체 높이 h_o", value: $objectHeight, range: 0.2...2.5,
                          format: "%.2f", unit: "m")
            Divider()
            Readout(label: "초점거리 f (부호 포함)",
                    value: String(format: "%+.2f m", f))
            Readout(label: "상거리 q",
                    value: q.isFinite ? String(format: "%+.2f m", q) : "∞")
            Readout(label: "배율 m = -q/p",
                    value: q.isFinite ? String(format: "%+.2f", -q / objectDist) : "−∞")
            Readout(label: "상 높이 h_i",
                    value: imageHeight.isFinite ? String(format: "%+.2f m", imageHeight) : "−")
            Text(q.isFinite ? (q > 0 ? "실상 (뒤집힘)" : "허상 (똑바로 섬)") : "초점에 위치 — 평행광")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        // 가로 길이 동적: max(p, |q|, |f|) 두 배 정도.
        let span = max(8.0, max(objectDist, q.isFinite ? abs(q) : objectDist) * 1.6)
        let height = max(3.0, max(abs(objectHeight), abs(imageHeight.isFinite ? imageHeight : 0)) * 2.4)
        let world = CGRect(x: -span, y: -height / 2, width: 2 * span, height: height)
        let map = CanvasMap(view: size, world: world, padding: 16)

        // 광축.
        var axis = Path()
        axis.move(to: map.point(x: -span, y: 0))
        axis.addLine(to: map.point(x:  span, y: 0))
        ctx.stroke(axis, with: .color(.white.opacity(0.4)), lineWidth: 1)

        // 렌즈 (수직선 + 화살표 머리).
        let lensTop = map.point(x: 0, y:  height / 2.5)
        let lensBot = map.point(x: 0, y: -height / 2.5)
        var lens = Path()
        lens.move(to: lensTop); lens.addLine(to: lensBot)
        ctx.stroke(lens, with: .color(.cyan), lineWidth: 2)
        // 렌즈 형태 표시.
        let arrowLen: CGFloat = 8
        let convex: [(CGPoint, CGPoint)] = [
            (CGPoint(x: lensTop.x - arrowLen, y: lensTop.y + arrowLen), lensTop),
            (CGPoint(x: lensTop.x + arrowLen, y: lensTop.y + arrowLen), lensTop),
            (CGPoint(x: lensBot.x - arrowLen, y: lensBot.y - arrowLen), lensBot),
            (CGPoint(x: lensBot.x + arrowLen, y: lensBot.y - arrowLen), lensBot),
        ]
        let concave: [(CGPoint, CGPoint)] = [
            (CGPoint(x: lensTop.x - arrowLen, y: lensTop.y - arrowLen), lensTop),
            (CGPoint(x: lensTop.x + arrowLen, y: lensTop.y - arrowLen), lensTop),
            (CGPoint(x: lensBot.x - arrowLen, y: lensBot.y + arrowLen), lensBot),
            (CGPoint(x: lensBot.x + arrowLen, y: lensBot.y + arrowLen), lensBot),
        ]
        for (a, b) in (diverging ? concave : convex) {
            var p = Path(); p.move(to: a); p.addLine(to: b)
            ctx.stroke(p, with: .color(.cyan), lineWidth: 2)
        }

        // 초점.
        for s in [-1.0, 1.0] {
            let pt = map.point(x: s * abs(f), y: 0)
            let r: CGFloat = 3
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                            width: r * 2, height: r * 2)),
                     with: .color(.orange))
            ctx.draw(Text(s < 0 ? "F" : "F′").font(.caption2)
                        .foregroundStyle(.orange),
                     at: CGPoint(x: pt.x, y: pt.y + 12))
        }

        // 물체 화살표 (왼쪽에).
        let objBase = Vec2(x: -objectDist, y: 0)
        let objTip  = Vec2(x: -objectDist, y: objectHeight)
        drawArrow(ctx: ctx, map: map, from: objBase, to: objTip, color: .yellow)

        // 세 광선.
        let pTip = objTip
        let lensY = objectHeight    // 광축 평행 광선이 렌즈와 만나는 높이
        // 광선 ①: tip → (0, h_o) → 굴절 후 후초점 F' 통과
        drawRay(ctx: ctx, map: map,
                points: [pTip,
                         Vec2(x: 0, y: lensY),
                         pointAfterRefraction(throughLensAt: lensY, slope: -lensY / f)])
        // 광선 ②: tip → 원점 직진
        drawRay(ctx: ctx, map: map,
                points: [pTip,
                         Vec2(x: 0, y: 0),
                         Vec2(x: span, y: -objectHeight * span / objectDist)])
        // 광선 ③: 굴절 후 광축에 평행이 되는 광선.
        // 얇은 렌즈 굴절식 m_after = m_before − y_lens / f, m_after = 0 일 조건.
        // 입사광선 직선식 (y_lens − h_o)/p = m_before = y_lens/f
        //   ⇒ y_lens = −f·h_o / (p − f).  수렴·발산 모두에 동일.
        let denom = objectDist - f
        let yLens3 = abs(denom) > 1e-6 ? -f * objectHeight / denom : 0.0
        drawRay(ctx: ctx, map: map,
                points: [pTip,
                         Vec2(x: 0, y: yLens3),
                         Vec2(x: span, y: yLens3)])

        // 상 화살표.
        if q.isFinite {
            let imgBase = Vec2(x: q, y: 0)
            let imgTip  = Vec2(x: q, y: imageHeight)
            let realImage = q > 0
            drawArrow(ctx: ctx, map: map, from: imgBase, to: imgTip,
                      color: realImage ? .green : .gray, dashed: !realImage)
        }
    }

    private func pointAfterRefraction(throughLensAt yLens: Double, slope: Double) -> Vec2 {
        let span = max(8.0, max(objectDist, q.isFinite ? abs(q) : objectDist) * 1.6)
        return Vec2(x: span, y: yLens + slope * span)
    }

    private func drawRay(ctx: GraphicsContext, map: CanvasMap,
                         points: [Vec2]) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: map.point(points[0]))
        for p in points.dropFirst() { path.addLine(to: map.point(p)) }
        ctx.stroke(path, with: .color(.red.opacity(0.7)), lineWidth: 1.2)
    }

    private func drawArrow(ctx: GraphicsContext, map: CanvasMap,
                           from a: Vec2, to b: Vec2, color: Color, dashed: Bool = false) {
        var line = Path()
        line.move(to: map.point(a)); line.addLine(to: map.point(b))
        if dashed {
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
        } else {
            ctx.stroke(line, with: .color(color), lineWidth: 2)
        }
        // 화살촉.
        let dir = (b - a).normalized
        let perp = Vec2(x: -dir.y, y: dir.x)
        let h1 = b - dir * 0.18 + perp * 0.10
        let h2 = b - dir * 0.18 - perp * 0.10
        var head = Path()
        head.move(to: map.point(h1))
        head.addLine(to: map.point(b))
        head.addLine(to: map.point(h2))
        ctx.stroke(head, with: .color(color), lineWidth: 2)
    }
}

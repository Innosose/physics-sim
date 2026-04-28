import SwiftUI

/// 점전하들이 만드는 전기장 시각화.
///
/// E(p) = Σ k·qᵢ·(p − rᵢ) / |p − rᵢ|³
///
/// • 격자 위에 화살표(방향만, 색상=세기) 로 표시
/// • 양/음 전하 각각에서 출발하는 전기력선을 적분해 그림
struct ElectricFieldScene: View {
    @State private var charges: [Charge] = [
        Charge(pos: Vec2(x: -2, y: 0), q:  1.0),
        Charge(pos: Vec2(x:  2, y: 0), q: -1.0),
    ]
    @State private var showLines = true
    @State private var showArrows = true
    @State private var preset: Int = 0

    struct Charge: Identifiable {
        let id = UUID()
        var pos: Vec2
        var q: Double      // 부호 + 크기
    }

    var body: some View {
        SimChrome(
                  blurb: "양전하(빨강)에서 음전하(파랑)로 흐르는 전기력선. 격자 위 화살표는 그 점에서의 전기장 방향과 세기.",
                  canvas: { canvas },
                  controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("배치", selection: $preset) {
                Text("쌍극자").tag(0)
                Text("동부호 전하 두 개").tag(1)
                Text("사극자").tag(2)
                Text("3양 1음").tag(3)
            }
            .pickerStyle(.segmented)
            .onChange(of: preset) { _, p in applyPreset(p) }

            Toggle("전기력선", isOn: $showLines)
            Toggle("격자 화살표", isOn: $showArrows)

            Divider()
            ForEach(charges.indices, id: \.self) { i in
                HStack {
                    Text("q\(i + 1)")
                    Slider(value: Binding(
                        get: { charges[i].q },
                        set: { charges[i].q = $0 }), in: -2...2)
                    Text(String(format: "%+.2f", charges[i].q))
                        .font(.caption.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private func applyPreset(_ p: Int) {
        switch p {
        case 0: charges = [Charge(pos: Vec2(x: -2, y: 0), q:  1),
                           Charge(pos: Vec2(x:  2, y: 0), q: -1)]
        case 1: charges = [Charge(pos: Vec2(x: -2, y: 0), q:  1),
                           Charge(pos: Vec2(x:  2, y: 0), q:  1)]
        case 2: charges = [Charge(pos: Vec2(x: -2, y: -2), q:  1),
                           Charge(pos: Vec2(x:  2, y: -2), q: -1),
                           Charge(pos: Vec2(x:  2, y:  2), q:  1),
                           Charge(pos: Vec2(x: -2, y:  2), q: -1)]
        case 3: charges = [Charge(pos: Vec2(x: -3, y: 0),  q:  1),
                           Charge(pos: Vec2(x:  0, y: -2), q:  1),
                           Charge(pos: Vec2(x:  3, y: 0),  q:  1),
                           Charge(pos: Vec2(x:  0, y:  2), q: -2)]
        default: break
        }
    }

    // MARK: - 물리

    private func field(at p: Vec2) -> Vec2 {
        var e = Vec2.zero
        for c in charges {
            let d = p - c.pos
            let r2 = d.lengthSquared
            if r2 < 0.04 { continue }   // 전하 근방 발산 방지
            let r = sqrt(r2)
            e += d * (c.q / (r2 * r))
        }
        return e
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let world = CGRect(x: -7, y: -5, width: 14, height: 10)
        let map = CanvasMap(view: size, world: world, padding: 8)

        if showArrows { drawArrowGrid(ctx: ctx, map: map, world: world) }
        if showLines { drawFieldLines(ctx: ctx, map: map, world: world) }
        drawCharges(ctx: ctx, map: map)
    }

    private func drawArrowGrid(ctx: GraphicsContext, map: CanvasMap, world: CGRect) {
        let step: Double = 0.7
        var x = Double(world.minX)
        while x <= Double(world.maxX) {
            var y = Double(world.minY)
            while y <= Double(world.maxY) {
                let p = Vec2(x: x, y: y)
                let e = field(at: p)
                let mag = e.length
                if mag > 1e-3 {
                    let dir = e / mag
                    let len = 0.55
                    let a = p - dir * (len / 2)
                    let b = p + dir * (len / 2)
                    var arrow = Path()
                    arrow.move(to: map.point(a))
                    arrow.addLine(to: map.point(b))
                    let alpha = min(1.0, 0.15 + log(1 + mag) * 0.5)
                    ctx.stroke(arrow, with: .color(.white.opacity(alpha)), lineWidth: 1)
                }
                y += step
            }
            x += step
        }
    }

    private func drawFieldLines(ctx: GraphicsContext, map: CanvasMap, world: CGRect) {
        // 양전하에서 출발 → 정방향 적분.  음전하에서 출발 → 역방향.
        for c in charges where c.q != 0 {
            let nLines = max(8, min(24, Int(8 * abs(c.q))))
            for k in 0..<nLines {
                let theta = 2 * .pi * Double(k) / Double(nLines)
                let start = c.pos + Vec2(x: cos(theta), y: sin(theta)) * 0.18
                let path = streamline(from: start, sign: c.q > 0 ? 1.0 : -1.0,
                                      bounds: world, map: map)
                ctx.stroke(path, with: .color(c.q > 0 ? .red.opacity(0.6) : .blue.opacity(0.6)),
                           lineWidth: 1.1)
            }
        }
    }

    private func streamline(from start: Vec2, sign: Double,
                            bounds: CGRect, map: CanvasMap) -> Path {
        var p = start
        var path = Path()
        path.move(to: map.point(p))
        let h = 0.05
        let maxSteps = 800
        for _ in 0..<maxSteps {
            let e = field(at: p)
            let m = e.length
            if m < 1e-4 { break }
            let dir = e / m * sign
            // RK2.
            let mid = p + dir * (h / 2)
            let e2 = field(at: mid)
            let m2 = e2.length
            if m2 < 1e-4 { break }
            let d2 = e2 / m2 * sign
            p = p + d2 * h
            // 화면 밖이면 종료.
            if p.x < Double(bounds.minX) - 0.5 || p.x > Double(bounds.maxX) + 0.5
                || p.y < Double(bounds.minY) - 0.5 || p.y > Double(bounds.maxY) + 0.5 {
                path.addLine(to: map.point(p)); break
            }
            // 다른 전하에 너무 가까우면 종료.
            var hit = false
            for c in charges {
                if (p - c.pos).length < 0.18 { hit = true; break }
            }
            path.addLine(to: map.point(p))
            if hit { break }
        }
        return path
    }

    private func drawCharges(ctx: GraphicsContext, map: CanvasMap) {
        for c in charges {
            let pt = map.point(c.pos)
            let r: CGFloat = CGFloat(8 + 6 * abs(c.q))
            let color: Color = c.q > 0 ? .red : (c.q < 0 ? .blue : .gray)
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                            width: r * 2, height: r * 2)),
                     with: .color(color))
            ctx.draw(Text(c.q > 0 ? "+" : "−").font(.headline.bold()).foregroundColor(.white),
                     at: pt)
        }
    }
}

import SwiftUI

/// 두 사인파의 중첩 — 맥놀이와 정상파.
///
/// y₁ = A₁·sin(k₁·x − ω₁·t)
/// y₂ = A₂·sin(k₂·x ± ω₂·t)         (반대 부호 선택 시 정상파)
/// 합:  y = y₁ + y₂
struct WaveSumScene: View {
    @State private var A1: Double = 1.0
    @State private var f1: Double = 1.0
    @State private var A2: Double = 1.0
    @State private var f2: Double = 1.1
    @State private var k1: Double = 1.0
    @State private var k2: Double = 1.0
    @State private var oppose: Bool = false   // true 면 두 번째 파를 반대방향(정상파)
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
                  blurb: "두 진동수가 가까우면 맥놀이가, 같은 진동수의 반대방향 파끼리는 정상파가 만들어진다.",
                  canvas: { canvas },
                  controls: { controls })
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(startTime)
                draw(ctx: ctx, size: size, t: t)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "A₁", value: $A1, range: 0...1.5, format: "%.2f")
            LabeledSlider(title: "f₁", value: $f1, range: 0.1...4, format: "%.2f", unit: "Hz")
            LabeledSlider(title: "k₁", value: $k1, range: 0.2...4, format: "%.2f", unit: "rad/m")
            LabeledSlider(title: "A₂", value: $A2, range: 0...1.5, format: "%.2f")
            LabeledSlider(title: "f₂", value: $f2, range: 0.1...4, format: "%.2f", unit: "Hz")
            LabeledSlider(title: "k₂", value: $k2, range: 0.2...4, format: "%.2f", unit: "rad/m")
            Toggle("두 번째 파 반대 진행 (정상파)", isOn: $oppose)
            HStack {
                Button(running ? "일시정지" : "재생") { running.toggle() }
                Button("처음부터") { startTime = Date(); running = true }
            }
            Divider()
            Readout(label: "맥놀이 진동수 |f₁−f₂|",
                    value: String(format: "%.2f Hz", abs(f1 - f2)))
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        // 위 1/3: y₁, 가운데 1/3: y₂, 아래 1/3: 합.
        let h = size.height / 3
        drawWave(ctx: ctx, in: CGRect(x: 0, y: 0,    width: size.width, height: h),
                 amp: A1, k: k1, omega: 2 * .pi * f1, t: t, sign: 1,
                 color: .cyan.opacity(0.8), label: "y₁")
        drawWave(ctx: ctx, in: CGRect(x: 0, y: h,    width: size.width, height: h),
                 amp: A2, k: k2, omega: 2 * .pi * f2, t: t,
                 sign: oppose ? -1 : 1,
                 color: .pink.opacity(0.8), label: "y₂")
        drawSum(ctx: ctx, in: CGRect(x: 0, y: 2 * h, width: size.width, height: h),
                t: t)
    }

    private func drawWave(ctx: GraphicsContext, in r: CGRect,
                          amp: Double, k: Double, omega: Double,
                          t: Double, sign: Double,
                          color: Color, label: String) {
        var axis = Path()
        axis.move(to: CGPoint(x: r.minX, y: r.midY))
        axis.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        ctx.stroke(axis, with: .color(.white.opacity(0.2)), lineWidth: 1)

        var path = Path()
        let n = 400
        let amplitudePx = r.height * 0.4
        let xMax = 12.0   // m
        for i in 0...n {
            let f = Double(i) / Double(n)
            let x = f * xMax
            let y = amp * sin(k * x - sign * omega * t)
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amplitudePx / 1.5
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(color), lineWidth: 1.6)
        ctx.draw(Text(label).font(.caption).foregroundStyle(color),
                 at: CGPoint(x: r.minX + 18, y: r.minY + 14))
    }

    private func drawSum(ctx: GraphicsContext, in r: CGRect, t: Double) {
        var axis = Path()
        axis.move(to: CGPoint(x: r.minX, y: r.midY))
        axis.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        ctx.stroke(axis, with: .color(.white.opacity(0.25)), lineWidth: 1)

        var path = Path()
        let n = 600
        let xMax = 12.0
        let s2: Double = oppose ? -1 : 1
        let omega1 = 2 * .pi * f1
        let omega2 = 2 * .pi * f2
        let amplitudePx = r.height * 0.45
        for i in 0...n {
            let f = Double(i) / Double(n)
            let x = f * xMax
            let y1 = A1 * sin(k1 * x - omega1 * t)
            let y2 = A2 * sin(k2 * x - s2 * omega2 * t)
            let y = y1 + y2
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amplitudePx / 3
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(.yellow), lineWidth: 1.8)
        ctx.draw(Text("y₁ + y₂").font(.caption).foregroundStyle(.yellow),
                 at: CGPoint(x: r.minX + 30, y: r.minY + 14))
    }
}

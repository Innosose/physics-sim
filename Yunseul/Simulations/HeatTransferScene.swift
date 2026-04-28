import SwiftUI

/// 열전달과 평형 — 두 물체 직접 접촉.
///
///  m₁c₁ dT₁/dt = −h·A·(T₁ − T₂)
///  m₂c₂ dT₂/dt = +h·A·(T₁ − T₂)        (에너지 보존: 한쪽 잃은 만큼 다른쪽 얻음)
///
/// 평형 온도(분석해): T_eq = (m₁c₁·T₁ + m₂c₂·T₂) / (m₁c₁ + m₂c₂)
///
/// 두 ODE 는 부호 반대여서 (T₁ − T₂) 가 지수적으로 0 에 가까워진다:
///   τ = (m₁c₁·m₂c₂) / (h·A·(m₁c₁ + m₂c₂))
///   T₁(t) − T₂(t) = (T₁₀ − T₂₀) · exp(−t / τ)
///
/// 적분기는 정확한 해석해와 동일하게 떨어지도록 작은 dt 의 Euler 사용 + 대조군으로
/// 분석해를 점선으로 그림.
struct HeatTransferScene: View {
    @State private var T1: Double = 80     // °C
    @State private var T2: Double = 20
    @State private var capRatio: Double = 1.0   // m₂c₂ / m₁c₁
    @State private var hA: Double = 1.0
    @State private var running = true

    @State private var t1Cur: Double = 80
    @State private var t2Cur: Double = 20
    @State private var time: Double = 0
    @State private var lastTime: TimeInterval? = nil

    @State private var trace1: [Double] = []
    @State private var trace2: [Double] = []
    private let traceLen = 300

    var body: some View {
        SimChrome(
            blurb: "두 물체가 닿으면 따뜻한 쪽에서 차가운 쪽으로 열이 흘러 같아진다. 평형 온도는 (m·c) 가 큰 쪽으로 치우친다.",
            canvas: { canvas },
            controls: { controls })
    }

    private func onSliderEnd(_ editing: Bool) { if !editing { restart() } }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                advance(to: tl.date.timeIntervalSinceReferenceDate)
                draw(ctx: ctx, size: size)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "물체 1 처음 온도", value: $T1, range: 0...100,
                          format: "%.0f", unit: "°C", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "물체 2 처음 온도", value: $T2, range: 0...100,
                          format: "%.0f", unit: "°C", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "열용량 비 (m₂c₂)/(m₁c₁)",
                          value: $capRatio, range: 0.1...5,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "전달 계수 h·A", value: $hA, range: 0.1...5,
                          format: "%.2f")
            PlayResetBar(running: $running, onReset: restart)
            Divider()
            let Teq = (T1 + capRatio * T2) / (1 + capRatio)
            Readout(label: "평형 온도 T_eq",
                    value: String(format: "%.2f °C", Teq))
            Readout(label: "현재 T₁",
                    value: String(format: "%.2f °C", t1Cur))
            Readout(label: "현재 T₂",
                    value: String(format: "%.2f °C", t2Cur))
            // 시상수 τ. m₁c₁ = 1 단위, m₂c₂ = capRatio.
            let tau = capRatio / (hA * (1 + capRatio))
            Readout(label: "시상수 τ",
                    value: String(format: "%.2f", tau))
        }
    }

    // MARK: - 동역학

    private func restart() {
        t1Cur = T1; t2Cur = T2; time = 0
        trace1.removeAll(); trace2.removeAll()
        lastTime = nil
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTime else { lastTime = now; return }
        guard running else { lastTime = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTime = now
        let sub = max(1, Int((dt / 0.001).rounded()))
        let h = dt / Double(sub)
        for _ in 0..<sub {
            // m₁c₁ = 1 단위로 정규화.
            let flow = hA * (t1Cur - t2Cur)
            t1Cur += -flow * h
            t2Cur += +flow / capRatio * h
            time += h
        }
        trace1.append(t1Cur)
        trace2.append(t2Cur)
        if trace1.count > traceLen {
            trace1.removeFirst(trace1.count - traceLen)
            trace2.removeFirst(trace2.count - traceLen)
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.40)
        let botRect = CGRect(x: 0, y: topRect.maxY, width: size.width,
                             height: size.height - topRect.maxY)
        drawObjects(ctx: ctx, in: topRect)
        drawGraph(ctx: ctx, in: botRect)
    }

    private func drawObjects(ctx: GraphicsContext, in r: CGRect) {
        let w: CGFloat = 140
        let h: CGFloat = 100
        let center1 = CGPoint(x: r.midX - w * 0.55, y: r.midY)
        let center2 = CGPoint(x: r.midX + w * 0.55, y: r.midY)
        let r1 = CGRect(x: center1.x - w / 2, y: center1.y - h / 2, width: w, height: h)
        let r2 = CGRect(x: center2.x - w / 2, y: center2.y - h / 2, width: w, height: h)
        ctx.fill(Path(roundedRect: r1, cornerRadius: 12), with: .color(tempColor(t1Cur)))
        ctx.fill(Path(roundedRect: r2, cornerRadius: 12), with: .color(tempColor(t2Cur)))
        ctx.stroke(Path(roundedRect: r1, cornerRadius: 12), with: .color(.white.opacity(0.4)), lineWidth: 1)
        ctx.stroke(Path(roundedRect: r2, cornerRadius: 12), with: .color(.white.opacity(0.4)), lineWidth: 1)

        // 라벨.
        ctx.draw(Text(String(format: "T₁ = %.0f °C", t1Cur))
                    .font(.caption.weight(.bold)).foregroundColor(.black),
                 at: center1)
        ctx.draw(Text(String(format: "T₂ = %.0f °C", t2Cur))
                    .font(.caption.weight(.bold)).foregroundColor(.black),
                 at: center2)

        // 접촉부 빨간 화살표 (열 흐름).
        if abs(t1Cur - t2Cur) > 0.5 {
            let from = t1Cur > t2Cur ? r1.maxX : r2.minX
            let to   = t1Cur > t2Cur ? r2.minX : r1.maxX
            var arrow = Path()
            arrow.move(to: CGPoint(x: from, y: r.midY))
            arrow.addLine(to: CGPoint(x: to, y: r.midY))
            ctx.stroke(arrow, with: .color(.red), lineWidth: 3)
            // 화살촉.
            let dx: CGFloat = to > from ? -8 : 8
            var head = Path()
            head.move(to: CGPoint(x: to + dx, y: r.midY - 6))
            head.addLine(to: CGPoint(x: to, y: r.midY))
            head.addLine(to: CGPoint(x: to + dx, y: r.midY + 6))
            ctx.stroke(head, with: .color(.red), lineWidth: 3)
        }
    }

    private func drawGraph(ctx: GraphicsContext, in r: CGRect) {
        ctx.draw(Text("온도–시간").font(.caption.weight(.semibold)).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 40, y: r.minY + 12))
        let inner = r.insetBy(dx: 12, dy: 24)
        ctx.stroke(Path(roundedRect: inner, cornerRadius: 8),
                   with: .color(.white.opacity(0.18)), lineWidth: 1)
        guard !trace1.isEmpty else { return }
        let lo = min(0.0, trace1.min() ?? 0, trace2.min() ?? 0)
        let hi = max(100.0, trace1.max() ?? 100, trace2.max() ?? 100)
        let n = trace1.count
        let stepX = inner.width / CGFloat(max(1, traceLen - 1))

        // 평형 온도 점선.
        let Teq = (T1 + capRatio * T2) / (1 + capRatio)
        let yEq = inner.maxY - 6 - CGFloat((Teq - lo) / (hi - lo)) * (inner.height - 12)
        var eqLine = Path()
        eqLine.move(to: CGPoint(x: inner.minX + 4, y: yEq))
        eqLine.addLine(to: CGPoint(x: inner.maxX - 4, y: yEq))
        ctx.stroke(eqLine, with: .color(.white.opacity(0.4)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        var p1 = Path(), p2 = Path()
        for i in 0..<n {
            let f = CGFloat(i) * stepX
            let x = inner.minX + 6 + f
            let y1 = inner.maxY - 6 - CGFloat((trace1[i] - lo) / (hi - lo)) * (inner.height - 12)
            let y2 = inner.maxY - 6 - CGFloat((trace2[i] - lo) / (hi - lo)) * (inner.height - 12)
            if i == 0 { p1.move(to: CGPoint(x: x, y: y1)); p2.move(to: CGPoint(x: x, y: y2)) }
            else { p1.addLine(to: CGPoint(x: x, y: y1)); p2.addLine(to: CGPoint(x: x, y: y2)) }
        }
        ctx.stroke(p1, with: .color(.red), lineWidth: 1.6)
        ctx.stroke(p2, with: .color(.cyan), lineWidth: 1.6)
    }

    private func tempColor(_ T: Double) -> Color {
        // 0..100 °C → 파랑..빨강 색상보간.
        let t = max(0, min(1, T / 100))
        return Color(hue: (1 - t) * 0.6, saturation: 0.85, brightness: 1)
    }
}

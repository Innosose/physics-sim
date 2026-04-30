import SwiftUI

/// 열전달과 평형 — 두 물체 직접 접촉. **닫힌 해 (analytical)**.
///
/// 운동방정식:
///   m₁c₁ dT₁/dt = −h·A·(T₁ − T₂)
///   m₂c₂ dT₂/dt = +h·A·(T₁ − T₂)
///
/// 합·차로 분해하면 차 (T₁ − T₂) 는 1계 선형 ODE 라 닫힌 해를 가진다:
///
///   T_eq = (m₁c₁·T₁₀ + m₂c₂·T₂₀) / (m₁c₁ + m₂c₂)            (보존)
///   τ    = (m₁c₁·m₂c₂) / (h·A·(m₁c₁ + m₂c₂))                (시상수)
///   T₁(t) = T_eq + (T₁₀ − T_eq) · exp(−t / τ)
///   T₂(t) = T_eq + (T₂₀ − T_eq) · exp(−t / τ)
///
/// 적분기 없음 — 시간 t 가 주어지면 위 식으로 직접 계산.
struct HeatTransferScene: View {
    @State private var T1: Double = 80      // °C — 초기 온도 1
    @State private var T2: Double = 20      // °C — 초기 온도 2
    @State private var capRatio: Double = 1 // m₂c₂ / m₁c₁
    @State private var hA: Double = 1       // h·A (전달 계수)
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
            blurb: "두 물체가 닿으면 따뜻한 쪽에서 차가운 쪽으로 열이 흘러 같아진다. 평형 온도는 (m·c) 가 큰 쪽으로 치우치고, 차이는 시상수 τ 로 지수적으로 0 에 가까워진다.",
            canvas: { canvas },
            controls: { controls })
    }

    /// 슬라이더 손 떼면 시작 시간 리셋 — 새 매개변수로 처음부터.
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
            LabeledSlider(title: "물체 1 처음 온도", value: $T1, range: 0...100,
                          format: "%.2f", unit: "°C", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "물체 2 처음 온도", value: $T2, range: 0...100,
                          format: "%.2f", unit: "°C", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "열용량 비 (m₂c₂)/(m₁c₁)",
                          value: $capRatio, range: 0.1...5,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            LabeledSlider(title: "전달 계수 h·A", value: $hA, range: 0.1...5,
                          format: "%.2f", onEditingChanged: onSliderEnd)
            PlayResetBar(running: $running,
                         onReset: { startTime = Date() },
                         resetLabel: "처음부터")
        }
    }

    // MARK: - 닫힌 해

    /// 평형 온도. m₁c₁ = 1 단위로 정규화.
    private var Teq: Double { (T1 + capRatio * T2) / (1 + capRatio) }

    /// 시상수.
    private var tau: Double { capRatio / (hA * (1 + capRatio)) }

    /// 시각 t 에서의 두 물체 온도 — 분석해.
    private func state(at t: Double) -> (T1: Double, T2: Double) {
        let f = exp(-t / tau)
        return (T1: Teq + (T1 - Teq) * f,
                T2: Teq + (T2 - Teq) * f)
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.40)
        let botRect = CGRect(x: 0, y: topRect.maxY, width: size.width,
                             height: size.height - topRect.maxY)
        let s = state(at: t)
        drawObjects(ctx: ctx, in: topRect, T1Now: s.T1, T2Now: s.T2)
        drawGraph(ctx: ctx, in: botRect, tNow: t)
    }

    private func drawObjects(ctx: GraphicsContext, in r: CGRect,
                             T1Now: Double, T2Now: Double) {
        let w: CGFloat = 140
        let h: CGFloat = 100
        let center1 = CGPoint(x: r.midX - w * 0.55, y: r.midY)
        let center2 = CGPoint(x: r.midX + w * 0.55, y: r.midY)
        let r1 = CGRect(x: center1.x - w / 2, y: center1.y - h / 2, width: w, height: h)
        let r2 = CGRect(x: center2.x - w / 2, y: center2.y - h / 2, width: w, height: h)
        ctx.fill(Path(roundedRect: r1, cornerRadius: 12), with: .color(tempColor(T1Now)))
        ctx.fill(Path(roundedRect: r2, cornerRadius: 12), with: .color(tempColor(T2Now)))
        ctx.stroke(Path(roundedRect: r1, cornerRadius: 12), with: .color(.white.opacity(0.4)), lineWidth: 1)
        ctx.stroke(Path(roundedRect: r2, cornerRadius: 12), with: .color(.white.opacity(0.4)), lineWidth: 1)

        // 라벨.
        ctx.draw(Text(String(format: "T₁ = %.0f °C", T1Now))
                    .font(.caption.weight(.bold)).foregroundColor(.black),
                 at: center1)
        ctx.draw(Text(String(format: "T₂ = %.0f °C", T2Now))
                    .font(.caption.weight(.bold)).foregroundColor(.black),
                 at: center2)

        // 접촉부 화살표.
        if abs(T1Now - T2Now) > 0.5 {
            let from = T1Now > T2Now ? r1.maxX : r2.minX
            let to   = T1Now > T2Now ? r2.minX : r1.maxX
            var arrow = Path()
            arrow.move(to: CGPoint(x: from, y: r.midY))
            arrow.addLine(to: CGPoint(x: to, y: r.midY))
            ctx.stroke(arrow, with: .color(.red), lineWidth: 3)
            let dx: CGFloat = to > from ? -8 : 8
            var head = Path()
            head.move(to: CGPoint(x: to + dx, y: r.midY - 6))
            head.addLine(to: CGPoint(x: to, y: r.midY))
            head.addLine(to: CGPoint(x: to + dx, y: r.midY + 6))
            ctx.stroke(head, with: .color(.red), lineWidth: 3)
        }
    }

    private func drawGraph(ctx: GraphicsContext, in r: CGRect, tNow: Double) {
        ctx.draw(Text("온도–시간 (분석해)").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 70, y: r.minY + 12))
        let inner = r.insetBy(dx: 12, dy: 24)
        ctx.stroke(Path(roundedRect: inner, cornerRadius: 8),
                   with: .color(.white.opacity(0.18)), lineWidth: 1)

        // 시간 범위: τ 의 약 6배 정도가 보이게.
        let tEnd = max(2 * tau, tNow * 1.1, 0.5)
        let lo = min(0.0, T1, T2)
        let hi = max(100.0, T1, T2)

        // 평형 점선.
        let yEq = inner.maxY - 6 - CGFloat((Teq - lo) / (hi - lo)) * (inner.height - 12)
        var eqLine = Path()
        eqLine.move(to: CGPoint(x: inner.minX + 4, y: yEq))
        eqLine.addLine(to: CGPoint(x: inner.maxX - 4, y: yEq))
        ctx.stroke(eqLine, with: .color(.white.opacity(0.4)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // T₁(t), T₂(t) 곡선 — 분석해를 직접 점 샘플링.
        var p1 = Path(), p2 = Path()
        let n = 200
        for i in 0...n {
            let f = Double(i) / Double(n)
            let t = f * tEnd
            let s = state(at: t)
            let px = inner.minX + 4 + CGFloat(f) * (inner.width - 8)
            let py1 = inner.maxY - 6 - CGFloat((s.T1 - lo) / (hi - lo)) * (inner.height - 12)
            let py2 = inner.maxY - 6 - CGFloat((s.T2 - lo) / (hi - lo)) * (inner.height - 12)
            if i == 0 {
                p1.move(to: CGPoint(x: px, y: py1)); p2.move(to: CGPoint(x: px, y: py2))
            } else {
                p1.addLine(to: CGPoint(x: px, y: py1)); p2.addLine(to: CGPoint(x: px, y: py2))
            }
        }
        ctx.stroke(p1, with: .color(.red),  lineWidth: 1.6)
        ctx.stroke(p2, with: .color(.cyan), lineWidth: 1.6)

        // 현재 시각 마커.
        let f = CGFloat(min(tNow, tEnd) / tEnd)
        let xNow = inner.minX + 4 + f * (inner.width - 8)
        var line = Path()
        line.move(to: CGPoint(x: xNow, y: inner.minY + 4))
        line.addLine(to: CGPoint(x: xNow, y: inner.maxY - 4))
        ctx.stroke(line, with: .color(Theme.glow.opacity(0.7)), lineWidth: 1)
    }

    private func tempColor(_ T: Double) -> Color {
        let t = max(0, min(1, T / 100))
        return Color(hue: (1 - t) * 0.6, saturation: 0.85, brightness: 1)
    }
}

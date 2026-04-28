import SwiftUI

/// 직렬·병렬 회로 — 옴의 법칙으로 전류·전압을 정확히 계산.
///
///  직렬:  R_eq = R₁ + R₂,        I = V / R_eq,   V_k = I·R_k
///  병렬:  1/R_eq = 1/R₁ + 1/R₂,  I = V / R_eq,   I_k = V / R_k
struct CircuitScene: View {
    enum Mode: String, CaseIterable, Identifiable {
        case series = "직렬", parallel = "병렬"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .series
    @State private var emf: Double = 12.0
    @State private var R1: Double  = 4.0
    @State private var R2: Double  = 6.0

    var body: some View {
        SimChrome(
            blurb: "직렬 연결에서는 전류가 같고 전압이 나뉜다. 병렬에서는 전압이 같고 전류가 나뉜다.",
            canvas: { canvas },
            controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("연결 방식", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            LabeledSlider(title: "기전력 V", value: $emf, range: 1...30,
                          format: "%.2f", unit: "V")
            LabeledSlider(title: "저항 R₁", value: $R1, range: 0.5...30,
                          format: "%.2f", unit: "Ω")
            LabeledSlider(title: "저항 R₂", value: $R2, range: 0.5...30,
                          format: "%.2f", unit: "Ω")
            Divider()
            let r = result
            Readout(label: "합성 저항 R_eq",
                    value: String(format: "%.2f Ω", r.Req))
            Readout(label: "전체 전류 I",
                    value: String(format: "%.2f A", r.I))
            Readout(label: mode == .series ? "R₁ 양단 전압" : "R₁ 전류",
                    value: mode == .series
                        ? String(format: "%.2f V", r.q1)
                        : String(format: "%.2f A", r.q1))
            Readout(label: mode == .series ? "R₂ 양단 전압" : "R₂ 전류",
                    value: mode == .series
                        ? String(format: "%.2f V", r.q2)
                        : String(format: "%.2f A", r.q2))
            Readout(label: "총 전력 P = VI",
                    value: String(format: "%.2f W", emf * r.I))
        }
    }

    private var result: (Req: Double, I: Double, q1: Double, q2: Double) {
        switch mode {
        case .series:
            let Req = R1 + R2
            let I = emf / Req
            return (Req, I, I * R1, I * R2)
        case .parallel:
            let Req = (R1 * R2) / (R1 + R2)
            let I = emf / Req
            return (Req, I, emf / R1, emf / R2)
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let r = CGRect(origin: .zero, size: size).insetBy(dx: 30, dy: 40)
        switch mode {
        case .series:   drawSeries(ctx: ctx, in: r)
        case .parallel: drawParallel(ctx: ctx, in: r)
        }
        // 배터리 (모든 모드에서 좌측에).
    }

    private func drawSeries(ctx: GraphicsContext, in r: CGRect) {
        // 사각 회로: 좌상 → 우상 → 우하 → 좌하.
        let lt = CGPoint(x: r.minX, y: r.minY)
        let rt = CGPoint(x: r.maxX, y: r.minY)
        let rb = CGPoint(x: r.maxX, y: r.maxY)
        let lb = CGPoint(x: r.minX, y: r.maxY)

        // 배터리: 좌측 변 가운데.
        drawBattery(ctx: ctx, at: CGPoint(x: lt.x, y: r.midY), vertical: true,
                    voltage: emf)

        // 윗변 = 저항 R1.
        let r1Center = CGPoint(x: r.midX - 60, y: lt.y)
        drawWire(ctx: ctx, from: CGPoint(x: lt.x, y: lt.y),
                 to: r1Center.offsetBy(dx: -40))
        drawResistor(ctx: ctx, at: r1Center, vertical: false,
                     label: "R₁ = \(short(R1)) Ω")
        drawWire(ctx: ctx, from: r1Center.offsetBy(dx: 40), to: rt)

        // 우측 변 → 우하.
        drawWire(ctx: ctx, from: rt, to: rb)
        // 아랫변 = 저항 R2.
        let r2Center = CGPoint(x: r.midX, y: rb.y)
        drawWire(ctx: ctx, from: rb, to: r2Center.offsetBy(dx: 40))
        drawResistor(ctx: ctx, at: r2Center, vertical: false,
                     label: "R₂ = \(short(R2)) Ω")
        drawWire(ctx: ctx, from: r2Center.offsetBy(dx: -40), to: lb)
        // 좌측 변 (배터리 아래쪽).
        drawWire(ctx: ctx, from: lb, to: CGPoint(x: lt.x, y: r.midY + 30))

        // 전류 화살표.
        drawCurrentLabel(ctx: ctx,
                         at: CGPoint(x: r.maxX - 30, y: r.midY),
                         text: String(format: "I = %.2f A", result.I))
    }

    private func drawParallel(ctx: GraphicsContext, in r: CGRect) {
        // 직사각형 두 가지가 위/아래로 갈라짐.
        let lt = CGPoint(x: r.minX, y: r.minY + 20)
        let lb = CGPoint(x: r.minX, y: r.maxY - 20)
        // 배터리는 좌측 가운데.
        drawBattery(ctx: ctx, at: CGPoint(x: lt.x, y: r.midY), vertical: true,
                    voltage: emf)

        // 좌측 분기점.
        let nodeL = CGPoint(x: r.minX + 80, y: r.midY)
        drawWire(ctx: ctx, from: CGPoint(x: lt.x, y: r.midY - 30), to: lt)
        drawWire(ctx: ctx, from: lt, to: CGPoint(x: nodeL.x, y: lt.y))
        drawWire(ctx: ctx, from: lb, to: CGPoint(x: nodeL.x, y: lb.y))
        drawWire(ctx: ctx, from: lb, to: CGPoint(x: lt.x, y: r.midY + 30))

        // 우측 분기점.
        let nodeR = CGPoint(x: r.maxX - 30, y: r.midY)
        drawWire(ctx: ctx, from: CGPoint(x: nodeL.x, y: lt.y),
                 to: CGPoint(x: nodeR.x, y: lt.y))
        drawWire(ctx: ctx, from: CGPoint(x: nodeL.x, y: lb.y),
                 to: CGPoint(x: nodeR.x, y: lb.y))
        // 우측 합쳐지는 부분.
        drawWire(ctx: ctx, from: CGPoint(x: nodeR.x, y: lt.y), to: nodeR)
        drawWire(ctx: ctx, from: CGPoint(x: nodeR.x, y: lb.y), to: nodeR)

        // R1 위 가지, R2 아래 가지.
        drawResistor(ctx: ctx, at: CGPoint(x: (nodeL.x + nodeR.x) / 2, y: lt.y),
                     vertical: false,
                     label: "R₁ = \(short(R1))Ω,  I₁=\(short(result.q1))A")
        drawResistor(ctx: ctx, at: CGPoint(x: (nodeL.x + nodeR.x) / 2, y: lb.y),
                     vertical: false,
                     label: "R₂ = \(short(R2))Ω,  I₂=\(short(result.q2))A")

        drawCurrentLabel(ctx: ctx,
                         at: CGPoint(x: nodeR.x - 30, y: r.midY - 14),
                         text: String(format: "I = %.2f A", result.I))
    }

    // MARK: - 그리기 보조

    private func drawWire(ctx: GraphicsContext, from a: CGPoint, to b: CGPoint) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(.white.opacity(0.85)), lineWidth: 2)
    }

    private func drawResistor(ctx: GraphicsContext, at c: CGPoint,
                              vertical: Bool, label: String) {
        let w: CGFloat = 80, h: CGFloat = 26
        let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 6),
                 with: .color(.orange.opacity(0.85)))
        ctx.stroke(Path(roundedRect: rect, cornerRadius: 6),
                   with: .color(.white.opacity(0.5)), lineWidth: 1)
        _ = vertical
        ctx.draw(Text(label).font(.caption.weight(.semibold)).foregroundColor(.white),
                 at: CGPoint(x: c.x, y: c.y + h / 2 + 12))
    }

    private func drawBattery(ctx: GraphicsContext, at c: CGPoint, vertical: Bool,
                             voltage: Double) {
        // 단순화된 기호 — 두 평행한 선.
        let h: CGFloat = 20
        if vertical {
            var long = Path()
            long.move(to: CGPoint(x: c.x - 14, y: c.y - h))
            long.addLine(to: CGPoint(x: c.x + 14, y: c.y - h))
            ctx.stroke(long, with: .color(.white), lineWidth: 3)
            var short = Path()
            short.move(to: CGPoint(x: c.x - 8, y: c.y + h))
            short.addLine(to: CGPoint(x: c.x + 8, y: c.y + h))
            ctx.stroke(short, with: .color(.white), lineWidth: 2)
        }
        ctx.draw(Text(String(format: "%.2f V", voltage))
                    .font(.caption.weight(.semibold)).foregroundStyle(.cyan),
                 at: CGPoint(x: c.x + 24, y: c.y))
    }

    private func drawCurrentLabel(ctx: GraphicsContext, at c: CGPoint, text: String) {
        ctx.draw(Text(text).font(.caption.weight(.bold)).foregroundStyle(.green),
                 at: c)
    }

    private func short(_ v: Double) -> String { String(format: "%.2f", v) }
}

private extension CGPoint {
    func offsetBy(dx: CGFloat = 0, dy: CGFloat = 0) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}

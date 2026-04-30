import SwiftUI

struct CircuitViewport: View {
    let scene: Preset.CircuitScene

    var body: some View {
        ZStack {
            Color.black
            switch scene {
            case .circuit: SimpleCircuitView()
            case .rlc:     RLCView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct SimpleCircuitView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case series = "직렬", parallel = "병렬"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .series
    @State private var emf: Double = 12
    @State private var R1: Double = 4
    @State private var R2: Double = 6

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            VStack(alignment: .leading, spacing: 8) {
                Picker("연결", selection: $mode) {
                    ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                slider("V", value: $emf, range: 1...30, unit: "V")
                slider("R₁", value: $R1, range: 0.5...30, unit: "Ω")
                slider("R₂", value: $R2, range: 0.5...30, unit: "Ω")
            }
        }
        .padding(8)
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            Slider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let r = CGRect(origin: .zero, size: size).insetBy(dx: 30, dy: 30)
        let lt = CGPoint(x: r.minX, y: r.minY)
        let rt = CGPoint(x: r.maxX, y: r.minY)
        let rb = CGPoint(x: r.maxX, y: r.maxY)
        let lb = CGPoint(x: r.minX, y: r.maxY)
        let mid = CGPoint(x: r.minX, y: r.midY)

        var b1 = Path(); b1.move(to: CGPoint(x: lt.x - 14, y: r.midY - 14)); b1.addLine(to: CGPoint(x: lt.x + 14, y: r.midY - 14))
        ctx.stroke(b1, with: .color(.white), lineWidth: 3)
        var b2 = Path(); b2.move(to: CGPoint(x: lt.x - 8, y: r.midY + 14)); b2.addLine(to: CGPoint(x: lt.x + 8, y: r.midY + 14))
        ctx.stroke(b2, with: .color(.white), lineWidth: 2)

        var wires = Path()
        wires.move(to: lt); wires.addLine(to: rt); wires.addLine(to: rb); wires.addLine(to: lb)
        wires.move(to: lt); wires.addLine(to: CGPoint(x: lt.x, y: r.midY - 30))
        wires.move(to: lb); wires.addLine(to: CGPoint(x: lb.x, y: r.midY + 30))
        ctx.stroke(wires, with: .color(.white.opacity(0.85)), lineWidth: 2)

        let r1Pos = CGPoint(x: r.midX - 60, y: lt.y)
        let r2Pos: CGPoint = mode == .series
            ? CGPoint(x: r.midX, y: rb.y)
            : CGPoint(x: r.midX, y: lt.y + 40)
        drawResistor(ctx, at: r1Pos, label: String(format: "R₁=%.2fΩ", R1))
        drawResistor(ctx, at: r2Pos, label: String(format: "R₂=%.2fΩ", R2))

        let req: Double, I: Double
        switch mode {
        case .series:   req = R1 + R2; I = emf / req
        case .parallel: req = (R1 * R2) / (R1 + R2); I = emf / req
        }
        ctx.draw(Text(String(format: "R_eq = %.2f Ω    I = %.2f A    P = %.2f W",
                              req, I, emf * I))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green),
                 at: CGPoint(x: r.midX, y: r.maxY + 18))
    }

    private func drawResistor(_ ctx: GraphicsContext, at c: CGPoint, label: String) {
        let w: CGFloat = 60, h: CGFloat = 22
        let rect = CGRect(x: c.x - w/2, y: c.y - h/2, width: w, height: h)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 6),
                 with: .color(.orange.opacity(0.85)))
        ctx.stroke(Path(roundedRect: rect, cornerRadius: 6),
                   with: .color(.white.opacity(0.5)), lineWidth: 1)
        ctx.draw(Text(label).font(.caption2.weight(.semibold)).foregroundColor(.white),
                 at: CGPoint(x: c.x, y: c.y + h / 2 + 10))
    }
}

private struct RLCView: View {
    @State private var R: Double = 5
    @State private var L: Double = 0.5
    @State private var C: Double = 0.005
    @State private var V0: Double = 10
    @State private var omega: Double = 20

    private var omega0: Double { 1 / (L * C).squareRoot() }

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx: ctx, size: size) }
            VStack(alignment: .leading, spacing: 8) {
                slider("R", value: $R, range: 0.1...30, unit: "Ω")
                slider("L", value: $L, range: 0.05...3, unit: "H")
                slider("C", value: $C, range: 0.0005...0.05, unit: "F")
                slider("V₀", value: $V0, range: 0.1...30, unit: "V")
                slider("ω", value: $omega, range: 0.5...100, unit: "rad/s")
            }
        }
        .padding(8)
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            Slider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {

        let r = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16)
        let omegaMax = max(omega * 1.4, omega0 * 2.5)
        var path = Path()
        let n = 200
        var maxInv = 0.001
        var samples: [Double] = []
        for k in 0...n {
            let w = omegaMax * Double(k) / Double(n)
            let XL = w * L, XC = w > 1e-6 ? 1 / (w * C) : 1e9
            let Z = (R * R + (XL - XC) * (XL - XC)).squareRoot()
            let inv = 1 / max(0.001, Z)
            samples.append(inv); maxInv = max(maxInv, inv)
        }
        for (k, inv) in samples.enumerated() {
            let f = CGFloat(k) / CGFloat(n)
            let px = r.minX + f * r.width
            let py = r.maxY - CGFloat(inv / maxInv) * (r.height - 20)
            if k == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(.orange), lineWidth: 1.6)

        let xω = r.minX + CGFloat(min(omega, omegaMax) / omegaMax) * r.width
        var line = Path()
        line.move(to: CGPoint(x: xω, y: r.minY))
        line.addLine(to: CGPoint(x: xω, y: r.maxY))
        ctx.stroke(line, with: .color(.red.opacity(0.7)), lineWidth: 1)
        ctx.draw(Text("1/|Z(ω)| — 공명 위치 ω₀=\(String(format: "%.2f", omega0))")
                    .font(.caption).foregroundStyle(.secondary),
                 at: CGPoint(x: r.minX + 80, y: r.minY + 12))
    }
}

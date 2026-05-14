import SwiftUI

// MARK: - Deterministic RNG so a given geometry sketches the same way each frame.

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    static func from(_ values: Double...) -> SeededGenerator {
        var s: UInt64 = 0x9E3779B97F4A7C15
        for v in values {
            let bits: UInt64 = v.isFinite ? v.bitPattern : 0
            s ^= bits
            s = s &* 0x100000001B3
        }
        return SeededGenerator(s)
    }
}

// MARK: - Sketchy drawing primitives for GraphicsContext.

enum Sketchy {
    /// Hand-drawn-ish line: jittered samples, 1–3 overlapping passes.
    /// `dash` applies an on/off pattern in points (CGFloat values), or nil
    /// for a continuous stroke.
    static func line(from a: CGPoint, to b: CGPoint, ctx: GraphicsContext,
                     color: Color,
                     lineWidth: CGFloat = 1.4,
                     passes: Int = 2,
                     jitter: CGFloat = 1.1,
                     dash: [CGFloat]? = nil) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0.5 else { return }
        let nx = -dy / len, ny = dx / len
        var rng = SeededGenerator.from(Double(a.x), Double(a.y),
                                       Double(b.x), Double(b.y))
        let samples = max(2, Int(len / 14))
        for _ in 0..<passes {
            var path = Path()
            let ox = CGFloat.random(in: -jitter * 0.3...jitter * 0.3, using: &rng)
            let oy = CGFloat.random(in: -jitter * 0.3...jitter * 0.3, using: &rng)
            path.move(to: CGPoint(x: a.x + ox, y: a.y + oy))
            for i in 1...samples {
                let t = CGFloat(i) / CGFloat(samples)
                let env = sin(.pi * Double(t)) * Double(jitter)
                let j = CGFloat.random(in: -1...1, using: &rng) * CGFloat(env)
                let x = a.x + dx * t + nx * j
                let y = a.y + dy * t + ny * j
                path.addLine(to: CGPoint(x: x, y: y))
            }
            let w = lineWidth * CGFloat.random(in: 0.85...1.18, using: &rng)
            let op = Double.random(in: 0.62...0.95, using: &rng)
            let style = (dash != nil)
                ? StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round, dash: dash!)
                : StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
            ctx.stroke(path, with: .color(color.opacity(op)), style: style)
        }
    }

    /// Hand-drawn circle outline. `jitter` is relative to radius.
    static func circle(center: CGPoint, radius: CGFloat,
                       ctx: GraphicsContext, color: Color,
                       lineWidth: CGFloat = 1.4,
                       passes: Int = 2,
                       jitter: CGFloat = 0.035) {
        guard radius > 0.5 else { return }
        var rng = SeededGenerator.from(Double(center.x), Double(center.y),
                                       Double(radius))
        let n = max(24, Int(radius * 1.4))
        for _ in 0..<passes {
            var path = Path()
            let startAngle = Double.random(in: -0.4...0.4, using: &rng)
            let endExtra = Double.random(in: 0.1...0.5, using: &rng)
            for i in 0...n {
                let t = Double(i) / Double(n)
                let angle = startAngle + t * (2 * .pi + endExtra)
                let jr = 1 + CGFloat.random(in: -jitter...jitter, using: &rng)
                let r = radius * jr
                let x = center.x + r * CGFloat(cos(angle))
                let y = center.y + r * CGFloat(sin(angle))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else      { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            let w = lineWidth * CGFloat.random(in: 0.85...1.15, using: &rng)
            let op = Double.random(in: 0.62...0.92, using: &rng)
            ctx.stroke(path, with: .color(color.opacity(op)),
                       style: StrokeStyle(lineWidth: w,
                                          lineCap: .round, lineJoin: .round))
        }
    }

    /// Filled circle (body) with a sketchy outline.
    static func fillCircle(center: CGPoint, radius: CGFloat,
                            ctx: GraphicsContext,
                            fill: Color, stroke: Color,
                            strokeWidth: CGFloat = 1.2) {
        guard radius > 0.5 else { return }
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                        width: radius * 2, height: radius * 2)),
                 with: .color(fill.opacity(0.85)))
        circle(center: center, radius: radius, ctx: ctx,
               color: stroke, lineWidth: strokeWidth, passes: 2, jitter: 0.025)
    }

    /// Hand-drawn rectangle outline (4 sketchy lines).
    static func rect(_ r: CGRect, ctx: GraphicsContext, color: Color,
                     lineWidth: CGFloat = 1.4, passes: Int = 1,
                     jitter: CGFloat = 1.0) {
        let corners = [
            CGPoint(x: r.minX, y: r.minY),
            CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX, y: r.maxY),
            CGPoint(x: r.minX, y: r.maxY),
        ]
        for i in 0..<4 {
            line(from: corners[i], to: corners[(i + 1) % 4], ctx: ctx,
                 color: color, lineWidth: lineWidth, passes: passes, jitter: jitter)
        }
    }

    /// A sequence of points joined by sketchy line segments (a single polyline).
    static func polyline(_ pts: [CGPoint], ctx: GraphicsContext,
                         color: Color,
                         lineWidth: CGFloat = 1.4,
                         passes: Int = 1,
                         jitter: CGFloat = 0.6) {
        guard pts.count >= 2 else { return }
        for i in 1..<pts.count {
            line(from: pts[i - 1], to: pts[i], ctx: ctx,
                 color: color, lineWidth: lineWidth, passes: passes, jitter: jitter)
        }
    }

    /// Clean (non-sketchy) stroke — for cases where jitter would obscure data
    /// (e.g. measured curves on a graph panel).
    static func smooth(_ path: Path, ctx: GraphicsContext,
                       color: Color, lineWidth: CGFloat = 1.2,
                       opacity: Double = 0.9) {
        ctx.stroke(path, with: .color(color.opacity(opacity)),
                   style: StrokeStyle(lineWidth: lineWidth,
                                      lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Sketch-styled button (replacement for .glass / .glassProminent).

struct SketchButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        let bg = prominent ? tint.opacity(0.92) : Theme.surface.opacity(0.6)
        let fg = prominent ? Theme.surface : tint
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(shape.fill(bg))
            .overlay(
                shape.stroke(
                    tint.opacity(pressed ? 0.95 : 0.7),
                    style: StrokeStyle(lineWidth: pressed ? 1.5 : 1.2)
                )
            )
            .foregroundStyle(fg)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .opacity(pressed ? 0.88 : 1.0)
            .animation(.spring(duration: 0.18), value: pressed)
    }
}

extension ButtonStyle where Self == SketchButtonStyle {
    static var sketch: SketchButtonStyle { SketchButtonStyle(prominent: false) }
    static var sketchProminent: SketchButtonStyle { SketchButtonStyle(prominent: true) }
}

// MARK: - Chip press style — visual feedback for .plain chip buttons.

struct ChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ChipPressStyle {
    static var chipPress: ChipPressStyle { ChipPressStyle() }
}

// MARK: - PaperSlider — sketchy ink-on-paper slider.

struct PaperSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var height: CGFloat = 28

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 1e-12 else { return 0 }
        return max(0, min(1, (value - range.lowerBound) / span))
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let leftPad: CGFloat = 6, rightPad: CGFloat = 6
                let usable = max(1, size.width - leftPad - rightPad)
                let midY = size.height / 2
                let handleX = leftPad + usable * CGFloat(fraction)

                Sketchy.line(from: CGPoint(x: leftPad, y: midY),
                              to: CGPoint(x: size.width - rightPad, y: midY),
                              ctx: ctx, color: Theme.ink.opacity(0.6),
                              lineWidth: 1.2, passes: 1, jitter: 0.25)
                if handleX > leftPad + 1 {
                    Sketchy.line(from: CGPoint(x: leftPad, y: midY),
                                  to: CGPoint(x: handleX, y: midY),
                                  ctx: ctx, color: Theme.glow,
                                  lineWidth: 2.2, passes: 2, jitter: 0.22)
                }
                Sketchy.fillCircle(center: CGPoint(x: handleX, y: midY), radius: 8,
                                    ctx: ctx, fill: Theme.surface,
                                    stroke: Theme.ink, strokeWidth: 1.4)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let leftPad: CGFloat = 6, rightPad: CGFloat = 6
                        let usable = max(1, geo.size.width - leftPad - rightPad)
                        let t = max(0, min(1, (g.location.x - leftPad) / usable))
                        let span = range.upperBound - range.lowerBound
                        value = range.lowerBound + Double(t) * span
                    }
            )
        }
        .frame(height: height)
    }
}

// MARK: - PaperPicker — segmented picker styled as a paper card.

struct PaperPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                let isActive = selection == opt
                Button {
                    withAnimation(.spring(duration: 0.18)) { selection = opt }
                } label: {
                    Text(label(opt))
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(isActive ? Theme.surface : Theme.ink)
                        .background(isActive
                                    ? Theme.ink.opacity(0.9)
                                    : Color.clear)
                }
                .buttonStyle(.chipPress)
                if idx < options.count - 1 {
                    Rectangle()
                        .fill(Theme.ink.opacity(0.45))
                        .frame(width: 1)
                }
            }
        }
        .background(Theme.surface.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.ink.opacity(0.65), lineWidth: 1.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

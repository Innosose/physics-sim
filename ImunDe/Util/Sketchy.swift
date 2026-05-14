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

// MARK: - Modern flat button styles.

struct SketchButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let bg: Color     = prominent ? Theme.ink : Theme.surface
        let fg: Color     = prominent ? Theme.surface : Theme.ink
        let border: Color = prominent ? Color.clear : Theme.stroke
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(shape.fill(bg))
            .overlay(shape.stroke(border, lineWidth: 1))
            .foregroundStyle(fg)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .opacity(pressed ? 0.82 : 1.0)
            .animation(.spring(duration: 0.15), value: pressed)
    }
}

extension ButtonStyle where Self == SketchButtonStyle {
    static var sketch: SketchButtonStyle { SketchButtonStyle(prominent: false) }
    static var sketchProminent: SketchButtonStyle { SketchButtonStyle(prominent: true) }
}

// MARK: - Animatable sketchy shapes (for .trim-based draw-in).

struct SketchyLineShape: Shape {
    var jitter: CGFloat = 0.5
    var seed: UInt64 = 0xCAFEBABE
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var rng = SeededGenerator(seed)
        let samples = max(6, Int(rect.width / 5))
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY))
        for i in 1...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let env = sin(.pi * Double(t)) * Double(jitter)
            let dy = CGFloat.random(in: -1...1, using: &rng) * CGFloat(env)
            path.addLine(to: CGPoint(x: rect.minX + rect.width * t,
                                     y: midY + dy))
        }
        return path
    }
}

struct SketchyCircleShape: Shape {
    var jitter: CGFloat = 0.025
    var seed: UInt64 = 0xDEADBEEF
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var rng = SeededGenerator(seed)
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let n = max(28, Int(r * 1.4))
        let startAngle = Double.random(in: -0.2...0.2, using: &rng)
        for i in 0...n {
            let t = Double(i) / Double(n)
            let angle = startAngle + t * 2 * .pi
            let jr = 1 + CGFloat.random(in: -jitter...jitter, using: &rng)
            let rr = r * jr
            let p = CGPoint(x: c.x + rr * CGFloat(cos(angle)),
                            y: c.y + rr * CGFloat(sin(angle)))
            if i == 0 { path.move(to: p) }
            else      { path.addLine(to: p) }
        }
        return path
    }
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

// MARK: - PaperSlider — clean modern slider.

struct PaperSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var height: CGFloat = 28

    init(value: Binding<Double>, in range: ClosedRange<Double>, height: CGFloat = 28) {
        self._value = value
        self.range = range
        self.height = height
    }

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 1e-12 else { return 0 }
        return max(0, min(1, (value - range.lowerBound) / span))
    }

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = 11
            let usable = max(1, geo.size.width - pad * 2)
            let handleX = pad + usable * CGFloat(fraction)
            let midY = height / 2
            let trackH: CGFloat = 3

            ZStack(alignment: .leading) {
                // Full track
                Capsule()
                    .fill(Theme.ink.opacity(0.10))
                    .frame(height: trackH)
                    .padding(.horizontal, pad)

                // Filled portion
                Capsule()
                    .fill(Theme.glow)
                    .frame(width: max(trackH, handleX), height: trackH)
                    .padding(.leading, pad)

                // Handle knob
                Circle()
                    .fill(Theme.surface)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Theme.ink.opacity(0.22), lineWidth: 1))
                    .shadow(color: Theme.ink.opacity(0.10), radius: 3, x: 0, y: 1)
                    .offset(x: handleX - 11)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let t = max(0, min(1, (g.location.x - pad) / usable))
                        let span = range.upperBound - range.lowerBound
                        value = range.lowerBound + Double(t) * span
                    }
            )
        }
        .frame(height: height)
    }
}

// MARK: - PaperPicker — clean modern segmented control.

struct PaperPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    @Environment(\.isEnabled) private var isEnabled
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { opt in
                let isActive = selection == opt
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = opt
                    }
                } label: {
                    Text(label(opt))
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(isActive ? Theme.surface : Theme.mist)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.ink)
                                    .matchedGeometryEffect(id: "pill", in: pillNS)
                            }
                        }
                }
                .buttonStyle(.chipPress)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.crest.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.55)
    }
}

// MARK: - ChipToggle — shared chip-style on/off control.

struct ChipToggle: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    var alignment: Alignment = .center
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Theme.surface : Theme.mist)
                .frame(maxWidth: .infinity, alignment: alignment)
                .padding(.vertical, alignment == .leading ? 7 : 6)
                .padding(.horizontal, alignment == .leading ? 10 : 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Theme.ink : Theme.crest.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isOn ? Color.clear : Theme.stroke, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.chipPress)
        .animation(.smooth(duration: 0.2), value: isOn)
    }
}

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

// MARK: - Drawing primitives for GraphicsContext.
//
// Charcoal feel: thick confident strokes (weight multiplier) + grain
// overlay rendered separately via `CharcoalGrain`. `passes` and `jitter`
// parameters are accepted for API compatibility but ignored.

enum Sketchy {
    /// Universal stroke weight multiplier — gives all simulation lines
    /// a charcoal-like presence without touching every call site.
    static let weight: CGFloat = 1.45

    static func line(from a: CGPoint, to b: CGPoint, ctx: GraphicsContext,
                     color: Color,
                     lineWidth: CGFloat = 1.4,
                     passes: Int = 2,
                     jitter: CGFloat = 1.1,
                     dash: [CGFloat]? = nil) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        let w = lineWidth * weight
        let style = (dash != nil)
            ? StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round, dash: dash!)
            : StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
        ctx.stroke(path, with: .color(color), style: style)
    }

    static func circle(center: CGPoint, radius: CGFloat,
                       ctx: GraphicsContext, color: Color,
                       lineWidth: CGFloat = 1.4,
                       passes: Int = 2,
                       jitter: CGFloat = 0.035) {
        guard radius > 0.5 else { return }
        let path = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2))
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: lineWidth * weight,
                                      lineCap: .round, lineJoin: .round))
    }

    static func fillCircle(center: CGPoint, radius: CGFloat,
                            ctx: GraphicsContext,
                            fill: Color, stroke: Color,
                            strokeWidth: CGFloat = 1.2) {
        guard radius > 0.5 else { return }
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(fill))
        ctx.stroke(Path(ellipseIn: rect), with: .color(stroke),
                   style: StrokeStyle(lineWidth: strokeWidth * weight,
                                      lineCap: .round, lineJoin: .round))
    }

    static func rect(_ r: CGRect, ctx: GraphicsContext, color: Color,
                     lineWidth: CGFloat = 1.4, passes: Int = 1,
                     jitter: CGFloat = 1.0) {
        ctx.stroke(Path(r), with: .color(color),
                   style: StrokeStyle(lineWidth: lineWidth * weight,
                                      lineCap: .round, lineJoin: .round))
    }

    static func polyline(_ pts: [CGPoint], ctx: GraphicsContext,
                         color: Color,
                         lineWidth: CGFloat = 1.4,
                         passes: Int = 1,
                         jitter: CGFloat = 0.6) {
        guard pts.count >= 2 else { return }
        var path = Path()
        path.move(to: pts[0])
        for i in 1..<pts.count {
            path.addLine(to: pts[i])
        }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: lineWidth * weight,
                                      lineCap: .round, lineJoin: .round))
    }

    /// Clean stroke — for graph curves where data shouldn't be exaggerated.
    static func smooth(_ path: Path, ctx: GraphicsContext,
                       color: Color, lineWidth: CGFloat = 1.2,
                       opacity: Double = 0.9) {
        ctx.stroke(path, with: .color(color.opacity(opacity)),
                   style: StrokeStyle(lineWidth: lineWidth,
                                      lineCap: .round, lineJoin: .round))
    }
}

// MARK: - CharcoalGrain — paper grain overlay for simulation canvases.

struct CharcoalGrain: View {
    var density: Double = 0.0012     // dots per pixel
    var seed: UInt64 = 0xC0FFEE_C0FFEE
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        _ = colorScheme  // body-level read so SwiftUI invalidates Canvas
        return Canvas { ctx, size in
            var rng = SeededGenerator(seed
                ^ UInt64(size.width.bitPattern)
                ^ UInt64(size.height.bitPattern))
            let count = max(20, Int(size.width * size.height * density))
            for _ in 0..<count {
                let x = CGFloat.random(in: 0..<size.width, using: &rng)
                let y = CGFloat.random(in: 0..<size.height, using: &rng)
                let r = CGFloat.random(in: 0.25...0.75, using: &rng)
                let op = Double.random(in: 0.05...0.16, using: &rng)
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: x - r, y: y - r,
                        width: r * 2, height: r * 2)),
                    with: .color(Theme.ink.opacity(op)))
            }
        }
        .allowsHitTesting(false)
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

// MARK: - EditableValue — tap-to-edit numeric label with range clamping.

/// Displays a numeric value formatted via `format`. Tapping reveals an
/// inline TextField; submitting parses the input, clamps to `range`,
/// and writes back through the binding. Useful next to PaperSlider so
/// users can either drag for coarse adjustment or type for exact values.
struct EditableValue: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// printf-style format applied to `value`, e.g. `"%.2f m"`.
    let format: String
    var width: CGFloat = 64

    @State private var draft: String = ""
    @State private var editing: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                TextField("", text: $draft)
                    .keyboardType(range.lowerBound < 0
                                  ? .numbersAndPunctuation : .decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { commit() }
                    .onChange(of: focused) { _, f in if !f { commit() } }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Theme.glow, lineWidth: 1)
                    )
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("완료") { focused = false }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
            } else {
                Text(String(format: format, value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditing() }
            }
        }
        .frame(width: width, alignment: .trailing)
    }

    private func startEditing() {
        draft = editableFormat(value)
        editing = true
        DispatchQueue.main.async { focused = true }
    }

    private func editableFormat(_ v: Double) -> String {
        // Plain number, no unit, reasonable precision.
        if abs(v) >= 100 {
            return String(format: "%.0f", v)
        } else if abs(v) >= 10 {
            return String(format: "%.2f", v)
        } else if abs(v) >= 0.1 {
            return String(format: "%.3f", v)
        } else {
            return String(format: "%.4g", v)
        }
    }

    private func commit() {
        let cleaned = draft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if let n = Double(cleaned), n.isFinite {
            value = min(max(n, range.lowerBound), range.upperBound)
        }
        // (invalid input is silently rejected — original value preserved)
        editing = false
        focused = false
    }
}

// MARK: - PaperSlider — clean modern slider.

struct PaperSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var height: CGFloat = 24

    init(value: Binding<Double>, in range: ClosedRange<Double>, height: CGFloat = 24) {
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

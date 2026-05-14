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

/// 옛날 코드: 매 프레임 600개의 `Path(ellipseIn:)` 생성 + 600회 ctx.fill
/// — 가장 비용 큰 hot path. 새 코드: size-키 캐시 — opacity 3 단계로
/// 버킷화 후 path 미리 만들어 두고 매 프레임 3번 fill 만 수행. ~200배 감소.
struct CharcoalGrain: View {
    var density: Double = 0.0012     // dots per pixel
    var seed: UInt64 = 0xC0FFEE_C0FFEE
    @Environment(\.colorScheme) private var colorScheme
    @State private var cachedSize: CGSize = .zero
    @State private var cachedPaths: [(opacity: Double, path: Path)] = []

    var body: some View {
        let _ = colorScheme
        Canvas { ctx, _ in
            for entry in cachedPaths {
                ctx.fill(entry.path, with: .color(Theme.ink.opacity(entry.opacity)))
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
            if newSize != cachedSize, newSize.width > 0, newSize.height > 0 {
                cachedSize = newSize
                cachedPaths = generatePaths(size: newSize)
            }
        }
        .allowsHitTesting(false)
    }

    private func generatePaths(size: CGSize) -> [(opacity: Double, path: Path)] {
        var rng = SeededGenerator(seed
            ^ UInt64(size.width.bitPattern)
            ^ UInt64(size.height.bitPattern))
        let count = max(20, Int(size.width * size.height * density))
        // 3 opacity buckets — visual variation 보존하면서 fill 호출은 3번만.
        var bucket1 = Path(), bucket2 = Path(), bucket3 = Path()
        for _ in 0..<count {
            let x = CGFloat.random(in: 0..<size.width, using: &rng)
            let y = CGFloat.random(in: 0..<size.height, using: &rng)
            let r = CGFloat.random(in: 0.25...0.75, using: &rng)
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            switch Int.random(in: 0..<3, using: &rng) {
            case 0:  bucket1.addEllipse(in: rect)
            case 1:  bucket2.addEllipse(in: rect)
            default: bucket3.addEllipse(in: rect)
            }
        }
        return [
            (0.06, bucket1),
            (0.10, bucket2),
            (0.14, bucket3),
        ]
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
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 12)        // 32 → 44pt 충족용 V padding ↑
            .frame(minHeight: 44)          // HIG 44pt 보강
            .background(shape.fill(bg))
            .overlay(shape.stroke(border, lineWidth: 1))
            .foregroundStyle(fg)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .opacity(pressed ? 0.82 : 1.0)
            .animation(Motion.press, value: pressed)
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
            .animation(Motion.press, value: configuration.isPressed)
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

    private var displayed: String { String(format: format, value) }

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
                Text(displayed)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditing() }
            }
        }
        .frame(width: width, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("값"))
        .accessibilityValue(Text(displayed))
        .accessibilityHint(Text("두 번 탭하여 편집"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { direction in
            let span = range.upperBound - range.lowerBound
            let step = span / 20
            let delta = (direction == .increment) ? step : -step
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            // Touch target — 44pt hit area per HIG. Visual stays at `height`
            // (default 24pt) but the drag-receiving area extends to 44pt
            // vertically via padded contentShape.
            .frame(height: height)
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Rectangle())
            .padding(.vertical, -max(0, (44 - height) / 2))
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
        // Custom slider doesn't auto-expose value to VoiceOver / Switch
        // Control — wire the standard semantics so AX users can adjust.
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - PaperPicker — clean modern segmented control.

struct PaperPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { opt in
                let isActive = selection == opt
                Button {
                    let anim: Animation? = reduceMotion ? nil : Motion.slide
                    withAnimation(anim) { selection = opt }
                } label: {
                    Text(label(opt))
                        .font(.system(.footnote, design: .default)
                                .weight(isActive ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 32)
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
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Theme.crest.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// On 상태 표시는 색만이 아니라 leading 아이콘도 — 색맹 사용자가
    /// 켜짐/꺼짐을 식별할 수 있도록.
    private var effectiveIcon: String {
        isOn ? "checkmark.circle.fill" : systemImage
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: effectiveIcon)
                .font(.system(.footnote, design: .default)
                        .weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Theme.surface : Theme.mist)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: alignment)
                .padding(.vertical, alignment == .leading ? 7 : 6)
                .padding(.horizontal, alignment == .leading ? 10 : 4)
                .background(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .fill(isOn ? Theme.ink : Theme.crest.opacity(0.5))
                )
                // 색맹 / 모노크롬용 보강 — On 상태에서도 옅은 stroke 유지
                // (색상만이 아니라 outline 변화로도 구분됨).
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .stroke(isOn ? Theme.ink.opacity(0.25) : Theme.stroke, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.chipPress)
        .animation(reduceMotion ? nil : Motion.toggle, value: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(isOn ? "켜짐" : "꺼짐"))
    }
}

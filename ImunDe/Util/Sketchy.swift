import SwiftUI

// MARK: - Drawing primitives for GraphicsContext.
//
// Clean engineering look: hairline-to-thin strokes, no grain overlay.
// `passes` and `jitter` parameters are kept for API compatibility but
// ignored — the earlier charcoal-feel weight multiplier (1.45) read as
// "kid's drawing app" rather than "physics simulator" for the high-school
// study audience; the pro-tool reference frame (Desmos, GeoGebra, COMSOL)
// uses 1.0× consistently.

enum Sketchy {
    /// Universal stroke weight multiplier — neutral by default. Per-call
    /// `lineWidth` carries the design intent.
    static let weight: CGFloat = 1.0

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

    /// 화살표 — shaft + 머리 양쪽 day. Mechanics2D 벡터/룰러/E-field 에서 공용.
    /// shaft 가 너무 짧으면 (~< 6px) head 만 stray dash 처럼 보이므로 생략.
    static func arrow(from a: CGPoint, to b: CGPoint, ctx: GraphicsContext,
                      color: Color, lineWidth: CGFloat = 1.5,
                      dashed: Bool = false) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 1.5 else { return }
        Sketchy.line(from: a, to: b, ctx: ctx, color: color,
                     lineWidth: lineWidth, passes: 1, jitter: 0.5,
                     dash: dashed ? [4, 3] : nil)
        guard len >= 6 else { return }
        let nx = dx / len, ny = dy / len
        let s = min(CGFloat(9), len * 0.5)
        let h1 = CGPoint(x: b.x - nx * s - ny * s * 0.45,
                         y: b.y - ny * s + nx * s * 0.45)
        let h2 = CGPoint(x: b.x - nx * s + ny * s * 0.45,
                         y: b.y - ny * s - nx * s * 0.45)
        Sketchy.line(from: b, to: h1, ctx: ctx, color: color,
                     lineWidth: lineWidth, passes: 1, jitter: 0.3)
        Sketchy.line(from: b, to: h2, ctx: ctx, color: color,
                     lineWidth: lineWidth, passes: 1, jitter: 0.3)
    }

    /// 화살표 머리만 (shaft 없이) — E-field 곡선 끝점 표시.
    static func arrowhead(from a: CGPoint, to b: CGPoint, ctx: GraphicsContext,
                          color: Color, size: CGFloat = 5) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0.001 else { return }
        let nx = dx / len, ny = dy / len
        let h1 = CGPoint(x: b.x - nx * size - ny * size * 0.5,
                         y: b.y - ny * size + nx * size * 0.5)
        let h2 = CGPoint(x: b.x - nx * size + ny * size * 0.5,
                         y: b.y - ny * size - nx * size * 0.5)
        Sketchy.line(from: b, to: h1, ctx: ctx, color: color,
                     lineWidth: 1.2, passes: 1, jitter: 0.2)
        Sketchy.line(from: b, to: h2, ctx: ctx, color: color,
                     lineWidth: 1.2, passes: 1, jitter: 0.2)
    }
}

// MARK: - Modern flat button styles.

struct SketchButtonStyle: ButtonStyle {
    var prominent: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .animation(reduceMotion ? nil : Motion.press, value: pressed)
    }
}

extension ButtonStyle where Self == SketchButtonStyle {
    static var sketch: SketchButtonStyle { SketchButtonStyle(prominent: false) }
    static var sketchProminent: SketchButtonStyle { SketchButtonStyle(prominent: true) }
}

// MARK: - Chip press style — visual feedback for .plain chip buttons.

struct ChipPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(reduceMotion ? nil : Motion.press, value: configuration.isPressed)
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
                    .frame(width: 26, height: 26)
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
                        .frame(maxWidth: .infinity, minHeight: 36)
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
    /// `false` 일 때 intrinsic 너비 — horizontal ScrollView 안에서 사용.
    /// 기본 `true` 로 HStack 등분 충전 동작 유지.
    var fillHorizontally: Bool = true
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
                .lineLimit(1)
                .minimumScaleFactor(0.85)  // 한글 wrap 방지 (Dynamic Type XL+)
                .frame(maxWidth: fillHorizontally ? .infinity : nil,
                       minHeight: 44, alignment: alignment)
                .padding(.vertical, alignment == .leading ? 7 : 6)
                .padding(.horizontal, alignment == .leading ? 10 : 10)
                .background(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .fill(isOn ? Theme.ink : Theme.crest.opacity(0.5))
                )
                // ON 상태에만 옅은 stroke 유지 (색맹/모노크롬용 a11y 보강).
                // OFF 상태는 Theme.crest fill 이 이미 분리하므로 stroke 불필요.
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .stroke(isOn ? Theme.ink.opacity(0.25) : Color.clear, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.chipPress)
        .animation(reduceMotion ? nil : Motion.toggle, value: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(isOn ? "켜짐" : "꺼짐"))
    }
}

// MARK: - LabeledSlider — title + slider + editable value
//
// 5개 viewport 에 같은 helper (slider/fSlider/sSlider/paramSlider) 가
// 중복 정의되어 있던 것을 통합. unit 으로 지정하면 "%.2f<unit>" 자동 조합,
// format 으로 직접 printf 문자열을 넘길 수도 있음 (Mechanics2D paramSlider
// 케이스).

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit: String = ""
    var format: String? = nil
    var width: CGFloat = 70

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
         unit: String = "", format: String? = nil, width: CGFloat = 70) {
        self.title = title
        self._value = value
        self.range = range
        self.unit = unit
        self.format = format
        self.width = width
    }

    private var resolvedFormat: String {
        format ?? "%.2f\(unit)"
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 96, alignment: .leading)
            PaperSlider(value: $value, in: range)
            EditableValue(value: $value, range: range,
                           format: resolvedFormat, width: width)
        }
    }
}

// MARK: - TransportButtons — play/pause + reset 한 쌍
//
// Wave/Graph/Circuit (Faraday) 4개 viewport 의 동일 패턴을 통합.
// Mechanics2DViewport 는 GlassEffectContainer 기반 별도 디자인 유지.

struct TransportButtons: View {
    let running: Bool
    let toggle: () -> Void
    let reset:  () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Button(action: toggle) {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketchProminent)
            .accessibilityLabel(Text(running ? "일시정지" : "재생"))

            Button(action: reset) {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketch)
            .accessibilityLabel(Text("처음부터"))
        }
    }
}

// MARK: - ViewportFrame — 5개 viewport 의 공통 chrome (둥근 사각형 마스킹)
//
// 옛 1pt Theme.stroke 보더는 제거 — Theme.deep (canvas) vs Theme.void (page)
// 톤 단차로 이미 분리됨. iOS 26 HIG Liquid Glass / Toss / Desmos / Algodoo
// 모두 "stroke 보다 톤+여백 우선" 컨벤션. 또한 bounded sim 의 world.bounds
// 벽 사각형과 외곽 chrome 이 이중-사각형으로 충돌하던 시각적 혼동 해소.

struct ViewportFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: Radius.viewport, style: .continuous))
    }
}

extension View {
    func viewportFrame() -> some View { modifier(ViewportFrame()) }
}

import SwiftUI

struct WorldScene: View {
    let preset: Preset

    var body: some View {
        ZStack {
            ImunDeBackground()
            VStack(spacing: 10) {
                if preset.formula != nil {
                    ConceptCard(preset: preset)
                }
                viewport
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .navigationTitle(preset.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var viewport: some View {
        switch preset.kind {
        case .mechanics2D:
            Mechanics2DViewport(preset: preset)
        case .optics(let scene):
            OpticsViewport(scene: scene)
        case .wave(let scene):
            WaveViewport(scene: scene)
        case .circuit(let scene):
            CircuitViewport(scene: scene)
        case .graph:
            GraphViewport(preset: preset)
        }
    }
}

// MARK: - ConceptCard

struct ConceptCard: View {
    let preset: Preset
    @State private var expanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(preset.curriculumLabel ?? "")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.mist)
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.glowText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded, let formula = preset.formula {
                Text(AttributedString.formula(formula, baseSize: 15))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .lineSpacing(6)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(Theme.deep.opacity(0.5))
                    )
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Theme.surface.opacity(0.45))
        )
    }
}

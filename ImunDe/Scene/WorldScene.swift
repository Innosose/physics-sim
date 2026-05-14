import SwiftUI

struct WorldScene: View {
    let preset: Preset

    var body: some View {
        ZStack {
            ImunDeBackground(topGlow: Theme.glow.opacity(0.06))
            VStack(spacing: 8) {
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
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(preset.curriculumLabel ?? "")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.mist)
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.glow)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded, let formula = preset.formula {
                Text(formula)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.glow.opacity(0.6), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Theme.deep.opacity(0.5))
                            )
                    )
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        )
    }
}

import SwiftUI
import RealityKit

struct WorldScene: View {
    let preset: Preset
    @Environment(\.openCalculator) private var openCalculator

    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.06))
            VStack(alignment: .leading, spacing: 12) {
                header
                viewport
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let topic = preset.calculatorTopic {
                    Button {
                        openCalculator(topic)
                    } label: {
                        Label("계산기", systemImage: "function")
                    }
                    .accessibilityLabel("이 시뮬의 계산기 열기")
                }
            }
        }
        .navigationTitle(preset.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .imageScale(.small)
                    .foregroundStyle(Theme.glow)
                    .accessibilityHidden(true)
                Text(preset.curriculumLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            if !preset.blurb.isEmpty {
                Text(preset.blurb)
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var viewport: some View {
        switch preset.kind {
        case .mechanics2D:
            Mechanics2DViewport(preset: preset)
        case .mechanics3D:
            MechanicsViewport(preset: preset)
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

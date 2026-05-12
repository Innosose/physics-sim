import SwiftUI
import RealityKit

struct WorldScene: View {
    let preset: Preset
    @Environment(\.openCalculator) private var openCalculator

    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.06))
            viewport
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let topic = preset.calculatorTopic {
                    Button {
                        openCalculator(topic)
                    } label: {
                        Image(systemName: "function")
                    }
                }
            }
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

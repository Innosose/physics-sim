import SwiftUI

/// 시뮬레이션 화면들의 공통 껍데기. 좌측(또는 상단)에 캔버스, 우측(또는 하단)에 컨트롤.
///
/// iOS 의 좁은 화면에서는 자동으로 세로 배치, 넓은 화면에서는 가로 배치.
struct SimChrome<Canvas: View, Controls: View>: View {
    let title: String
    let blurb: String
    @ViewBuilder var canvas: () -> Canvas
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 720
            Group {
                if wide {
                    HStack(spacing: 0) {
                        canvasArea
                        Divider()
                        controlsArea(width: 320)
                    }
                } else {
                    VStack(spacing: 0) {
                        canvasArea
                        Divider()
                        controlsArea(width: nil)
                    }
                }
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var canvasArea: some View {
        canvas()
            .background(Color.black.opacity(0.92))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlsArea(width: CGFloat?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(blurb)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                controls()
            }
            .padding(16)
        }
        .frame(width: width)
        .background(.regularMaterial)
    }
}

/// 슬라이더 + 라벨 + 값 표시.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var format: String = "%.2f"
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(String(format: format, value) + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if step > 0 {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
    }
}

/// 한 줄 측정값 표시.
struct Readout: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospacedDigit())
        }
    }
}

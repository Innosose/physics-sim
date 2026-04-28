import SwiftUI

/// 시뮬레이션 화면들의 공통 껍데기. 좌측(또는 상단)에 캔버스, 우측(또는 하단)에 컨트롤.
///
/// iOS 의 좁은 화면에서는 자동으로 세로 배치, 넓은 화면에서는 가로 배치.
/// iOS 26 Liquid Glass 패널 사용.
struct SimChrome<Canvas: View, Controls: View>: View {
    let blurb: String
    @ViewBuilder var canvas: () -> Canvas
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 760
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.08),
                             Color(red: 0.01, green: 0.02, blue: 0.05)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if wide {
                    HStack(spacing: 16) {
                        canvasArea
                        controlsArea
                            .frame(width: 320)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 12) {
                        canvasArea
                            .frame(maxHeight: geo.size.height * 0.55)
                        controlsArea
                    }
                    .padding(12)
                }
            }
        }
    }

    private var canvasArea: some View {
        canvas()
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controlsArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !blurb.isEmpty {
                    Text(blurb)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
                controls()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassPanel(cornerRadius: 22)
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

/// 한 줄 측정값.
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

/// 시뮬 화면에서 자주 쓰는 "재생/일시정지 + 초기화" 버튼 묶음.
struct PlayResetBar: View {
    @Binding var running: Bool
    var onReset: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                running.toggle()
            } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)

            Button {
                onReset()
            } label: {
                Label("초기화", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }
}

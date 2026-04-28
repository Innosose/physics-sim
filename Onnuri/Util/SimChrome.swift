import SwiftUI

/// 시뮬레이션 화면들의 공통 껍데기 — Blender 모바일 풍.
///
/// 화면이 넓으면 좌측 viewport + 우측 properties panel,
/// 좁으면 상단 viewport + 하단 properties panel.
/// Liquid Glass 카드 위에 Blender 의 어두운 graphite 톤을 입혔다.
struct SimChrome<Canvas: View, Controls: View>: View {
    let blurb: String
    @ViewBuilder var canvas: () -> Canvas
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 760
            ZStack {
                background
                if wide {
                    HStack(alignment: .top, spacing: 12) {
                        viewportArea
                        propertiesPanel(width: 320)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 10) {
                        viewportArea
                            .frame(maxHeight: geo.size.height * 0.55)
                        propertiesPanel(width: nil)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - 영역

    private var viewportArea: some View {
        ZStack {
            // viewport 그래파이트 + 살짝 dot grid.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BlenderTheme.viewportBg)

            DotGrid()
                .opacity(0.18)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            canvas()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BlenderTheme.stroke, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func propertiesPanel(width: CGFloat?) -> some View {
        VStack(spacing: 8) {
            // 헤더.
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BlenderTheme.dimText)
                Text("PROPERTIES")
                    .font(.blenderHeader)
                    .foregroundStyle(BlenderTheme.dimText)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // 컨트롤.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if !blurb.isEmpty {
                        Text(blurb)
                            .font(.caption)
                            .foregroundStyle(BlenderTheme.dimText)
                            .lineSpacing(2)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 4)
                    }
                    controls()
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: width == nil ? .infinity : width)
        .frame(maxHeight: .infinity)
        .blenderCard(cornerRadius: 16)
    }

    private var background: some View {
        // 전체 화면 그래파이트 + 살짝 vignette.
        ZStack {
            BlenderTheme.viewportBg.ignoresSafeArea()
            RadialGradient(colors: [Color.black.opacity(0.4), .clear],
                           center: .center, startRadius: 200, endRadius: 700)
                .ignoresSafeArea()
        }
    }
}

// MARK: - 미세 dot grid

/// 작은 점 격자 — viewport 의 깊이감 보조.
private struct DotGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 26
            let r: CGFloat = 0.9
            var x: CGFloat = step / 2
            while x < size.width {
                var y: CGFloat = step / 2
                while y < size.height {
                    let rect = CGRect(x: x - r, y: y - r,
                                      width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(0.35)))
                    y += step
                }
                x += step
            }
        }
    }
}

// MARK: - Blender 풍 슬라이더·측정값

/// 슬라이더 + 라벨 + 모노스페이스 값.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var format: String = "%.2f"
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.blenderLabel)
                    .foregroundStyle(BlenderTheme.monoText)
                Spacer(minLength: 8)
                Text(formattedValue)
                    .font(.blenderMonoBold)
                    .foregroundStyle(BlenderTheme.accent)
            }
            sliderControl
                .tint(BlenderTheme.highlight)
        }
        .padding(.vertical, 2)
    }

    private var formattedValue: String {
        let v = String(format: format, value)
        return unit.isEmpty ? v : "\(v) \(unit)"
    }

    @ViewBuilder
    private var sliderControl: some View {
        if step > 0 {
            Slider(value: $value, in: range, step: step).controlSize(.small)
        } else {
            Slider(value: $value, in: range).controlSize(.small)
        }
    }
}

/// 한 줄 측정값.
struct Readout: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(BlenderTheme.dimText)
            Spacer()
            Text(value)
                .font(.blenderMono)
                .foregroundStyle(BlenderTheme.monoText)
        }
        .padding(.vertical, 1)
    }
}

/// 속성 그룹 — 헤더 + 내용. Blender 의 N-panel 섹션 풍.
struct PropertySection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(BlenderTheme.dimText)
                Text(title.uppercased())
                    .font(.blenderHeader)
                    .foregroundStyle(BlenderTheme.dimText)
            }
            .padding(.bottom, 2)
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(.leading, 2)
        }
        .padding(.top, 4)
    }
}

/// 가는 분할선.
struct PropertyDivider: View {
    var body: some View {
        Rectangle()
            .fill(BlenderTheme.divider)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

/// 재생/일시정지 + 초기화. Blender 풍 액센트.
struct PlayResetBar: View {
    @Binding var running: Bool
    var onReset: () -> Void
    var resetLabel: String = "초기화"

    var body: some View {
        HStack(spacing: 8) {
            Button {
                running.toggle()
            } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(BlenderTheme.accent)

            Button {
                onReset()
            } label: {
                Label(resetLabel, systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .padding(.vertical, 2)
    }
}

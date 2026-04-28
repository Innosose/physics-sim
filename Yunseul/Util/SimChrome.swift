import SwiftUI

/// 시뮬레이션 화면들의 공통 껍데기 — 윤슬 (Yunseul) 디자인.
///
/// 화면이 넓으면 좌측 viewport + 우측 properties panel,
/// 좁으면 상단 viewport + 하단 properties panel.
/// 뷰포트는 깊은 밤바다 (`Theme.deep`) 위에 잔물결 라인 (`RippleField`),
/// 패널은 Liquid Glass 위에 `surface` 톤을 살짝 입힌 `themeCard`.
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
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            // 깊은 밤바다 + 잔물결 라인 (윤슬).
            shape.fill(Theme.deep)
            RippleField()
                .clipShape(shape)
            canvas()
                .clipShape(shape)
        }
        .overlay { shape.stroke(Theme.stroke, lineWidth: 1) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func propertiesPanel(width: CGFloat?) -> some View {
        VStack(spacing: 8) {
            // 헤더.
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mist)
                Text("PROPERTIES")
                    .font(.themeHeader)
                    .foregroundStyle(Theme.mist)
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
                            .foregroundStyle(Theme.mist)
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
        .themeCard(cornerRadius: 16)
    }

    private var background: some View {
        // 전체 화면: void 그라데이션 + 위쪽 금빛 광원 (별 패턴은 시뮬에서는 생략).
        YunseulBackground(topGlow: Theme.glow.opacity(0.06), stars: false)
    }
}

// MARK: - 윤슬 풍 슬라이더·측정값

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
                    .font(.themeLabel)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(formattedValue)
                    .font(.themeMonoBold)
                    .foregroundStyle(Theme.glow)
            }
            sliderControl
                .tint(Theme.accent)
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
                .foregroundStyle(Theme.mist)
            Spacer()
            Text(value)
                .font(.themeMono)
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 1)
    }
}

/// 속성 그룹 — 헤더 + 내용. 속성 패널의 컬랩서블 섹션.
struct PropertySection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.mist)
                Text(title.uppercased())
                    .font(.themeHeader)
                    .foregroundStyle(Theme.mist)
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
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

/// 재생/일시정지 + 초기화. 윤슬 — 금빛 액센트.
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
            .tint(Theme.glow)

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

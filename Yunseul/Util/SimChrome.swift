import SwiftUI

/// 시뮬레이션 화면들의 공통 껍데기 — 윤슬 (Yunseul) 디자인.
///
/// 화면이 넓으면 좌측 viewport + 우측 properties panel,
/// 좁으면 상단 viewport + 하단 properties panel.
/// 뷰포트는 깊은 밤바다 (`Theme.deep`), 패널은 Liquid Glass 위 surface 톤 (`themeCard`).
struct SimChrome<Canvas: View, Controls: View>: View {
    let blurb: String
    @ViewBuilder var canvas: () -> Canvas
    @ViewBuilder var controls: () -> Controls

    @Environment(\.simulationItem) private var item
    @Environment(\.openCalculator) private var openCalculator

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
        .toolbar {
            // 짝이 되는 계산기가 있으면 우상단에 점프 버튼.
            ToolbarItem(placement: .topBarTrailing) {
                if let topic = item?.calculatorTopic {
                    Button {
                        openCalculator(topic)
                    } label: {
                        Label("계산기", systemImage: "function")
                    }
                    .accessibilityLabel("이 시뮬의 계산기 열기")
                }
            }
        }
    }

    // MARK: - 영역

    private var viewportArea: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(Theme.deep)
            canvas()
                .clipShape(shape)
        }
        .overlay { shape.stroke(Theme.stroke, lineWidth: 1) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func propertiesPanel(width: CGFloat?) -> some View {
        // 단원 위치 행 + blurb (있으면) + 컨트롤. 수식·정확한 값은 표시하지 않음.
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if let item {
                    ConceptCard(item: item)
                }
                if !blurb.isEmpty {
                    Text(blurb)
                        .font(.caption)
                        .foregroundStyle(Theme.mist)
                        .lineSpacing(2)
                }
                controls()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: width == nil ? .infinity : width)
        .frame(maxHeight: .infinity)
        .themeCard(cornerRadius: 16)
    }

    private var background: some View {
        YunseulBackground(topGlow: Theme.glow.opacity(0.06))
    }
}

// MARK: - ConceptCard — 교육과정 위치 + 계산 종류 배지

/// 시뮬 화면 properties 패널 상단에 고정으로 보여주는 정보 행.
/// 단원 위치 + 계산 종류 배지만. 수식·정확한 값은 표시하지 않음 — 시뮬은 보는 용도.
struct ConceptCard: View {
    let item: SimulationItem

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "graduationcap.fill")
                .imageScale(.small)
                .foregroundStyle(Theme.glow)
                .accessibilityHidden(true)
            Text(item.curriculum)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
            CalcKindBadge(kind: item.calcKind)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("교육과정 위치: \(item.curriculum). 계산 종류: \(item.calcKind.label).")
    }
}

// MARK: - 계산 종류 배지

/// 닫힌 해 / 이벤트 기반 / 수치 — 작은 색 배지로 표시.
struct CalcKindBadge: View {
    let kind: SimCalcKind
    var body: some View {
        Text(kind.label)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(kind.badgeColor)
            .background(
                Capsule().fill(kind.badgeColor.opacity(0.16))
            )
            .overlay(
                Capsule().stroke(kind.badgeColor.opacity(0.45), lineWidth: 1)
            )
            .accessibilityLabel("계산 종류: \(kind.label)")
    }
}

// MARK: - 윤슬 풍 슬라이더·측정값

/// 슬라이더 + 라벨 + 모노스페이스 값.
///
/// `onEditingChanged` 는 드래그 시작·끝 신호. 이 값이 false 가 됐을 때만
/// 무거운 작업(예: `reset()`) 을 호출하면, 드래그 중 "매 틱마다 리셋" 하는
/// 끔찍한 깜빡임이 사라진다.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var format: String = "%.2f"
    var unit: String = ""
    var onEditingChanged: (Bool) -> Void = { _ in }

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
        // HIG: Touch targets — 시스템 기본(.regular) 슬라이더는 44pt 가까이의
        // 탭 영역을 보장. .controlSize(.small) 은 정보 밀도 화면에서만 권장.
        if step > 0 {
            Slider(value: $value, in: range, step: step,
                   onEditingChanged: onEditingChanged)
        } else {
            Slider(value: $value, in: range,
                   onEditingChanged: onEditingChanged)
        }
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
                    .imageScale(.small)             // HIG: Dynamic Type 따라 함께 확대
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

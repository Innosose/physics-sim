import SwiftUI

/// 앱의 최상위 화면 — `NavigationSplitView` 3-column.
///
/// HIG 근거:
/// - *Sidebars* — "Use a sidebar to navigate between top-level collections of
///   content in a hierarchical app." 학년(초·중·고·자유) 이 정확히 그 케이스.
/// - *Navigation* — iPad/Mac 에서 NavigationSplitView 권장. iPhone 에서는
///   자동으로 stack 으로 collapse 되어 push 처럼 동작.
///
/// 컬럼:
/// - **Sidebar**: 윤슬 브랜드 헤더 + 4개 학년.
/// - **Content**: 선택된 학년의 시뮬 목록 (카테고리별 그룹).
/// - **Detail**: 선택된 시뮬 화면. 미선택 상태에서는 환영 화면 (별자리 + 잔물결).
struct RootSplitView: View {
    @State private var curriculumSelection: Curriculum? = nil
    @State private var simSelection: SimulationItem? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $curriculumSelection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } content: {
            if let c = curriculumSelection {
                SimList(curriculum: c, selection: $simSelection)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 360)
            } else {
                EmptyState(
                    icon: "sparkles",
                    title: "학년을 선택하세요",
                    message: "왼쪽 사이드바에서 초등 · 중학 · 고등 · 자유 시뮬레이션 중 하나를 골라 보세요."
                )
            }
        } detail: {
            if let sim = simSelection {
                SimulationCatalog.view(for: sim.id)
                    .environment(\.simulationItem, sim)
                    .navigationTitle(sim.title)
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                WelcomeDetail()
            }
        }
        .navigationSplitViewStyle(.balanced)
        // iPhone collapse 시 자동으로 stack 으로 동작. detail 이 비어 있어도
        // root 가 sidebar 로 보임.
    }
}

// MARK: - Sidebar (학년)

private struct Sidebar: View {
    @Binding var selection: Curriculum?

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(Curriculum.allCases) { c in
                    NavigationLink(value: c) {
                        CurriculumRow(curriculum: c)
                    }
                }
            } header: {
                YunseulBrand()
                    .padding(.vertical, 6)
                    .textCase(nil)             // section header 의 자동 대문자화 제거
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("윤슬")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)      // List 기본 배경 숨겨서 윤슬 톤 통과
        .background(YunseulBackground(topGlow: Theme.glow.opacity(0.10),
                                       stars: false))
    }
}

private struct YunseulBrand: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.glow)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text("YUNSEUL")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Theme.mist)
            }
            Text("윤슬")
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
            Text("물리를 눈으로 보는 시뮬")
                .font(.caption)
                .foregroundStyle(Theme.mist)
            RippleAccent()
                .frame(width: 72, height: 8)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("윤슬. 물리를 눈으로 보는 시뮬레이션 모음.")
    }
}

private struct CurriculumRow: View {
    let curriculum: Curriculum

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(curriculum.accent.opacity(0.20))
                    .frame(width: 38, height: 38)
                Image(systemName: curriculum.iconSystemName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(curriculum.accent)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(curriculum.rawValue)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(curriculum.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Content column (시뮬 목록)

private struct SimList: View {
    let curriculum: Curriculum
    @Binding var selection: SimulationItem?

    var body: some View {
        let groups = SimulationCatalog.grouped(for: curriculum)
        List(selection: $selection) {
            ForEach(groups, id: \.0) { (cat, items) in
                Section {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            SimRow(item: item, accent: curriculum.accent)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: cat.systemImage)
                            .imageScale(.small)
                            .foregroundStyle(curriculum.accent)
                            .accessibilityHidden(true)
                        Text(cat.rawValue)
                            .font(.themeHeader)
                            .foregroundStyle(Theme.mist)
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(YunseulBackground(
            topGlow: curriculum.accent.opacity(0.10), stars: false))
        .navigationTitle(curriculum.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SimRow: View {
    let item: SimulationItem
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.systemImage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text(item.curriculum)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.glow.opacity(0.85))
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("열기 — \(item.curriculum)")
    }
}

// MARK: - Detail (환영 / 빈 상태)

/// 시뮬을 아직 선택하지 않았을 때 detail 컬럼이 보여주는 환영 화면.
///
/// 여기에 윤슬 splash 의 정수(별자리 배경, 큰 표제, 잔물결) 가 응축되어
/// 흡수됨. 사용자가 시뮬을 처음 선택하기 전에만 보이는 "표지" 역할.
private struct WelcomeDetail: View {
    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.18), stars: true)
            VStack(spacing: 14) {
                Text("윤슬")
                    .font(.themeTitle)
                    .foregroundStyle(Theme.ink)
                Text("물리를 눈으로 보는 시뮬레이션 모음")
                    .font(.callout)
                    .foregroundStyle(Theme.mist)
                RippleAccent()
                    .frame(width: 120, height: 12)
                    .padding(.top, 6)
                HStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text("왼쪽에서 학년과 시뮬을 골라 보세요")
                        .font(.footnote)
                }
                .foregroundStyle(Theme.mist)
                .padding(.top, 18)
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("환영 화면. 왼쪽 사이드바에서 학년과 시뮬을 선택하세요.")
    }
}

/// 학년이 선택됐지만 그 학년 안에서 아직 시뮬을 안 골랐을 때 (iPad 가운데 컬럼)
/// 또는 일반 빈 상태 표시.
private struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.10), stars: false)
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundStyle(Theme.glow.opacity(0.7))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Theme.mist)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .padding()
        }
    }
}

#Preview {
    RootSplitView()
        .preferredColorScheme(.dark)
}

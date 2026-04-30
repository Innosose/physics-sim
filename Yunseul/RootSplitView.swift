import SwiftUI

/// 앱의 최상위 화면 — `NavigationSplitView` 3-column.
///
/// HIG 근거:
/// - *Sidebars* — "Use a sidebar to navigate between top-level collections of
///   content in a hierarchical app." 학년이 그 케이스.
/// - *Navigation* — iPad/Mac 에서 NavigationSplitView 권장. iPhone 에서는
///   자동으로 stack 으로 collapse 되어 push 처럼 동작.
///
/// 컬럼:
/// - **Sidebar**: 학년 (중·고·자유)
/// - **Content**: 선택된 학년의 시뮬 목록
/// - **Detail**: 선택된 시뮬 화면. 시뮬 안에서 계산기로 진입 가능 — 계산기는
///   별도 사이드바 항목이 아니라 시뮬에 딸린 "이론·계산" 도구로 자리잡음.
///
/// 정체성은 한글 글자 마크(`LetterMark`) 로 표현하고, 작은 보조 심볼(▶·↻·›·🎓)
/// 만 SF Symbol 로 사용한다.
struct RootSplitView: View {
    @State private var sidebarSelection: SidebarSection? = nil
    @State private var detailSelection: DetailItem? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $sidebarSelection,
                    showSettings: $showSettings)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: - 컬럼

    @ViewBuilder
    private var contentColumn: some View {
        switch sidebarSelection {
        case .curriculum(let c):
            SimList(curriculum: c, selection: $detailSelection)
        case nil:
            EmptyState(
                title: "학년을 선택하세요",
                message: "왼쪽 사이드바에서 학년을 골라 시뮬을 열어 보세요. 계산기는 각 시뮬 화면 우상단에서 진입할 수 있습니다."
            )
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch detailSelection {
        case .simulation(let item):
            SimulationCatalog.view(for: item.id)
                .environment(\.simulationItem, item)
                .environment(\.openCalculator, OpenCalculatorAction { topic in
                    // 계산기로 진입 — sidebar 선택은 그대로 (시뮬의 학년 유지).
                    detailSelection = .calculator(topic)
                })
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
        case .calculator(let topic):
            CalculatorView(topic: topic)
                .environment(\.openSimulation, OpenSimulationAction { item in
                    // 짝이 되는 시뮬로 복귀 — sidebar 도 해당 시뮬의 학년으로 옮김.
                    let c = SimulationCatalog.curriculum(of: item) ?? .free
                    sidebarSelection = .curriculum(c)
                    detailSelection = .simulation(item)
                })
        case nil:
            WelcomeDetail()
        }
    }
}

// MARK: - 선택 모델

/// 사이드바의 최상위 항목 — 현재는 학년만.
enum SidebarSection: Hashable, Identifiable {
    case curriculum(Curriculum)

    var id: String {
        switch self {
        case .curriculum(let c): return "curriculum:\(c.rawValue)"
        }
    }
}

/// Detail 컬럼이 보여줄 대상.
enum DetailItem: Hashable, Identifiable {
    case simulation(SimulationItem)
    case calculator(CalculatorTopic)

    var id: String {
        switch self {
        case .simulation(let s): return "sim:\(s.id)"
        case .calculator(let t): return "calc:\(t.id)"
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Binding var selection: SidebarSection?
    @Binding var showSettings: Bool

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(Curriculum.allCases) { c in
                    NavigationLink(value: SidebarSection.curriculum(c)) {
                        CurriculumRow(curriculum: c)
                    }
                }
            } header: {
                YunseulBrand()
                    .padding(.vertical, 6)
                    .textCase(nil)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("윤슬")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(YunseulBackground(topGlow: Theme.glow.opacity(0.10),
                                       stars: false))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("설정")
                }
            }
        }
    }
}

private struct YunseulBrand: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                LogoOrFallback().frame(width: 22, height: 22)
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

private struct LogoOrFallback: View {
    var body: some View {
        ZStack {
            Circle().fill(Theme.glow).accessibilityHidden(true)
            Image("AppLogo").resizable().scaledToFit()
        }
    }
}

private struct CurriculumRow: View {
    let curriculum: Curriculum
    var body: some View {
        HStack(spacing: 12) {
            LetterMark(mark: curriculum.letterMark, tint: curriculum.accent, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(curriculum.rawValue)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(curriculum.subtitle)
                    .font(.caption).foregroundStyle(Theme.mist).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Content column (시뮬 목록)

private struct SimList: View {
    let curriculum: Curriculum
    @Binding var selection: DetailItem?

    var body: some View {
        let groups = SimulationCatalog.grouped(for: curriculum)
        List(selection: $selection) {
            ForEach(groups, id: \.0) { (cat, items) in
                Section {
                    ForEach(items) { item in
                        NavigationLink(value: DetailItem.simulation(item)) {
                            SimRow(item: item, accent: curriculum.accent)
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(cat.letterMark)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(curriculum.accent)
                            .frame(width: 16, height: 16)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(curriculum.accent.opacity(0.16))
                            )
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
            LetterMark(mark: item.category.letterMark, tint: accent, size: 36)
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
                Text("‹ 왼쪽에서 학년을 골라 시뮬을 열어 보세요")
                    .font(.footnote)
                    .foregroundStyle(Theme.mist)
                    .padding(.top, 18)
                Text("계산기는 각 시뮬 화면 우상단에서 진입")
                    .font(.caption2)
                    .foregroundStyle(Theme.mist.opacity(0.7))
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("환영 화면. 왼쪽 사이드바에서 학년을 선택하면 시뮬 목록이 나타납니다.")
    }
}

private struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.10), stars: false)
            VStack(spacing: 12) {
                Text("?")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
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
}

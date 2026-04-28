import SwiftUI

/// 앱의 최상위 화면 — `NavigationSplitView` 3-column.
///
/// HIG 근거:
/// - *Sidebars* — "Use a sidebar to navigate between top-level collections of
///   content in a hierarchical app." 학년이 정확히 그 케이스.
/// - *Navigation* — iPad/Mac 에서 NavigationSplitView 권장. iPhone 에서는
///   자동으로 stack 으로 collapse 되어 push 처럼 동작.
///
/// 컬럼:
/// - **Sidebar**: 윤슬 브랜드 헤더 + 3개 학년 (중·고·자유).
/// - **Content**: 선택된 학년의 시뮬 목록 (카테고리별 그룹).
/// - **Detail**: 선택된 시뮬 화면. 미선택 상태에서는 환영 화면.
///
/// 정체성은 한글 글자 마크(`LetterMark`) 로 표현하고, 작은 보조 심볼(▶·↻·›·🎓)
/// 만 SF Symbol 로 사용한다.
struct RootSplitView: View {
    @State private var curriculumSelection: Curriculum? = nil
    @State private var simSelection: SimulationItem? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $curriculumSelection,
                    showSettings: $showSettings)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } content: {
            if let c = curriculumSelection {
                SimList(curriculum: c, selection: $simSelection)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 360)
            } else {
                EmptyState(
                    title: "학년을 선택하세요",
                    message: "왼쪽 사이드바에서 중학교 · 고등학교 · 자유 시뮬레이션 중 하나를 골라 보세요."
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
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

// MARK: - Sidebar (학년)

private struct Sidebar: View {
    @Binding var selection: Curriculum?
    @Binding var showSettings: Bool

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
                // 사용자 로고가 들어갈 슬롯. Assets.xcassets 의 "AppLogo" 가 있으면
                // 그걸 쓰고, 없으면 typographic fallback (작은 금빛 점) 으로.
                LogoOrFallback()
                    .frame(width: 22, height: 22)
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

/// `Assets.xcassets/AppLogo` 가 있으면 그걸 쓰고, 없으면 작은 금빛 점으로 떨어짐.
/// 사용자가 직접 만든 로고를 끼워 넣을 수 있는 슬롯.
private struct LogoOrFallback: View {
    var body: some View {
        // SwiftUI 는 Image(name:) 에 없는 asset 도 컴파일은 통과시키고 런타임에
        // 빈 이미지를 그린다. 따라서 fallback 을 ZStack 으로 같이 그려두면 안전.
        ZStack {
            Circle()
                .fill(Theme.glow)
                .accessibilityHidden(true)
            Image("AppLogo")                              // 사용자 슬롯
                .resizable()
                .scaledToFit()
        }
    }
}

private struct CurriculumRow: View {
    let curriculum: Curriculum

    var body: some View {
        HStack(spacing: 12) {
            LetterMark(mark: curriculum.letterMark,
                       tint: curriculum.accent,
                       size: 38)
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
            LetterMark(mark: item.category.letterMark,
                       tint: accent,
                       size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    // 작은 보조 심볼은 유지 (포인트 용도)
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

/// 시뮬 미선택 시 detail 컬럼이 보여주는 환영 화면.
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
                Text("‹ 왼쪽에서 학년과 시뮬을 골라 보세요")
                    .font(.footnote)
                    .foregroundStyle(Theme.mist)
                    .padding(.top, 18)
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("환영 화면. 왼쪽 사이드바에서 학년과 시뮬을 선택하세요.")
    }
}

private struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.10), stars: false)
            VStack(spacing: 12) {
                // 큰 타이포 마크 — 아이콘 대신 정체성 표현
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

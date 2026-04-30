import SwiftUI

struct RootSplitView: View {
    @State private var sidebarSelection: Curriculum? = nil
    @State private var detailSelection: DetailItem? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
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

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
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
        .background(YunseulBackground(topGlow: Theme.glow.opacity(0.10)))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("설정")
                }
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch sidebarSelection {
        case .some(let c):
            PresetList(curriculum: c, selection: $detailSelection)
        case nil:
            EmptyState(
                title: "기능을 선택하세요",
                message: "왼쪽 사이드바에서 기능을 골라 시뮬을 열어 보세요. 계산기는 각 시뮬 화면 우상단에서 진입할 수 있습니다."
            )
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch detailSelection {
        case .preset(let p):
            WorldScene(preset: p)
                .environment(\.openCalculator, OpenCalculatorAction { topic in
                    detailSelection = .calculator(topic)
                })
        case .calculator(let topic):
            CalculatorView(topic: topic)
                .environment(\.openSimulation, OpenSimulationAction { p in
                    sidebarSelection = p.curriculum
                    detailSelection = .preset(p)
                })
        case nil:
            WelcomeDetail()
        }
    }
}

enum DetailItem: Hashable, Identifiable {
    case preset(Preset)
    case calculator(CalculatorTopic)

    var id: String {
        switch self {
        case .preset(let p):     return "preset:\(p.id)"
        case .calculator(let t): return "calc:\(t.id)"
        }
    }
}

private struct YunseulBrand: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("윤슬")
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
            Text("물리를 눈으로 보는 시뮬")
                .font(.caption)
                .foregroundStyle(Theme.mist)
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
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(curriculum.accent)
                .frame(width: 3)
                .accessibilityHidden(true)
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

private struct PresetList: View {
    let curriculum: Curriculum
    @Binding var selection: DetailItem?

    var body: some View {
        let groups = PresetCatalog.grouped(for: curriculum)
        List(selection: Binding(
            get: {
                if case .preset(let p) = selection { return p }
                return nil
            },
            set: { newValue in
                if let p = newValue { selection = .preset(p) }
                else                { selection = nil }
            }
        )) {
            ForEach(groups, id: \.0) { (cat, presets) in
                Section {
                    ForEach(presets) { p in
                        NavigationLink(value: p) {
                            PresetRow(preset: p, accent: curriculum.accent)
                        }
                    }
                } header: {
                    Text(cat.rawValue)
                        .font(.themeHeader)
                        .foregroundStyle(Theme.mist)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(YunseulBackground(topGlow: curriculum.accent.opacity(0.10)))
        .navigationTitle(curriculum.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PresetRow: View {
    let preset: Preset
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text(preset.curriculumLabel)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.glow.opacity(0.85))
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("열기 — \(preset.curriculumLabel)")
    }
}

private struct WelcomeDetail: View {
    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.10))
            VStack(spacing: 10) {
                Text("윤슬")
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                Text("물리를 눈으로 보는 시뮬레이션 모음")
                    .font(.callout)
                    .foregroundStyle(Theme.mist)
                Text("왼쪽에서 기능을 골라 시뮬을 열어 보세요. 계산기는 각 시뮬 화면 우상단에서 진입.")
                    .font(.footnote)
                    .foregroundStyle(Theme.mist)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .frame(maxWidth: 360)
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("환영 화면. 왼쪽 사이드바에서 기능을 선택하면 시뮬 목록이 나타납니다.")
    }
}

private struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            YunseulBackground(topGlow: Theme.glow.opacity(0.10))
            VStack(spacing: 8) {
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

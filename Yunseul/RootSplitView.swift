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
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(c.accent)
                                .frame(width: 3)
                            Text(c.rawValue)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("윤슬")
                        .font(.title.bold())
                        .foregroundStyle(Theme.ink)
                    Text("물리를 눈으로 보다")
                        .font(.caption)
                        .foregroundStyle(Theme.mist)
                }
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
            Color.clear
                .background(YunseulBackground(topGlow: Theme.glow.opacity(0.10)))
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
            Color.clear
                .background(YunseulBackground(topGlow: Theme.glow.opacity(0.10)))
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
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(curriculum.accent)
                                    .frame(width: 3)
                                Text(p.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.vertical, 4)
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

#Preview {
    RootSplitView()
}

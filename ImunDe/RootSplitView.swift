import SwiftUI

enum SidebarItem: Hashable, Identifiable {
    case curriculum(Curriculum)
    case calculator

    var id: String {
        switch self {
        case .curriculum(let c): return c.rawValue
        case .calculator: return "calculator"
        }
    }
}

struct RootSplitView: View {
    @State private var sidebarItem: SidebarItem? = nil
    @State private var detailSelection: DetailItem? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings: Bool = false
    @State private var presentedCalculator: CalculatorTopic? = nil

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
        .preferredCompactColumn(.sidebar)
        .onChange(of: sidebarItem) { _, _ in detailSelection = nil }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $presentedCalculator) { topic in
            NavigationStack {
                CalculatorView(topic: topic)
                    .environment(\.openSimulation, OpenSimulationAction { p in
                        presentedCalculator = nil
                        sidebarItem = .curriculum(p.curriculum)
                        detailSelection = .preset(p)
                    })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("완료") { presentedCalculator = nil }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var sidebar: some View {
        List(selection: $sidebarItem) {
            Section {
                ForEach(Curriculum.allCases) { c in
                    NavigationLink(value: SidebarItem.curriculum(c)) {
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
                    Text("이문데")
                        .font(.title.bold())
                        .foregroundStyle(Theme.ink)
                    Text("이런 문제 데이터베이스")
                        .font(.caption)
                        .foregroundStyle(Theme.mist)
                }
                .padding(.vertical, 6)
                .textCase(nil)
            }

            Section {
                NavigationLink(value: SidebarItem.calculator) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Theme.glow)
                            .frame(width: 3)
                        Text("계산기")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("도구")
                    .font(.themeHeader)
                    .foregroundStyle(Theme.mist)
                    .padding(.vertical, 6)
                    .textCase(nil)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("이문데")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(ImunDeBackground(topGlow: Theme.glow.opacity(0.10)))
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
        switch sidebarItem {
        case .curriculum(let c):
            PresetList(curriculum: c, selection: $detailSelection)
        case .calculator:
            CalculatorTopicList(presentedCalculator: $presentedCalculator)
        case nil:
            Color.clear
                .background(ImunDeBackground(topGlow: Theme.glow.opacity(0.10)))
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch detailSelection {
        case .preset(let p):
            WorldScene(preset: p)
                .environment(\.openCalculator, OpenCalculatorAction { topic in
                    presentedCalculator = topic
                })
        case nil:
            WelcomeView()
        }
    }
}

enum DetailItem: Hashable, Identifiable {
    case preset(Preset)

    var id: String {
        switch self {
        case .preset(let p): return "preset:\(p.id)"
        }
    }
}

// MARK: - Welcome

private struct WelcomeView: View {
    var body: some View {
        ZStack {
            ImunDeBackground(topGlow: Theme.glow.opacity(0.12))
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("이문데")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("이런 문제 데이터베이스")
                        .font(.title3)
                        .foregroundStyle(Theme.mist)
                }
                Rectangle()
                    .fill(Theme.glow)
                    .frame(width: 40, height: 2)
                    .cornerRadius(1)
                VStack(spacing: 8) {
                    ForEach([
                        ("중학교", "역학·빛·회로·열", Color(red: 0.30, green: 0.74, blue: 0.85)),
                        ("고등학교", "물리Ⅰ·Ⅱ 전 범위", Color(red: 0.55, green: 0.45, blue: 0.95)),
                        ("샌드박스", "자유 시뮬레이션", Color(red: 0.98, green: 0.86, blue: 0.40)),
                    ], id: \.0) { item in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(item.2)
                                .frame(width: 3, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.0)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(item.1)
                                    .font(.caption)
                                    .foregroundStyle(Theme.mist)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.surface.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.stroke, lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: 320)
                Text("← 왼쪽에서 학년을 선택하세요")
                    .font(.footnote)
                    .foregroundStyle(Theme.mist.opacity(0.7))
            }
            .padding(24)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preset list

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
        .background(ImunDeBackground(topGlow: curriculum.accent.opacity(0.10)))
        .navigationTitle(curriculum.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Calculator topic list

private struct CalculatorTopicList: View {
    @Binding var presentedCalculator: CalculatorTopic?

    private var grouped: [(String, [CalculatorTopic])] {
        let order = ["역학", "전자기", "파동·광학"]
        var dict: [String: [CalculatorTopic]] = [:]
        for t in CalculatorTopic.allCases { dict[t.section, default: []].append(t) }
        return order.compactMap { s in dict[s].map { (s, $0) } }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.0) { (section, topics) in
                Section {
                    ForEach(topics) { topic in
                        Button {
                            presentedCalculator = topic
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Theme.glow)
                                    .frame(width: 3)
                                Text(topic.rawValue)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(section)
                        .font(.themeHeader)
                        .foregroundStyle(Theme.mist)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ImunDeBackground(topGlow: Theme.glow.opacity(0.10)))
        .navigationTitle("계산기")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    RootSplitView()
}

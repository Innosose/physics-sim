import SwiftUI

enum SidebarItem: Hashable, Identifiable {
    case curriculum(Curriculum)

    var id: String {
        switch self {
        case .curriculum(let c): return c.rawValue
        }
    }
}

struct RootSplitView: View {
    @State private var sidebarItem: SidebarItem? = nil
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
        .onChange(of: sidebarItem) { _, new in
            // Preserve detail selection when the new sidebar curriculum
            // matches the selected preset (e.g. featured preset tapped on welcome).
            if case .preset(let p) = detailSelection,
               case .curriculum(let c) = new,
               p.curriculum == c { return }
            detailSelection = nil
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var sidebar: some View {
        List(selection: $sidebarItem) {
            Section {
                ForEach(Curriculum.allCases) { c in
                    NavigationLink(value: SidebarItem.curriculum(c)) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                    .fill(c.accent.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: c.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(c.accent)
                            }
                            Text(c.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("이문데")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("이런 문제 데이터베이스")
                        .font(.footnote)
                        .foregroundStyle(Theme.mist)
                }
                .padding(.vertical, 8)
                .textCase(nil)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("이문데")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(ImunDeBackground())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        Group {
            switch sidebarItem {
            case .curriculum(let c):
                PresetList(curriculum: c, selection: $detailSelection)
                    .id("curr-\(c.rawValue)")
            case nil:
                Color.clear
                    .background(ImunDeBackground())
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.22), value: sidebarItem)
    }

    @ViewBuilder
    private var detailColumn: some View {
        Group {
            switch detailSelection {
            case .preset(let p):
                WorldScene(preset: p)
                    .id("ws-\(p.id)")
            case nil:
                WelcomeView(
                    hasSidebarSelection: sidebarItem != nil,
                    onSelectCurriculum: { c in
                        sidebarItem = .curriculum(c)
                    }
                )
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.25), value: detailSelection)
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
    var hasSidebarSelection: Bool = false
    var onSelectCurriculum: ((Curriculum) -> Void)? = nil

    @State private var appear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let entries: [(curriculum: Curriculum, sub: String)] = [
        (.middle, "역학 · 빛 · 회로 · 열"),
        (.high, "물리Ⅰ · Ⅱ"),
        (.free, "자유 시뮬레이션"),
    ]

    var body: some View {
        ZStack {
            ImunDeBackground()
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("이문데")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("물리학 I · II · 2022 개정 과학과")
                        .font(.themeHeader)
                        .tracking(0.4)
                        .foregroundStyle(Theme.mist)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { i, entry in
                        Button {
                            onSelectCurriculum?(entry.curriculum)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: entry.curriculum.icon)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(entry.curriculum.accent)
                                    .frame(width: 18)
                                Text(entry.curriculum.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Text(entry.sub)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.mist)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if i < entries.count - 1 {
                            Rectangle()
                                .fill(Theme.divider)
                                .frame(height: 1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text(hasSidebarSelection
                         ? "목록에서 시뮬레이션을 고르세요."
                         : "사이드바에서 학년을 고르세요.")
                        .font(.footnote)
                        .foregroundStyle(Theme.mist)
                    Text("교육과정 기준 · 2022 개정 과학과 교육과정")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.mistDisabled)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
            .opacity(appear ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion { appear = true }
            else { withAnimation(.easeOut(duration: 0.25)) { appear = true } }
        }
    }
}

// MARK: - Preset list

private struct PresetList: View {
    let curriculum: Curriculum
    @Binding var selection: DetailItem?
    @State private var searchText: String = ""
    @AppStorage("favoritePresets") private var favoritesRaw: String = ""

    private var favorites: Set<String> {
        Set(favoritesRaw.split(separator: ",").map(String.init))
    }

    private func toggleFavorite(_ id: String) {
        var current = favorites
        if current.contains(id) { current.remove(id) }
        else                    { current.insert(id) }
        favoritesRaw = current.sorted().joined(separator: ",")
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private var allPresets: [Preset] {
        PresetCatalog.grouped(for: curriculum).flatMap { $0.1 }
    }

    private var filteredGroups: [(SimCategory, [Preset])] {
        let baseGroups = PresetCatalog.grouped(for: curriculum)
        guard isSearching else { return baseGroups }
        let q = trimmedQuery
        return baseGroups.compactMap { (cat, presets) in
            let matched = presets.filter { matches(preset: $0, query: q) }
            return matched.isEmpty ? nil : (cat, matched)
        }
    }

    private func matches(preset p: Preset, query q: String) -> Bool {
        if p.title.lowercased().contains(q) { return true }
        if p.subtitle.lowercased().contains(q) { return true }
        if let f = p.formula, f.lowercased().contains(q) { return true }
        if let l = p.curriculumLabel, l.lowercased().contains(q) { return true }
        if p.category.rawValue.lowercased().contains(q) { return true }
        return false
    }

    private var favoritePresets: [Preset] {
        allPresets.filter { favorites.contains($0.id) }
    }

    private var listSelection: Binding<Preset?> {
        Binding(
            get: {
                if case .preset(let p) = selection { return p }
                return nil
            },
            set: { newValue in
                if let p = newValue { selection = .preset(p) }
                else                { selection = nil }
            }
        )
    }

    var body: some View {
        let groups = filteredGroups
        let favs = favoritePresets

        List(selection: listSelection) {
            if !favs.isEmpty && !isSearching {
                Section {
                    ForEach(favs) { p in
                        presetLink(p)
                    }
                } header: {
                    sectionHeader(
                        title: "즐겨찾기",
                        count: favs.count,
                        leadingIcon: "star.fill",
                        iconColor: Theme.glowText)
                }
            }

            ForEach(groups, id: \.0) { (cat, presets) in
                Section {
                    ForEach(presets) { p in
                        presetLink(p)
                    }
                } header: {
                    sectionHeader(title: cat.rawValue.uppercased(),
                                  count: presets.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ImunDeBackground())
        .overlay {
            if isSearching && groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .background(ImunDeBackground())
            }
        }
        .navigationTitle(curriculum.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "검색")
    }

    @ViewBuilder
    private func presetLink(_ p: Preset) -> some View {
        let isFav = favorites.contains(p.id)
        NavigationLink(value: p) {
            PresetRow(preset: p, curriculum: curriculum, isFavorite: isFav)
        }
        .swipeActions(edge: .trailing) {
            Button {
                toggleFavorite(p.id)
            } label: {
                Label(isFav ? "해제" : "즐겨찾기",
                      systemImage: isFav ? "star.slash.fill" : "star.fill")
            }
            .tint(Theme.glow)
        }
        .contextMenu {
            Button {
                toggleFavorite(p.id)
            } label: {
                Label(isFav ? "즐겨찾기 해제" : "즐겨찾기에 추가",
                      systemImage: isFav ? "star.slash" : "star")
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, count: Int,
                                leadingIcon: String? = nil,
                                iconColor: Color = Theme.mist) -> some View {
        HStack(spacing: 6) {
            if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.mist)
                .tracking(0.6)
            Spacer()
            Text("\(count)")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.mist)
        }
        .textCase(nil)
    }
}

private struct PresetRow: View {
    let preset: Preset
    let curriculum: Curriculum
    var isFavorite: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(curriculum.accent.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: preset.kind.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(curriculum.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(preset.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.glowText)
                    }
                }
                if !preset.subtitle.isEmpty {
                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.mist)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Text(preset.category.rawValue)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.mist)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.crest)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RootSplitView()
}

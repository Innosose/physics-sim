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
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(c.accent.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: c.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(c.accent)
                            }
                            Text(c.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("이문데")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("이런 문제 데이터베이스")
                        .font(.system(size: 11))
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
                    .background(ImunDeBackground(topGlow: Theme.glow.opacity(0.10)))
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
                    },
                    onSelectPreset: { p in
                        sidebarItem = .curriculum(p.curriculum)
                        detailSelection = .preset(p)
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
    var onSelectPreset: ((Preset) -> Void)? = nil

    @State private var heroIn = false
    @State private var titleIn = false
    @State private var subIn = false
    @State private var underlineProgress: CGFloat = 0
    @State private var statsIn = false
    @State private var featuredIn = false
    @State private var rowsIn = [false, false, false]
    @State private var footerIn = false
    @State private var featured: Preset? = nil

    private static let uniquePresets: [Preset] = {
        var seen = Set<String>()
        var out: [Preset] = []
        for c in Curriculum.allCases {
            for (_, presets) in PresetCatalog.grouped(for: c) {
                for p in presets where seen.insert(p.id).inserted {
                    out.append(p)
                }
            }
        }
        return out
    }()

    private static let totalSimCount: Int = uniquePresets.count
    private static let totalCategoryCount: Int = {
        Set(uniquePresets.map { $0.category }).count
    }()

    private let rows: [(curriculum: Curriculum, sub: String)] = [
        (.middle, "역학·빛·회로·열"),
        (.high, "물리Ⅰ·Ⅱ 전 범위"),
        (.free, "자유 시뮬레이션"),
    ]

    var body: some View {
        ZStack {
            ImunDeBackground()
            ScrollView {
                VStack(spacing: 22) {
                    heroSection
                    statsRow
                    featuredCard
                    curriculumStack
                    footer
                }
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: animateIn)
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            OrbitMascot()
                .frame(width: 64, height: 64)
                .opacity(heroIn ? 1 : 0)
                .scaleEffect(heroIn ? 1 : 0.55)
            Text("이문데")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.ink)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 10)
            Text("인터랙티브 물리 시뮬레이션")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mist)
                .opacity(subIn ? 1 : 0)
                .offset(y: subIn ? 0 : 6)
            Rectangle()
                .fill(Theme.glow)
                .frame(width: underlineProgress * 48, height: 3)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.7).delay(0.40),
                           value: underlineProgress)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statBlock(value: "\(Self.totalSimCount)", label: "시뮬레이션")
            statDivider
            statBlock(value: "\(Self.totalCategoryCount)", label: "카테고리")
            statDivider
            statBlock(value: "3", label: "학년")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Theme.surface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .opacity(statsIn ? 1 : 0)
        .offset(y: statsIn ? 0 : 10)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.mist)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 26)
    }

    @ViewBuilder
    private var featuredCard: some View {
        if let f = featured {
            Button {
                onSelectPreset?(f)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.glow)
                        Text("오늘의 시뮬레이션")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.mist)
                            .tracking(0.6)
                        Spacer()
                    }
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(f.curriculum.accent.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: f.kind.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(f.curriculum.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(f.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            if !f.subtitle.isEmpty {
                                Text(f.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.mist)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if let formula = f.formula {
                        Text(formula)
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(Theme.mist.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("열기")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.glow)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.glow.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: Theme.ink.opacity(0.06), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.chipPress)
            .opacity(featuredIn ? 1 : 0)
            .offset(y: featuredIn ? 0 : 12)
        }
    }

    private var curriculumStack: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { i in
                let item = rows[i]
                Button {
                    onSelectCurriculum?(item.curriculum)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(item.curriculum.accent.opacity(0.10))
                                .frame(width: 36, height: 36)
                            Image(systemName: item.curriculum.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(item.curriculum.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.curriculum.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(item.sub)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.mist)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.mist.opacity(0.45))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 1)
                    )
                    .shadow(color: Theme.ink.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.chipPress)
                .opacity(rowsIn[i] ? 1 : 0)
                .offset(y: rowsIn[i] ? 0 : 12)
            }
        }
    }

    private var footer: some View {
        Text(hasSidebarSelection
             ? "목록에서 시뮬레이션을 선택하세요"
             : "사이드바에서 학년을 선택하세요")
            .font(.system(size: 12))
            .foregroundStyle(Theme.mist.opacity(0.6))
            .opacity(footerIn ? 1 : 0)
            .padding(.top, 4)
    }

    private func animateIn() {
        if featured == nil {
            featured = Self.uniquePresets.randomElement()
        }
        guard !titleIn else { return }
        withAnimation(.spring(duration: 0.6)) { heroIn = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.10)) { titleIn = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.22)) { subIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            underlineProgress = 1
        }
        withAnimation(.spring(duration: 0.5).delay(0.40)) { statsIn = true }
        withAnimation(.spring(duration: 0.55).delay(0.55)) { featuredIn = true }
        for i in 0..<rowsIn.count {
            withAnimation(.spring(duration: 0.5).delay(0.78 + Double(i) * 0.08)) {
                rowsIn[i] = true
            }
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.10)) { footerIn = true }
    }
}

// MARK: - OrbitMascot — live binary-orbit canvas as the welcome hero.

private struct OrbitMascot: View {
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, sz in
                let t = tl.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let r1 = min(sz.width, sz.height) * 0.36
                let r2 = r1 * 0.55

                let outer = Path(ellipseIn: CGRect(
                    x: center.x - r1, y: center.y - r1,
                    width: r1 * 2, height: r1 * 2))
                ctx.stroke(outer,
                           with: .color(Theme.mist.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 0.7, dash: [2, 3]))

                // Trail behind outer planet
                let omega1 = 2 * Double.pi / 4.2
                var trail = Path()
                let nSamples = 20
                for i in 0..<nSamples {
                    let dt = Double(i) * 0.045
                    let a = (t - dt) * omega1
                    let p = CGPoint(
                        x: center.x + cos(a) * r1,
                        y: center.y + sin(a) * r1)
                    if i == 0 { trail.move(to: p) } else { trail.addLine(to: p) }
                }
                ctx.stroke(trail,
                           with: .color(Theme.ink.opacity(0.14)),
                           style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

                // Central star
                let starR: CGFloat = 4.5
                ctx.fill(Path(ellipseIn: CGRect(
                    x: center.x - starR, y: center.y - starR,
                    width: starR * 2, height: starR * 2)),
                         with: .color(Theme.glow))

                // Outer planet (ink)
                let a1 = t * omega1
                let p1 = CGPoint(
                    x: center.x + cos(a1) * r1,
                    y: center.y + sin(a1) * r1)
                ctx.fill(Path(ellipseIn: CGRect(
                    x: p1.x - 3, y: p1.y - 3, width: 6, height: 6)),
                         with: .color(Theme.ink))

                // Inner planet (mist, retrograde)
                let omega2 = -2 * Double.pi / 2.5
                let a2 = t * omega2
                let p2 = CGPoint(
                    x: center.x + cos(a2) * r2,
                    y: center.y + sin(a2) * r2)
                ctx.fill(Path(ellipseIn: CGRect(
                    x: p2.x - 2, y: p2.y - 2, width: 4, height: 4)),
                         with: .color(Theme.mist))
            }
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
                        iconColor: Theme.glow)
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
                    prompt: "제목·공식·개념 검색")
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
                    .font(.system(size: 9))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.mist)
                .tracking(0.6)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.mist.opacity(0.6))
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(curriculum.accent.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: preset.kind.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(curriculum.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(preset.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.glow)
                    }
                }
                if !preset.subtitle.isEmpty {
                    Text(preset.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mist)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Text(preset.category.rawValue)
                .font(.system(size: 10, weight: .medium))
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

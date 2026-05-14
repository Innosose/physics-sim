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
        .onChange(of: sidebarItem) { _, _ in detailSelection = nil }
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
                WelcomeView()
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
    @State private var titleIn = false
    @State private var subIn = false
    @State private var underlineProgress: CGFloat = 0
    @State private var rowsIn = [false, false, false]
    @State private var footerIn = false

    private let rows: [(curriculum: Curriculum, sub: String)] = [
        (.middle, "역학·빛·회로·열"),
        (.high, "물리Ⅰ·Ⅱ 전 범위"),
        (.free, "자유 시뮬레이션"),
    ]

    var body: some View {
        ZStack {
            ImunDeBackground()
            VStack(spacing: 24) {
                VStack(spacing: 5) {
                    Text("이문데")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .opacity(titleIn ? 1 : 0)
                        .offset(y: titleIn ? 0 : 12)
                    Text("이런 문제 데이터베이스")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mist)
                        .opacity(subIn ? 1 : 0)
                        .offset(y: subIn ? 0 : 6)
                }
                Rectangle()
                    .fill(Theme.glow)
                    .frame(width: underlineProgress * 48, height: 3)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.7).delay(0.38), value: underlineProgress)
                VStack(spacing: 6) {
                    ForEach(rows.indices, id: \.self) { i in
                        let item = rows[i]
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
                        .opacity(rowsIn[i] ? 1 : 0)
                        .offset(y: rowsIn[i] ? 0 : 12)
                    }
                }
                .frame(maxWidth: 340)
                Text("사이드바에서 학년을 선택하세요")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mist.opacity(0.6))
                    .opacity(footerIn ? 1 : 0)
            }
            .padding(24)
        }
        .ignoresSafeArea()
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        guard !titleIn else { return }
        withAnimation(.easeOut(duration: 0.5)) { titleIn = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) { subIn = true }
        withAnimation(.none) { underlineProgress = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            underlineProgress = 1
        }
        for i in 0..<rowsIn.count {
            withAnimation(.spring(duration: 0.5).delay(0.55 + Double(i) * 0.10)) {
                rowsIn[i] = true
            }
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.95)) { footerIn = true }
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
                            PresetRow(preset: p, curriculum: curriculum)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(cat.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.mist)
                            .tracking(0.6)
                        Spacer()
                        Text("\(presets.count)")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(Theme.mist.opacity(0.6))
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ImunDeBackground())
        .navigationTitle(curriculum.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PresetRow: View {
    let preset: Preset
    let curriculum: Curriculum

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
                Text(preset.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
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

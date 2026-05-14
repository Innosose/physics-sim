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

    private let rows: [(title: String, sub: String, color: Color)] = [
        ("중학교", "역학·빛·회로·열", Curriculum.middle.accent),
        ("고등학교", "물리Ⅰ·Ⅱ 전 범위", Curriculum.high.accent),
        ("샌드박스", "자유 시뮬레이션", Curriculum.free.accent),
    ]

    var body: some View {
        ZStack {
            ImunDeBackground(topGlow: Theme.glow.opacity(0.12))
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("이문데")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .opacity(titleIn ? 1 : 0)
                        .offset(y: titleIn ? 0 : 14)
                    Text("이런 문제 데이터베이스")
                        .font(.title3)
                        .foregroundStyle(Theme.mist)
                        .opacity(subIn ? 1 : 0)
                        .offset(y: subIn ? 0 : 8)
                }
                SketchyLineShape(jitter: 1.0, seed: 0xAA55AA55)
                    .trim(from: 0, to: underlineProgress)
                    .stroke(Theme.glow, style: StrokeStyle(lineWidth: 2.2,
                                                            lineCap: .round))
                    .frame(width: 64, height: 8)
                VStack(spacing: 8) {
                    ForEach(rows.indices, id: \.self) { i in
                        let item = rows[i]
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(item.color)
                                .frame(width: 3, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(item.sub)
                                    .font(.caption)
                                    .foregroundStyle(Theme.mist)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.surface.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.ink.opacity(0.45), lineWidth: 1.1)
                        )
                        .opacity(rowsIn[i] ? 1 : 0)
                        .offset(y: rowsIn[i] ? 0 : 14)
                    }
                }
                .frame(maxWidth: 320)
                Text("사이드바에서 학년을 선택하세요")
                    .font(.footnote)
                    .foregroundStyle(Theme.mist.opacity(0.7))
                    .opacity(footerIn ? 1 : 0)
            }
            .padding(24)
        }
        .ignoresSafeArea()
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        guard !titleIn else { return }
        withAnimation(.easeOut(duration: 0.55)) { titleIn = true }
        withAnimation(.easeOut(duration: 0.55).delay(0.18)) { subIn = true }
        withAnimation(.easeInOut(duration: 0.7).delay(0.38)) {
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
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(curriculum.accent)
                                    .frame(width: 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    if !p.subtitle.isEmpty {
                                        Text(p.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Theme.mist)
                                            .lineLimit(2)
                                    }
                                }
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

#Preview {
    RootSplitView()
}

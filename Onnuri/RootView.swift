import SwiftUI

/// 앱의 최상위 화면. NavigationSplitView 로 좌측 카탈로그, 우측 시뮬 표시.
struct RootView: View {
    @State private var selection: SimulationItem? = SimulationCatalog.all.first

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SimulationCatalog.byCategory, id: \.0) { (cat, items) in
                    Section {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(item.title).font(.body)
                                        Text(item.level)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.18),
                                                        in: Capsule())
                                    }
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        Label(cat.rawValue, systemImage: cat.systemImage)
                    }
                }
            }
            .navigationTitle("온누리")
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        } detail: {
            if let s = selection {
                SimulationCatalog.view(for: s)
            } else {
                WelcomeView()
            }
        }
    }
}

private struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("온누리")
                .font(.largeTitle.bold())
            Text("대학교 2학년까지의 물리를 눈으로 보는 시뮬레이션 모음")
                .foregroundStyle(.secondary)
            Text("왼쪽 목록에서 주제를 골라 보세요.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

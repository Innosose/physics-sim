import SwiftUI

/// 한 학년(또는 자유) 안의 시뮬 목록 — outliner 풍 (카테고리 → 시뮬 행).
///
/// 카테고리(역학·파동·전자기·…) 별로 섹션을 만들고, 그 안에 시뮬 행을 단정하게 나열.
struct CurriculumView: View {
    let curriculum: Curriculum

    var body: some View {
        let groups = SimulationCatalog.grouped(for: curriculum)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 짧은 헤더 — 학년·시뮬 개수.
                summary
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ForEach(groups, id: \.0) { (cat, items) in
                    Section {
                        VStack(spacing: 10) {
                            ForEach(items) { item in
                                NavigationLink(value: item) {
                                    SimRow(item: item, accent: curriculum.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                    } header: {
                        sectionHeader(cat)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(background)
        .navigationTitle(curriculum.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SimulationItem.self) { item in
            SimulationCatalog.view(for: item.id)
                .environment(\.simulationItem, item)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var summary: some View {
        let items = SimulationCatalog.items(for: curriculum)
        return HStack(spacing: 10) {
            Image(systemName: curriculum.iconSystemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(curriculum.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(curriculum.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Text("\(items.count) 개 시뮬")
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.mist)
            }
            Spacer()
        }
        .padding(14)
        .themeCard(cornerRadius: 14)
        .padding(.horizontal, 4)
    }

    private func sectionHeader(_ cat: SimCategory) -> some View {
        HStack(spacing: 6) {
            Image(systemName: cat.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(curriculum.accent.opacity(0.85))
            Text(cat.rawValue.uppercased())
                .font(.themeHeader)
                .foregroundStyle(Theme.mist)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private var background: some View {
        ZStack {
            Theme.deep.ignoresSafeArea()
            RadialGradient(
                colors: [curriculum.accent.opacity(0.10), .clear],
                center: .topLeading, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
        }
    }
}

private struct SimRow: View {
    let item: SimulationItem
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: item.category.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
                    .lineLimit(2)
                // 교육과정 단원 칩 — 들어가기 전부터 어느 단원인지 보이도록.
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(item.curriculum)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.glow.opacity(0.85))
                .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.mist.opacity(0.6))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .themeCard(cornerRadius: 14)
    }
}

#Preview {
    NavigationStack {
        CurriculumView(curriculum: .high)
    }
}

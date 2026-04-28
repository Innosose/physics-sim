import SwiftUI

/// 한 학년(또는 자유) 안의 시뮬 목록. 시작화면 다음 단계.
struct CurriculumView: View {
    let curriculum: Curriculum

    var body: some View {
        let groups = SimulationCatalog.grouped(for: curriculum)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(groups, id: \.0) { (cat, items) in
                    Section {
                        VStack(spacing: 12) {
                            ForEach(items) { item in
                                NavigationLink(value: item) {
                                    SimRow(item: item, accent: curriculum.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Label(cat.rawValue, systemImage: cat.systemImage)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(background)
        .navigationTitle(curriculum.rawValue)
        .navigationDestination(for: SimulationItem.self) { item in
            SimulationCatalog.view(for: item.id)
                .navigationTitle(item.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.05, blue: 0.10),
                Color(red: 0.02, green: 0.03, blue: 0.07)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct SimRow: View {
    let item: SimulationItem
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: item.category.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body.weight(.semibold))
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: 720)
        .glassCard(cornerRadius: 18)
        .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack {
        CurriculumView(curriculum: .high)
    }
}

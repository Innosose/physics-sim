import SwiftUI

/// 시작화면 — 학년 선택 + 자유 시뮬 진입.
///
/// 윤슬 디자인 — 위쪽에 앱 표제, 가운데 학년 타일 3개, 그 아래 작은 자유 시뮬 링크.
struct StartView: View {
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let portrait = geo.size.height > geo.size.width
                ZStack {
                    background
                    VStack(spacing: 0) {
                        Spacer(minLength: portrait ? 36 : 12)
                        header
                        Spacer(minLength: 12)
                        tiles(portrait: portrait)
                            .padding(.horizontal, portrait ? 18 : 28)
                        Spacer(minLength: 16)
                        freeSimLink
                            .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationDestination(for: Curriculum.self) { c in
                CurriculumView(curriculum: c)
            }
        }
    }

    // MARK: - 구성요소

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.glow)
                    .frame(width: 8, height: 8)
                Text("ONNURI")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.mist)
            }
            Text("온누리")
                .font(.themeTitle)
                .foregroundStyle(Theme.ink)
            Text("물리를 눈으로 보는 시뮬레이션 모음")
                .font(.callout)
                .foregroundStyle(Theme.mist)
            // 윤슬 — 표제 아래 작은 금빛 잔물결.
            RippleAccent()
                .frame(width: 96, height: 10)
                .padding(.top, 2)
        }
    }

    private func tiles(portrait: Bool) -> some View {
        Group {
            if portrait {
                VStack(spacing: 12) { tileList }
            } else {
                HStack(alignment: .top, spacing: 12) { tileList }
            }
        }
    }

    @ViewBuilder
    private var tileList: some View {
        ForEach([Curriculum.elementary, .middle, .high]) { c in
            NavigationLink(value: c) {
                GradeTile(curriculum: c,
                          count: SimulationCatalog.items(for: c).count)
            }
            .buttonStyle(.plain)
        }
    }

    private var freeSimLink: some View {
        NavigationLink(value: Curriculum.free) {
            HStack(spacing: 8) {
                Image(systemName: Curriculum.free.iconSystemName)
                    .font(.footnote.weight(.semibold))
                Text(Curriculum.free.rawValue)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .tint(Theme.accent)
    }

    private var background: some View {
        // 윤슬 배경 — 깊은 밤바다 + 위쪽 금빛 광원 + 별자리.
        YunseulBackground(topGlow: Theme.glow.opacity(0.18), stars: true)
    }
}

// MARK: - 학년 타일

private struct GradeTile: View {
    let curriculum: Curriculum
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(curriculum.accent.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: curriculum.iconSystemName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(curriculum.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(curriculum.rawValue)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                    Text("\(count)").font(.themeMonoBold)
                        .foregroundStyle(Theme.mist)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.crest,
                                    in: Capsule())
                }
                Text(curriculum.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.mist)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.mist)
        }
        .padding(18)
        .frame(maxWidth: 720, minHeight: 92)
        .themeCard(cornerRadius: 18)
        .shadow(color: curriculum.accent.opacity(0.16), radius: 22, x: 0, y: 10)
    }
}

#Preview { StartView() }

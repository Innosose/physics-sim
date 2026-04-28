import SwiftUI

/// 시작화면 — 학년 선택 + 자유 시뮬 진입.
///
/// Blender 모바일 풍 — 위쪽에 앱 표제, 가운데 학년 타일 3개, 그 아래 작은 자유 시뮬 링크.
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
                    .fill(BlenderTheme.accent)
                    .frame(width: 8, height: 8)
                Text("ONNURI")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(BlenderTheme.dimText)
            }
            Text("온누리")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(BlenderTheme.monoText)
            Text("물리를 눈으로 보는 시뮬레이션 모음")
                .font(.callout)
                .foregroundStyle(BlenderTheme.dimText)
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
        .tint(BlenderTheme.highlight)
    }

    private var background: some View {
        ZStack {
            BlenderTheme.viewportBg.ignoresSafeArea()
            // 살짝 떠 있는 광원.
            RadialGradient(
                colors: [BlenderTheme.accent.opacity(0.12), .clear],
                center: .top, startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
            // 미세 dot.
            DotPattern()
                .opacity(0.10)
                .ignoresSafeArea()
        }
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
                        .foregroundStyle(BlenderTheme.monoText)
                    Text("\(count)").font(.blenderMonoBold)
                        .foregroundStyle(BlenderTheme.dimText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(BlenderTheme.header,
                                    in: Capsule())
                }
                Text(curriculum.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BlenderTheme.dimText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BlenderTheme.dimText)
        }
        .padding(18)
        .frame(maxWidth: 720, minHeight: 92)
        .blenderCard(cornerRadius: 18)
        .shadow(color: curriculum.accent.opacity(0.16), radius: 22, x: 0, y: 10)
    }
}

private struct DotPattern: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 32
            let r: CGFloat = 1.0
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: x - r, y: y - r,
                                      width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(0.45)))
                    y += step
                }
                x += step
            }
        }
    }
}

#Preview { StartView() }

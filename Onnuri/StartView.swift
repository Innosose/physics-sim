import SwiftUI

/// 앱의 첫 화면. 큰 학년 타일 3개 + 그 아래 작은 "자유 시뮬레이션" 링크.
struct StartView: View {
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isPortrait = geo.size.height > geo.size.width
                ZStack {
                    background
                    VStack(spacing: 24) {
                        Spacer(minLength: isPortrait ? 60 : 24)
                        header
                        Spacer(minLength: 0)

                        Group {
                            if isPortrait {
                                VStack(spacing: 16) { gradeTiles }
                                    .padding(.horizontal, 24)
                            } else {
                                HStack(spacing: 16) { gradeTiles }
                                    .padding(.horizontal, 32)
                            }
                        }

                        Spacer(minLength: 12)
                        freeSimLink
                            .padding(.bottom, 24)
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
        VStack(spacing: 6) {
            Text("온누리")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("물리를 눈으로 보는 시뮬레이션 모음")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var gradeTiles: some View {
        ForEach([Curriculum.elementary, .middle, .high]) { c in
            NavigationLink(value: c) {
                GradeTile(curriculum: c)
            }
            .buttonStyle(.plain)
        }
    }

    private var freeSimLink: some View {
        NavigationLink(value: Curriculum.free) {
            HStack(spacing: 8) {
                Image(systemName: Curriculum.free.iconSystemName)
                Text(Curriculum.free.rawValue)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .tint(Curriculum.free.accent)
    }

    private var background: some View {
        // 학년 타일과 어울리는 그라데이션 배경.
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.06, blue: 0.12),
                Color(red: 0.02, green: 0.04, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            // 부드러운 광원 한 점.
            RadialGradient(colors: [Color.white.opacity(0.10), .clear],
                           center: .top, startRadius: 0, endRadius: 380)
                .ignoresSafeArea()
        }
    }
}

/// 학년 큰 타일 — Liquid Glass + 강조색 그림자.
private struct GradeTile: View {
    let curriculum: Curriculum

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(curriculum.accent.opacity(0.25))
                    .frame(width: 64, height: 64)
                Image(systemName: curriculum.iconSystemName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(curriculum.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(curriculum.rawValue)
                    .font(.title2.bold())
                Text(curriculum.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: 720, minHeight: 100)
        .glassCard(cornerRadius: 28)
        .shadow(color: curriculum.accent.opacity(0.18), radius: 24, x: 0, y: 8)
    }
}

#Preview {
    StartView()
}

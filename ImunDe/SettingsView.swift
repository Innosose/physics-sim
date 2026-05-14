import SwiftUI

struct SettingsView: View {
    @AppStorage("themeMode") private var themeModeRaw: String = ThemeMode.system.rawValue
    @Environment(\.dismiss) private var dismiss

    private var themeMode: Binding<ThemeMode> {
        Binding(
            get: { ThemeMode(rawValue: themeModeRaw) ?? .system },
            set: { themeModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ImunDeBackground(topGlow: Theme.glow.opacity(0.06))
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        section(title: "테마") {
                            PaperPicker(selection: themeMode,
                                         options: ThemeMode.allCases) { $0.label }
                        }
                        section(title: "정보") {
                            HStack {
                                Text("이문데")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("0.4")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(Theme.mist)
                            }
                            Text("이런 문제 데이터베이스 — 인터랙티브 물리 시뮬레이션")
                                .font(.caption)
                                .foregroundStyle(Theme.mist)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 520)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String,
                                         @ViewBuilder content: () -> Content)
        -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.themeHeader)
                .foregroundStyle(Theme.mist)
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surface.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        }
    }
}

enum ThemeMode: String, CaseIterable, Identifiable, Hashable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "시스템"
        case .light:  return "라이트"
        case .dark:   return "다크"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

#Preview {
    SettingsView()
}

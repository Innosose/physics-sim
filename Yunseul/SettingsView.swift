import SwiftUI

/// 사용자 설정 — 테마만.
///
/// 테마는 `AppStorage("themeMode")` 에 저장되며, `.preferredColorScheme(_:)`
/// 으로 앱 루트에 적용된다. 시스템(자동) / 라이트 / 다크 세 옵션.
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
            Form {
                Section("테마") {
                    Picker("테마", selection: themeMode) {
                        ForEach(ThemeMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
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
}

/// 테마 선택지. `AppStorage` 에 raw String 으로 저장.
enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "시스템"
        case .light:  return "라이트"
        case .dark:   return "다크"
        }
    }

    /// `.preferredColorScheme(_:)` 에 전달할 값. `nil` 이면 시스템 따라감.
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

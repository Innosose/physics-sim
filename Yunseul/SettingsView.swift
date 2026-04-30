import SwiftUI

/// 사용자 설정 — 테마(외관) 만.
///
/// 테마는 `AppStorage("appearance")` 에 저장되며, `.preferredColorScheme(_:)`
/// 으로 앱 루트에 적용된다. 시스템(자동) / 라이트 / 다크 세 옵션.
struct SettingsView: View {
    @AppStorage("appearance") private var appearanceRaw: String = Appearance.system.rawValue
    @Environment(\.dismiss) private var dismiss

    private var appearance: Binding<Appearance> {
        Binding(
            get: { Appearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("외관", selection: appearance) {
                        ForEach(Appearance.allCases) { a in
                            Text(a.label).tag(a)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("테마")
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

/// 외관 선택지. `AppStorage` 에 raw String 으로 저장.
enum Appearance: String, CaseIterable, Identifiable {
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

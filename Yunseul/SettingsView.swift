import SwiftUI

/// 사용자 설정 — 외관(테마) · 정보.
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
                    Text("외관")
                } footer: {
                    Text("시스템 — 기기 설정을 따라감.  라이트 — 밝은 테마.  다크 — 어두운 테마.")
                        .font(.caption)
                }

                Section {
                    LabeledContent("이름", value: "윤슬 (Yunseul)")
                    LabeledContent("뜻", value: "햇빛·달빛에 어린 잔물결 — 순우리말")
                    LabeledContent("대상", value: "중·고등학생")
                    LabeledContent("버전", value: "0.5")
                } header: {
                    Text("앱 정보")
                }

                Section {
                    Text("각 시뮬은 세 가지 방식으로 계산됩니다 — ConceptCard 우상단 뱃지로 표시.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("· 닫힌 해 — 시각 t 의 수식을 직접 풀어 정확한 값 (예: 진자·케플러).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("· 이벤트 기반 — 사이는 등속·임펄스만 닫힌 해 (예: 충돌·기체).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("· 수치 — 닫힌 해가 없는 다체 문제는 Velocity-Verlet 적분 (N체 중력).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("포물선 운동 시뮬은 2D / 3D 토글로 시점을 회전·줌 할 수 있습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("계산 원리")
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

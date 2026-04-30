import SwiftUI

@main
struct YunseulApp: App {
    @AppStorage("themeMode") private var themeModeRaw: String = ThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .preferredColorScheme(
                    (ThemeMode(rawValue: themeModeRaw) ?? .system).colorScheme)
                .tint(Theme.glow)
                // Theme.adaptive 는 UITraitCollection 기반 dynamic UIColor 를 쓰는데,
                // SwiftUI 의 .preferredColorScheme 변경 직후 trait collection 갱신이
                // 즉각 반영되지 않는 케이스가 있다. 루트에 .id 를 묶어 테마가 바뀌면
                // view tree 자체를 새로 만들어 모든 색을 강제로 다시 풀게 한다.
                .id(themeModeRaw)
        }
    }
}

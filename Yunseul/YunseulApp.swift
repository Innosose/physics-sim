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
        }
    }
}

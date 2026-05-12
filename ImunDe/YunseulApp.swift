import SwiftUI

@main
struct ImunDeApp: App {
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

import SwiftUI

@main
struct YunseulApp: App {
    @AppStorage("appearance") private var appearanceRaw: String = Appearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .preferredColorScheme(
                    (Appearance(rawValue: appearanceRaw) ?? .system).colorScheme)
                .tint(Theme.glow)
        }
    }
}

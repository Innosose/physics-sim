import SwiftUI

@main
struct YunseulApp: App {
    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .preferredColorScheme(.dark)
                .tint(Theme.glow)
        }
    }
}

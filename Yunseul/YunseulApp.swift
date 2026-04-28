import SwiftUI

@main
struct YunseulApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
                .preferredColorScheme(.dark)
                .tint(Theme.glow)
        }
    }
}

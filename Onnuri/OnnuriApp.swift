import SwiftUI

@main
struct OnnuriApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
                .preferredColorScheme(.dark)
                .tint(BlenderTheme.accent)
        }
    }
}

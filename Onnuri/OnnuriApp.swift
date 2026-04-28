import SwiftUI

@main
struct OnnuriApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        #endif
    }
}

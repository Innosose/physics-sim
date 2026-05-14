import SwiftUI

@main
struct ImunDeApp: App {
    @AppStorage("themeMode") private var themeModeRaw: String = ThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .preferredColorScheme(
                    (ThemeMode(rawValue: themeModeRaw) ?? .system).colorScheme)
                .tint(Theme.glow)
        }
    }
}

private struct AppRoot: View {
    @State private var showSplash: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            RootSplitView()
                .opacity(showSplash ? 0 : 1)
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        // Total splash time before fading out.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                            if reduceMotion { showSplash = false }
                            else {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    showSplash = false
                                }
                            }
                        }
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: showSplash)
    }
}

private struct SplashView: View {
    @State private var titleIn = false
    @State private var barW: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ImunDeBackground()
            VStack(spacing: 10) {
                Text("이문데")
                    // Dynamic Type 상한만 캡 — 초대형 텍스트로 splash 가
                    // 망가지는 것 방지. .largeTitle 기반 weight 처리.
                    .font(.largeTitle.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(Theme.ink)
                    .opacity(titleIn ? 1 : 0)
                Capsule()
                    .fill(Theme.glow)
                    .frame(width: barW, height: 3)
            }
        }
        .onAppear {
            if reduceMotion {
                titleIn = true
                barW = 48
            } else {
                withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
                withAnimation(.easeInOut(duration: 0.55).delay(0.25)) { barW = 48 }
            }
        }
    }
}

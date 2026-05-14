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
                            withAnimation(.easeInOut(duration: 0.45)) {
                                showSplash = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showSplash)
    }
}

private struct SplashView: View {
    @State private var titleIn = false
    @State private var subIn = false
    @State private var trim: CGFloat = 0

    var body: some View {
        ZStack {
            ImunDeBackground(topGlow: Theme.glow.opacity(0.10))
            VStack(spacing: 10) {
                Text("이문데")
                    .font(.system(size: 64, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 12)
                Text("이런 문제 데이터베이스")
                    .font(.title3)
                    .foregroundStyle(Theme.mist)
                    .opacity(subIn ? 1 : 0)
                SketchyLineShape(jitter: 1.1, seed: 0x5A5A5A5A)
                    .trim(from: 0, to: trim)
                    .stroke(Theme.glow,
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: 92, height: 10)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { titleIn = true }
            withAnimation(.easeOut(duration: 0.55).delay(0.22)) { subIn = true }
            withAnimation(.easeInOut(duration: 0.7).delay(0.42)) { trim = 1 }
        }
    }
}

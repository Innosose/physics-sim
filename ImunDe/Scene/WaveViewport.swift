import SwiftUI

struct WaveViewport: View {
    let scene: Preset.WaveScene

    var body: some View {
        ZStack {
            Theme.deep
            switch scene {
            case .waveSum: WaveSumView()
            case .doppler: DopplerView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct WaveSumView: View {
    @State private var f1: Double = 1.0
    @State private var f2: Double = 1.1
    @State private var oppose: Bool = false
    @State private var elapsed: Double = 0
    @State private var lastTick: TimeInterval? = nil
    @State private var running: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size, t: elapsed)
                }
                .onChange(of: tl.date) { _, newDate in
                    advance(to: newDate.timeIntervalSinceReferenceDate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("f₁", value: $f1, range: 0.1...4, unit: "Hz")
                slider("f₂", value: $f2, range: 0.1...4, unit: "Hz")
                Toggle("두 번째 파 반대 진행 (정상파)", isOn: $oppose).font(.caption)
                playReset
            }
        }
        .padding(8)
    }

    private var playReset: some View {
        HStack(spacing: 8) {
            Button {
                running.toggle()
            } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.glow)

            Button {
                elapsed = 0; lastTick = nil; running = false
            } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTick else { lastTick = now; return }
        guard running else { lastTick = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTick = now
        elapsed += dt
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            Slider(value: value, in: range).tint(Theme.glow)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let h = size.height / 3
        drawWave(ctx, in: CGRect(x: 0, y: 0, width: size.width, height: h),
                 amp: 1, omega: 2 * .pi * f1, t: t, sign: 1, color: .cyan)
        drawWave(ctx, in: CGRect(x: 0, y: h, width: size.width, height: h),
                 amp: 1, omega: 2 * .pi * f2, t: t, sign: oppose ? -1 : 1, color: .pink)
        drawSum(ctx, in: CGRect(x: 0, y: 2 * h, width: size.width, height: h), t: t)
    }

    private func drawWave(_ ctx: GraphicsContext, in r: CGRect,
                          amp: Double, omega: Double, t: Double,
                          sign: Double, color: Color) {
        var path = Path()
        let n = 400
        let xMax = 12.0
        let amplitudePx = r.height * 0.4
        for i in 0...n {
            let f = Double(i) / Double(n)
            let x = f * xMax
            let y = amp * sin(x - sign * omega * t)
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amplitudePx / 1.5
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(color), lineWidth: 1.6)
    }

    private func drawSum(_ ctx: GraphicsContext, in r: CGRect, t: Double) {
        var path = Path()
        let n = 600
        let xMax = 12.0
        let s2: Double = oppose ? -1 : 1
        let ω1 = 2 * .pi * f1
        let ω2 = 2 * .pi * f2
        let amp = r.height * 0.45
        for i in 0...n {
            let f = Double(i) / Double(n)
            let x = f * xMax
            let y = sin(x - ω1 * t) + sin(x - s2 * ω2 * t)
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amp / 3
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(.yellow), lineWidth: 1.8)
    }
}

private struct DopplerView: View {
    @State private var sourceSpeed: Double = 60
    @State private var soundSpeed: Double = 340
    @State private var freq: Double = 1.5
    @State private var elapsed: Double = 0
    @State private var lastTick: TimeInterval? = nil
    @State private var running: Bool = false

    private var tStop: Double {
        let span: Double = 800
        let xStart = -span / 4
        let xWall = span / 2 - 30
        return sourceSpeed > 0 ? (xWall - xStart) / sourceSpeed : .infinity
    }
    private var sourceAtWall: Bool { elapsed >= tStop }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    draw(ctx: ctx, size: size, t: elapsed)
                }
                .onChange(of: tl.date) { _, newDate in
                    advance(to: newDate.timeIntervalSinceReferenceDate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                slider("v_s", value: $sourceSpeed, range: 0...400, unit: "m/s")
                slider("c", value: $soundSpeed, range: 100...400, unit: "m/s")
                slider("f", value: $freq, range: 0.5...4, unit: "Hz")
                playReset
            }
        }
        .padding(8)
    }

    private var playReset: some View {
        HStack(spacing: 8) {
            Button {
                if !running && sourceAtWall {
                    elapsed = 0; lastTick = nil
                }
                running.toggle()
            } label: {
                Label(running ? "일시정지" : "재생",
                      systemImage: running ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.glow)

            Button {
                elapsed = 0; lastTick = nil; running = false
            } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTick else { lastTick = now; return }
        guard running else { lastTick = now; return }
        var dt = now - last
        if dt > 0.05 { dt = 0.05 }
        lastTick = now
        elapsed += dt
        if sourceAtWall { running = false }
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
            Slider(value: value, in: range).tint(Theme.glow)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.glow)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let span: Double = 800
        let scale = size.width / CGFloat(span)
        let cy = size.height / 2

        let xStart = -span / 4
        let xWall = span / 2 - 30          // 오른쪽 벽 안쪽
        let tStop = sourceSpeed > 0 ? (xWall - xStart) / sourceSpeed : .infinity
        let curT = min(t, tStop)
        let cur = xStart + sourceSpeed * curT

        // 오른쪽 벽 표시.
        let wallPx = CGFloat(xWall + span / 2) * scale
        var wall = Path()
        wall.move(to: CGPoint(x: wallPx, y: cy - 30))
        wall.addLine(to: CGPoint(x: wallPx, y: cy + 30))
        ctx.stroke(wall, with: .color(Theme.ink.opacity(0.5)), lineWidth: 2)

        // 파면들 — 음원 정지 후에도 이미 방출된 파면은 계속 퍼져나감.
        let period = 1 / freq
        let tMax = span / soundSpeed * 1.4
        let kMin = max(0, Int(((t - tMax) / period).rounded(.up)))
        let kMax = Int((curT / period).rounded(.down))
        if kMax >= kMin {
            for k in kMin...kMax {
                let te = Double(k) * period
                let xs = xStart + sourceSpeed * te
                let radius = soundSpeed * (t - te)
                if radius < 0 { continue }
                let center = CGPoint(x: CGFloat(xs + span / 2) * scale, y: cy)
                let rPx = CGFloat(radius) * scale
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: center.x - rPx, y: center.y - rPx,
                                           width: rPx * 2, height: rPx * 2)),
                    with: .color(.cyan.opacity(0.8)), lineWidth: 1)
            }
        }
        let sx = CGFloat(cur + span / 2) * scale
        let sr: CGFloat = 6
        ctx.fill(Path(ellipseIn: CGRect(x: sx - sr, y: cy - sr,
                                         width: sr * 2, height: sr * 2)),
                 with: .color(.yellow))
    }
}

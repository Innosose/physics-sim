import SwiftUI

struct WaveViewport: View {
    let scene: Preset.WaveScene
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Theme.deep
            switch scene {
            case .waveSum: WaveSumView()
            case .doppler: DopplerView()
            }
            CharcoalGrain().allowsHitTesting(false)
        }
        .id(colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct WaveSumView: View {
    enum Axis: String, CaseIterable, Identifiable {
        case space = "공간 x"
        case time  = "시간 t (맥놀이)"
        var id: String { rawValue }
    }

    @State private var f1: Double = 1.0
    @State private var f2: Double = 1.1
    @State private var oppose: Bool = false
    @State private var axis: Axis = .space
    @State private var elapsed: Double = 0
    @State private var lastTick: TimeInterval? = nil
    @State private var running: Bool = true

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
                PaperPicker(selection: $axis,
                             options: Axis.allCases) { $0.rawValue }
                slider("f₁", value: $f1, range: 0.1...4, unit: "Hz")
                slider("f₂", value: $f2, range: 0.1...4, unit: "Hz")
                ChipToggle(title: "두 번째 파 반대 진행 (정상파)",
                            systemImage: "arrow.left.arrow.right",
                            isOn: oppose,
                            alignment: .leading) {
                    oppose.toggle()
                }
                .disabled(axis == .time)
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
            .buttonStyle(.sketchProminent)

            Button {
                elapsed = 0; lastTick = nil; running = false
            } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketch)
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
            PaperSlider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let h = size.height / 3
        drawWave(ctx, in: CGRect(x: 0, y: 0, width: size.width, height: h),
                 amp: 1, omega: 2 * .pi * f1, t: t, sign: 1, dashed: false)
        drawWave(ctx, in: CGRect(x: 0, y: h, width: size.width, height: h),
                 amp: 1, omega: 2 * .pi * f2, t: t,
                 sign: oppose ? -1 : 1, dashed: true)
        drawSum(ctx, in: CGRect(x: 0, y: 2 * h, width: size.width, height: h), t: t)

        let labels: [(String, CGFloat)] = [
            (String(format: "f₁ = %.2f Hz", f1), h * 0.5),
            (String(format: "f₂ = %.2f Hz", f2), h * 1.5),
            ("합성파", h * 2.5),
        ]
        for (label, y) in labels {
            ctx.draw(Text(label)
                        .font(.system(size: 9).monospaced())
                        .foregroundStyle(Theme.mist.opacity(0.7)),
                     at: CGPoint(x: 6, y: y), anchor: .leading)
        }
    }

    private func drawWave(_ ctx: GraphicsContext, in r: CGRect,
                          amp: Double, omega: Double, t: Double,
                          sign: Double, dashed: Bool) {
        var path = Path()
        let n = 400
        let amplitudePx = r.height * 0.4
        for i in 0...n {
            let f = Double(i) / Double(n)
            let y: Double
            if axis == .space {
                let x = f * 12.0
                y = amp * sin(x - sign * omega * t)
            } else {
                let timeWindow = 6.0
                let tau = t - timeWindow * (1 - f)
                y = amp * sin(-omega * tau)
            }
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amplitudePx / 1.5
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        let style: StrokeStyle = dashed
            ? StrokeStyle(lineWidth: 1.3, lineCap: .round,
                          lineJoin: .round, dash: [5, 3])
            : StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        ctx.stroke(path, with: .color(Theme.ink), style: style)
    }

    private func drawSum(_ ctx: GraphicsContext, in r: CGRect, t: Double) {
        var path = Path()
        let n = 600
        let s2: Double = oppose ? -1 : 1
        let ω1 = 2 * .pi * f1
        let ω2 = 2 * .pi * f2
        let amp = r.height * 0.45
        for i in 0...n {
            let f = Double(i) / Double(n)
            let y: Double
            if axis == .space {
                let x = f * 12.0
                y = sin(x - ω1 * t) + sin(x - s2 * ω2 * t)
            } else {
                let timeWindow = 6.0
                let tau = t - timeWindow * (1 - f)
                y = sin(-ω1 * tau) + sin(-ω2 * tau)
            }
            let px = r.minX + CGFloat(f) * r.width
            let py = r.midY - CGFloat(y) * amp / 3
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else      { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        ctx.stroke(path, with: .color(Theme.glow), lineWidth: 1.9)

        if axis == .time && abs(f1 - f2) > 0.001 && !oppose {
            // 맥놀이 포락선
            let beat = abs(f1 - f2)
            let timeWindow = 6.0
            var envUp = Path(), envDn = Path()
            for i in 0...n {
                let f = Double(i) / Double(n)
                let tau = t - timeWindow * (1 - f)
                let env = 2 * abs(cos(.pi * beat * tau))
                let px = r.minX + CGFloat(f) * r.width
                let pyUp = r.midY - CGFloat(env) * amp / 3
                let pyDn = r.midY + CGFloat(env) * amp / 3
                if i == 0 { envUp.move(to: CGPoint(x: px, y: pyUp))
                            envDn.move(to: CGPoint(x: px, y: pyDn)) }
                else      { envUp.addLine(to: CGPoint(x: px, y: pyUp))
                            envDn.addLine(to: CGPoint(x: px, y: pyDn)) }
            }
            ctx.stroke(envUp, with: .color(Theme.ink.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            ctx.stroke(envDn, with: .color(Theme.ink.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
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

    private var derived: (fAhead: Double, fBehind: Double, mach: Double) {
        // 정지 관측자에 대해 음원이 다가올 때 / 멀어질 때
        let denomAhead = max(soundSpeed - sourceSpeed, 1e-9)
        let fAhead = freq * soundSpeed / denomAhead
        let fBehind = freq * soundSpeed / (soundSpeed + sourceSpeed)
        return (fAhead, fBehind, sourceSpeed / soundSpeed)
    }

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
            HStack(spacing: 14) {
                Text(String(format: "f′ 다가올 때 %.2f Hz", derived.fAhead))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(String(format: "멀어질 때 %.2f Hz", derived.fBehind))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(String(format: "M=%.2f", derived.mach))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 4)
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
                Label(playLabel, systemImage: playIcon)
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketchProminent)

            Button {
                elapsed = 0; lastTick = nil; running = false
            } label: {
                Label("처음부터", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sketch)
        }
    }

    private var playLabel: String {
        if running { return "일시정지" }
        if sourceAtWall { return "다시 재생" }
        return "재생"
    }
    private var playIcon: String {
        if running { return "pause.fill" }
        if sourceAtWall { return "arrow.clockwise" }
        return "play.fill"
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
            PaperSlider(value: value, in: range)
            Text(String(format: "%.2f%@", value.wrappedValue, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.ink)
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

        // 오른쪽 벽
        let wallPx = CGFloat(xWall + span / 2) * scale
        Sketchy.line(from: CGPoint(x: wallPx, y: cy - 30),
                     to: CGPoint(x: wallPx, y: cy + 30),
                     ctx: ctx, color: Theme.ink,
                     lineWidth: 1.8, passes: 2, jitter: 0.4)

        // 파면들
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
                Sketchy.circle(center: center, radius: rPx, ctx: ctx,
                                color: Theme.ink.opacity(0.6),
                                lineWidth: 1.0, passes: 1, jitter: 0.02)
            }
        }
        let sx = CGFloat(cur + span / 2) * scale
        Sketchy.fillCircle(center: CGPoint(x: sx, y: cy), radius: 7, ctx: ctx,
                            fill: Theme.glow, stroke: Theme.ink, strokeWidth: 1.4)

        // 음원 레이블
        ctx.draw(Text("음원").font(.caption2.weight(.semibold)).foregroundStyle(Theme.mist),
                 at: CGPoint(x: sx, y: cy - 18))

        // 벽 레이블
        ctx.draw(Text("벽").font(.caption2).foregroundStyle(Theme.mist.opacity(0.7)),
                 at: CGPoint(x: wallPx + 6, y: cy - 20), anchor: .leading)

        // 초음속 경고
        if sourceSpeed >= soundSpeed {
            ctx.draw(Text("초음속 (충격파)")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Theme.glow),
                     at: CGPoint(x: size.width / 2, y: 14))
        }

        // 범례
        ctx.draw(Text("○ 파면   ● 음원")
                    .font(.system(size: 9)).foregroundStyle(Theme.mist.opacity(0.7)),
                 at: CGPoint(x: 8, y: size.height - 10), anchor: .leading)
    }
}

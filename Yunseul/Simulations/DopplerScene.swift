import SwiftUI

/// 도플러 효과 — 움직이는 음원이 주기적으로 방출하는 파면을 그린다.
///
/// 일정 시간 간격 T 마다 그 순간의 음원 위치에서 동심원이 c (음속) 로 퍼져나간다.
/// 음원이 음속에 가까우면 마하원뿔의 평면 단면이 보인다.
struct DopplerScene: View {
    @State private var sourceSpeed: Double = 60     // m/s (음원의 +x 속도)
    @State private var soundSpeed: Double = 340     // m/s
    @State private var freq: Double = 1.5           // Hz (방출 주기 = 1/freq)
    @State private var startTime = Date()
    @State private var running = true

    var body: some View {
        SimChrome(
                  blurb: "음원 앞쪽은 파면이 빽빽 (높은 진동수), 뒤쪽은 듬성듬성 (낮은 진동수). v_s → c 일 때 마하 충격파가 형성된다.",
                  canvas: { canvas },
                  controls: { controls })
    }

    private var canvas: some View {
        TimelineView(.animation(paused: !running)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(startTime)
                draw(ctx: ctx, size: size, t: t)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "음원 속력 v_s", value: $sourceSpeed, range: 0...400,
                          format: "%.0f", unit: "m/s")
            LabeledSlider(title: "음속 c", value: $soundSpeed, range: 100...400,
                          format: "%.0f", unit: "m/s")
            LabeledSlider(title: "방출 진동수 f", value: $freq, range: 0.5...4,
                          format: "%.2f", unit: "Hz")
            HStack {
                Button(running ? "일시정지" : "재생") { running.toggle() }
                Button("처음부터") { startTime = Date(); running = true }
            }
            Divider()
            let mach = sourceSpeed / soundSpeed
            Readout(label: "마하 수 v_s / c", value: String(format: "%.2f", mach))
            if sourceSpeed < soundSpeed {
                let fFront = freq * soundSpeed / (soundSpeed - sourceSpeed)
                let fRear  = freq * soundSpeed / (soundSpeed + sourceSpeed)
                Readout(label: "앞쪽 관측 f′", value: String(format: "%.2f Hz", fFront))
                Readout(label: "뒤쪽 관측 f′", value: String(format: "%.2f Hz", fRear))
            } else {
                Text("초음속 — 마하 원뿔의 평면 단면이 보입니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let span: Double = 800   // m (가로 가시 영역)
        let world = CGRect(x: -span / 2, y: -span / 4, width: span, height: span / 2)
        let map = CanvasMap(view: size, world: world, padding: 10)

        // 음원 현재 위치.
        let cur = Vec2(x: -span / 4 + sourceSpeed * t, y: 0)

        // 시간 구간 [t - tMax, t] 안의 방출 이벤트들을 모두 그린다.
        let period = 1 / freq
        let tMax = span / soundSpeed * 1.4
        let kMin = max(0, Int(((t - tMax) / period).rounded(.up)))
        let kMax = Int((t / period).rounded(.down))
        if kMax >= kMin {
            for k in kMin...kMax {
                let te = Double(k) * period
                let xs = -span / 4 + sourceSpeed * te
                let radius = soundSpeed * (t - te)
                if radius < 0 { continue }
                let center = map.point(x: xs, y: 0)
                let rPx = map.length(radius)
                let rect = CGRect(x: center.x - rPx, y: center.y - rPx,
                                  width: rPx * 2, height: rPx * 2)
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(.cyan.opacity(0.8)), lineWidth: 1)
            }
        }

        // 음원 자취.
        var trail = Path()
        trail.move(to: map.point(x: -span / 4, y: 0))
        trail.addLine(to: map.point(cur))
        ctx.stroke(trail, with: .color(.white.opacity(0.25)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // 음원.
        let sp = map.point(cur)
        let sr: CGFloat = 6
        ctx.fill(Path(ellipseIn: CGRect(x: sp.x - sr, y: sp.y - sr,
                                        width: sr * 2, height: sr * 2)),
                 with: .color(.yellow))
    }
}

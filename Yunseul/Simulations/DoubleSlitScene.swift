import SwiftUI

/// 이중 슬릿 — 간섭과 단일슬릿 회절의 합성 패턴.
///
///  I(θ) = I₀ · cos²(π d sinθ / λ) · [sin(π a sinθ / λ) / (π a sinθ / λ)]²
///
/// 위에는 슬릿 + 막의 모식도, 아래에는 강도 분포 곡선.
struct DoubleSlitScene: View {
    @State private var wavelength: Double = 550   // nm
    @State private var slitSep: Double = 50_000   // nm  (= 50 µm)
    @State private var slitWidth: Double = 8_000  // nm  (= 8 µm)
    @State private var screenDist: Double = 1.5   // m
    @State private var showEnvelope = true

    var body: some View {
        SimChrome(
                  blurb: "좁은 슬릿 두 개를 통과한 빛은 간섭한다. 가는 슬릿일수록 단일슬릿 회절 봉투가 넓어진다.",
                  canvas: { canvas },
                  controls: { controls })
    }

    private var canvas: some View {
        Canvas { ctx, size in draw(ctx: ctx, size: size) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledSlider(title: "파장 λ", value: $wavelength, range: 380...780,
                          format: "%.0f", unit: "nm")
            LabeledSlider(title: "슬릿 간격 d", value: $slitSep, range: 10_000...200_000,
                          format: "%.0f", unit: "nm")
            LabeledSlider(title: "슬릿 폭 a", value: $slitWidth, range: 2_000...30_000,
                          format: "%.0f", unit: "nm")
            LabeledSlider(title: "막까지 거리 D", value: $screenDist, range: 0.3...3,
                          format: "%.2f", unit: "m")
            Toggle("회절 봉투 표시", isOn: $showEnvelope)
            Divider()
            // 첫 번째 보강 무늬 위치 y₁ = λ D / d.
            let y1 = wavelength * 1e-9 * screenDist / (slitSep * 1e-9)
            Readout(label: "이웃 무늬 간격", value: String(format: "%.2f mm", y1 * 1000))
            // 첫 번째 회절 영점 y_a = λ D / a.
            let ya = wavelength * 1e-9 * screenDist / (slitWidth * 1e-9)
            Readout(label: "회절 첫 영점", value: String(format: "%.2f mm", ya * 1000))
        }
    }

    // MARK: - 그리기

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.45)
        let botRect = CGRect(x: 0, y: topRect.maxY, width: size.width,
                             height: size.height - topRect.maxY)
        drawSchematic(ctx: ctx, in: topRect)
        drawIntensity(ctx: ctx, in: botRect)
    }

    private func drawSchematic(ctx: GraphicsContext, in r: CGRect) {
        let leftX = r.minX + 30
        let slitX = r.minX + r.width * 0.38
        let screenX = r.maxX - 30

        // 광원에서 슬릿까지 평면파를 짧은 막대들로.
        for k in 0..<6 {
            let t = CGFloat(k) / 5
            let x = leftX + t * (slitX - leftX)
            var line = Path()
            line.move(to: CGPoint(x: x, y: r.minY + 20))
            line.addLine(to: CGPoint(x: x, y: r.maxY - 20))
            ctx.stroke(line, with: .color(wavelengthColor(wavelength).opacity(0.25)),
                       lineWidth: 1)
        }

        // 슬릿 벽.
        let cy = r.midY
        let slitGap = max(8.0, slitSep / 8000)        // 픽셀
        let slitH   = max(3.0, slitWidth / 4000)      // 픽셀
        var wall = Path()
        wall.move(to: CGPoint(x: slitX, y: r.minY + 20))
        wall.addLine(to: CGPoint(x: slitX, y: cy - CGFloat(slitGap) - CGFloat(slitH) / 2))
        wall.move(to: CGPoint(x: slitX, y: cy - CGFloat(slitGap) + CGFloat(slitH) / 2))
        wall.addLine(to: CGPoint(x: slitX, y: cy + CGFloat(slitGap) - CGFloat(slitH) / 2))
        wall.move(to: CGPoint(x: slitX, y: cy + CGFloat(slitGap) + CGFloat(slitH) / 2))
        wall.addLine(to: CGPoint(x: slitX, y: r.maxY - 20))
        ctx.stroke(wall, with: .color(.white.opacity(0.6)), lineWidth: 3)

        // 슬릿에서 막 방향으로 호이겐스 파 — 동심원으로 표시.
        for sign in [-1, 1] {
            let center = CGPoint(x: slitX, y: cy + CGFloat(sign) * CGFloat(slitGap))
            let waves = 5
            for k in 1...waves {
                let rad: CGFloat = CGFloat(k) * (screenX - slitX) / CGFloat(waves * 2)
                let rect = CGRect(x: center.x - rad, y: center.y - rad,
                                  width: rad * 2, height: rad * 2)
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(wavelengthColor(wavelength).opacity(0.18)),
                           lineWidth: 1)
            }
        }

        // 막.
        var screen = Path()
        screen.move(to: CGPoint(x: screenX, y: r.minY + 20))
        screen.addLine(to: CGPoint(x: screenX, y: r.maxY - 20))
        ctx.stroke(screen, with: .color(.white.opacity(0.7)), lineWidth: 2)
    }

    private func drawIntensity(ctx: GraphicsContext, in r: CGRect) {
        // 화면 가로 = 막의 ±yMax.
        let yMax = wavelength * 1e-9 * screenDist / (slitSep * 1e-9) * 5  // 미터
        let n = 600
        var Imax = 0.0
        var samples: [(y: Double, I: Double, env: Double)] = []
        for k in 0...n {
            let f = Double(k) / Double(n)
            let y = -yMax + 2 * yMax * f
            let theta = atan2(y, screenDist)
            let kλ = .pi * slitSep * 1e-9 / (wavelength * 1e-9) * sin(theta)
            let aλ = .pi * slitWidth * 1e-9 / (wavelength * 1e-9) * sin(theta)
            let single = abs(aλ) < 1e-9 ? 1.0 : pow(sin(aλ) / aλ, 2)
            let interf = pow(cos(kλ), 2)
            let I = single * interf
            samples.append((y, I, single))
            Imax = max(Imax, I)
        }
        if Imax < 1e-12 { Imax = 1 }

        // 빛 띠 (강도에 비례한 밝기).
        let stripH: CGFloat = 30
        for s in samples {
            let f = CGFloat((s.y + yMax) / (2 * yMax))
            let x = r.minX + f * r.width
            let bar = CGRect(x: x, y: r.minY + 8, width: r.width / CGFloat(n) + 1,
                             height: stripH)
            let alpha = s.I / Imax
            ctx.fill(Path(bar),
                     with: .color(wavelengthColor(wavelength).opacity(alpha)))
        }

        // 곡선.
        var curve = Path()
        var env = Path()
        for (k, s) in samples.enumerated() {
            let f = CGFloat((s.y + yMax) / (2 * yMax))
            let x = r.minX + f * r.width
            let yI = r.maxY - 8 - CGFloat(s.I / Imax) * (r.height - 50)
            let yE = r.maxY - 8 - CGFloat(s.env)     * (r.height - 50)
            if k == 0 {
                curve.move(to: CGPoint(x: x, y: yI))
                env.move(to: CGPoint(x: x, y: yE))
            } else {
                curve.addLine(to: CGPoint(x: x, y: yI))
                env.addLine(to: CGPoint(x: x, y: yE))
            }
        }
        if showEnvelope {
            ctx.stroke(env, with: .color(.white.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        ctx.stroke(curve, with: .color(.yellow), lineWidth: 1.6)
    }

    /// 가시광 파장 → 대략적 sRGB 색.
    private func wavelengthColor(_ wl: Double) -> Color {
        var rr = 0.0, gg = 0.0, bb = 0.0
        switch wl {
        case 380..<440: rr = -(wl - 440) / 60; bb = 1
        case 440..<490: gg = (wl - 440) / 50; bb = 1
        case 490..<510: gg = 1; bb = -(wl - 510) / 20
        case 510..<580: rr = (wl - 510) / 70; gg = 1
        case 580..<645: rr = 1; gg = -(wl - 645) / 65
        case 645...780: rr = 1
        default: rr = 0.5; gg = 0.5; bb = 0.5
        }
        return Color(red: max(0, min(1, rr)),
                     green: max(0, min(1, gg)),
                     blue: max(0, min(1, bb)))
    }
}

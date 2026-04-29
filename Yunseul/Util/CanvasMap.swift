import SwiftUI

/// 물리 좌표(미터, y-위)와 Canvas 픽셀 좌표(y-아래) 간 변환.
///
/// `world` 사각형이 전부 `view` 사각형 안에 들어가도록 등방(同方) 스케일.
/// 좌표축은 화면 좌표계 보정을 위해 y 만 반전.
struct CanvasMap {
    let view: CGSize
    let worldOrigin: Vec2   // 화면의 (0, 0) 픽셀에 대응하는 월드 좌표 (좌상단 기준)
    let scale: Double       // 픽셀 / 미터

    /// `worldRect` 가 화면에 맞도록 등방 스케일을 계산.
    init(view: CGSize, world: CGRect, padding: Double = 8) {
        self.view = view
        let w = max(1, Double(view.width) - 2 * padding)
        let h = max(1, Double(view.height) - 2 * padding)
        let sx = w / max(1e-9, Double(world.width))
        let sy = h / max(1e-9, Double(world.height))
        self.scale = min(sx, sy)
        // 월드 사각형을 뷰 중앙에 배치하기 위한 오프셋 (좌상단 기준).
        let usedW = Double(world.width) * scale
        let usedH = Double(world.height) * scale
        let offX = (Double(view.width) - usedW) * 0.5
        let offY = (Double(view.height) - usedH) * 0.5
        // worldOrigin 은 픽셀 (0,0) 에 대응하는 월드 좌표.
        // 픽셀 px = (worldX - worldRect.minX) * scale + offX
        //   ⇒ worldX(px=0) = worldRect.minX - offX/scale
        // 픽셀 py = (worldRect.maxY - worldY) * scale + offY  (y 반전)
        //   ⇒ worldY(py=0) = worldRect.maxY + offY/scale
        self.worldOrigin = Vec2(x: Double(world.minX) - offX / scale,
                                y: Double(world.maxY) + offY / scale)
    }

    /// 월드 → 픽셀.
    func point(_ p: Vec2) -> CGPoint {
        CGPoint(x: (p.x - worldOrigin.x) * scale,
                y: (worldOrigin.y - p.y) * scale)
    }

    func point(x: Double, y: Double) -> CGPoint { point(Vec2(x: x, y: y)) }

    /// 길이 (미터 → 픽셀).
    func length(_ m: Double) -> CGFloat { CGFloat(m * scale) }

    /// 픽셀 → 월드.
    func world(_ p: CGPoint) -> Vec2 {
        Vec2(x: worldOrigin.x + Double(p.x) / scale,
             y: worldOrigin.y - Double(p.y) / scale)
    }
}

// MARK: - 그리드 보조 함수

/// 그리드 간격을 1·2·5·10ⁿ 으로 반올림. 그래프 축의 "예쁜" 눈금에 사용.
func niceStep(_ raw: Double) -> Double {
    guard raw > 0 else { return 1 }
    let exp = floor(log10(raw))
    let base = pow(10, exp)
    let f = raw / base
    let nice: Double
    if f < 1.5 { nice = 1 }
    else if f < 3.5 { nice = 2 }
    else if f < 7.5 { nice = 5 }
    else { nice = 10 }
    return nice * base
}

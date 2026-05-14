import Foundation

/// TimelineView 의 `tl.date` 를 받아 한 프레임의 dt 를 계산.
///
/// 6개 viewport 의 `advance(to:)` 가 모두 같은 패턴 (lastTick guard,
/// paused 시 lastTick 갱신 후 skip, dt cap) 을 손으로 풀어 쓰던 것을 통합.
///
/// - Parameters:
///   - now: 새 프레임의 wall-clock TimeInterval (tl.date 변환값).
///   - lastTick: 직전 프레임 timestamp 저장소. 첫 호출이면 nil → 초기화 후 skip.
///   - running: false 면 skip (lastTick 은 갱신해 재생 직후 dt 점프 방지).
///   - cap: dt 상한 (s). 기본 0.05 — 백그라운드 복귀 시 한 프레임에
///          긴 시간 점프 차단.
/// - Returns: 진행해야 할 dt (clamped). skip 케이스면 nil.
func clockTick(
    now: TimeInterval,
    lastTick: inout TimeInterval?,
    running: Bool,
    cap: TimeInterval = 0.05
) -> TimeInterval? {
    guard let last = lastTick else { lastTick = now; return nil }
    guard running else { lastTick = now; return nil }
    let dt = min(now - last, cap)
    lastTick = now
    return dt
}

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum NBodyVariant: String, CaseIterable, Identifiable {
    case solar = "태양계"
    case threeBody = "3체"
    var id: String { rawValue }
}

struct Mechanics2DViewport: View {
    let preset: Preset

    @State private var world = World()
    @State private var lastTick: TimeInterval? = nil
    @State private var running = false
    @State private var redrawTick: Int = 0
    @State private var nBodyVariant: NBodyVariant = .solar
    @State private var canvasSize: CGSize = .zero
    @State private var vectorsOn: Bool = false
    @State private var energyOn: Bool = false
    @State private var trailsOn: Bool = false
    @State private var graphsOn: Bool = false
    @State private var rulerOn: Bool = false
    @State private var analysisOn: Bool = false
    @State private var rulerStart: Vec3 = Vec3(x: -1.5, y: 0, z: 0)
    @State private var rulerEnd: Vec3 = Vec3(x: 1.5, y: 0, z: 0)
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dragMode: DragMode = .none
    @State private var motionHistory: [UUID: [MotionSample]] = [:]
    @State private var timeScale: Double = 1.0
    @State private var inspectedId: UUID? = nil
    @State private var energyHistory: [World.EnergyBreakdown] = []
    @State private var lorentzB: Double = 1.0
    @State private var freefallH0: Double = 5
    @State private var freefallV0: Double = 0
    @State private var freefallG: Double = 9.8
    @State private var projectileV0: Double = 8
    @State private var projectileAngle: Double = 45        // degrees
    @State private var projectileH0: Double = 0
    @State private var projectileG: Double = 9.8
    @State private var pendulumL: Double = 1.5
    @State private var pendulumTheta0: Double = 60         // degrees
    @State private var pendulumG: Double = 9.8
    @State private var collisionE: Double = 1.0
    @State private var collisionM1: Double = 1.0
    @State private var collisionM2: Double = 1.0
    @State private var collisionV1: Double = 2.0
    @State private var collisionV2: Double = -1.0
    @State private var springK: Double = 5.0
    @State private var springM: Double = 1.0
    @State private var autoStopped = false
    @State private var hasEverMoved = false
    @State private var dragStart: CGPoint = .zero
    @State private var dragStartTime: Date = .distantPast
    @State private var didMoveBeyondSlop: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let pointerTapSlop: CGFloat = 10.0   // UIKit allowableMovement 기본
    private let pointerLongPress: TimeInterval = 0.5  // Apple HIG / UILongPress 기본
    @State private var initialExtent: CGSize = CGSize(width: 5, height: 5)
    @State private var maxObservedExtent: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0
    @GestureState private var isPointerActive: Bool = false
    @GestureState private var isPinching: Bool = false
    @State private var longPressProgress: Double = 0
    @State private var pointerWorldPos: Vec3? = nil
    @State private var pointerIsLive: Bool = false  // false = stale (손가락 뗀 후)
    @AppStorage("hasDraggedBody") private var hasDraggedBody = false
    @Environment(\.colorScheme) private var colorScheme

    private let energyHistMax = 240
    private let motionHistMax = 240
    private var tapEnabled: Bool { preset.id == "freecollide" }

    var body: some View {
        // `let _` is a declaration that @ViewBuilder happily ignores,
        // but the getter runs in body — registering the env dep so the
        // Canvas re-renders on theme change.
        let _ = colorScheme
        VStack(spacing: 10) {
            if preset.id == "nbody" {
                PaperPicker(selection: $nBodyVariant,
                            options: NBodyVariant.allCases) { $0.rawValue }
                    .onChange(of: nBodyVariant) { _, _ in reset() }
            }

            ZStack {
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        draw(ctx: ctx, size: size)
                    }
                    .onChange(of: tl.date) { _, newDate in
                        advance(to: newDate.timeIntervalSinceReferenceDate)
                    }
                }
                .id(redrawTick)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.deep)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
                // 키보드/safe-area 애니메이션이 sub-pixel 변동을 만들기 때문에
                // 1pt 이상 변화일 때만 — 그리고 드래그 활성일 때만 — cancel.
                let active: Bool = { if case .none = dragMode { false } else { true } }()
                if active {
                    let dw = abs(canvasSize.width - newSize.width)
                    let dh = abs(canvasSize.height - newSize.height)
                    if dw > 1 || dh > 1 { cancelActiveDrag() }
                }
                canvasSize = newSize
            }
            .gesture(pointerGesture)
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinchDelta) { value, state, _ in state = value.magnification }
                    .updating($isPinching) { _, state, _ in state = true }
                    .onEnded { value in
                        zoomScale = min(max(zoomScale * value.magnification, 0.3), 8.0)
                    }
            )
            // iOS 26 회귀 — DragGesture(min:0) 의 첫 onChanged 가 일부
            // 컨텍스트에서 발화되지 않는 케이스가 있어 LongPressGesture
            // simultaneousGesture 로 recognizer 를 깨운다 (비interceptive).
            .simultaneousGesture(LongPressGesture(minimumDuration: 0))
            .defersSystemGestures(on: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("물리 시뮬레이션"))
            .accessibilityValue(Text("입자 \(world.bodies.count)개"))
            .accessibilityHint(Text("아래 제어판으로 조작합니다"))
            .accessibilityAction(named: Text(running ? "일시정지" : "재생")) {
                if !running && allBodiesAtRest() { reset() }
                running.toggle()
                if running { autoStopped = false }
            }
            .accessibilityAction(named: Text("초기화")) { reset() }
            .overlay { longPressIndicator }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    zoomBadge
                    coordStatusBar
                }
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 6) {
                    miniMapOverlay
                    inspectorPanel
                }
            }
            .overlay(alignment: .bottom) { transportBar }
            .overlay(alignment: .bottomLeading) { settledBadge }
            .overlay(alignment: .bottomTrailing) { scaleBar }
            // hintLabel 는 마지막 — toast 위치 (transportBar 위 가운데)
            // 로 분리 (옛 bottomTrailing 은 scaleBar 와 겹침).
            .overlay(alignment: .bottom) { hintLabel }

            dataSection

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    toggleRow
                    presetParameterRow
                    timeScaleRow
                    presetDerivedRow
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // iPhone SE (375×667) 등 compact 화면에선 컨트롤 영역을 줄여
            // 캔버스 비율 60:40 유지 (PhET 표준). Regular 에선 여유 공간.
            .frame(maxHeight: horizontalSizeClass == .regular ? 280 : 200)
        }
        .onAppear { reset() }
        .onChange(of: preset.id) { _, _ in reset() }
        .onChange(of: scenePhase) { _, phase in
            // .inactive (알림 배너 / Control Center pulldown) 만으로는
            // cancel 하지 않음 — drag 진행 중에 잠깐 inactive 가 되는 경우
            // 사용자가 의도한 게 아닌데 끊긴다. .background 가 진짜
            // dismissal signal.
            if phase == .background { cancelActiveDrag() }
        }
        // @GestureState `isPointerActive` 가 false 로 떨어질 때는 시스템이
        // 제스처를 취소했거나 (Control Center pulldown, 인터럽트 등)
        // 정상 종료된 경우. onEnded 가 fire 되지 않는 system-cancel
        // 경로에서 dragMode 누수를 방지하기 위해 cleanup.
        .onChange(of: isPointerActive) { wasActive, nowActive in
            if wasActive && !nowActive { cancelActiveDrag() }
        }
        // 두 번째 손가락이 도착했고 아직 tap 후보 상태라면 long-press 가
        // spuriously 발화하지 않게 .consumed 로 전환.
        .onChange(of: isPinching) { _, pinching in
            if pinching, case .pendingTap = dragMode {
                dragMode = .consumed
                longPressProgress = 0
            }
        }
    }

    @ViewBuilder
    private var longPressIndicator: some View {
        if longPressProgress > 0 && longPressProgress < 1 {
            Circle()
                .trim(from: 0, to: CGFloat(longPressProgress))
                .stroke(Theme.glow,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 40)
                .position(dragStart)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Unified pointer gesture
    //
    // 단일 DragGesture(minimumDistance: 0) + 상태 머신으로 tap/long-press/
    // drag/pan/ruler 모두 처리. tap = "slop 안에서 짧은 시간 후 끝난 drag",
    // long-press = "slop 안에서 시간 임계점 초과", drag/pan = "slop 넘은 이동".
    // SwiftUI gesture composition 의 iOS 18+ regression / tap–drag race 우회.

    private var pointerGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($isPointerActive) { _, state, _ in state = true }
            .onChanged { v in pointerOnChanged(v) }
            .onEnded   { v in pointerOnEnded(v) }
    }

    private func pointerOnChanged(_ v: DragGesture.Value) {
        if case .none = dragMode {
            dragStart = v.startLocation
            dragStartTime = Date()
            didMoveBeyondSlop = false
            dragMode = classifyHit(at: v.startLocation)
            if case .body = dragMode, !hasDraggedBody { hasDraggedBody = true }
        }
        // 커서 월드좌표 — 상태바에 표시. CAD/COMSOL 표준 컨벤션.
        pointerWorldPos = screenToWorld(v.location)
        pointerIsLive = true

        let dx = v.location.x - dragStart.x
        let dy = v.location.y - dragStart.y
        if hypot(dx, dy) > pointerTapSlop { didMoveBeyondSlop = true }

        // Long-press progress (visual feedback in tap-add 프리셋만).
        if !didMoveBeyondSlop, tapEnabled, case .pendingTap = dragMode {
            let dt = Date().timeIntervalSince(dragStartTime)
            longPressProgress = min(1.0, dt / pointerLongPress)
            if dt >= pointerLongPress {
                handleLongPress(at: dragStart)
                dragMode = .consumed
                longPressProgress = 0
                return
            }
        } else if longPressProgress != 0 {
            longPressProgress = 0
        }

        switch dragMode {
        case .pendingTap where didMoveBeyondSlop:
            // 빈 공간 + 움직임 → pan 으로 승격.
            dragMode = .pan(initial: panOffset)
            applyPan(translation: v.translation)
        case .pendingTap:
            break  // 아직 tap 후보
        case .body(let id):
            guard let idx = world.bodies.firstIndex(where: { $0.id == id })
            else {
                // 드래그 중에 해당 body 가 제거된 경우 (다른 경로의 reset
                // 등) — 무한히 .body(deadId) 로 머물지 않도록 cleanup.
                cancelActiveDrag()
                return
            }
            if running { running = false }
            let target = screenToWorld(v.location)
            world.bodies[idx].pos = constrainDragPosition(id: id, target: target)
            world.bodies[idx].vel = .zero
            inspectedId = id
        case .pan:
            applyPan(translation: v.translation)
        case .rulerStart:
            rulerStart = screenToWorld(v.location)
        case .rulerEnd:
            rulerEnd = screenToWorld(v.location)
        case .none, .consumed:
            break
        }
    }

    private func pointerOnEnded(_ v: DragGesture.Value) {
        let dt = Date().timeIntervalSince(dragStartTime)
        if !didMoveBeyondSlop, dt < pointerLongPress,
           case .pendingTap = dragMode {
            handleTap(at: dragStart)
        }
        cancelActiveDrag()
        // 마지막 좌표 5 초간 stale (회색) 유지 — 학생이 값 확인 후 손
        // 떼는 자연스런 동선. 영구 유지는 노이즈, 즉시 hide 는 단절.
        pointerIsLive = false
        let captured = pointerWorldPos
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            // 5 초 후에도 같은 좌표면 hide; 그 사이 새 드래그가 갱신했다면
            // 이 task 는 옛 좌표를 보고 hide 하지 말아야 함.
            if !pointerIsLive,
               let cur = pointerWorldPos, let cap = captured,
               cur.x == cap.x, cur.y == cap.y {
                pointerWorldPos = nil
            }
        }
    }

    private func classifyHit(at p: CGPoint) -> DragMode {
        if rulerOn, let end = pickRulerHandle(at: p) {
            return end == .start ? .rulerStart : .rulerEnd
        }
        if let id = pickBody(at: p, requireMovable: true) {
            return .body(id)
        }
        return .pendingTap
    }

    private func applyPan(translation: CGSize) {
        if case .pan(let initial) = dragMode {
            panOffset = CGSize(width: initial.width + translation.width,
                                height: initial.height + translation.height)
        }
    }

    /// Reset drag state. Called on gesture end and on system cancellation
    /// (scenePhase != .active, canvas size change). DragGesture.onEnded is
    /// not invoked on system-cancelled gestures so we must clean up
    /// defensively to avoid leaking dragMode = .body across resumes.
    private func cancelActiveDrag() {
        dragMode = .none
        didMoveBeyondSlop = false
        longPressProgress = 0
        // 시스템 cancel 경로 — 좌표바도 stale 처리 (pointerOnEnded 와 동일).
        pointerIsLive = false
    }

    @ViewBuilder
    private var dataSection: some View {
        if energyOn || graphsOn {
            // 데이터 패널은 glass 가 적합하지 않음 — 차트는 수치 읽기가
            // 1차 목적이므로 배경이 뒤 콘텐츠를 비추면 가독성 손해. iOS 26
            // Liquid Glass 가이드도 "데이터 디스플레이는 solid material"
            // 권장. flat surface + 1pt 보더로 교체.
            VStack(spacing: 6) {
                if energyOn {
                    // 차트는 60-120Hz 필요 없음 — 30Hz 로 제한해 main
                    // 캔버스의 frame budget 을 보호 (Opus Agent 1).
                    // compact (iPhone SE) 에선 캔버스 크기 확보를 위해 차트
                    // 높이도 96 → 72 로 축소.
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                        Canvas { ctx, size in
                            drawEnergyChart(ctx: ctx,
                                             in: CGRect(origin: .zero, size: size))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: horizontalSizeClass == .regular ? 96 : 72)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 0.5)
                            )
                    )
                }
                if graphsOn {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                        Canvas { ctx, size in
                            drawMotionChart(ctx: ctx,
                                             in: CGRect(origin: .zero, size: size))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: horizontalSizeClass == .regular ? 128 : 96)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 0.5)
                            )
                    )
                }
            }
            .transition(reduceMotion ? .opacity
                        : .opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var hintLabel: some View {
        let text: String? = {
            if tapEnabled { return "탭 → 입자 추가 · 길게 누르면 삭제" }
            if !hasDraggedBody && hasMovableBody { return "입자를 끌어 위치 변경" }
            return nil
        }()
        if let t = text {
            Text(t)
                .font(.caption2)
                .foregroundStyle(reduceTransparency ? Theme.ink : Theme.mist.opacity(0.9))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .glassEffect(.regular, in: Capsule())
                .padding(.bottom, 56)  // transportBar (~44pt) 위 살짝 띄움
                .allowsHitTesting(false)
        }
    }

    private var hasMovableBody: Bool { world.bodies.contains { !$0.pinned } }

    private struct ChipMask {
        var vectors = true
        var energy = true
        var trails = true
        var graphs = true
        var ruler = true
    }

    private var chipMask: ChipMask {
        switch preset.id {
        case "kinetic":
            // 많은 입자 — 자취/그래프/벡터는 화면을 어지럽힘.
            // 탄성 충돌만 있어 총 KE도 보존 → 에너지 그래프는 평평한 직선.
            return ChipMask(vectors: false, energy: false,
                            trails: false, graphs: false)
        case "freecollide":
            // 동일한 이유 — 에너지/자취/그래프 모두 의미 없음.
            return ChipMask(energy: false, trails: false, graphs: false)
        case "lorentz":
            // 자기력은 일을 하지 않아 KE 항상 일정 → 에너지 그래프 의미 없음.
            return ChipMask(energy: false)
        case "efield":
            // 전기력선이 이미 그려짐, 자취 중복
            return ChipMask(trails: false)
        default:
            return ChipMask()
        }
    }

    private var toggleRow: some View {
        let mask = chipMask
        // Compact width (iPhone SE 등) 에선 6 칩이 가로 폭 부족 → horizontal
        // scroll. Regular 에선 등분 fill 유지.
        let isCompact = horizontalSizeClass != .regular
        let fill = !isCompact
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                if mask.vectors {
                    ChipToggle(title: "벡터", systemImage: "arrow.up.right",
                               isOn: vectorsOn, fillHorizontally: fill) {
                        vectorsOn.toggle(); haptic(.light)
                    }
                }
                if mask.energy {
                    ChipToggle(title: "에너지", systemImage: "chart.bar.fill",
                               isOn: energyOn, fillHorizontally: fill) {
                        energyOn.toggle(); haptic(.light)
                    }
                }
                if mask.trails {
                    ChipToggle(title: "자취", systemImage: "scribble",
                               isOn: trailsOn, fillHorizontally: fill) {
                        trailsOn.toggle(); haptic(.light)
                        world.trailEnabled = trailsOn
                        if !trailsOn { world.trails.removeAll() }
                    }
                }
                if mask.graphs {
                    ChipToggle(title: "그래프", systemImage: "chart.xyaxis.line",
                               isOn: graphsOn, fillHorizontally: fill) {
                        graphsOn.toggle(); haptic(.light)
                        if !graphsOn { motionHistory.removeAll() }
                    }
                }
                if mask.ruler {
                    ChipToggle(title: "자", systemImage: "ruler",
                               isOn: rulerOn, fillHorizontally: fill) {
                        rulerOn.toggle(); haptic(.light)
                    }
                }
                ChipToggle(title: "분석", systemImage: "grid",
                           isOn: analysisOn, fillHorizontally: fill) {
                    analysisOn.toggle(); haptic(.light)
                }
            }
            .padding(.horizontal, isCompact ? 0 : 0)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDisabled(!isCompact)
    }

    @ViewBuilder
    private var miniMapOverlay: some View {
        if needsMiniMap {
            // 96×72 → 128×96 (iPhone) / 160×120 (iPad) — 옛 크기는
            // readability floor 미만 (Opus Agent 6 — PhET / NASA Eyes
            // ~150×120 표준).
            let mapW: CGFloat = horizontalSizeClass == .regular ? 160 : 128
            let mapH: CGFloat = horizontalSizeClass == .regular ? 120 : 96
            // 30Hz throttle — main 캔버스 frame budget 보호.
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                Canvas { ctx, size in
                    drawMiniMap(ctx: ctx, size: size)
                }
            }
            .frame(width: mapW, height: mapH)
            .background(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(Theme.surface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 0.5)
                    )
            )
            .padding(10)
            .contentShape(Rectangle())
            // Tap-to-recenter — 탭 한 곳을 main canvas 중앙으로 pan.
            .onTapGesture(coordinateSpace: .local) { tap in
                handleMiniMapTap(at: tap, mapSize: CGSize(width: mapW, height: mapH))
            }
            .transition(.opacity)
            .accessibilityLabel(Text("미니맵"))
            .accessibilityHint(Text("두 번 탭하여 그 지점을 메인 캔버스 가운데로"))
        }
    }

    private func handleMiniMapTap(at tap: CGPoint, mapSize: CGSize) {
        let extent = miniMapExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let s = min(mapSize.width / worldW, mapSize.height / worldH) * 0.84
        guard s > 0 else { return }
        let mapCx = mapSize.width / 2
        let mapCy = mapSize.height / 2
        let wx = Double((tap.x - mapCx) / s) + extent.center.x
        let wy = -Double((tap.y - mapCy) / s) + extent.center.y
        let mainScale = viewScale()
        let mainExtent = computeExtent()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            panOffset = CGSize(
                width:  -CGFloat(wx - mainExtent.center.x) * mainScale,
                height:  CGFloat(wy - mainExtent.center.y) * mainScale)
        }
        haptic(.light)
    }

    private func drawMiniMap(ctx: GraphicsContext, size: CGSize) {
        let extent = miniMapExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let scale = min(size.width / worldW, size.height / worldH) * 0.84
        let cx = size.width / 2
        let cy = size.height / 2

        // Indicate the main canvas's currently visible world rectangle.
        // Accounts for live pinch-zoom and pan.
        let mainScale = viewScale()
        if mainScale > 0, canvasSize.width > 0, canvasSize.height > 0 {
            let visibleW = Double(canvasSize.width) / Double(mainScale)
            let visibleH = Double(canvasSize.height) / Double(mainScale)
            let mainExtent = computeExtent()
            let centerWX = mainExtent.center.x - Double(panOffset.width) / Double(mainScale)
            let centerWY = mainExtent.center.y + Double(panOffset.height) / Double(mainScale)
            let rectW = CGFloat(visibleW) * scale
            let rectH = CGFloat(visibleH) * scale
            let rectCX = cx + CGFloat(centerWX - extent.center.x) * scale
            let rectCY = cy - CGFloat(centerWY - extent.center.y) * scale
            let rect = CGRect(
                x: rectCX - rectW / 2, y: rectCY - rectH / 2,
                width: rectW, height: rectH)
            ctx.stroke(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(Theme.glow.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1.0, dash: [3, 2]))
        }

        // Predicted ellipse (Kepler 2체 한정, 묶임 궤도일 때만) —
        // 분석적으로 한 번 계산되므로 매 프레임 다시 그려도 가벼움.
        if preset.id == "kepler",
           let star = world.bodies.first(where: { $0.kind == .star || $0.pinned }),
           let planet = world.bodies.first(where: { !$0.pinned && $0.kind != .star }),
           let orbit = keplerOrbitEllipse(planet: planet, star: star) {
            let center = CGPoint(
                x: cx + CGFloat(orbit.cx - extent.center.x) * scale,
                y: cy - CGFloat(orbit.cy - extent.center.y) * scale)
            let majorPx = CGFloat(orbit.a) * scale
            let minorPx = CGFloat(orbit.b) * scale
            var path = Path()
            path.addEllipse(in: CGRect(
                x: -majorPx, y: -minorPx,
                width: majorPx * 2, height: minorPx * 2))
            // Rotate around its own center, then translate.
            var transform = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: CGFloat(-orbit.angle))  // y-flip 화면좌표
            path = path.applying(transform)
            ctx.stroke(path,
                       with: .color(Theme.glowText.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 0.6, dash: [2, 2]))
        }

        // Bodies — small filled dots, slightly enlarged so they're visible.
        for body in world.bodies {
            guard body.pos.isFinite else { continue }
            let p = CGPoint(
                x: cx + CGFloat(body.pos.x - extent.center.x) * scale,
                y: cy - CGFloat(body.pos.y - extent.center.y) * scale)
            let r = max(1.6, CGFloat(body.radius) * scale * 0.6)
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: p.x - r, y: p.y - r,
                    width: r * 2, height: r * 2)),
                with: .color(body.color))
        }
    }

    /// Kepler 2체 분석적 궤도 — bound (E < 0) 일 때 ellipse 파라미터.
    private func keplerOrbitEllipse(planet: PhysicsBody, star: PhysicsBody)
        -> (cx: Double, cy: Double, a: Double, b: Double, angle: Double)? {
        let mu = world.G * star.mass
        let dr = planet.pos - star.pos
        let v = planet.vel
        let r = dr.length
        let v2 = v.lengthSquared
        guard r > 1e-6, mu > 0 else { return nil }
        let energy = 0.5 * v2 - mu / r
        guard energy < 0 else { return nil }  // bound 만
        let a = -mu / (2 * energy)
        let h = dr.x * v.y - dr.y * v.x
        let eSq = max(0, 1 + 2 * energy * h * h / (mu * mu))
        let ecc = eSq.squareRoot()
        // 이심률 벡터 (periapsis 방향). 표준 공식.
        let dotRV = dr.x * v.x + dr.y * v.y
        let coeff = v2 - mu / r
        let evx = (coeff * dr.x - dotRV * v.x) / mu
        let evy = (coeff * dr.y - dotRV * v.y) / mu
        let angle = atan2(evy, evx)
        let b = a * (1 - ecc * ecc).squareRoot()
        // Ellipse 중심 = star - periapsis 방향 × (a*e)
        let cx = star.pos.x - a * ecc * cos(angle)
        let cy = star.pos.y - a * ecc * sin(angle)
        // Path / CGAffineTransform 에 NaN/Inf 들어가면 Canvas 가 죽음.
        guard a.isFinite, b.isFinite, cx.isFinite, cy.isFinite, angle.isFinite,
              a > 0.001, b > 0.001 else { return nil }
        return (cx, cy, a, b, angle)
    }

    @ViewBuilder
    private var zoomBadge: some View {
        let live = zoomScale * pinchDelta
        if abs(live - 1.0) > 0.01 || panOffset != .zero {
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
                    zoomScale = 1.0
                    panOffset = .zero
                }
                haptic(.light)
            } label: {
                Label(String(format: "%.2fx", live),
                      systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(reduceTransparency ? Theme.ink : Theme.glowText)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .glassEffect(.regular.interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    /// 커서 월드좌표 표시. Desmos 컨벤션의 `(x, y) m` — 한국 교과서 표기.
    /// 손가락이 캔버스 위면 live (ink), 떼면 5초간 stale (mist) 표시 후
    /// hide. 즉시 hide 는 학생이 값 확인 직전에 사라지는 UX 단절 (Opus
    /// Agent 3 — "PhET 측정 도구도 stale 좌표 유지 패턴").
    @ViewBuilder
    private var coordStatusBar: some View {
        if let p = pointerWorldPos, p.isFinite {
            Text("(\(SciFormat.fixed(p.x, places: 2)), \(SciFormat.fixed(p.y, places: 2))) m")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(pointerIsLive ? Theme.ink : Theme.mist)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.surface.opacity(pointerIsLive ? 0.88 : 0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Theme.stroke, lineWidth: 0.5)
                        )
                )
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    /// 척도 바 — round-number 1·2·5 시퀀스 (지도학 표준) 로 현재 zoom 에
    /// 맞는 길이를 골라 그림. PhET/Algodoo 등 학습 도구엔 척도바가 흔치
    /// 않아 영구 표시는 시각 노이즈 — zoom 변화가 있거나 분석 모드일
    /// 때만 노출 (학생이 측정 컨텍스트인 순간).
    @ViewBuilder
    private var scaleBar: some View {
        let s = viewScale() * pinchDelta
        let liveZoom = zoomScale * pinchDelta
        let shouldShow = analysisOn || abs(liveZoom - 1.0) > 0.01
        if shouldShow, s > 0, canvasSize.width > 0 {
            // 화면상 약 60pt 가까운 round 길이 선택.
            let targetPx: CGFloat = 60
            let rawMeters = Double(targetPx / s)
            let pow10 = pow(10, floor(log10(rawMeters)))
            let normalized = rawMeters / pow10
            let stepped: Double = (normalized < 1.5) ? 1.0
                                : (normalized < 3.5) ? 2.0
                                : (normalized < 7.5) ? 5.0 : 10.0
            let lengthM = stepped * pow10
            let lengthPx = CGFloat(lengthM) * s
            HStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.ink).frame(width: lengthPx, height: 1.5)
                    Rectangle().fill(Theme.ink).frame(width: 1.5, height: 6)
                    Rectangle().fill(Theme.ink).frame(width: 1.5, height: 6)
                        .offset(x: lengthPx - 1.5)
                }
                .frame(width: lengthPx, height: 6)
                Text(SciFormat.withUnit(lengthM, unit: "m", digits: 2))
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.surface.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 0.5)
                    )
            )
            .padding(.trailing, 8).padding(.bottom, 56)  // transportBar 위
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var presetDerivedRow: some View {
        if let text = derivedValueText() {
            HStack {
                Text(text)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.surface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.ink.opacity(0.22), lineWidth: 0.8)
                    )
            )
        }
    }

    private func derivedValueText() -> String? {
        switch preset.id {
        case "freefall":
            guard let bob = world.bodies.first(where: { !$0.pinned }),
                  bob.pos.isFinite, bob.vel.isFinite else { return nil }
            let y = bob.pos.y, vy = bob.vel.y
            let g = -world.gravity.y
            guard g > 0 else { return nil }
            let disc = vy * vy + 2 * g * y
            guard disc >= 0 else { return nil }
            let tHit = (vy + disc.squareRoot()) / g
            let vHit = disc.squareRoot()
            return String(format: "남은 비행 %.2fs   충돌 속도 %.2f m/s", tHit, vHit)

        case "projectile":
            guard let proj = world.bodies.first(where: { !$0.pinned }),
                  proj.pos.isFinite, proj.vel.isFinite else { return nil }
            let y = proj.pos.y, vx = proj.vel.x, vy = proj.vel.y
            let g = -world.gravity.y
            guard g > 0 else { return nil }
            let disc = vy * vy + 2 * g * y
            guard disc >= 0 else { return nil }
            let tHit = (vy + disc.squareRoot()) / g
            let xPredict = proj.pos.x + vx * tHit
            return String(format: "남은 시간 %.2fs   예상 사거리 %.2f m", tHit, xPredict)

        case "pendulum":
            guard let pivot = world.bodies.first(where: { $0.pinned }),
                  let bob   = world.bodies.first(where: { !$0.pinned }),
                  pivot.pos.isFinite, bob.pos.isFinite else { return nil }
            let L = (bob.pos - pivot.pos).length
            let g = -world.gravity.y
            guard g > 0, L > 1e-6 else { return nil }
            let T0 = 2 * .pi * (L / g).squareRoot()
            let dx = bob.pos.x - pivot.pos.x
            let dy = pivot.pos.y - bob.pos.y
            let θ = atan2(dx, dy)
            let θ2 = θ * θ, θ4 = θ2 * θ2
            let corr = 1 + θ2 / 16 + 11 * θ4 / 3072
            return String(format: "이상 주기 T₀ = %.3fs    실제 주기 T = %.3fs",
                          T0, T0 * corr)

        case "collision1d":
            let nonPinned = world.bodies.filter { !$0.pinned }
            guard nonPinned.count >= 2 else { return nil }
            let p = nonPinned.map { $0.mass * $0.vel.x }.reduce(0, +)
            let ke = nonPinned.map { 0.5 * $0.mass * $0.vel.lengthSquared }.reduce(0, +)
            return String(format: "운동량 p = %.2f   운동에너지 KE = %.2f", p, ke)

        case "kepler", "nbody":
            guard let star = world.bodies.first(where: { $0.kind == .star || $0.pinned }),
                  let planet = world.bodies.first(where: { !$0.pinned && $0.kind != .star }),
                  star.pos.isFinite, planet.pos.isFinite else { return nil }
            let mu = world.G * star.mass
            let dr = planet.pos - star.pos
            let r = dr.length
            let v = planet.vel.length
            guard r > 1e-6 else { return nil }
            let E = 0.5 * v * v - mu / r
            if E >= 0 {
                return String(format: "거리 r = %.2f   속도 v = %.2f   (탈출 궤도)", r, v)
            }
            // Kepler's 3rd law: T = 2π√(a³/GM). 학생들 친숙 — 장반경 a,
            // 이심률 e 같은 교과 외 양은 화면에 노출하지 않는다.
            let a = -mu / (2 * E)
            let T = 2 * .pi * (a * a * a / mu).squareRoot()
            return String(format: "거리 r = %.2f   속도 v = %.2f   주기 T = %.2fs",
                          r, v, T)

        default:
            return nil
        }
    }

    @ViewBuilder
    private var presetParameterRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch preset.id {
            case "lorentz":
                paramSlider("자기장 B_z", value: $lorentzB,
                             range: -3...3, fmt: "%+.2f T")
            case "freefall":
                paramSlider("초기 높이 h_0", value: $freefallH0,
                             range: 1...20, fmt: "%.1f m")
                paramSlider("초기 속도 v_0", value: $freefallV0,
                             range: -10...10, fmt: "%+.1f m/s")
                paramSlider("중력 g", value: $freefallG,
                             range: 1...25, fmt: "%.1f m/s²")
            case "projectile":
                paramSlider("초기 속도 v_0", value: $projectileV0,
                             range: 1...20, fmt: "%.1f m/s")
                paramSlider("발사각 θ", value: $projectileAngle,
                             range: 0...90, fmt: "%.0f°")
                paramSlider("초기 높이 h_0", value: $projectileH0,
                             range: 0...15, fmt: "%.1f m")
                paramSlider("중력 g", value: $projectileG,
                             range: 1...25, fmt: "%.1f m/s²")
            case "pendulum":
                paramSlider("줄 길이 L", value: $pendulumL,
                             range: 0.5...3, fmt: "%.2f m")
                paramSlider("초기 각도 θ", value: $pendulumTheta0,
                             range: 5...90, fmt: "%.0f°")
                paramSlider("중력 g", value: $pendulumG,
                             range: 1...25, fmt: "%.1f m/s²")
            case "collision1d":
                paramSlider("반발계수 e", value: $collisionE,
                             range: 0...1, fmt: "%.2f")
                paramSlider("질량 m_1", value: $collisionM1,
                             range: 0.1...5, fmt: "%.1f kg")
                paramSlider("질량 m_2", value: $collisionM2,
                             range: 0.1...5, fmt: "%.1f kg")
                paramSlider("속도 v_1", value: $collisionV1,
                             range: -5...5, fmt: "%+.1f m/s")
                paramSlider("속도 v_2", value: $collisionV2,
                             range: -5...5, fmt: "%+.1f m/s")
            case "spring":
                paramSlider("강성 k", value: $springK,
                             range: 1...50, fmt: "%.1f N/m")
                paramSlider("질량 m", value: $springM,
                             range: 0.2...3, fmt: "%.2f kg")
            default:
                EmptyView()
            }
        }
        .onChange(of: lorentzB) { _, v in
            world.magneticB = Vec3(x: 0, y: 0, z: v)
        }
        .onChange(of: collisionE) { _, v in
            // 라이브 — 다음 충돌부터 새 반발계수 적용
            world.restitution = v
        }
        // 중력 g 는 world 속성 — 시뮬 재시작 없이 라이브로 반영.
        .onChange(of: liveGravitySignature) { _, _ in applyLiveGravity() }
        // Single .onChange covering every preset's init-condition slider —
        // 17개 개별 onChange 체인은 Swift type-checker가 timeout 시켜서
        // joined signature 하나로 묶었다.
        .onChange(of: paramResetSignature) { _, _ in reset() }
    }

    /// 초기 조건 변화 — reset 트리거. gravity 는 제외 (라이브).
    private var paramResetSignature: String {
        let parts: [Double] = [
            freefallH0, freefallV0,
            projectileV0, projectileAngle, projectileH0,
            pendulumL, pendulumTheta0,
            collisionM1, collisionM2, collisionV1, collisionV2,
            springK, springM,
        ]
        return parts.map { String($0) }.joined(separator: "|")
    }

    /// gravity 슬라이더만 별도 — 현재 프리셋의 g 가 바뀌면 world.gravity
    /// 만 라이브로 갱신 (시뮬 재시작 없음).
    private var liveGravitySignature: Double {
        switch preset.id {
        case "freefall":   return freefallG
        case "projectile": return projectileG
        case "pendulum":   return pendulumG
        default:           return 0
        }
    }

    private func applyLiveGravity() {
        switch preset.id {
        case "freefall":   world.gravity = Vec3(x: 0, y: -freefallG, z: 0)
        case "projectile": world.gravity = Vec3(x: 0, y: -projectileG, z: 0)
        case "pendulum":   world.gravity = Vec3(x: 0, y: -pendulumG, z: 0)
        default: break
        }
    }

    private func paramSlider(_ title: String, value: Binding<Double>,
                              range: ClosedRange<Double>, fmt: String)
        -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).foregroundStyle(Theme.mist)
                .frame(minWidth: 96, alignment: .leading)
            PaperSlider(value: value, in: range)
            EditableValue(value: value, range: range, format: fmt, width: 70)
        }
    }

    private var timeScaleRow: some View {
        HStack(spacing: 6) {
            Text(String(format: "t=%.2fs", world.time))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.mist)
                .frame(width: 62, alignment: .leading)
            PaperSlider(value: $timeScale, in: 0.25...4)
            EditableValue(value: $timeScale, range: 0.25...4,
                           format: "%.2fx", width: 50)
        }
    }

    private var transportBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    if !running && allBodiesAtRest() { reset() }
                    running.toggle()
                    if running { autoStopped = false }
                    haptic(.medium)
                } label: {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(playButtonGlass, in: Circle())

                Button {
                    stepOnce()
                    haptic(.light)
                } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(running ? Theme.mist : Theme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .disabled(running)

                Button {
                    reset()
                    haptic(.medium)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .padding(.bottom, 8)
    }

    /// Play button's glass material. When running we tint with `Theme.glow`,
    /// but skip the tint if Reduce Transparency is on (glass becomes opaque
    /// material there and a saturated tint would dominate the chrome).
    private var playButtonGlass: Glass {
        if running && !reduceTransparency {
            return .regular.tint(Theme.glow).interactive()
        }
        return .regular.interactive()
    }

    @ViewBuilder
    private var settledBadge: some View {
        if autoStopped {
            Text("정지됨")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(reduceTransparency ? Theme.ink : Theme.mist)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .glassEffect(.regular, in: Capsule())
                .padding(.leading, 8).padding(.bottom, 8)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: autoStopped)
        }
    }

    private func allBodiesAtRest() -> Bool {
        guard !world.pairwiseGravity,
              world.time > 0.3,
              hasEverMoved  // never auto-stop until the system actually moved
        else { return false }
        let dissipative = world.drag > 0
            || world.springs.contains { $0.damping > 0 }
            || (world.bounds.map { $0.restitution < 0.99 } ?? false)
            || (world.hardSphereCollisions && world.restitution < 0.99)
        guard dissipative else { return false }
        let nonPinned = world.bodies.filter { !$0.pinned }
        guard !nonPinned.isEmpty else { return false }
        let maxV = nonPinned.map { $0.vel.length }.max() ?? 0
        return maxV < 1e-3
    }

    private func reset() {
        world.bodies.removeAll()
        world.springs.removeAll()
        world.trails.removeAll()
        world.bounds = nil
        world.gravity = .zero
        world.magneticB = .zero
        world.electricE = .zero
        world.drag = 0
        world.integrator = .velocityVerlet
        world.pairwiseGravity = false
        world.pairwiseCoulomb = false
        world.hardSphereCollisions = false
        world.restitution = 1.0
        world.G = 1.0
        world.kCoulomb = 1.0
        world.trailEnabled = false
        world.trailMax = 48
        world.time = 0
        if preset.id == "nbody" {
            switch nBodyVariant {
            case .solar:     MechanicsPresets.solarSystem(world)
            case .threeBody: MechanicsPresets.threeBody(world)
            }
        } else {
            preset.load(world)
        }
        applyUserParameters()
        lastTick = nil
        running = false
        autoStopped = false
        inspectedId = nil
        energyHistory.removeAll()
        motionHistory.removeAll()
        dragMode = .none
        zoomScale = 1.0
        panOffset = .zero
        rulerStart = Vec3(x: -1.5, y: 0, z: 0)
        rulerEnd = Vec3(x: 1.5, y: 0, z: 0)
        trailsOn = world.trailEnabled
        lorentzB = world.magneticB.z
        hasEverMoved = false
        captureInitialExtent()
        redrawTick &+= 1
    }

    /// Overrides preset defaults with the user's current slider values.
    /// Runs after preset.load so the initial state reflects user input.
    /// All formula variables of each preset are exposed to the user here.
    private func applyUserParameters() {
        switch preset.id {
        case "freefall":
            world.gravity = Vec3(x: 0, y: -freefallG, z: 0)
            if let idx = world.bodies.firstIndex(where: { !$0.pinned }) {
                let r = world.bodies[idx].radius
                let y0 = clampedAboveBounds(freefallH0, radius: r)
                world.bodies[idx].pos = Vec3(x: 0, y: y0, z: 0)
                world.bodies[idx].vel = Vec3(x: 0, y: freefallV0, z: 0)
            }
        case "projectile":
            world.gravity = Vec3(x: 0, y: -projectileG, z: 0)
            if let idx = world.bodies.firstIndex(where: { !$0.pinned }) {
                let θ = projectileAngle * .pi / 180
                let r = world.bodies[idx].radius
                let y0 = clampedAboveBounds(projectileH0, radius: r)
                world.bodies[idx].pos = Vec3(x: 0, y: y0, z: 0)
                world.bodies[idx].vel = Vec3(
                    x: projectileV0 * cos(θ),
                    y: projectileV0 * sin(θ),
                    z: 0)
            }
        case "pendulum":
            world.gravity = Vec3(x: 0, y: -pendulumG, z: 0)
            if let pivotIdx = world.bodies.firstIndex(where: { $0.pinned }),
               let bobIdx   = world.bodies.firstIndex(where: { !$0.pinned }) {
                let pivot = world.bodies[pivotIdx].pos
                let θ = pendulumTheta0 * .pi / 180
                world.bodies[bobIdx].pos = Vec3(
                    x: pivot.x + pendulumL * sin(θ),
                    y: pivot.y - pendulumL * cos(θ),
                    z: 0)
                world.bodies[bobIdx].vel = .zero
                if let sIdx = world.springs.firstIndex(where: { $0.rigid }) {
                    world.springs[sIdx].restLength = pendulumL
                }
            }
        case "collision1d":
            world.restitution = collisionE
            let nonPinned = world.bodies.indices.filter { !world.bodies[$0].pinned }
            if nonPinned.count >= 2 {
                world.bodies[nonPinned[0]].mass = collisionM1
                world.bodies[nonPinned[0]].vel = Vec3(x: collisionV1, y: 0, z: 0)
                world.bodies[nonPinned[1]].mass = collisionM2
                world.bodies[nonPinned[1]].vel = Vec3(x: collisionV2, y: 0, z: 0)
            }
        case "spring":
            if let bobIdx = world.bodies.firstIndex(where: { !$0.pinned }) {
                world.bodies[bobIdx].mass = springM
            }
            for i in world.springs.indices where !world.springs[i].rigid {
                world.springs[i].stiffness = springK
            }
        default:
            break
        }
    }

    /// Pushes the requested y0 above any ground bound by a small margin so
    /// the body doesn't spawn inside or touching a wall (which can cause
    /// the simulation to immediately settle into rest).
    private func clampedAboveBounds(_ y0: Double, radius: Double) -> Double {
        guard let bounds = world.bounds else { return y0 }
        let minY = bounds.min.y + radius + 0.02
        return max(y0, minY)
    }

    /// Substep 갯수는 stiff 시뮬 (springs/충돌/coulomb) 만 8 사용,
    /// 일반 시뮬은 4 — Box2D 표준. 가벼운 시뮬에서 절반 비용 절감.
    private var physicsSubsteps: Int {
        if world.springs.contains(where: { $0.stiffness > 200 }) { return 8 }
        if world.hardSphereCollisions, world.bodies.count > 30 { return 8 }
        if world.pairwiseCoulomb { return 8 }
        return 4
    }

    private func stepOnce() {
        let dt = (1.0 / 60.0) * timeScale
        let sub = physicsSubsteps
        let h = dt / Double(sub)
        for _ in 0..<sub { world.step(dt: h) }
        recordEnergy()
        recordMotion()
        updateMaxObservedExtent()
        if world.bodies.contains(where: { !$0.pos.isFinite || !$0.vel.isFinite }) {
            reset()
        }
    }

    private func recordEnergy() {
        guard energyOn else { return }
        energyHistory.append(world.energyBreakdown())
        if energyHistory.count > energyHistMax {
            energyHistory.removeFirst(energyHistory.count - energyHistMax)
        }
    }

    private func recordMotion() {
        guard graphsOn else { return }
        let t = world.time
        for body in world.bodies where !body.pinned {
            var arr = motionHistory[body.id] ?? []
            arr.append(MotionSample(t: t, pos: body.pos, vel: body.vel))
            if arr.count > motionHistMax {
                arr.removeFirst(arr.count - motionHistMax)
            }
            motionHistory[body.id] = arr
        }
        // Drop history of removed bodies
        let alive = Set(world.bodies.map { $0.id })
        let stale = motionHistory.keys.filter { !alive.contains($0) }
        for id in stale { motionHistory.removeValue(forKey: id) }
    }

    private func graphTargetBody() -> PhysicsBody? {
        if let id = inspectedId,
           let b = world.bodies.first(where: { $0.id == id }), !b.pinned {
            return b
        }
        return world.bodies.first { !$0.pinned }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    private func viewScale() -> CGFloat {
        let extent = computeExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let base = min(canvasSize.width / worldW, canvasSize.height / worldH) * 0.9
        return base * zoomScale * pinchDelta
    }

    private func screenToWorld(_ pt: CGPoint) -> Vec3 {
        let extent = computeExtent()
        let scale = viewScale()
        let cx = canvasSize.width / 2 + panOffset.width
        let cy = canvasSize.height / 2 + panOffset.height
        let wx = Double((pt.x - cx) / scale) + extent.center.x
        let wy = -Double((pt.y - cy) / scale) + extent.center.y
        return Vec3(x: wx, y: wy, z: 0)
    }

    private func handleTap(at screenPt: CGPoint) {
        if let id = pickBody(at: screenPt, requireMovable: false) {
            inspectedId = (inspectedId == id) ? nil : id
            haptic(.light)
            return
        }
        if tapEnabled {
            spawnParticle(at: screenPt)
            return
        }
        inspectedId = nil
    }

    private func handleLongPress(at screenPt: CGPoint) {
        guard tapEnabled,
              let id = pickBody(at: screenPt, requireMovable: true),
              let idx = world.bodies.firstIndex(where: { $0.id == id }) else { return }
        world.bodies.remove(at: idx)
        if inspectedId == id { inspectedId = nil }
        haptic(.medium)
    }

    private func spawnParticle(at screenPt: CGPoint) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        let p = screenToWorld(screenPt)
        if let b = world.bounds {
            guard p.x > b.min.x && p.x < b.max.x && p.y > b.min.y && p.y < b.max.y else { return }
        }
        let color = Theme.bodyPalette[world.bodies.count % Theme.bodyPalette.count]
        let r = Double.random(in: 0.06...0.13)
        let speed = Double.random(in: 0.3...0.8)
        let angle = Double.random(in: 0...(2 * .pi))
        world.bodies.append(PhysicsBody(
            pos: p,
            vel: Vec3(x: speed * cos(angle), y: speed * sin(angle), z: 0),
            mass: .random(in: 0.8...2.5), radius: r, color: color))
        if !running { running = true }
    }


    private func pickRulerHandle(at screenPt: CGPoint) -> RulerEnd? {
        let extent = computeExtent()
        let scale = viewScale()
        let cx = canvasSize.width / 2 + panOffset.width
        let cy = canvasSize.height / 2 + panOffset.height
        let s = CGPoint(x: cx + CGFloat(rulerStart.x - extent.center.x) * scale,
                        y: cy - CGFloat(rulerStart.y - extent.center.y) * scale)
        let e = CGPoint(x: cx + CGFloat(rulerEnd.x - extent.center.x) * scale,
                        y: cy - CGFloat(rulerEnd.y - extent.center.y) * scale)
        let dS = hypot(screenPt.x - s.x, screenPt.y - s.y)
        let dE = hypot(screenPt.x - e.x, screenPt.y - e.y)
        let threshold: CGFloat = 32
        if dS <= dE && dS < threshold { return .start }
        if dE < threshold { return .end }
        return nil
    }

    private func constrainDragPosition(id: UUID, target: Vec3) -> Vec3 {
        for s in world.springs where s.rigid {
            let otherId: UUID? = s.aId == id ? s.bId : (s.bId == id ? s.aId : nil)
            guard let oid = otherId,
                  let other = world.bodies.first(where: { $0.id == oid }),
                  other.pinned else { continue }
            let d = target - other.pos
            let dist = d.length
            guard dist > 1e-9 else { return target }
            return other.pos + d * (s.restLength / dist)
        }
        return target
    }

    private func pickBody(at screenPt: CGPoint, requireMovable: Bool) -> UUID? {
        let worldPt = screenToWorld(screenPt)
        let scale = max(viewScale(), 1)
        // 28pt floor — Apple HIG 44pt 충족 (대략, 손가락 중심 to body
        // 중심 거리 ≈ 22pt, body 가장자리까지면 22+~6 ≈ 28).
        let minHit = 28.0 / Double(scale)
        var bestId: UUID? = nil
        var bestDist = Double.infinity
        for body in world.bodies {
            if requireMovable && body.pinned { continue }
            let d = (body.pos - worldPt).length
            let hit = max(body.radius * 1.6, minHit)
            if d < hit && d < bestDist {
                bestDist = d
                bestId = body.id
            }
        }
        return bestId
    }

    private func advance(to now: TimeInterval) {
        guard let last = lastTick else { lastTick = now; return }
        guard running else { lastTick = now; return }
        var dt = (now - last) * timeScale
        // dt cap 0.05s → 1/60s — 0.05s × 8 substep × 100 body = 400 ms CPU
        // spike 위험. 1/60 으로 cap 하면 기본 frame budget 유지.
        let dtCap = (1.0 / 60.0) * max(timeScale, 1)
        if dt > dtCap { dt = dtCap }
        lastTick = now
        let sub = physicsSubsteps
        let h = dt / Double(sub)
        for _ in 0..<sub { world.step(dt: h) }
        recordEnergy()
        recordMotion()
        updateMaxObservedExtent()
        if !hasEverMoved {
            let maxV = world.bodies.filter { !$0.pinned }
                .map { $0.vel.length }.max() ?? 0
            if maxV > 0.05 { hasEverMoved = true }
        }
        if world.bodies.contains(where: {
            !$0.pos.isFinite || !$0.vel.isFinite
        }) {
            reset()
        }
        if allBodiesAtRest() { running = false; autoStopped = true }
    }

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let extent = computeExtent()
        let worldW = max(0.001, extent.x * 2)
        let worldH = max(0.001, extent.y * 2)
        let scale = min(size.width / worldW, size.height / worldH) * 0.9 * zoomScale * pinchDelta
        let cx = size.width / 2 + panOffset.width
        let cy = size.height / 2 + panOffset.height

        if analysisOn {
            drawAnalysisGrid(ctx: ctx, size: size, scale: scale,
                              cx: cx, cy: cy, ext: extent.center)
        }

        if let b = world.bounds {
            let x0 = cx + CGFloat(b.min.x - extent.center.x) * scale
            let x1 = cx + CGFloat(b.max.x - extent.center.x) * scale
            let y0 = cy - CGFloat(b.max.y - extent.center.y) * scale
            let y1 = cy - CGFloat(b.min.y - extent.center.y) * scale
            Sketchy.rect(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
                         ctx: ctx, color: Theme.ink,
                         lineWidth: 1.4, passes: 2, jitter: 1.4)
        }

        if abs(world.magneticB.z) > 1e-6 {
            drawFieldGrid(ctx: ctx, size: size, outward: world.magneticB.z > 0)
        }

        if world.bodies.contains(where: { $0.charge != 0 }) {
            drawEFieldLines(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }

        // 자취 — 오래된 점은 흐릿하고 가늘게, 최근 점은 진하고 굵게.
        // 옛날 코드: 세그먼트당 ctx.stroke 호출 → trailMax 48 × bodies 100
        // = 4,800 stroke/frame. 새 코드: body 당 4 시간-버킷, 버킷당
        // 단일 stroke → bodies 100 × 4 = 400 stroke/frame. 12배 감소,
        // visual fade 보존.
        if world.trailEnabled {
            let buckets = 4
            for body in world.bodies {
                guard let pts = world.trails[body.id], pts.count > 1 else { continue }
                let screenPts: [CGPoint] = pts.compactMap { p in
                    guard p.isFinite else { return nil }
                    return mapPoint(p, scale: scale, cx: cx, cy: cy, ext: extent.center)
                }
                let n = screenPts.count
                guard n > 1 else { continue }
                let perBucket = max(1, (n - 1) / buckets)
                for b in 0..<buckets {
                    let start = b * perBucket
                    let end   = min((b + 1) * perBucket, n - 1)
                    guard end > start else { continue }
                    let t = Double(b + 1) / Double(buckets)
                    let alpha = pow(t, 1.4) * 0.85
                    let width = 0.4 + 1.2 * CGFloat(t)
                    var path = Path()
                    path.move(to: screenPts[start])
                    for i in (start + 1)...end {
                        path.addLine(to: screenPts[i])
                    }
                    ctx.stroke(path,
                               with: .color(body.color.opacity(alpha)),
                               style: StrokeStyle(lineWidth: width,
                                                  lineCap: .round,
                                                  lineJoin: .round))
                }
            }
        }

        for s in world.springs {
            guard let a = world.bodies.first(where: { $0.id == s.aId }),
                  let b = world.bodies.first(where: { $0.id == s.bId }),
                  a.pos.isFinite, b.pos.isFinite
            else { continue }
            let pa = mapPoint(a.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            let pb = mapPoint(b.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            Sketchy.line(from: pa, to: pb, ctx: ctx,
                         color: Theme.ink,
                         lineWidth: s.rigid ? 1.8 : 1.3,
                         passes: s.rigid ? 2 : 1,
                         jitter: s.rigid ? 0.7 : 0.4)
        }

        let grabbedID: UUID? = {
            if case .body(let id) = dragMode { return id }
            return nil
        }()

        for body in world.bodies {
            guard body.pos.isFinite else { continue }
            let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: extent.center)
            let pr = max(2, CGFloat(body.radius) * scale)
            guard pr.isFinite else { continue }

            // Grab feedback — 진한 솔리드 body 위에 cobalt selection ring.
            // 이전: cream halo + 색연필 톤 (0.55 fill). 6 opus 합의 — pro
            // 도구 컨벤션은 솔리드 fill + 강조 ring (Figma/Sketch 선택 동작).
            let isGrabbed = (grabbedID == body.id)
            if isGrabbed {
                let haloR = pr + 6
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.x - haloR, y: p.y - haloR,
                                            width: haloR * 2, height: haloR * 2)),
                    with: .color(Theme.glow.opacity(0.16)))
            }

            // 솔리드 fill + 옅은 윤곽 — Material Design dark theme:
            // "use 5–10% white overlay, not full borders". 0.6 opacity ink
            // 가 다크 모드 halation 을 막으면서 라이트 모드 시인성도 보존.
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr,
                                       width: pr * 2, height: pr * 2)),
                with: .color(body.color))
            Sketchy.circle(center: p, radius: pr, ctx: ctx,
                            color: Theme.ink.opacity(0.6),
                            lineWidth: 0.6, passes: 1, jitter: 0)

            // Selection ring: 안쪽 cobalt + 바깥 ink hairline 으로 인접
            // grayscale body (white@92%) 대비 WCAG 1.4.11 보강.
            if isGrabbed {
                Sketchy.circle(center: p, radius: pr + 3, ctx: ctx,
                                color: Theme.glow, lineWidth: 2.0)
                Sketchy.circle(center: p, radius: pr + 4.2, ctx: ctx,
                                color: Theme.ink.opacity(0.35),
                                lineWidth: 0.6)
            }
        }

        if vectorsOn {
            drawVectors(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }
        drawBodyLabels(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        if rulerOn {
            drawRuler(ctx: ctx, scale: scale, cx: cx, cy: cy, ext: extent.center)
        }
        // Energy / graphs panels were moved to a dedicated section below
        // the canvas (see `dataSection`), so they no longer overlay here.
        // Inspector panel moved to right-docked SwiftUI overlay
        // (`inspectorPanel`); only reticle stays on canvas.
        if let id = inspectedId,
           let body = world.bodies.first(where: { $0.id == id }) {
            drawInspectorReticle(ctx: ctx, body: body,
                                  scale: scale, cx: cx, cy: cy, ext: extent.center)
        }
    }

    private func drawBodyLabels(ctx: GraphicsContext, scale: CGFloat,
                                 cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        for body in world.bodies {
            guard let name = body.name, body.pos.isFinite else { continue }
            let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: ext)
            let pr = max(2, CGFloat(body.radius) * scale)
            ctx.draw(
                Text(name).font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.mist.opacity(0.9)),
                at: CGPoint(x: p.x, y: p.y - pr - 8))
        }
    }

    /// 선택된 body 주변에 작은 reticle (조준원) 만 그림. 정보 패널은
    /// `inspectorPanel` SwiftUI overlay 가 우측 도킹 위치에 따로 렌더.
    private func drawInspectorReticle(ctx: GraphicsContext,
                                        body: PhysicsBody, scale: CGFloat,
                                        cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let p = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: ext)
        let pr = max(2, CGFloat(body.radius) * scale)
        Sketchy.circle(center: p, radius: pr + 4, ctx: ctx,
                        color: Theme.glow, lineWidth: 1.2)
    }

    /// 인스펙터 정보 줄들 — drawInspector 와 SwiftUI 패널 모두에서 사용.
    private func inspectorLines(for body: PhysicsBody) -> [String] {
        let accels = world.accelerations()
        let idx = world.bodies.firstIndex(where: { $0.id == body.id }) ?? 0
        let a = idx < accels.count ? accels[idx] : .zero
        let ke = body.pinned ? 0 : 0.5 * body.mass * body.vel.lengthSquared
        var lines: [String] = [
            body.name ?? (body.kind.rawValue),
            "m = \(SciFormat.withUnit(body.mass, unit: "kg"))",
            "|v| = \(SciFormat.withUnit(body.vel.length, unit: "m/s"))",
            "|a| = \(SciFormat.withUnit(a.length, unit: "m/s²"))",
            "KE = \(SciFormat.withUnit(ke, unit: "J"))",
        ]
        switch preset.id {
        case "collision1d", "freecollide", "kepler", "nbody":
            lines.append("p = \(SciFormat.withUnit(body.mass * body.vel.length, unit: "kg·m/s"))")
        case "freefall", "projectile":
            lines.append("(\(SciFormat.fixed(body.pos.x, places: 2)), \(SciFormat.fixed(body.pos.y, places: 2))) m")
        case "lorentz", "efield":
            lines.append(String(format: "q = %+.3f C", body.charge))
        case "pendulum":
            if let pivot = world.bodies.first(where: { $0.pinned }) {
                let dx = body.pos.x - pivot.pos.x
                let dy = pivot.pos.y - body.pos.y
                let θ = atan2(dx, dy) * 180 / .pi
                lines.append("θ = \(SciFormat.degrees(θ))")
            }
        default: break
        }
        return lines
    }

    /// 우측 도킹 인스펙터 — Canvas 안 floating 패널을 대체. 본체가 어디
    /// 있든 위치 고정 → 좌/우 side flip 히스테리시스 불필요, body 가림
    /// 없음, 텍스트 선택/접근성 자연스러움.
    ///
    /// 정보 영역은 `.allowsHitTesting(false)` 로 body drag 가 통과 — 화면
    /// 우상단으로 드래그 시 인스펙터가 차단하지 않음. X 버튼만 hit.
    @ViewBuilder
    private var inspectorPanel: some View {
        if let id = inspectedId,
           let body = world.bodies.first(where: { $0.id == id }) {
            let lines = inspectorLines(for: body)
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(body.color)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Theme.ink.opacity(0.4), lineWidth: 0.5))
                        Text(lines.first ?? "")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 22)  // X 버튼 자리
                    }
                    ForEach(lines.dropFirst().indices, id: \.self) { i in
                        Text(lines[i + 1])
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.mist)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
                .padding(10)
                .frame(width: 148, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                .stroke(Theme.stroke, lineWidth: 0.5)
                        )
                )
                .allowsHitTesting(false)
                // VO 라벨: 6줄 전체 joined 는 5초 polling 으로 끝까지 못
                // 읽고 잘림. 핵심 3줄 (이름·질량·속력) 만 + updatesFrequently
                // 로 재읽기 빈도 자동 throttle.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(lines.prefix(3).joined(separator: ", ")))
                .accessibilityAddTraits(.updatesFrequently)

                Button {
                    inspectedId = nil
                    haptic(.light)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.mist)
                        .frame(width: 44, height: 44)  // HIG 44pt hit area
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("인스펙터 닫기"))
            }
            .padding(.trailing, 10)
            .padding(.top, 10)
            .transition(reduceMotion ? .opacity
                        : .opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private func drawVectors(ctx: GraphicsContext, scale: CGFloat,
                              cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let accels = world.accelerations()
        let movable = world.bodies.indices.filter { !world.bodies[$0].pinned }
        guard !movable.isEmpty else { return }
        let maxV = max(movable.map { world.bodies[$0].vel.length }.max() ?? 1, 0.001)
        let maxF = max(movable.map { (accels[$0] * world.bodies[$0].mass).length }.max() ?? 1, 0.001)
        let avgR = max(movable.map { world.bodies[$0].radius }.reduce(0, +)
                       / Double(movable.count), 0.1)
        let vWorld = 4.0 * avgR / maxV
        let fWorld = 4.0 * avgR / maxF

        for i in movable {
            let body = world.bodies[i]
            guard body.pos.isFinite else { continue }
            let start = mapPoint(body.pos, scale: scale, cx: cx, cy: cy, ext: ext)
            if body.vel.lengthSquared > 1e-9 {
                let end = mapPoint(body.pos + body.vel * vWorld,
                                   scale: scale, cx: cx, cy: cy, ext: ext)
                drawArrow(ctx: ctx, from: start, to: end, color: Theme.ink, dashed: false)
            }
            let F = accels[i] * body.mass
            if F.lengthSquared > 1e-9 {
                let end = mapPoint(body.pos + F * fWorld,
                                   scale: scale, cx: cx, cy: cy, ext: ext)
                drawArrow(ctx: ctx, from: start, to: end, color: Theme.ink, dashed: true)
            }
        }
    }

    private func drawArrow(ctx: GraphicsContext, from: CGPoint, to: CGPoint,
                            color: Color, dashed: Bool = false) {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 1.5 else { return }
        Sketchy.line(from: from, to: to, ctx: ctx, color: color,
                     lineWidth: 1.5, passes: 1, jitter: 0.5,
                     dash: dashed ? [4, 3] : nil)
        let nx = dx / len, ny = dy / len
        // Hide arrowhead when shaft is too short — 옛날엔 0.8px head 가
        // shaft 보다 작아 invisible head + visible shaft 가 stray dash 처럼
        // 보였음.
        guard len >= 6 else { return }
        let s = min(CGFloat(9), len * 0.5)
        let h1 = CGPoint(x: to.x - nx * s - ny * s * 0.45,
                         y: to.y - ny * s + nx * s * 0.45)
        let h2 = CGPoint(x: to.x - nx * s + ny * s * 0.45,
                         y: to.y - ny * s - nx * s * 0.45)
        Sketchy.line(from: to, to: h1, ctx: ctx, color: color,
                     lineWidth: 1.5, passes: 1, jitter: 0.3)
        Sketchy.line(from: to, to: h2, ctx: ctx, color: color,
                     lineWidth: 1.5, passes: 1, jitter: 0.3)
    }

    /// Renders the energy chart into the given panel rect (no background —
    /// caller's SwiftUI view provides that).
    private func drawEnergyChart(ctx: GraphicsContext, in panel: CGRect) {
        let e = world.energyBreakdown()
        let total = e.total
        // Header
        ctx.draw(Text(String(format: "KE %.2f   PE %+.2f   ΣE %+.2f",
                              e.kinetic, e.potential, total))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: panel.midX, y: panel.minY + 13))

        let plotR = CGRect(x: panel.minX + 10,
                           y: panel.minY + 26,
                           width: panel.width - 20,
                           height: panel.height - 38)
        ctx.stroke(Path(roundedRect: plotR, cornerRadius: 4),
                   with: .color(Theme.ink.opacity(0.22)), lineWidth: 0.6)

        guard energyHistory.count > 1 else {
            ctx.draw(Text("재생 중 에너지 추이 기록")
                        .font(.caption2).foregroundStyle(Theme.mist.opacity(0.6)),
                     at: CGPoint(x: plotR.midX, y: plotR.midY))
            return
        }

        let allValues = energyHistory.flatMap { [$0.kinetic, $0.potential, $0.total] }
        let lo = allValues.min() ?? 0
        let hi = allValues.max() ?? 1
        let span = max(hi - lo, 0.001)

        // 0 기준선
        if lo < 0 && hi > 0 {
            let zeroY = plotR.maxY - CGFloat((0 - lo) / span) * plotR.height
            var z = Path()
            z.move(to: CGPoint(x: plotR.minX, y: zeroY))
            z.addLine(to: CGPoint(x: plotR.maxX, y: zeroY))
            ctx.stroke(z, with: .color(Theme.ink.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }

        let entries: [(KeyPath<World.EnergyBreakdown, Double>, [CGFloat]?, CGFloat, Color)] = [
            (\.kinetic,   nil,    1.4, Theme.ink),    // solid ink
            (\.potential, [4, 3], 1.2, Theme.ink),    // dashed ink
            (\.total,     nil,    1.8, Theme.energy), // solid gold — energy semantic
        ]
        for (kp, dash, lw, color) in entries {
            var path = Path()
            // Denominator = actual count, not max capacity — otherwise the
            // first few seconds of recording (history.count << energyHistMax)
            // get squashed into the leftmost ~12% of the chart.
            let denom = CGFloat(max(energyHistory.count - 1, 1))
            for (i, e) in energyHistory.enumerated() {
                let f = CGFloat(i) / denom
                let px = plotR.minX + f * plotR.width
                let py = plotR.maxY - CGFloat((e[keyPath: kp] - lo) / span) * plotR.height
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else      { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            let style: StrokeStyle = dash == nil
                ? StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
                : StrokeStyle(lineWidth: lw, lineCap: .round,
                              lineJoin: .round, dash: dash!)
            ctx.stroke(path, with: .color(color), style: style)
        }
        // Legend
        ctx.draw(Text("실선 KE   점선 PE   굵선 ΣE")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.mist),
                 at: CGPoint(x: plotR.midX, y: plotR.maxY - 6))
    }

    private func mapPoint(_ p: Vec3, scale: CGFloat, cx: CGFloat, cy: CGFloat,
                          ext: CGPoint) -> CGPoint {
        CGPoint(x: cx + CGFloat(p.x - ext.x) * scale,
                y: cy - CGFloat(p.y - ext.y) * scale)
    }

    /// 분석 모드 격자 + 좌표축. zoom 에 맞춰 round-number 간격을 1·2·5
    /// 시퀀스로 선택 → 항상 측정 가능한 좌표선. 축 라벨은 매우 옅게 (Tufte
    /// minimum-ink). 원점이 화면 안에 있으면 더 진한 0 축.
    private func drawAnalysisGrid(ctx: GraphicsContext, size: CGSize,
                                    scale: CGFloat, cx: CGFloat, cy: CGFloat,
                                    ext: CGPoint) {
        guard scale > 0 else { return }
        // 화면 60pt 근처에서 round 간격 선택.
        let targetPx: CGFloat = 60
        let rawSpacing = Double(targetPx / scale)
        let pow10 = pow(10, floor(log10(rawSpacing)))
        let normalized = rawSpacing / pow10
        let stepped: Double = (normalized < 1.5) ? 1.0
                            : (normalized < 3.5) ? 2.0
                            : (normalized < 7.5) ? 5.0 : 10.0
        let spacing = stepped * pow10
        let spacingPx = CGFloat(spacing) * scale

        // 화면 좌상단/우하단의 world 좌표 → grid 시작점.
        let leftW = Double((-cx) / scale) + ext.x
        let rightW = Double((size.width - cx) / scale) + ext.x
        let topW = -Double((-cy) / scale) + ext.y     // y 화면 ↓ = world ↑
        let bottomW = -Double((size.height - cy) / scale) + ext.y

        let xStart = (leftW / spacing).rounded(.down) * spacing
        let xEnd = (rightW / spacing).rounded(.up) * spacing
        let yStart = (bottomW / spacing).rounded(.down) * spacing
        let yEnd = (topW / spacing).rounded(.up) * spacing

        // 격자선 — 0.5pt 옅은 ink. 너무 빽빽한 zoom 보호 (분당 100 라인 cap).
        // 0.08 → 0.10 (다크에서 white@8% 가 캔버스 회색과 거의 동일해 보임 —
        // Datawrapper / CleanChart 다크 권장 5–10% 상단).
        guard spacingPx >= 8 else { return }
        let lineColor = Theme.ink.opacity(0.10)
        var x = xStart
        while x <= xEnd {
            let sx = cx + CGFloat(x - ext.x) * scale
            if sx >= 0, sx <= size.width {
                var p = Path()
                p.move(to: CGPoint(x: sx, y: 0))
                p.addLine(to: CGPoint(x: sx, y: size.height))
                ctx.stroke(p, with: .color(lineColor), lineWidth: 0.5)
            }
            x += spacing
        }
        var y = yStart
        while y <= yEnd {
            let sy = cy - CGFloat(y - ext.y) * scale
            if sy >= 0, sy <= size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: sy))
                p.addLine(to: CGPoint(x: size.width, y: sy))
                ctx.stroke(p, with: .color(lineColor), lineWidth: 0.5)
            }
            y += spacing
        }

        // 0 축 (원점) — 더 진한 1pt ink.
        let originX = cx - CGFloat(ext.x) * scale
        let originY = cy + CGFloat(ext.y) * scale
        let axisColor = Theme.ink.opacity(0.28)
        if originX >= 0, originX <= size.width {
            var p = Path()
            p.move(to: CGPoint(x: originX, y: 0))
            p.addLine(to: CGPoint(x: originX, y: size.height))
            ctx.stroke(p, with: .color(axisColor), lineWidth: 0.8)
        }
        if originY >= 0, originY <= size.height {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: originY))
            p.addLine(to: CGPoint(x: size.width, y: originY))
            ctx.stroke(p, with: .color(axisColor), lineWidth: 0.8)
        }

        // 라벨 — 격자 spacing 단위로만 (디시멀 자릿수는 spacing 으로 결정).
        if spacingPx >= 36 {
            let labelColor = Theme.mist.opacity(0.6)
            // Canvas Text 가 Dynamic Type 을 따르도록 text-style 폰트 사용.
            let labelFont = Font.caption2.monospacedDigit()
            let decimals = max(0, Int(-floor(log10(spacing))))
            // x 라벨 — 0 축 위 또는 화면 하단.
            let xLabelY: CGFloat = (originY >= 8 && originY <= size.height - 14)
                ? originY + 8
                : size.height - 14
            var lx = xStart
            while lx <= xEnd {
                if abs(lx) > 1e-9 {  // 0 라벨은 생략
                    let sx = cx + CGFloat(lx - ext.x) * scale
                    if sx >= 14, sx <= size.width - 14 {
                        ctx.draw(Text(String(format: "%.\(decimals)f", lx))
                                    .font(labelFont).foregroundStyle(labelColor),
                                 at: CGPoint(x: sx, y: xLabelY))
                    }
                }
                lx += spacing
            }
            let yLabelX: CGFloat = (originX >= 16 && originX <= size.width - 28)
                ? originX - 10
                : 14
            var ly = yStart
            while ly <= yEnd {
                if abs(ly) > 1e-9 {
                    let sy = cy - CGFloat(ly - ext.y) * scale
                    if sy >= 10, sy <= size.height - 10 {
                        ctx.draw(Text(String(format: "%.\(decimals)f", ly))
                                    .font(labelFont).foregroundStyle(labelColor),
                                 at: CGPoint(x: yLabelX, y: sy),
                                 anchor: .trailing)
                    }
                }
                ly += spacing
            }
        }
    }

    private func drawFieldGrid(ctx: GraphicsContext, size: CGSize, outward: Bool) {
        // Step = 0.5 world units → screen pt, clamped to readable range.
        // 옛날 36pt 고정 → 8x 줌에서 dense ant trail, 0.25x 줌에서 9px 격자.
        // 이제는 zoom 에 따라 적응 — physical interpretation 유지.
        let scale = viewScale()
        let step: CGFloat = max(20, min(64, 0.5 * scale))
        var x: CGFloat = step / 2
        while x < size.width {
            var y: CGFloat = step / 2
            while y < size.height {
                if outward {
                    let r: CGFloat = 1.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                                     width: r * 2, height: r * 2)),
                             with: .color(Theme.ink.opacity(0.45)))
                } else {
                    Sketchy.line(from: CGPoint(x: x - 3, y: y - 3),
                                  to: CGPoint(x: x + 3, y: y + 3),
                                  ctx: ctx, color: Theme.ink.opacity(0.55),
                                  lineWidth: 0.9, passes: 1, jitter: 0.15)
                    Sketchy.line(from: CGPoint(x: x - 3, y: y + 3),
                                  to: CGPoint(x: x + 3, y: y - 3),
                                  ctx: ctx, color: Theme.ink.opacity(0.55),
                                  lineWidth: 0.9, passes: 1, jitter: 0.15)
                }
                y += step
            }
            x += step
        }
    }

    private func drawEFieldLines(ctx: GraphicsContext, scale: CGFloat,
                                 cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let charges = world.bodies.filter { $0.charge != 0 && $0.pos.isFinite }
        let positives = charges.filter { $0.charge > 0 }
        guard !positives.isEmpty else { return }
        // Cached extent for exit check (replaces world `|p|>50` zoom-blind cap).
        let viewExtent = computeExtent()

        let nLines = 14
        let stepSize: Double = 0.06
        let maxSteps = 400

        for c in positives {
            for i in 0..<nLines {
                let θ = Double(i) / Double(nLines) * 2 * .pi
                let r0 = c.radius * 1.6
                var p = Vec3(x: c.pos.x + r0 * cos(θ),
                             y: c.pos.y + r0 * sin(θ), z: 0)
                var pts: [CGPoint] = [mapPoint(p, scale: scale, cx: cx, cy: cy, ext: ext)]

                var stopped = false
                for _ in 0..<maxSteps {
                    var Ex: Double = 0, Ey: Double = 0
                    for q in charges {
                        let dx = p.x - q.pos.x
                        let dy = p.y - q.pos.y
                        let r2 = dx * dx + dy * dy
                        if r2 < 1e-6 { stopped = true; break }
                        let r = r2.squareRoot()
                        let f = q.charge / (r2 * r)
                        Ex += f * dx
                        Ey += f * dy
                    }
                    if stopped { break }
                    let mag = (Ex * Ex + Ey * Ey).squareRoot()
                    if mag < 1e-9 { break }
                    p.x += stepSize * Ex / mag
                    p.y += stepSize * Ey / mag
                    pts.append(mapPoint(p, scale: scale, cx: cx, cy: cy, ext: ext))
                    for q in charges where q.charge < 0 {
                        let dx = p.x - q.pos.x
                        let dy = p.y - q.pos.y
                        if dx * dx + dy * dy < q.radius * q.radius * 2.5 {
                            stopped = true; break
                        }
                    }
                    if stopped { break }
                    // Visible-region exit — 옛날 world `|p|>50` 은 zoom 무시.
                    // 이제 computeExtent 기반으로 visible region + 약간의
                    // margin 만 follow.
                    let exitX = viewExtent.x * 1.4
                    let exitY = viewExtent.y * 1.4
                    if abs(p.x - viewExtent.center.x) > exitX
                        || abs(p.y - viewExtent.center.y) > exitY { break }
                    if !p.isFinite { break }
                }

                guard pts.count > 1 else { continue }
                Sketchy.polyline(pts, ctx: ctx, color: Theme.ink.opacity(0.65),
                                 lineWidth: 1.1, passes: 1, jitter: 0.3)

                let midIdx = pts.count / 2
                if midIdx >= 1 && midIdx < pts.count {
                    drawArrowhead(ctx: ctx,
                                  from: pts[midIdx - 1],
                                  to: pts[midIdx],
                                  color: Theme.ink)
                }
            }
        }
    }

    private func drawArrowhead(ctx: GraphicsContext, from a: CGPoint, to b: CGPoint,
                               color: Color) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0.001 else { return }
        let nx = dx / len, ny = dy / len
        let size: CGFloat = 5
        let h1 = CGPoint(x: b.x - nx * size - ny * size * 0.5,
                         y: b.y - ny * size + nx * size * 0.5)
        let h2 = CGPoint(x: b.x - nx * size + ny * size * 0.5,
                         y: b.y - ny * size - nx * size * 0.5)
        Sketchy.line(from: b, to: h1, ctx: ctx, color: color,
                     lineWidth: 1.2, passes: 1, jitter: 0.2)
        Sketchy.line(from: b, to: h2, ctx: ctx, color: color,
                     lineWidth: 1.2, passes: 1, jitter: 0.2)
    }

    private struct Extent { var center: CGPoint; var x: Double; var y: Double }

    private var hasFixedBounds: Bool { world.bounds != nil }

    /// The world region drawn on the main canvas. For bounded sims this is
    /// the world bounds. For unbounded sims (kepler/nbody/lorentz) this is
    /// pinned to `initialExtent` so the view doesn't zoom in/out as bodies
    /// orbit — bodies that go off-screen show up on the mini-map instead.
    private func computeExtent() -> Extent {
        if let b = world.bounds {
            return Extent(
                center: CGPoint(x: (b.min.x + b.max.x) / 2,
                                y: (b.min.y + b.max.y) / 2),
                x: max(0.5, (b.max.x - b.min.x) / 2),
                y: max(0.5, (b.max.y - b.min.y) / 2))
        }
        return Extent(center: .zero,
                      x: max(5, Double(initialExtent.width)),
                      y: max(5, Double(initialExtent.height)))
    }

    /// The extent covering every body's farthest reach so far — used to
    /// scale the mini-map so distant bodies are always visible there.
    private func miniMapExtent() -> Extent {
        if let b = world.bounds {
            return Extent(
                center: CGPoint(x: (b.min.x + b.max.x) / 2,
                                y: (b.min.y + b.max.y) / 2),
                x: max(0.5, (b.max.x - b.min.x) / 2),
                y: max(0.5, (b.max.y - b.min.y) / 2))
        }
        return Extent(center: .zero,
                      x: max(5, Double(maxObservedExtent.width)),
                      y: max(5, Double(maxObservedExtent.height)))
    }

    private func captureInitialExtent() {
        guard !hasFixedBounds else { return }
        let xs = world.bodies.compactMap { $0.pos.x.isFinite ? $0.pos.x : nil }
        let ys = world.bodies.compactMap { $0.pos.y.isFinite ? $0.pos.y : nil }
        // Tight initial view — body 가까이 보고 싶다. 행성이 멀리 가도
        // mini-map이 전체 궤도를 보여주므로 main canvas는 시작 위치 기준.
        let mx = (xs.map { abs($0) }.max() ?? 3) * 1.3
        let my = (ys.map { abs($0) }.max() ?? 3) * 1.3
        initialExtent = CGSize(width: max(3, CGFloat(mx)),
                                height: max(3, CGFloat(my)))
        maxObservedExtent = initialExtent
    }

    private func updateMaxObservedExtent() {
        guard !hasFixedBounds else { return }
        let xs = world.bodies.compactMap { $0.pos.x.isFinite ? $0.pos.x : nil }
        let ys = world.bodies.compactMap { $0.pos.y.isFinite ? $0.pos.y : nil }
        let mx = (xs.map { abs($0) }.max() ?? 5) * 1.4
        let my = (ys.map { abs($0) }.max() ?? 5) * 1.4
        maxObservedExtent.width = max(maxObservedExtent.width, CGFloat(mx))
        maxObservedExtent.height = max(maxObservedExtent.height, CGFloat(my))
    }

    private var needsMiniMap: Bool {
        // Show mini-map for unbounded sims where bodies can wander
        // far from the locked initial view.
        guard !hasFixedBounds else { return false }
        let extX = max(1, maxObservedExtent.width)
        let extY = max(1, maxObservedExtent.height)
        // Reveal once the world has expanded ≥ ~25% beyond the locked view.
        return extX > initialExtent.width * 1.25
            || extY > initialExtent.height * 1.25
    }

    /// Renders the motion (x/y position + velocity) chart into the given
    /// panel rect. Background and corner styling is the caller's job.
    private func drawMotionChart(ctx: GraphicsContext, in panel: CGRect) {
        guard let body = graphTargetBody(),
              let history = motionHistory[body.id], history.count > 1 else {
            ctx.draw(Text("재생 중 위치·속도 추이 기록")
                        .font(.caption2).foregroundStyle(Theme.mist.opacity(0.65)),
                     at: CGPoint(x: panel.midX, y: panel.midY))
            return
        }

        let title = body.name ?? "선택 입자"
        ctx.draw(Text("\(title) — x·y(m) ⏐ vₓ·v_y(m/s)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: panel.midX, y: panel.minY + 13))

        let inner = CGRect(x: panel.minX + 10,
                           y: panel.minY + 26,
                           width: panel.width - 20,
                           height: panel.height - 36)
        let subH = (inner.height - 6) / 2
        let posR = CGRect(x: inner.minX, y: inner.minY,
                          width: inner.width, height: subH - 2)
        let velR = CGRect(x: inner.minX, y: inner.minY + subH + 4,
                          width: inner.width, height: subH - 2)

        drawTwoCurve(ctx: ctx, in: posR, history: history,
                     keyA: { $0.pos.x }, keyB: { $0.pos.y },
                     leftLabel: "x", rightLabel: "y")
        drawTwoCurve(ctx: ctx, in: velR, history: history,
                     keyA: { $0.vel.x }, keyB: { $0.vel.y },
                     leftLabel: "vₓ", rightLabel: "v_y")
    }

    private func drawTwoCurve(ctx: GraphicsContext, in r: CGRect,
                              history: [MotionSample],
                              keyA: (MotionSample) -> Double,
                              keyB: (MotionSample) -> Double,
                              leftLabel: String, rightLabel: String) {
        let valsA = history.map(keyA)
        let valsB = history.map(keyB)
        let lo = min(valsA.min() ?? 0, valsB.min() ?? 0)
        let hi = max(valsA.max() ?? 1, valsB.max() ?? 1)
        let span = max(hi - lo, 0.001)

        ctx.stroke(Path(roundedRect: r, cornerRadius: 4),
                   with: .color(Theme.ink.opacity(0.35)), lineWidth: 0.7)

        if lo < 0 && hi > 0 {
            let zeroY = r.maxY - CGFloat((0 - lo) / span) * r.height
            var z = Path()
            z.move(to: CGPoint(x: r.minX, y: zeroY))
            z.addLine(to: CGPoint(x: r.maxX, y: zeroY))
            ctx.stroke(z, with: .color(Theme.ink.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }

        // A: solid, B: dashed
        for (vals, dashed) in [(valsA, false), (valsB, true)] {
            var p = Path()
            let denom = CGFloat(max(history.count - 1, 1))
            for (i, v) in vals.enumerated() {
                let f = CGFloat(i) / denom
                let px = r.minX + f * r.width
                let py = r.maxY - CGFloat((v - lo) / span) * r.height
                if i == 0 { p.move(to: CGPoint(x: px, y: py)) }
                else      { p.addLine(to: CGPoint(x: px, y: py)) }
            }
            let style: StrokeStyle = dashed
                ? StrokeStyle(lineWidth: 1.1, lineCap: .round,
                              lineJoin: .round, dash: [4, 3])
                : StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            ctx.stroke(p, with: .color(Theme.ink), style: style)
        }

        // Current value labels at right edge
        let last = history.last
        let a = last.map(keyA) ?? 0
        let b = last.map(keyB) ?? 0
        ctx.draw(Text("\(leftLabel) \(String(format: "%+.2f", a))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.ink),
                 at: CGPoint(x: r.maxX - 4, y: r.minY + 6), anchor: .trailing)
        ctx.draw(Text("\(rightLabel) \(String(format: "%+.2f", b))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.mist),
                 at: CGPoint(x: r.maxX - 4, y: r.minY + 16), anchor: .trailing)
    }

    private func drawRuler(ctx: GraphicsContext, scale: CGFloat,
                           cx: CGFloat, cy: CGFloat, ext: CGPoint) {
        let s = mapPoint(rulerStart, scale: scale, cx: cx, cy: cy, ext: ext)
        let e = mapPoint(rulerEnd, scale: scale, cx: cx, cy: cy, ext: ext)

        // Main rod
        Sketchy.line(from: s, to: e, ctx: ctx, color: Theme.ink,
                     lineWidth: 1.7, passes: 2, jitter: 0.6)

        // Tick marks every 0.5 m
        let dxW = rulerEnd.x - rulerStart.x
        let dyW = rulerEnd.y - rulerStart.y
        let distW = (dxW * dxW + dyW * dyW).squareRoot()
        let lineLen = hypot(e.x - s.x, e.y - s.y)
        if distW > 0.2, lineLen > 4 {
            // Adaptive tick step — 화면 8개 정도의 tick 을 목표로 nice
            // round number (1, 2, 5, 10, 20, 50 ...) 선택. 옛날에는 0.5 m
            // 고정 + 80개 cap → 100m 자에서 40m 만 표시되는 버그.
            let rawStep = distW / 8
            let mag = pow(10.0, floor(log10(rawStep)))
            let normalized = rawStep / mag
            let nice: Double
            if normalized < 1.5 { nice = 1 }
            else if normalized < 3.5 { nice = 2 }
            else if normalized < 7.5 { nice = 5 }
            else { nice = 10 }
            let tickStep = nice * mag
            let nTicks = min(Int(distW / tickStep) + 1, 60)
            let perpX = -(e.y - s.y) / lineLen
            let perpY =  (e.x - s.x) / lineLen
            for i in 0...nTicks {
                let t = CGFloat(Double(i) * tickStep / distW)
                let xC = s.x + (e.x - s.x) * t
                let yC = s.y + (e.y - s.y) * t
                let isMajor = (i % 2 == 0)
                let tl: CGFloat = isMajor ? 5 : 3
                Sketchy.line(from: CGPoint(x: xC - perpX * tl, y: yC - perpY * tl),
                              to: CGPoint(x: xC + perpX * tl, y: yC + perpY * tl),
                              ctx: ctx, color: Theme.ink,
                              lineWidth: 0.9, passes: 1, jitter: 0.2)
            }
        }

        // Endpoint handles (larger for easier grabbing)
        for pt in [s, e] {
            Sketchy.fillCircle(center: pt, radius: 10, ctx: ctx,
                                fill: Theme.surface, stroke: Theme.ink,
                                strokeWidth: 1.6)
        }

        // Label
        let mid = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
        let label = String(format: "%.2f m", distW)
        var ox: CGFloat = 0, oy: CGFloat = -14
        if lineLen > 0.5 {
            let nx = (e.y - s.y) / lineLen
            let ny = -(e.x - s.x) / lineLen
            ox = nx * 14; oy = ny * 14
        }
        let lblPt = CGPoint(x: mid.x + ox, y: mid.y + oy)
        let bg = CGRect(x: lblPt.x - 32, y: lblPt.y - 9, width: 64, height: 18)
        ctx.fill(Path(roundedRect: bg, cornerRadius: 4),
                 with: .color(Theme.surface.opacity(0.92)))
        Sketchy.rect(bg, ctx: ctx, color: Theme.ink,
                     lineWidth: 0.9, passes: 1, jitter: 0.3)
        ctx.draw(Text(label).font(.caption2.monospacedDigit()).foregroundStyle(Theme.ink),
                 at: lblPt)
    }

    fileprivate struct MotionSample {
        let t: Double
        let pos: Vec3
        let vel: Vec3
    }

    fileprivate enum RulerEnd { case start, end }

    fileprivate enum DragMode {
        case none
        case pendingTap                  // touch down, not yet classified
        case body(UUID)
        case pan(initial: CGSize)
        case rulerStart
        case rulerEnd
        case consumed                    // long-press fired, ignore remaining moves
    }
}

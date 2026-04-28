# 온누리 (Onnuri)

> "온 세상" 을 뜻하는 순우리말. 대학교 2학년까지의 물리를 눈으로 볼 수 있게
> 만든 SwiftUI 시뮬레이션 모음 — iOS / iPadOS / macOS.

외부 의존성 없이 SwiftUI 표준 컴포넌트(`Canvas`, `TimelineView`) 만 사용.

## 수록 시뮬레이션

| 분류 | 시뮬 | 다루는 개념 |
|------|------|------|
| 역학 | 포물선 운동 | 등가속도 운동, 선형 공기저항의 해석해 |
|     | 단진자 | 비선형 ODE 와 작은-각 근사 비교 (RK4) |
|     | 감쇠·구동 진동자 | 감쇠비 ζ, 공명 곡선 \|X(ω)\| |
|     | 1차원 충돌 | 운동량 보존, 반발계수 e, KE 변화 |
|     | 케플러 궤도 | 역제곱 중심력, 타원/포물선/쌍곡선, L 보존 |
| 파동·열 | 파동의 중첩 | 맥놀이, 정상파 |
|     | 도플러 효과 | 움직이는 음원의 파면, 마하 충격파 |
|     | 기체 분자 운동 | 딱딱한 원판 충돌, 맥스웰–볼츠만 분포 |
| 전자기 | 전기력선 | 점전하 배치, 전기장 적분으로 그린 흐름선 |
|     | 자기장 속 하전입자 | 사이클로트론 운동, E×B 표류 |
|     | RLC 회로 | 공명 ω₀ = 1/√(LC), 위상, 임피던스 곡선 |
| 광학 | 이중 슬릿 | 간섭 ⊗ 단일슬릿 회절의 합성 패턴 |
|     | 얇은 렌즈 결상 | 1/f = 1/p + 1/q, 광선 작도, 실상/허상 |

## 빌드 & 실행

### 1) Xcode 프로젝트 생성

`.xcodeproj` 파일은 저장소에 포함하지 않았다. [XcodeGen](https://github.com/yonaskolb/XcodeGen) 으로 생성한다.

```sh
brew install xcodegen
xcodegen generate
open Onnuri.xcodeproj
```

`project.yml` 한 파일이 모든 빌드 설정을 담고 있다.

### 2) 직접 만들고 싶다면

XcodeGen 없이 진행하려면:

1. Xcode → *File ▸ New ▸ Project ▸ App* (Multiplatform)
2. Product Name: `Onnuri`, Bundle Identifier: `app.onnuri.Onnuri`,
   Interface: SwiftUI, Language: Swift.
3. 생성된 기본 `ContentView.swift`, `OnnuriApp.swift` 를 삭제하고 이 저장소의
   `Onnuri/` 안의 모든 `.swift` 파일과 `Resources/Assets.xcassets` 를 끌어다 넣는다.
4. *Signing & Capabilities* 에서 Team 선택 후 시뮬레이터로 실행.

### 시스템 요구사항

- Xcode 15 이상
- iOS 17 / iPadOS 17 / macOS 14 (Sonoma) 이상

## 코드 구조

```
Onnuri/
├── OnnuriApp.swift          # @main 진입점
├── RootView.swift           # NavigationSplitView 카탈로그
├── Util/
│   ├── Vec2.swift           # 2D 벡터 연산
│   ├── CanvasMap.swift      # 월드(미터) ↔ 픽셀 변환
│   └── SimChrome.swift      # 공통 레이아웃, 슬라이더, 측정값 행
├── Models/
│   └── SimulationCatalog.swift   # 카탈로그 + 분류
├── Simulations/             # 13 개 시뮬 화면
└── Resources/Assets.xcassets
```

각 시뮬 파일은 `View` 한 개로 자체 완결 — 위 화면(Canvas) + 우측 컨트롤
패널의 동일한 패턴을 따른다. `TimelineView(.animation(paused:))` 로 고정
프레임 갱신, 필요한 경우 그 안에서 직접 ODE 적분.

## 학습 동선 제안

1. **포물선 → 단진자 → 감쇠·구동 진동자**: 1자유도 ODE 의 단순화에서 비선형,
   감쇠, 강제 진동까지의 흐름.
2. **충돌 → 케플러**: 운동량/에너지/각운동량 보존을 시각적으로.
3. **파동 중첩 → 도플러 → 이중슬릿**: 시간/공간에서의 위상 차가 만드는 무늬.
4. **전기력선 → 자기장 속 하전입자 → RLC**: 정적장 → 운동 → 회로 응답.
5. **얇은 렌즈**: 광선 작도와 부호 규약.

## 기존 C++/SDL 데모

이 저장소는 원래 `src/physics_sim.cpp` 의 단일 파일 SDL2 데모였다. 그
코드는 `legacy/` 로 이동했고, 컴파일 방법은 `legacy/build.sh` 에 그대로
남아 있다.

## 라이선스

MIT.

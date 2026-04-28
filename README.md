# 온누리 (Onnuri)

> "온 세상" 을 뜻하는 순우리말. 초등 / 중등 / 고등 교육과정과 자유 샌드박스를
> 한데 모은 SwiftUI 물리 시뮬 앱 — iOS 26 · iPadOS 26 · macOS 26 (Liquid Glass).

외부 의존성 없음. SwiftUI 의 `Canvas`, `TimelineView`, `glassEffect`, 그리고
`buttonStyle(.glass)` 만 사용.

## 시작화면 → 학년별 카탈로그

```
            온누리
   ──────────────────────
       [ 초등학교 ]
       [ 중학교  ]
       [ 고등학교 ]

       자유 시뮬레이션
```

큰 타일 셋이 학년별 카탈로그로, 그 아래 작은 텍스트가 자유 샌드박스로 들어간다.

## 수록 시뮬레이션

### 초등학교 (3–6학년 과학)
| 시뮬 | 다루는 개념 |
|------|------|
| 자석의 인력과 반발 | 같은 극끼리 밀고 다른 극끼리 당김 (역제곱 모형) |
| 지렛대 | 받침점에서 거리 × 무게 — 토크 균형 |
| 부력 | 잠긴 부피 비율 = 밀도 비율 |
| 빛과 그림자 | 점광원과 닮음 삼각형 |
| 그네 (진자) | 줄 길이와 주기 (단순화 UI) |

### 중학교 (1–3학년 과학)
| 시뮬 | 다루는 개념 |
|------|------|
| 자유낙하·연직 던지기 | y = y₀ + v₀t − ½gt², 분석해 |
| 등속 vs 등가속도 | 위치–시간, 속도–시간 그래프 |
| 빛의 반사·굴절 | n₁ sinθ₁ = n₂ sinθ₂, 임계각 |
| 직렬·병렬 회로 | 옴의 법칙으로 정확히 계산 |
| 열전달과 평형 | T_eq = (m₁c₁T₁ + m₂c₂T₂) / Σmc |
| 1차원 충돌 | 운동량 보존, 반발계수 |

### 고등학교 (물리Ⅰ·Ⅱ)
| 시뮬 | 다루는 개념 |
|------|------|
| 포물선 운동 | 선형 drag 의 해석해 |
| 단진자 (비선형) | RK4 vs 작은-각 근사 |
| 감쇠·구동 진동자 | 공명 곡선 \|X(ω)\|, 감쇠비 ζ |
| 케플러 궤도 | symplectic Euler, 에너지·L 보존 |
| 파동의 중첩 | 맥놀이, 정상파 |
| 도플러 효과 | 움직이는 음원의 파면 |
| 기체 분자 운동 | 맥스웰–볼츠만 분포 |
| 전기력선 | 점전하의 streamline |
| 자기장 속 하전입자 | 사이클로트론, E×B 표류 |
| 직렬 RLC | 공명 ω₀ = 1/√(LC), 위상 |
| 이중 슬릿 | 간섭 ⊗ 회절의 합성 |
| 얇은 렌즈 결상 | 1/f = 1/p + 1/q, 광선 작도 (수렴/발산 모두) |

### 자유 시뮬레이션 (샌드박스)
| 시뮬 | 다루는 개념 |
|------|------|
| 자유 충돌 박스 | 재질(강철·고무·점토·얼음)별 e·ρ, 다체 동시 충돌. 박스 안 어디든 탭하면 입자 생성. |
| N체 중력 | Velocity-Verlet 으로 에너지·각운동량 보존. 태양–행성 / 이중성 / Chenciner–Montgomery 8자 / 8체 무작위 프리셋. |

## 정확성 원칙

> 보이는 것은 시각효과가 들어간 근사라도, **계산 결과는 정확하다.**

- 등가속도 운동(자유낙하·등속/등가속도 그래프)은 닫힌 해를 사용 (수치오차 0).
- 충돌은 법선 임펄스 J = (1+e)·μ·v·n̂ 으로 운동량을 매 충돌에서 정확히 보존.
- 다체 중력은 velocity-Verlet (symplectic) — 에너지가 장기간 ε 범위에서 진동.
- 회로·렌즈·슬넬·도플러는 닫힌 해.
- 옴의 법칙·열용량 비례식·임피던스 등은 모두 정확한 분석식.

각 시뮬의 우측 패널에 보존되는 양(총 운동량 / 운동에너지 / 각운동량 / 에너지)을
실시간으로 표시해서 "정말 보존되는지" 직접 확인할 수 있다.

## 빌드 & 실행

`.xcodeproj` 는 저장소에 포함하지 않고 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 으로 생성한다.

```sh
brew install xcodegen
xcodegen generate
open Onnuri.xcodeproj
```

직접 만들고 싶으면: Xcode → File ▸ New ▸ Project ▸ App (Multiplatform).
Bundle ID `app.onnuri.Onnuri`, Interface SwiftUI, Language Swift. 기본 생성된
`ContentView.swift`, `OnnuriApp.swift` 를 지우고 `Onnuri/` 안의 모든 `.swift`
와 `Resources/Assets.xcassets` 를 끌어다 넣는다.

### 시스템 요구사항

- Xcode 17 이상
- iOS 26 / iPadOS 26 / macOS 26 (Tahoe) 이상

## 코드 구조

```
Onnuri/
├── OnnuriApp.swift               @main
├── StartView.swift               시작화면 (학년 선택 + 자유 링크)
├── CurriculumView.swift          학년별 시뮬 목록
├── Util/
│   ├── Vec2.swift                2D 벡터
│   ├── CanvasMap.swift           월드(미터) ↔ 픽셀 변환
│   ├── SimChrome.swift           공통 레이아웃·컨트롤
│   └── LiquidGlass.swift         iOS 26 glassEffect 헬퍼
├── Models/
│   ├── Curriculum.swift          교육과정 enum + 색·아이콘
│   └── SimulationCatalog.swift   ID → View 매핑 + 학년별 목록
├── Simulations/                  24 개 시뮬 화면
└── Resources/Assets.xcassets
```

## 라이선스

MIT.

# 윤슬 (Yunseul)

> "햇빛·달빛에 어린 잔물결" 을 뜻하는 순우리말. 초등 / 중등 / 고등
> 교육과정과 자유 샌드박스를 한데 모은 SwiftUI 물리 시뮬 앱
> — **iOS 26 / iPadOS 26 전용**.

깊은 밤바다 위에 떠 있는 따뜻한 금빛 결을 모티프로 한 고유한 디자인 시스템.

## 디자인 토큰

| 토큰 | 색 | 용도 |
|------|-----|-----|
| `void / deep / surface / crest` | 짙은 남빛 4단계 (`#050816 → #1E2750`) | 바닥·패널·헤더 |
| **`glow`** | `#E0B574` 따뜻한 금빛 | 재생·확정 등 주 액션 |
| **`accent`** | `#66D4C0` 청록 진주 | 슬라이더 트랙·보조 |
| `pulse` | `#B98DE5` 자수정 | 선택 |
| `confirm / danger` | 박하 / 산호 | 보존·위험 |
| `ink / mist` | 따뜻한 상아 / 안개 푸른 회색 | 본문·보조 텍스트 |

비주얼 시그니처:

- **시뮬 뷰포트**는 dot-grid 대신 `RippleField` (잔잔한 수평 잔물결).
- **시작화면**은 `StarField` (별자리 점 분포 + 큰 별 두 개) + 위쪽 금빛 광원.
- **카드**는 Liquid Glass 위에 `surface` 톤을 살짝 입히고, 좌상단에 작은 금빛 마커 점.
- **시작 표제 아래**에 짧은 금빛 잔물결(`RippleAccent`) 한 줄.
- 외부 의존성 없음. SwiftUI 표준(`Canvas`, `TimelineView`, `glassEffect`,
  `buttonStyle(.glass)`, `buttonStyle(.glassProminent)`) 만 사용.

## 시작화면 → 학년별 카탈로그

```
              윤슬
   ──────────────────────
       [ 초등학교 ]
       [ 중학교  ]
       [ 고등학교 ]

       자유 시뮬레이션
```

큰 타일 셋이 학년별 카탈로그로, 그 아래 작은 텍스트가 자유 샌드박스로 들어간다.

## 수록 시뮬레이션 (총 24개)

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
| 자유 충돌 박스 | 재질(강철·고무·점토·얼음)별 e·ρ. 박스 안 어디든 **탭하면 그 자리에 새 입자 생성**. "3개 충돌 / 뉴턴 요람 / 무작위 12" 프리셋. |
| N체 중력 | Velocity-Verlet 으로 에너지·각운동량 보존. 태양–행성 / 이중성 / Chenciner–Montgomery 8자 / 8체 무작위 프리셋. |

## 정확성 원칙

> 보이는 것은 시각효과가 들어간 근사라도, **계산 결과는 정확하다.**

- 등가속도 운동(자유낙하·등속/등가속도 그래프)은 닫힌 해를 사용 (수치오차 0).
- 충돌은 법선 임펄스 J = (1+e)·μ·v·n̂ 으로 운동량을 매 충돌에서 정확히 보존.
  서로 다른 재질의 입자는 e_pair = √(e₁·e₂) (기하 평균).
- 다체 중력은 velocity-Verlet (symplectic) — 에너지가 장기간 ε 범위에서 진동.
- 회로·렌즈·스넬·도플러·임피던스 등은 모두 정확한 분석식.
- 단진자만 RK4 (비선형 ODE 라 닫힌 해 없음) — 작은-각 근사와 나란히 그려서 차이를 직접 볼 수 있다.

각 시뮬의 우측 패널에 보존되는 양(총 운동량 / 운동에너지 / 각운동량 / 에너지)을
실시간으로 표시해서 "정말 보존되는지" 직접 확인할 수 있다.

## 화면 구성

- 큰 화면(가로 ≥ 760pt)에서는 좌측 viewport + 우측 properties panel.
- 좁으면 위 viewport + 아래 properties panel.
- properties panel 헤더는 small caps + 트래킹된 `PROPERTIES` 라벨.
- 슬라이더 값은 모노스페이스 + 금빛, 측정값은 모노스페이스 + 따뜻한 상아색.

## 교육과정 연계 (`ConceptCard`)

GeoGebra 의 "이론 영역" 처럼, 시뮬을 열면 properties 패널 가장 위에
**무엇을 다루는 단원인지** 와 **핵심 공식**이 한 카드로 박혀 있다.

```
┌────────────────────────────────────────────┐
│  🎓 물리Ⅰ · 등가속도 운동                   │
│  ┌──────────────────────────────────────┐  │
│  │  x = v₀ cosθ · t                      │  │
│  │  y = v₀ sinθ · t − ½ g t²             │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

- 한국 교육과정과 매핑된 단원 태그 (예: *중3 과학 · 운동과 에너지*,
  *물리Ⅱ · 자기장과 운동*).
- 공식은 모노스페이스 박스 + 금빛 보더 + 텍스트 선택 가능.
- 학년 카탈로그의 시뮬 행에도 같은 태그가 작은 칩으로 미리 보인다.

매핑은 `SimulationCatalog.allItems` 한 곳에서 정의되고, 환경 값
`\.simulationItem` 을 통해 모든 시뮬 화면에 자동으로 흘러간다.

## 빌드 & 실행

`.xcodeproj` 는 저장소에 포함하지 않고 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 으로 생성한다.

```sh
brew install xcodegen
xcodegen generate
open Yunseul.xcodeproj
```

`project.yml` 한 파일이 모든 빌드 설정을 담고 있다. 직접 만들고 싶으면
Xcode → File ▸ New ▸ Project ▸ App (iOS), Bundle ID `app.yunseul.Yunseul`,
Interface SwiftUI, Language Swift. 기본 `ContentView.swift`/`YunseulApp.swift`
삭제 후 이 저장소의 `Yunseul/` 안 모든 `.swift` 와 `Resources/Assets.xcassets`
를 끌어 넣는다.

### 시스템 요구사항

- Xcode 17 이상 (iOS 26 SDK 포함)
- iOS 26 / iPadOS 26 이상

## 코드 구조

```
Yunseul/
├── YunseulApp.swift              @main
├── StartView.swift               시작화면 (학년 선택 + 자유 링크)
├── CurriculumView.swift          학년별 시뮬 목록
├── Util/
│   ├── Vec2.swift                2D 벡터
│   ├── CanvasMap.swift           월드(미터) ↔ 픽셀 변환
│   ├── SimChrome.swift           viewport + properties + 슬라이더
│   └── Theme.swift               윤슬 팔레트·폰트·themeCard·RippleField·StarField
├── Models/
│   ├── Curriculum.swift          교육과정 enum + 색·아이콘
│   └── SimulationCatalog.swift   ID → View 매핑 + 학년별 목록
├── Simulations/                  24 개 시뮬 화면
└── Resources/Assets.xcassets
```

## 라이선스

MIT.

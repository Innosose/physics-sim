# 윤슬 (Yunseul)

> "햇빛·달빛에 어린 잔물결" 을 뜻하는 순우리말. **중·고등학생** 과 자유
> 샌드박스를 위한 SwiftUI 물리 시뮬 앱 — **iOS 26 / iPadOS 26 전용**.

깊은 밤바다(다크) 또는 잔잔한 새벽 수면(라이트) 위에 떠 있는 금빛 결을
모티프로 한 고유한 디자인 시스템.

## 디자인 원칙

- **글자로 정체성** — SVG 도, 큰 SF Symbol 도 안 쓴다. 학년·카테고리 표시는
  한글 글자(중·고·자 / 역·파·전·광·샌) + 색 배경의 작은 정사각 마크 (`LetterMark`).
- **심볼은 포인트로만** — 작고 기능적인 심볼(▶·↻·›·🎓 등) 은 그대로 사용.
- **닫힌 해 우선** — 모든 결과값은 수학적 닫힌 해(analytical) 로 계산.
  - 등가속도·반사·굴절·옴·도플러·렌즈·이중슬릿·전기력선 등은 본래 닫힌 해.
  - **HeatTransfer / Spring / RLC / Lorentz / Kepler** 는 적분 없이
    분석해 직접 평가 (지수감쇠·감쇠진동·E×B 표류·Kepler 방정식 Newton 풀이).
  - 단진자 비선형은 일반적으로 초등 함수로 표현 불가 (타원적분 sn 필요)
    → 작은-각 닫힌 해 + 비선형 RK4 두 개 동시 표시 (라벨링).
  - 다체 문제(자유 충돌·기체 분자·N체 중력) 는 *각 사건* 은 닫힌 해
    임펄스, 사이는 등속 운동(닫힌 해) — 구간별 닫힌 해. N체 중력만
    **수치 적분 (Verlet)** 으로 별도 표시.
- **라이트 / 다크 / 시스템** — 모든 색 토큰은 `Color.adaptive(light:dark:)`
  로 정의. Settings 에서 사용자가 선택.

## 디자인 토큰 (다크 / 라이트 자동)

| 토큰 | 다크 | 라이트 | 용도 |
|------|------|--------|------|
| `void / deep / surface / crest` | 짙은 남빛 4단계 | 옅은 안개 4단계 | 바닥·패널·헤더 |
| **`glow`** | `#E0B574` | `#C78D2E` 황금빛 | 주 액션 |
| **`accent`** | `#66D4C0` | `#33A695` 청록 | 슬라이더 트랙·보조 |
| `pulse / confirm / danger` | 자수정 / 박하 / 산호 | 같은 톤 (어두운 계열) | 선택·보존·위험 |
| `ink / mist` | 상아 / 안개 푸른 회색 | 짙은 남빛 / 중간 회색 | 본문·보조 텍스트 |
| `decorationLine` | 흰색 | 검정 | 별·잔물결 등 장식 라인 |

비주얼 시그니처:

- **시뮬 뷰포트**: `RippleField` (잔잔한 수평 잔물결, 금빛 라인).
- **사이드바·환영 화면**: `StarField` (별자리 + 큰 별 두 개).
- **카드**: Liquid Glass 위에 `surface` 톤. 좌상단에 작은 금빛 마커 점.
- **표제 아래**: 짧은 금빛 잔물결 (`RippleAccent`).
- **로고**: `Resources/Assets.xcassets/AppLogo.imageset/` 슬롯 — 사용자가
  직접 만든 이미지 추가. 비어 있으면 작은 금빛 점으로 fallback.

## 화면 구조 — 계층형 (`NavigationSplitView`)

```
┌──────────────┬──────────────────┬─────────────────────┐
│  ◉ YUNSEUL   │  중학교           │   포물선 운동        │
│   윤슬   ⚙   │  운동과 에너지     │   ┌─ Concept ────┐  │
│   ~~~~~      │  [역] 자유낙하    │   │ 🎓 물리Ⅰ      │  │
│              │  [역] 등속 vs …   │   │ y = …         │  │
│  [중] 중학교 ●│  …              │   └──────────────┘  │
│  [고] 고등학교│                  │   ◀ viewport ▶      │
│  [자] 자유   │                  │   [ 슬라이더 …]    │
└──────────────┴──────────────────┴─────────────────────┘
   sidebar       content              detail
```

- **Sidebar**: 윤슬 브랜드 헤더 + 3 학년 행 (중·고·자유). 우상단 ⚙ 로 Settings.
- **Content**: 카테고리(역·파·전·광·샌) 별 그룹 + 시뮬 행. 각 행에 단원 칩.
- **Detail**: 선택된 시뮬 화면. 미선택 시 환영 화면.

## 수록 시뮬레이션 (총 20개)

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
| 얇은 렌즈 결상 | 1/f = 1/p + 1/q, 광선 작도 |

### 자유 시뮬레이션 (샌드박스)
| 시뮬 | 다루는 개념 |
|------|------|
| 자유 충돌 박스 | 재질별 e·ρ. 박스 안 어디든 탭하면 새 입자 생성. |
| N체 중력 | Velocity-Verlet 으로 에너지·각운동량 보존. |

## 교육과정 연계 (`ConceptCard`)

GeoGebra 의 "이론 영역" 처럼, 시뮬을 열면 properties 패널 가장 위에
**무엇을 다루는 단원인지** 와 **핵심 공식**이 한 카드로 박혀 있다.

- 한국 교육과정과 매핑된 단원 태그 (예: *중3 과학 · 운동과 에너지*).
- 공식은 모노스페이스 박스 + 금빛 보더 + 텍스트 선택 가능.
- 학년 카탈로그의 시뮬 행에도 같은 태그가 작은 칩으로 미리 보임.

## 빌드 & 실행

```sh
brew install xcodegen
xcodegen generate
open Yunseul.xcodeproj
```

### 시스템 요구사항

- Xcode 17 이상 (iOS 26 SDK 포함)
- iOS 26 / iPadOS 26 이상

## 코드 구조

```
Yunseul/
├── YunseulApp.swift              @main — 외관(다크/라이트/시스템) 적용
├── RootSplitView.swift           NavigationSplitView 3-column
├── SettingsView.swift            외관 선택 + 앱 정보
├── Util/
│   ├── Vec2.swift                2D 벡터
│   ├── CanvasMap.swift           월드(미터) ↔ 픽셀 변환
│   ├── SimChrome.swift           viewport + ConceptCard + properties
│   └── Theme.swift               adaptive 팔레트 + LetterMark + 장식 뷰
├── Models/
│   ├── Curriculum.swift          학년 enum + letterMark + accent
│   └── SimulationCatalog.swift   ID → View 매핑 + 학년별 목록 + 환경값
├── Simulations/                  20 개 시뮬 화면
└── Resources/Assets.xcassets/
    ├── AppIcon.appiconset
    ├── AccentColor.colorset
    └── AppLogo.imageset          ← 사용자 로고 슬롯
```

## 라이선스

MIT.

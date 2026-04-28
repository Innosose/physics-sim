# physics-sim — 교육용 물리 시뮬레이션 (단일 파일)

작은 SDL2 + OpenGL 3.3 프로그램. 외부 의존성은 SDL2 만. 학생이 코드 전체
(~400 줄) 를 읽고 이해할 수 있도록 의도적으로 압축.

## 학습 포인트

1. **Semi-implicit Euler 적분기** — `physics_step()` 함수 한 곳에 중력,
   drag (선형 감쇠), 위치 갱신, 바닥 충돌이 모두 들어 있음.
2. **에너지 보존** — drag=0 일 때 KE+PE 가 거의 일정 (수치 적분 1-2% drift).
   bounce 시 inelastic → 가시적 KE 감소.
3. **충돌 응답** — `if (b.pos.y < floor + radius)` 분기에서 위치 보정 +
   속도 반사 (restitution). 가장 단순한 상호작용.
4. **OpenGL 최소 파이프라인** — VS/FS shader 한 페어, 단위 cube 1 개,
   uniform 으로 색/모델 행렬 변경. Lambert 조명만.

## 의존성

| 플랫폼 | 패키지 |
|--------|--------|
| Linux (apt) | `libsdl2-dev` |
| macOS (brew) | `sdl2` |
| Windows (vcpkg) | `sdl2` |

## 빌드 & 실행

```bash
./build.sh           # POSIX (Linux/macOS)
./physics_sim
```

또는 수동 컴파일:
```bash
c++ -std=c++17 -O2 -o physics_sim src/physics_sim.cpp \
    $(sdl2-config --cflags --libs) -lGL -ldl   # Linux
```

## 조작

| 키 | 동작 |
|----|------|
| `Space` | 다시 발사 (위치/속도 reset) |
| `↑ ↓` | 발사각 ±5° (0..89°) |
| `← →` | 초속력 ±2 m/s (1..50) |
| `D` | drag toggle (0 ↔ 0.10) |
| `ESC` | 종료 |

stdout 에 0.5 초 간격으로 측정값 출력:
```
t= 1.00s  pos=( -6.97, 7.48)  vel=( 8.03, 1.66) |v|= 8.20  KE= 33.62 PE= 63.58 E= 97.20  [angle=55 speed=14 drag=0]
```

## 코드 구조 (src/physics_sim.cpp)

| 섹션 | 줄 | 내용 |
|------|----|------|
| GL 함수 포인터 로드 | 35-90 | macOS/Win 용 `SDL_GL_GetProcAddress` |
| `Vec3`, `Mat4` | 95-145 | 최소 선형대수 (perspective, look_at) |
| `Body`, `physics_step` | 150-180 | 적분기 본체 |
| Shader / mesh | 185-260 | VS+FS, 단위 cube 36 vert |
| `main` | 265-끝 | SDL 초기화, 메인 루프, 발사 / 키 / 렌더 |

## 실험 제안

1. `gravity = 1.62` — 달 중력. 비행 시간 6 배.
2. `restitution = 1.0` — 완전 탄성 → 영원히 튕김 (수치 오차 누적 시 결국 정지).
3. `drag = 0.5` — 강한 공기 저항 → 포물선이 비대칭 (descent 가 더 짧음).
4. 발사각 30°, 45°, 60° 실험 → 사정거리 비교 (h₀=1m 환경).
5. 코드 수정: Verlet 적분기로 교체하여 `E` drift 비교.

## 확장 (TODO)

- on-screen HUD (현재는 stdout)
- 다중 시나리오: pendulum, spring, 1D collision, billiards
- 그래프 출력 (시간 vs E, vs vy 등)
- JSON 시나리오 파일 + scenario 선택 메뉴

## 라이선스

MIT (사용 / 수정 / 재배포 자유).

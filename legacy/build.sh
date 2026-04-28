#!/usr/bin/env bash
# build.sh - physics_sim 단일 파일 컴파일.
#
# 의존성: c++17 컴파일러 + SDL2 (apt: libsdl2-dev / brew: sdl2 / vcpkg: sdl2).
# 결과: ./physics_sim 실행 파일.

set -euo pipefail
cd "$(dirname "$0")"

CXX=${CXX:-c++}
SDL_FLAGS=$(sdl2-config --cflags --libs)

UNAME=$(uname -s)
case "$UNAME" in
    Darwin)
        # macOS: -framework OpenGL.
        $CXX -std=c++17 -O2 -Wall -o physics_sim src/physics_sim.cpp \
             $SDL_FLAGS -framework OpenGL
        ;;
    Linux)
        # Linux: GL 동적 link, dlopen 용 ldl.
        $CXX -std=c++17 -O2 -Wall -o physics_sim src/physics_sim.cpp \
             $SDL_FLAGS -lGL -ldl
        ;;
    *)
        echo "Unsupported platform: $UNAME (Linux / macOS / Windows-WSL only)"
        exit 1
        ;;
esac

echo "✓ built ./physics_sim — run with ./physics_sim"

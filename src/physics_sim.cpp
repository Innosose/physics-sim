// physics_sim.cpp - 교육용 물리 시뮬레이션. 단일 파일, SDL2 + OpenGL 3.3.
//
// 빌드:
//   POSIX:   c++ -std=c++17 -O2 -o physics_sim src/physics_sim.cpp \
//                  $(sdl2-config --cflags --libs) -ldl
//   macOS:   c++ -std=c++17 -O2 -o physics_sim src/physics_sim.cpp \
//                  $(sdl2-config --cflags --libs) -framework OpenGL
//   Windows: cl /std:c++17 /O2 src/physics_sim.cpp /I<SDL2 headers> ...
//
// 의존성: SDL2 만 (system 또는 vcpkg). GL 함수 포인터는 런타임 로드.
//
// 학습 목표:
//   1) 적분기 (semi-implicit Euler) 의 코드 구조 파악.
//   2) 운동에너지 + 위치에너지 → 보존 (drag=0 가정).
//   3) 발사각/초속력 변경 → 사정거리 변화 직관.
//   4) 비탄성 충돌 (restitution) 의 에너지 손실.
//
// 조작:
//   Space  → 다시 발사 (모든 매개변수 reset 안 함, 위치/속도만)
//   ↑ ↓    → 발사각 ±5°
//   ← →    → 초속력 ±2 m/s
//   D      → drag toggle (0 ↔ 0.1)
//   ESC    → 종료

#include <SDL.h>
#define GL_GLEXT_PROTOTYPES   // Linux 기본
#include <SDL_opengl.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

// ────────────────────── GL 함수 포인터 (macOS / Windows 용) ──────────────────────
//
// macOS / Windows 는 GL 헤더에 modern 함수 포인터 안 옴 → SDL_GL_GetProcAddress
// 로 런타임 로드. Linux 는 GL_GLEXT_PROTOTYPES 로 정적 link 가능하지만 모든
// 플랫폼 공통 동작 위해 항상 동적 로드.

#if defined(__APPLE__) || defined(_WIN32)
typedef GLuint (APIENTRY *PFN_glCreateShader)(GLenum);
typedef void   (APIENTRY *PFN_glShaderSource)(GLuint, GLsizei, const GLchar* const*, const GLint*);
typedef void   (APIENTRY *PFN_glCompileShader)(GLuint);
typedef void   (APIENTRY *PFN_glGetShaderiv)(GLuint, GLenum, GLint*);
typedef void   (APIENTRY *PFN_glGetShaderInfoLog)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef void   (APIENTRY *PFN_glDeleteShader)(GLuint);
typedef GLuint (APIENTRY *PFN_glCreateProgram)(void);
typedef void   (APIENTRY *PFN_glAttachShader)(GLuint, GLuint);
typedef void   (APIENTRY *PFN_glLinkProgram)(GLuint);
typedef void   (APIENTRY *PFN_glGetProgramiv)(GLuint, GLenum, GLint*);
typedef void   (APIENTRY *PFN_glUseProgram)(GLuint);
typedef GLint  (APIENTRY *PFN_glGetUniformLocation)(GLuint, const GLchar*);
typedef void   (APIENTRY *PFN_glUniformMatrix4fv)(GLint, GLsizei, GLboolean, const GLfloat*);
typedef void   (APIENTRY *PFN_glUniform4f)(GLint, GLfloat, GLfloat, GLfloat, GLfloat);
typedef void   (APIENTRY *PFN_glUniform3f)(GLint, GLfloat, GLfloat, GLfloat);
typedef void   (APIENTRY *PFN_glGenVertexArrays)(GLsizei, GLuint*);
typedef void   (APIENTRY *PFN_glBindVertexArray)(GLuint);
typedef void   (APIENTRY *PFN_glGenBuffers)(GLsizei, GLuint*);
typedef void   (APIENTRY *PFN_glBindBuffer)(GLenum, GLuint);
typedef void   (APIENTRY *PFN_glBufferData)(GLenum, GLsizeiptr, const void*, GLenum);
typedef void   (APIENTRY *PFN_glEnableVertexAttribArray)(GLuint);
typedef void   (APIENTRY *PFN_glVertexAttribPointer)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void*);

#define GL_FUNCS                                              \
    X(glCreateShader)        X(glShaderSource)                \
    X(glCompileShader)       X(glGetShaderiv)                 \
    X(glGetShaderInfoLog)    X(glDeleteShader)                \
    X(glCreateProgram)       X(glAttachShader)                \
    X(glLinkProgram)         X(glGetProgramiv)                \
    X(glUseProgram)          X(glGetUniformLocation)          \
    X(glUniformMatrix4fv)    X(glUniform4f)                   \
    X(glUniform3f)           X(glGenVertexArrays)             \
    X(glBindVertexArray)     X(glGenBuffers)                  \
    X(glBindBuffer)          X(glBufferData)                  \
    X(glEnableVertexAttribArray)                              \
    X(glVertexAttribPointer)

#define X(name) static PFN_##name name = nullptr;
GL_FUNCS
#undef X

static bool gl_load() {
#define X(name) \
    name = (PFN_##name)SDL_GL_GetProcAddress(#name); \
    if (!name) { std::fprintf(stderr, "GL load fail: %s\n", #name); return false; }
    GL_FUNCS
#undef X
    return true;
}
#else
static bool gl_load() { return true; }   // Linux: 헤더에 직접 정의 됨.
#endif

// ────────────────────── Math ──────────────────────

struct Vec3 {
    float x, y, z;
    Vec3 operator+(Vec3 r) const { return {x+r.x, y+r.y, z+r.z}; }
    Vec3 operator-(Vec3 r) const { return {x-r.x, y-r.y, z-r.z}; }
    Vec3 operator*(float s) const { return {x*s, y*s, z*s}; }
    float length() const { return std::sqrt(x*x + y*y + z*z); }
};

struct Mat4 {
    float m[16];   // column-major (OpenGL convention).
    static Mat4 identity() {
        Mat4 r{};
        r.m[0] = r.m[5] = r.m[10] = r.m[15] = 1;
        return r;
    }
    static Mat4 translate(Vec3 t) {
        Mat4 r = identity();
        r.m[12] = t.x; r.m[13] = t.y; r.m[14] = t.z;
        return r;
    }
    static Mat4 scale(Vec3 s) {
        Mat4 r{};
        r.m[0] = s.x; r.m[5] = s.y; r.m[10] = s.z; r.m[15] = 1;
        return r;
    }
    static Mat4 perspective(float fov_rad, float aspect, float n, float f) {
        Mat4 r{};
        float t = std::tan(fov_rad * 0.5f);
        r.m[0]  = 1.0f / (aspect * t);
        r.m[5]  = 1.0f / t;
        r.m[10] = -(f + n) / (f - n);
        r.m[11] = -1.0f;
        r.m[14] = -(2.0f * f * n) / (f - n);
        return r;
    }
    static Mat4 look_at(Vec3 eye, Vec3 center, Vec3 up) {
        Vec3 f = center - eye;
        float fl = f.length(); f = (fl > 1e-6f) ? f * (1.0f / fl) : Vec3{0,0,-1};
        Vec3 s = { f.y*up.z - f.z*up.y, f.z*up.x - f.x*up.z, f.x*up.y - f.y*up.x };
        float sl = s.length(); s = (sl > 1e-6f) ? s * (1.0f / sl) : Vec3{1,0,0};
        Vec3 u = { s.y*f.z - s.z*f.y, s.z*f.x - s.x*f.z, s.x*f.y - s.y*f.x };
        Mat4 r = identity();
        r.m[0] = s.x;  r.m[4] = s.y;  r.m[8]  = s.z;
        r.m[1] = u.x;  r.m[5] = u.y;  r.m[9]  = u.z;
        r.m[2] =-f.x;  r.m[6] =-f.y;  r.m[10] =-f.z;
        r.m[12] = -(s.x*eye.x + s.y*eye.y + s.z*eye.z);
        r.m[13] = -(u.x*eye.x + u.y*eye.y + u.z*eye.z);
        r.m[14] =  (f.x*eye.x + f.y*eye.y + f.z*eye.z);
        return r;
    }
    Mat4 operator*(const Mat4& r) const {
        Mat4 o{};
        for (int c = 0; c < 4; ++c)
            for (int rrow = 0; rrow < 4; ++rrow) {
                float v = 0;
                for (int k = 0; k < 4; ++k) v += m[k*4 + rrow] * r.m[c*4 + k];
                o.m[c*4 + rrow] = v;
            }
        return o;
    }
};

// ────────────────────── Physics ──────────────────────

struct Body {
    Vec3  pos{0, 0, 0};
    Vec3  vel{0, 0, 0};
    float mass = 1.0f;
    float radius = 0.3f;       // 바닥 충돌용 충돌 반경 (cube scale).
    float restitution = 0.55f; // 0..1.
};

// 학습 포인트: Semi-implicit Euler 적분기.
//   1) 가속도 → 속도 (vel += a * dt)
//   2) drag (선형 감쇠) → 속도
//   3) 속도 → 위치 (pos += vel * dt)
//   4) 바닥 충돌 (y < floor + radius): 위치 보정 + 속도 반사 (restitution).
//
// vs Explicit Euler: 위치 갱신에 *현재* 속도 사용. 안정성 향상.
// vs Verlet/RK4: 더 정확하지만 코드 복잡도 ↑. 교육용은 semi-implicit 가 표준 선택.
static void physics_step(Body& b, float dt, float gravity, float drag, float floor_y) {
    b.vel.y -= gravity * dt;
    float k = 1.0f - drag * dt;
    if (k < 0) k = 0;
    b.vel = b.vel * k;
    b.pos = b.pos + b.vel * dt;
    if (b.pos.y < floor_y + b.radius) {
        b.pos.y = floor_y + b.radius;
        b.vel.y = -b.vel.y * b.restitution;
        if (std::fabs(b.vel.y) < 0.15f) b.vel.y = 0;   // 작은 진동 정지.
    }
}

// ────────────────────── Render ──────────────────────

static const char* VS = R"(
#version 330 core
layout(location=0) in vec3 a_pos;
layout(location=1) in vec3 a_norm;
uniform mat4 u_mvp;
uniform mat4 u_model;
out vec3 v_norm_world;
out vec3 v_pos_world;
void main() {
    vec4 wp = u_model * vec4(a_pos, 1.0);
    v_pos_world = wp.xyz;
    v_norm_world = mat3(u_model) * a_norm;
    gl_Position = u_mvp * vec4(a_pos, 1.0);
}
)";
static const char* FS = R"(
#version 330 core
in vec3 v_norm_world;
in vec3 v_pos_world;
uniform vec4 u_color;
uniform vec3 u_light_dir;
out vec4 frag;
void main() {
    vec3 n = normalize(v_norm_world);
    float lambert = max(dot(n, normalize(-u_light_dir)), 0.0);
    vec3 lit = u_color.rgb * (0.25 + 0.75 * lambert);
    frag = vec4(lit, u_color.a);
}
)";

static GLuint compile_shader(GLenum kind, const char* src) {
    GLuint s = glCreateShader(kind);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof(log), nullptr, log);
        std::fprintf(stderr, "shader compile fail: %s\n", log);
        glDeleteShader(s);
        return 0;
    }
    return s;
}
static GLuint build_program() {
    GLuint vs = compile_shader(GL_VERTEX_SHADER, VS);
    GLuint fs = compile_shader(GL_FRAGMENT_SHADER, FS);
    if (!vs || !fs) return 0;
    GLuint p = glCreateProgram();
    glAttachShader(p, vs);
    glAttachShader(p, fs);
    glLinkProgram(p);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    glDeleteShader(vs); glDeleteShader(fs);
    if (!ok) { std::fprintf(stderr, "program link fail\n"); return 0; }
    return p;
}

// 단위 큐브 (centered at origin, edge length 1). pos + normal interleaved.
struct Mesh {
    GLuint vao = 0, vbo = 0;
    GLsizei count = 0;
};
static Mesh build_cube() {
    // 6 faces × 2 tris × 3 verts = 36. (pos.xyz, normal.xyz)
    static const float V[] = {
        // +X
         0.5, -0.5, -0.5,  1, 0, 0,   0.5,  0.5, -0.5, 1, 0, 0,   0.5,  0.5,  0.5, 1, 0, 0,
         0.5, -0.5, -0.5,  1, 0, 0,   0.5,  0.5,  0.5, 1, 0, 0,   0.5, -0.5,  0.5, 1, 0, 0,
        // -X
        -0.5, -0.5,  0.5, -1, 0, 0,  -0.5,  0.5,  0.5, -1, 0, 0,  -0.5,  0.5, -0.5, -1, 0, 0,
        -0.5, -0.5,  0.5, -1, 0, 0,  -0.5,  0.5, -0.5, -1, 0, 0,  -0.5, -0.5, -0.5, -1, 0, 0,
        // +Y
        -0.5,  0.5, -0.5, 0, 1, 0,  -0.5,  0.5,  0.5, 0, 1, 0,   0.5,  0.5,  0.5, 0, 1, 0,
        -0.5,  0.5, -0.5, 0, 1, 0,   0.5,  0.5,  0.5, 0, 1, 0,   0.5,  0.5, -0.5, 0, 1, 0,
        // -Y
        -0.5, -0.5,  0.5, 0,-1, 0,  -0.5, -0.5, -0.5, 0,-1, 0,   0.5, -0.5, -0.5, 0,-1, 0,
        -0.5, -0.5,  0.5, 0,-1, 0,   0.5, -0.5, -0.5, 0,-1, 0,   0.5, -0.5,  0.5, 0,-1, 0,
        // +Z
        -0.5, -0.5,  0.5, 0, 0, 1,   0.5, -0.5,  0.5, 0, 0, 1,   0.5,  0.5,  0.5, 0, 0, 1,
        -0.5, -0.5,  0.5, 0, 0, 1,   0.5,  0.5,  0.5, 0, 0, 1,  -0.5,  0.5,  0.5, 0, 0, 1,
        // -Z
         0.5, -0.5, -0.5, 0, 0,-1,  -0.5, -0.5, -0.5, 0, 0,-1,  -0.5,  0.5, -0.5, 0, 0,-1,
         0.5, -0.5, -0.5, 0, 0,-1,  -0.5,  0.5, -0.5, 0, 0,-1,   0.5,  0.5, -0.5, 0, 0,-1,
    };
    Mesh m;
    glGenVertexArrays(1, &m.vao);
    glGenBuffers(1, &m.vbo);
    glBindVertexArray(m.vao);
    glBindBuffer(GL_ARRAY_BUFFER, m.vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(V), V, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3 * sizeof(float)));
    glBindVertexArray(0);
    m.count = sizeof(V) / sizeof(float) / 6;
    return m;
}

// ────────────────────── Main ──────────────────────

int main(int /*argc*/, char** /*argv*/) {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::fprintf(stderr, "SDL init fail: %s\n", SDL_GetError());
        return 1;
    }
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    SDL_Window* win = SDL_CreateWindow("physics_sim — projectile",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!win) { std::fprintf(stderr, "Window fail: %s\n", SDL_GetError()); return 1; }
    SDL_GLContext ctx = SDL_GL_CreateContext(win);
    if (!ctx) { std::fprintf(stderr, "GL ctx fail: %s\n", SDL_GetError()); return 1; }
    if (!gl_load()) return 1;
    SDL_GL_SetSwapInterval(1);   // vsync.

    GLuint prog = build_program();
    if (!prog) return 1;
    Mesh cube = build_cube();

    // Ball state + 발사 매개변수 (학습용 — 키보드로 조정).
    Body ball;
    ball.pos = {-15, 1, 0};
    ball.radius = 0.3f;
    ball.restitution = 0.55f;
    float launch_speed = 14.0f;
    float launch_angle = 55.0f;
    float gravity = 9.81f;
    float drag = 0.0f;
    float t_elapsed = 0;

    auto launch = [&]() {
        ball.pos = {-15, 1, 0};
        float ang = launch_angle * 3.14159265f / 180.0f;
        ball.vel = { std::cos(ang) * launch_speed, std::sin(ang) * launch_speed, 0 };
        t_elapsed = 0;
    };
    launch();

    GLint u_mvp     = glGetUniformLocation(prog, "u_mvp");
    GLint u_model   = glGetUniformLocation(prog, "u_model");
    GLint u_color   = glGetUniformLocation(prog, "u_color");
    GLint u_lightd  = glGetUniformLocation(prog, "u_light_dir");

    glEnable(GL_DEPTH_TEST);

    bool running = true;
    bool drag_on = false;
    int  print_div = 0;
    Uint64 last_freq = SDL_GetPerformanceFrequency();
    Uint64 last_t = SDL_GetPerformanceCounter();
    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) running = false;
            if (e.type == SDL_KEYDOWN) {
                switch (e.key.keysym.sym) {
                case SDLK_ESCAPE: running = false; break;
                case SDLK_SPACE:  launch(); break;
                case SDLK_UP:     launch_angle += 5.0f; if (launch_angle > 89) launch_angle = 89; break;
                case SDLK_DOWN:   launch_angle -= 5.0f; if (launch_angle < 0)  launch_angle = 0; break;
                case SDLK_RIGHT:  launch_speed += 2.0f; if (launch_speed > 50) launch_speed = 50; break;
                case SDLK_LEFT:   launch_speed -= 2.0f; if (launch_speed < 1)  launch_speed = 1; break;
                case SDLK_d:      drag_on = !drag_on; drag = drag_on ? 0.10f : 0.0f; break;
                }
            }
        }

        // Fixed dt 1/60 — 시각/물리 같은 step (단순화).
        float dt = 1.0f / 60.0f;
        physics_step(ball, dt, gravity, drag, 0.0f);
        t_elapsed += dt;

        // 30 frame (0.5s) 마다 stdout 측정 출력 (HUD 대신).
        if (++print_div >= 30) {
            print_div = 0;
            float speed = ball.vel.length();
            float ke = 0.5f * ball.mass * speed * speed;
            float pe = ball.mass * gravity * (ball.pos.y - 1.0f);
            std::printf("t=%5.2fs  pos=(%6.2f,%5.2f)  vel=(%5.2f,%5.2f) |v|=%5.2f  "
                        "KE=%6.2f PE=%6.2f E=%6.2f  [angle=%g speed=%g drag=%s]\n",
                        t_elapsed, ball.pos.x, ball.pos.y, ball.vel.x, ball.vel.y, speed,
                        ke, pe, ke + pe, launch_angle, launch_speed, drag_on ? "0.10" : "0");
            std::fflush(stdout);
        }

        // ── render ─────────
        int w, h; SDL_GL_GetDrawableSize(win, &w, &h);
        glViewport(0, 0, w, h);
        glClearColor(0.55f, 0.65f, 0.78f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        Mat4 proj = Mat4::perspective(50.0f * 3.14159f / 180.0f, float(w) / float(h ? h : 1), 0.1f, 200.0f);
        Mat4 view = Mat4::look_at({0, 6, 22}, {0, 4, 0}, {0, 1, 0});
        Mat4 vp = proj * view;

        glUseProgram(prog);
        glUniform3f(u_lightd, -0.4f, -0.8f, -0.3f);

        // Ground (큰 납작 cube).
        {
            Mat4 model = Mat4::translate({0, -0.25f, 0}) * Mat4::scale({60, 0.5f, 30});
            Mat4 mvp = vp * model;
            glUniformMatrix4fv(u_mvp, 1, GL_FALSE, mvp.m);
            glUniformMatrix4fv(u_model, 1, GL_FALSE, model.m);
            glUniform4f(u_color, 0.40f, 0.42f, 0.45f, 1.0f);
            glBindVertexArray(cube.vao);
            glDrawArrays(GL_TRIANGLES, 0, cube.count);
        }
        // Backboard (시각 깊이감).
        {
            Mat4 model = Mat4::translate({0, 5, -10}) * Mat4::scale({60, 10, 0.5f});
            Mat4 mvp = vp * model;
            glUniformMatrix4fv(u_mvp, 1, GL_FALSE, mvp.m);
            glUniformMatrix4fv(u_model, 1, GL_FALSE, model.m);
            glUniform4f(u_color, 0.16f, 0.18f, 0.22f, 1.0f);
            glDrawArrays(GL_TRIANGLES, 0, cube.count);
        }
        // Ball.
        {
            float s = ball.radius * 2.0f;
            Mat4 model = Mat4::translate(ball.pos) * Mat4::scale({s, s, s});
            Mat4 mvp = vp * model;
            glUniformMatrix4fv(u_mvp, 1, GL_FALSE, mvp.m);
            glUniformMatrix4fv(u_model, 1, GL_FALSE, model.m);
            glUniform4f(u_color, 0.95f, 0.55f, 0.10f, 1.0f);
            glDrawArrays(GL_TRIANGLES, 0, cube.count);
        }

        SDL_GL_SwapWindow(win);

        // CPU 부하 ↓.
        Uint64 now = SDL_GetPerformanceCounter();
        double frame_dt = double(now - last_t) / double(last_freq);
        if (frame_dt < 1.0 / 120.0) SDL_Delay(1);
        last_t = now;
    }

    SDL_GL_DeleteContext(ctx);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}

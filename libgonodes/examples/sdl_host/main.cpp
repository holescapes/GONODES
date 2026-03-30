/*
 * GONODES SDL Host Example
 *
 * Demonstrates embedding GONODES in a general-purpose SDL2 application
 * with an OpenGL rendering context.  The host creates an SDL window and
 * GL context, shares the context with LibGodot, loads a .gnpatch, feeds
 * an LFO value into a HostInCHOP, cooks each frame, and renders the
 * output texture from a HostOutTOP as a fullscreen quad.
 *
 * After loading, the Host I/O manifest is queried via gonodes_get_host_io()
 * to discover the patch's declared inputs, outputs, and exposed parameters.
 *
 * Build:
 *   cd libgonodes/build && cmake .. && cmake --build . --target sdl_host
 *
 * Run:
 *   ./sdl_host path/to/gonodes_project path/to/show.gnpatch
 */

#include <gonodes_host.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_opengl.h>

#include <cstdio>
#include <cstdlib>
#include <cmath>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Fullscreen Quad Renderer                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

static const char* VS_SRC =
    "#version 330 core\n"
    "out vec2 uv;\n"
    "void main() {\n"
    "    float x = float((gl_VertexID & 1) << 2) - 1.0;\n"
    "    float y = float((gl_VertexID & 2) << 1) - 1.0;\n"
    "    uv = vec2(x * 0.5 + 0.5, y * 0.5 + 0.5);\n"
    "    gl_Position = vec4(x, y, 0.0, 1.0);\n"
    "}\n";

static const char* FS_SRC =
    "#version 330 core\n"
    "in vec2 uv;\n"
    "out vec4 frag;\n"
    "uniform sampler2D tex;\n"
    "void main() {\n"
    "    frag = texture(tex, uv);\n"
    "}\n";

static GLuint compile_shader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof(log), nullptr, log);
        fprintf(stderr, "Shader error: %s\n", log);
    }
    return s;
}

static GLuint create_quad_program() {
    GLuint vs = compile_shader(GL_VERTEX_SHADER, VS_SRC);
    GLuint fs = compile_shader(GL_FRAGMENT_SHADER, FS_SRC);
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glLinkProgram(prog);
    glDeleteShader(vs);
    glDeleteShader(fs);
    return prog;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Main                                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int main(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <project_path> <patch_file.gnpatch>\n", argv[0]);
        return 1;
    }
    const char* project_path = argv[1];
    const char* patch_file   = argv[2];

    /* ── SDL + OpenGL Setup ─────────────────────────────────────────── */

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    SDL_Window* window = SDL_CreateWindow(
        "GONODES SDL Host",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        1280, 720,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE
    );
    if (!window) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_GLContext gl_ctx = SDL_GL_CreateContext(window);
    if (!gl_ctx) {
        fprintf(stderr, "SDL_GL_CreateContext failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    SDL_GL_SetSwapInterval(1);  /* VSync */

    printf("[SDL Host] OpenGL %s\n", glGetString(GL_VERSION));

    /* ── GONODES Initialization ─────────────────────────────────────── */

    gonodes_gpu_context_t gpu = {};
    gpu.graphics_api = GONODES_GFX_OPENGL;
    gpu.gl_context   = (void*)gl_ctx;

    printf("[SDL Host] Creating GONODES instance...\n");
    gonodes_instance_t gn = gonodes_create(project_path, &gpu);
    if (!gn) {
        fprintf(stderr, "[SDL Host] gonodes_create failed\n");
        SDL_GL_DeleteContext(gl_ctx);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    printf("[SDL Host] Loading patch: %s\n", patch_file);
    int err = gonodes_load_patch(gn, patch_file);
    if (err != GONODES_OK) {
        fprintf(stderr, "[SDL Host] gonodes_load_patch failed: %d — %s\n",
                err, gonodes_get_last_error(gn));
        gonodes_destroy(gn);
        SDL_GL_DeleteContext(gl_ctx);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    /* Enable auto-reload for live iteration. */
    gonodes_set_auto_reload(gn, 1, 0.5);

    /* ── Query Host I/O Manifest ────────────────────────────────────── */

    const char* host_io = gonodes_get_host_io(gn);
    if (host_io && host_io[0] != '\0') {
        printf("[SDL Host] Host I/O Manifest:\n%s\n", host_io);
    } else {
        printf("[SDL Host] No Host I/O manifest in patch.\n");
    }

    /* Log callback: route GONODES messages to stdout. */
    gonodes_set_log_callback(gn,
        [](int level, const char* cat, const char* msg, void*) {
            const char* lvl_str[] = {"DBG", "INF", "WRN", "ERR"};
            printf("[GONODES %s/%s] %s\n",
                   lvl_str[level < 4 ? level : 3], cat, msg);
        }, nullptr);

    /* ── Create Quad Shader ─────────────────────────────────────────── */

    GLuint vao = 0;
    glGenVertexArrays(1, &vao);
    GLuint quad_prog = create_quad_program();

    /* ── Main Loop ──────────────────────────────────────────────────── */

    Uint64 freq  = SDL_GetPerformanceFrequency();
    Uint64 prev  = SDL_GetPerformanceCounter();
    float  time  = 0.0f;
    int    running = 1;

    while (running) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT) running = 0;
            if (ev.type == SDL_KEYDOWN && ev.key.keysym.sym == SDLK_ESCAPE) running = 0;
            if (ev.type == SDL_KEYDOWN && ev.key.keysym.sym == SDLK_r) {
                printf("[SDL Host] Manual reload triggered\n");
                gonodes_reload_patch(gn);
            }
        }

        Uint64 now = SDL_GetPerformanceCounter();
        double delta = (double)(now - prev) / (double)freq;
        prev = now;
        time += (float)delta;

        /* ── Inject Input Data ──────────────────────────────────────── */

        /* Push an LFO value into a HostInCHOP named "host_lfo". */
        float lfo_val = sinf(time * 2.0f) * 0.5f + 0.5f;
        gonodes_set_input_chop(gn, "host_lfo", "lfo", &lfo_val, 1);

        /* ── Cook Frame ─────────────────────────────────────────────── */

        gonodes_cook_frame(gn, delta);

        /* ── Read Output ────────────────────────────────────────────── */

        int tex_w = 0, tex_h = 0;
        uint64_t tex_handle = gonodes_get_output_texture(gn, "host_out", &tex_w, &tex_h);

        /* ── Render ─────────────────────────────────────────────────── */

        int win_w, win_h;
        SDL_GetWindowSize(window, &win_w, &win_h);
        glViewport(0, 0, win_w, win_h);
        glClearColor(0.05f, 0.05f, 0.05f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        if (tex_handle != 0) {
            glUseProgram(quad_prog);
            glBindVertexArray(vao);
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, (GLuint)tex_handle);
            glDrawArrays(GL_TRIANGLES, 0, 3);
        }

        SDL_GL_SwapWindow(window);
    }

    /* ── Cleanup ────────────────────────────────────────────────────── */

    glDeleteProgram(quad_prog);
    glDeleteVertexArrays(1, &vao);

    gonodes_destroy(gn);
    SDL_GL_DeleteContext(gl_ctx);
    SDL_DestroyWindow(window);
    SDL_Quit();

    printf("[SDL Host] Clean exit.\n");
    return 0;
}

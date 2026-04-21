/*
 * GONODES OpenGL Host Example
 *
 * Demonstrates embedding GONODES with a GLFW + OpenGL 3.3 context.
 * Simpler than the SDL example — focused on OpenGL context sharing.
 *
 * After loading, the Host I/O manifest is queried via gonodes_get_host_io()
 * to discover the patch's declared inputs, outputs, and exposed parameters.
 *
 * Build:
 *   cd libgonodes/build && cmake .. && cmake --build . --target opengl_host
 *
 * Run:
 *   ./opengl_host path/to/gonodes_project path/to/show.gnpatch
 */

#include <gonodes_host.h>

#include <GLFW/glfw3.h>

#include <cstdio>
#include <cstdlib>
#include <cmath>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Fullscreen Quad                                                          */
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
/*  Callbacks                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void error_callback(int error, const char* description) {
    fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

static void key_callback(GLFWwindow* win, int key, int /*scancode*/, int action, int /*mods*/) {
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
        glfwSetWindowShouldClose(win, GLFW_TRUE);
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

    /* ── GLFW + OpenGL Setup ────────────────────────────────────────── */

    glfwSetErrorCallback(error_callback);
    if (!glfwInit()) return 1;

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
#endif

    GLFWwindow* window = glfwCreateWindow(1280, 720, "GONODES OpenGL Host", nullptr, nullptr);
    if (!window) {
        glfwTerminate();
        return 1;
    }
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);
    glfwSetKeyCallback(window, key_callback);

    printf("[GL Host] OpenGL %s\n", glGetString(GL_VERSION));

    /* ── GONODES Initialization ─────────────────────────────────────── */

    /*
     * Share the current GL context.  On different platforms:
     *   Windows: wglGetCurrentContext()
     *   macOS:   [NSOpenGLContext currentContext]
     *   Linux:   eglGetCurrentContext() or glXGetCurrentContext()
     *
     * GLFW abstracts this — we pass the raw handle.
     */
    void* gl_ctx = nullptr;
#if defined(_WIN32)
    gl_ctx = (void*)wglGetCurrentContext();
#elif defined(__APPLE__)
    /* NSOpenGLContext — GLFW manages this internally. */
    gl_ctx = nullptr;  /* Let LibGodot create its own for macOS. */
#else
    /* EGL or GLX — platform-dependent.  In production, detect and extract. */
    gl_ctx = nullptr;
#endif

    gonodes_gpu_context_t gpu = {};
    gpu.graphics_api = GONODES_GFX_OPENGL;
    gpu.gl_context   = gl_ctx;

    gonodes_instance_t gn = gonodes_create(project_path, &gpu);
    if (!gn) {
        fprintf(stderr, "[GL Host] gonodes_create failed\n");
        glfwDestroyWindow(window);
        glfwTerminate();
        return 1;
    }

    gonodes_patch_t p = gonodes_load_patch(gn, patch_file);
    if (!p) {
        fprintf(stderr, "[GL Host] Load failed: %s\n", gonodes_get_last_error(gn));
        gonodes_destroy(gn);
        glfwDestroyWindow(window);
        glfwTerminate();
        return 1;
    }

    gonodes_set_auto_reload(gn, p, 1, 0.5);

    /* ── Query Host I/O Manifest ────────────────────────────────────── */

    const char* host_io = gonodes_get_host_io(gn, p);
    if (host_io && host_io[0] != '\0') {
        printf("[GL Host] Host I/O Manifest:\n%s\n", host_io);
    } else {
        printf("[GL Host] No Host I/O manifest in patch.\n");
    }

    /* ── Render Setup ───────────────────────────────────────────────── */

    GLuint vao = 0;
    glGenVertexArrays(1, &vao);
    GLuint quad_prog = create_quad_program();

    /* ── Main Loop ──────────────────────────────────────────────────── */

    double prev_time = glfwGetTime();

    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();

        double now = glfwGetTime();
        double delta = now - prev_time;
        prev_time = now;

        /* Inject an animated value. */
        float wave = (float)(sin(now * 3.0) * 0.5 + 0.5);
        gonodes_set_input_chop(gn, p, "host_lfo", "wave", &wave, 1);

        /* Cook. */
        gonodes_cook_frame(gn, delta);

        /* Read output. */
        int tw = 0, th = 0;
        uint64_t tex = gonodes_get_output_texture(gn, p, "host_out", &tw, &th);

        /* Render fullscreen quad with output texture. */
        int fw, fh;
        glfwGetFramebufferSize(window, &fw, &fh);
        glViewport(0, 0, fw, fh);
        glClearColor(0.08f, 0.08f, 0.08f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        if (tex != 0) {
            glUseProgram(quad_prog);
            glBindVertexArray(vao);
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, (GLuint)tex);
            glDrawArrays(GL_TRIANGLES, 0, 3);
        }

        glfwSwapBuffers(window);
    }

    /* ── Cleanup ────────────────────────────────────────────────────── */

    glDeleteProgram(quad_prog);
    glDeleteVertexArrays(1, &vao);

    gonodes_destroy(gn);
    glfwDestroyWindow(window);
    glfwTerminate();

    printf("[GL Host] Clean exit.\n");
    return 0;
}

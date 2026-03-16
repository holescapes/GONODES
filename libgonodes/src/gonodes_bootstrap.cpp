/*
 * gonodes_bootstrap.cpp — LibGodot initialization and frame loop.
 *
 * This file wraps Godot 4.6's LibGodot C API.  The LibGodot entry points
 * are loaded dynamically at runtime from the shared library, so hosts
 * link only against libgonodes (not against Godot directly).
 *
 * The key LibGodot functions (from Godot source main/main.h):
 *
 *   bool godot_create(int argc, char** argv);
 *   bool godot_setup(int argc, char** argv);
 *   bool godot_start();
 *   bool godot_iteration();
 *   void godot_shutdown();
 *
 * And from the rendering device setup:
 *   RenderingDevice can accept an external VkDevice / MTLDevice via
 *   the --rendering-driver and --gpu-index arguments, plus environment
 *   variables for context injection.
 */

#include "gonodes_bootstrap.h"
#include <cstdlib>
#include <cstring>
#include <cstdio>

#if defined(_WIN32)
  #include <windows.h>
  #include <sys/stat.h>
#else
  #include <sys/stat.h>
  #include <dlfcn.h>
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  String Helpers                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

char* gn_strdup(const char* src) {
    if (!src) return nullptr;
    size_t len = strlen(src) + 1;
    char* dst = (char*)malloc(len);
    if (dst) memcpy(dst, src, len);
    return dst;
}

void gn_free_cached(char** ptr) {
    if (ptr && *ptr) {
        free(*ptr);
        *ptr = nullptr;
    }
}

void gn_set_error(gonodes_instance_s* inst, const char* msg) {
    gn_free_cached(&inst->last_error);
    inst->last_error = gn_strdup(msg);
}

uint64_t gn_file_mtime(const char* path) {
#if defined(_WIN32)
    struct _stat64 st;
    if (_stat64(path, &st) == 0) return (uint64_t)st.st_mtime;
#else
    struct stat st;
    if (stat(path, &st) == 0) return (uint64_t)st.st_mtime;
#endif
    return 0;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  LibGodot Dynamic Loading                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

/*
 * LibGodot function pointers.  Loaded once on first gonodes_create().
 *
 * Godot 4.6 exposes these as the embeddable entry points:
 *   godot_setup(argc, argv)  — parse args, init OS layer
 *   godot_start()            — boot scene tree, autoloads, main scene
 *   godot_iteration()        — run one _process + _physics + render frame
 *   godot_shutdown()         — teardown
 *
 * The alternative "godot_create" combined API may differ between Godot
 * 4.6 releases.  We use the granular setup/start/iteration/shutdown
 * sequence for maximum control.
 */

typedef int  (*pf_godot_setup)(int, char**);
typedef int  (*pf_godot_start)(void);
typedef int  (*pf_godot_iteration)(void);
typedef void (*pf_godot_shutdown)(void);

static pf_godot_setup     s_godot_setup     = nullptr;
static pf_godot_start     s_godot_start     = nullptr;
static pf_godot_iteration s_godot_iteration = nullptr;
static pf_godot_shutdown  s_godot_shutdown  = nullptr;
static int s_libgodot_loaded = 0;

#if defined(_WIN32)
static HMODULE s_libgodot_handle = nullptr;
#else
static void*   s_libgodot_handle = nullptr;
#endif

static int load_libgodot() {
    if (s_libgodot_loaded) return 1;

    /* Look for libgodot next to the gonodes library. */
#if defined(_WIN32)
    const char* lib_name = "libgodot.dll";
    s_libgodot_handle = LoadLibraryA(lib_name);
    if (!s_libgodot_handle) return 0;
    s_godot_setup     = (pf_godot_setup)    GetProcAddress(s_libgodot_handle, "godot_setup");
    s_godot_start     = (pf_godot_start)    GetProcAddress(s_libgodot_handle, "godot_start");
    s_godot_iteration = (pf_godot_iteration)GetProcAddress(s_libgodot_handle, "godot_iteration");
    s_godot_shutdown  = (pf_godot_shutdown) GetProcAddress(s_libgodot_handle, "godot_shutdown");
#elif defined(__APPLE__)
    const char* lib_name = "libgodot.dylib";
    s_libgodot_handle = dlopen(lib_name, RTLD_NOW);
    if (!s_libgodot_handle) return 0;
    s_godot_setup     = (pf_godot_setup)    dlsym(s_libgodot_handle, "godot_setup");
    s_godot_start     = (pf_godot_start)    dlsym(s_libgodot_handle, "godot_start");
    s_godot_iteration = (pf_godot_iteration)dlsym(s_libgodot_handle, "godot_iteration");
    s_godot_shutdown  = (pf_godot_shutdown) dlsym(s_libgodot_handle, "godot_shutdown");
#else
    const char* lib_name = "libgodot.so";
    s_libgodot_handle = dlopen(lib_name, RTLD_NOW);
    if (!s_libgodot_handle) return 0;
    s_godot_setup     = (pf_godot_setup)    dlsym(s_libgodot_handle, "godot_setup");
    s_godot_start     = (pf_godot_start)    dlsym(s_libgodot_handle, "godot_start");
    s_godot_iteration = (pf_godot_iteration)dlsym(s_libgodot_handle, "godot_iteration");
    s_godot_shutdown  = (pf_godot_shutdown) dlsym(s_libgodot_handle, "godot_shutdown");
#endif

    if (!s_godot_setup || !s_godot_start || !s_godot_iteration || !s_godot_shutdown) {
        return 0;
    }
    s_libgodot_loaded = 1;
    return 1;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Bootstrap Implementation                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

GDExtensionInstanceHandle gn_bootstrap_init(
    const char* project_path,
    const gonodes_gpu_context_t* gpu
) {
    if (!load_libgodot()) {
        fprintf(stderr, "[GONODES] Failed to load LibGodot shared library.\n");
        return nullptr;
    }

    /*
     * Build the argument list for godot_setup().
     * Key arguments:
     *   --path <project_path>   — sets ProjectSettings path
     *   --headless              — no window (we manage output ourselves)
     *   --rendering-method X    — match host's graphics API
     *
     * For GPU context sharing, we rely on environment variables or the
     * Godot RenderingDevice external context API (Godot 4.6+).
     */

    const char* renderer = "forward_plus";
    if (gpu) {
        switch (gpu->graphics_api) {
            case GONODES_GFX_VULKAN: renderer = "forward_plus"; break;
            case GONODES_GFX_METAL:  renderer = "forward_plus"; break;
            case GONODES_GFX_OPENGL: renderer = "gl_compatibility"; break;
            default: break;
        }
    }

    /* Build argv. */
    const char* argv_list[16];
    int argc = 0;
    argv_list[argc++] = "gonodes_embedded";
    argv_list[argc++] = "--path";
    argv_list[argc++] = project_path;
    argv_list[argc++] = "--rendering-method";
    argv_list[argc++] = renderer;
    argv_list[argc++] = "--headless";

    /*
     * GPU context injection:
     *
     * Godot 4.6's RenderingDevice supports external device injection via:
     *   RenderingDevice::initialize_from_external_vulkan_device()
     *   RenderingDevice::initialize_from_external_opengl_context()
     *
     * These are called after godot_setup() but before godot_start(), via
     * the GDExtension interface or environment variables.  The exact
     * mechanism depends on the Godot 4.6 release.
     *
     * For now, we set environment variables that the GONODES autoload
     * (GNEmbeddedHost) reads to configure the RenderingDevice.
     *
     * TODO: Replace with direct RenderingDevice API calls when Godot 4.6
     * stabilizes the external device injection interface.
     */
    if (gpu) {
        char buf[64];
        if (gpu->vulkan_device) {
            snprintf(buf, sizeof(buf), "%" PRIu64, (uint64_t)(uintptr_t)gpu->vulkan_device);
            #if defined(_WIN32)
            _putenv_s("GONODES_VK_DEVICE", buf);
            #else
            setenv("GONODES_VK_DEVICE", buf, 1);
            #endif
        }
        if (gpu->vulkan_instance) {
            snprintf(buf, sizeof(buf), "%" PRIu64, (uint64_t)(uintptr_t)gpu->vulkan_instance);
            #if defined(_WIN32)
            _putenv_s("GONODES_VK_INSTANCE", buf);
            #else
            setenv("GONODES_VK_INSTANCE", buf, 1);
            #endif
        }
        if (gpu->gl_context) {
            snprintf(buf, sizeof(buf), "%" PRIu64, (uint64_t)(uintptr_t)gpu->gl_context);
            #if defined(_WIN32)
            _putenv_s("GONODES_GL_CONTEXT", buf);
            #else
            setenv("GONODES_GL_CONTEXT", buf, 1);
            #endif
        }
        if (gpu->metal_device) {
            snprintf(buf, sizeof(buf), "%" PRIu64, (uint64_t)(uintptr_t)gpu->metal_device);
            #if defined(_WIN32)
            _putenv_s("GONODES_MTL_DEVICE", buf);
            #else
            setenv("GONODES_MTL_DEVICE", buf, 1);
            #endif
        }
    }

    /* Boot Godot. */
    if (!s_godot_setup(argc, (char**)argv_list)) {
        fprintf(stderr, "[GONODES] godot_setup() failed.\n");
        return nullptr;
    }

    if (!s_godot_start()) {
        fprintf(stderr, "[GONODES] godot_start() failed.\n");
        s_godot_shutdown();
        return nullptr;
    }

    /* Return a non-null sentinel.  In a multi-instance future, this would
     * be a unique identifier for the Godot instance. */
    return (GDExtensionInstanceHandle)(uintptr_t)1;
}

void gn_bootstrap_iteration(GDExtensionInstanceHandle handle, double delta) {
    (void)handle;
    (void)delta;
    /* LibGodot's godot_iteration() runs one full frame: _process,
     * _physics_process, and rendering.  Delta is managed internally
     * by Godot's OS timer, but we could inject it via the main loop
     * override if needed. */
    if (s_godot_iteration) {
        s_godot_iteration();
    }
}

void gn_bootstrap_shutdown(GDExtensionInstanceHandle handle) {
    (void)handle;
    if (s_godot_shutdown) {
        s_godot_shutdown();
    }
}

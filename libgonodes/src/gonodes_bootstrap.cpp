/*
 * gonodes_bootstrap.cpp — LibGodot initialization, frame loop, and
 * internal helpers for libgonodes v2.5.
 *
 * This file wraps Godot 4.6's LibGodot C API.  The LibGodot entry points
 * are loaded dynamically at runtime from the shared library, so hosts
 * link only against libgonodes (not against Godot directly).
 *
 * v2.5 changes:
 *   - Eliminated per-frame env-var IPC bridge layer (~490 lines removed)
 *   - GNHostBridge GDExtension now reads the command queue and writes
 *     response slots directly via pointer access
 *   - Only env var remaining: GONODES_BRIDGE_INSTANCE_PTR (one-time init)
 *   - Response slot writers retained as utility functions
 */

#include "gonodes_bootstrap.h"
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <cinttypes>

#if defined(_WIN32)
  #include <windows.h>
  #include <sys/stat.h>
  #define gn_strtok_r(s, d, ctx) strtok_s(s, d, ctx)
#else
  #include <sys/stat.h>
  #include <dlfcn.h>
  #define gn_strtok_r(s, d, ctx) strtok_r(s, d, ctx)
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
/*  Command Queue                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gn_cmd_push(gonodes_instance_s* inst, const gn_command* cmd) {
    if (!inst || !cmd) return 0;
    gn_command_queue* q = &inst->cmd_queue;
    int next = (q->write_pos + 1) % GN_CMD_QUEUE_SIZE;
    if (next == q->read_pos) {
        /* Queue full. */
        gn_set_error(inst, "Command queue full");
        return 0;
    }
    q->commands[q->write_pos] = *cmd;
    q->write_pos = next;
    return 1;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Patch Lookup                                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

gonodes_patch_s* gn_find_patch(gonodes_instance_s* inst, gonodes_patch_t handle) {
    if (!inst || !handle) return nullptr;
    /* The handle IS the pointer.  Validate it exists in our array. */
    for (int i = 0; i < GONODES_MAX_PATCHES; ++i) {
        if (inst->patches[i] == handle) return handle;
    }
    return nullptr;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Patch Allocation / Free                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

gonodes_patch_s* gn_alloc_patch(gonodes_instance_s* inst) {
    if (!inst) return nullptr;
    if (inst->patch_count >= GONODES_MAX_PATCHES) return nullptr;

    auto* p = (gonodes_patch_s*)calloc(1, sizeof(gonodes_patch_s));
    if (!p) return nullptr;

    p->id = ++inst->next_patch_id;
    p->transport_speed = 1.0;

    /* Find an empty slot. */
    for (int i = 0; i < GONODES_MAX_PATCHES; ++i) {
        if (inst->patches[i] == nullptr) {
            inst->patches[i] = p;
            inst->patch_count++;
            return p;
        }
    }

    free(p);
    return nullptr;
}

void gn_free_patch(gonodes_instance_s* inst, gonodes_patch_s* patch) {
    if (!inst || !patch) return;

    /* Remove from array. */
    for (int i = 0; i < GONODES_MAX_PATCHES; ++i) {
        if (inst->patches[i] == patch) {
            inst->patches[i] = nullptr;
            inst->patch_count--;
            break;
        }
    }

    /* Free cached strings. */
    gn_free_cached(&patch->cached_nodes_json);
    gn_free_cached(&patch->cached_node_info_json);
    gn_free_cached(&patch->cached_params_json);
    gn_free_cached(&patch->cached_connections_json);
    gn_free_cached(&patch->cached_table_json);
    gn_free_cached(&patch->cached_param_value_json);
    gn_free_cached(&patch->cached_host_io_json);
    gn_free_cached(&patch->cached_texture_info_json);

    /* Free response slot heap allocations. */
    for (int i = 0; i < patch->dat_output_count; ++i)
        free(patch->dat_outputs[i].json_data);
    for (int i = 0; i < patch->param_output_count; ++i)
        free(patch->param_outputs[i].value_json);
    free(patch->readback_slot.pixel_data);

    /* Free geometry buffers. */
    free(patch->geo_positions_buf);
    free(patch->geo_normals_buf);
    free(patch->geo_uvs_buf);
    free(patch->geo_colors_buf);
    free(patch->geo_indices_buf);
    free(patch->pixel_readback_buf);
    free(patch->cached_chop_channels);

    free(patch);
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
            case GONODES_GFX_MOBILE: renderer = "mobile"; break;
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

    /* Run one full Godot frame: _process, _physics_process, render.
     *
     * GNEmbeddedHost._process() calls GNHostBridge.drain_commands() to read
     * the C command queue directly, and GNHostBridge.set_*_output() to write
     * response data directly into the C struct.  No env-var dispatch/collect
     * layer needed.
     */
    if (s_godot_iteration) {
        s_godot_iteration();
    }

    /* Free staging buffers allocated for this frame's pointer-based data. */
    if (s_active_inst) {
        gn_free_staging_bufs(s_active_inst);
    }
}

void gn_bootstrap_shutdown(GDExtensionInstanceHandle handle) {
    (void)handle;
    if (s_godot_shutdown) {
        s_godot_shutdown();
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Pixel Format Helper                                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gn_bytes_per_pixel(int format) {
    switch (format) {
        case GONODES_FORMAT_RGBA8:   return 4;
        case GONODES_FORMAT_BGRA8:   return 4;
        case GONODES_FORMAT_RGBA16F: return 8;
        case GONODES_FORMAT_RGBA32F: return 16;
        case GONODES_FORMAT_R8:      return 1;
        case GONODES_FORMAT_RG8:     return 2;
        case GONODES_FORMAT_R16F:    return 2;
        case GONODES_FORMAT_RG16F:   return 4;
        default:                     return 4;
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Staging Buffer Tracking                                                  */
/*                                                                           */
/*  When the host passes pixel data with row padding (row_stride > tight),   */
/*  the C API allocates a tightly-packed copy.  These owned buffers are       */
/*  tracked here and freed after the Godot iteration completes (the pointer  */
/*  is only borrowed for one frame).                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gn_track_staging_buf(gonodes_instance_s* inst, void* buf) {
    if (!inst || !buf) return;
    if (inst->staging_buf_count >= GONODES_MAX_STAGING_BUFS) {
        fprintf(stderr, "[libgonodes] staging_bufs overflow, leaking buffer\n");
        return;
    }
    inst->staging_bufs[inst->staging_buf_count++] = buf;
}

void gn_free_staging_bufs(gonodes_instance_s* inst) {
    if (!inst) return;
    for (int i = 0; i < inst->staging_buf_count; ++i) {
        free(inst->staging_bufs[i]);
        inst->staging_bufs[i] = nullptr;
    }
    inst->staging_buf_count = 0;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Response Slot Writers                                                    */
/*                                                                           */
/*  Called by GNEmbeddedHost (GDScript singleton) to populate output data    */
/*  directly into the C struct.  The C API reads these fields later.         */
/*  Single-threaded: Godot and the C API never run concurrently.             */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gn_patch_set_tex_output(gonodes_patch_s* p, const char* node_id,
                             uint64_t handle, int w, int h, int fmt, int ch, int api) {
    if (!p || !node_id) return;

    /* Update existing slot or add new one. */
    for (int i = 0; i < p->tex_output_count; ++i) {
        if (strcmp(p->tex_outputs[i].node_id, node_id) == 0) {
            p->tex_outputs[i].handle = handle;
            p->tex_outputs[i].width = w;
            p->tex_outputs[i].height = h;
            p->tex_outputs[i].format = fmt;
            p->tex_outputs[i].channels = ch;
            p->tex_outputs[i].graphics_api = api;
            return;
        }
    }
    if (p->tex_output_count >= GONODES_MAX_OUTPUT_SLOTS) return;
    auto& slot = p->tex_outputs[p->tex_output_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.handle = handle;
    slot.width = w;
    slot.height = h;
    slot.format = fmt;
    slot.channels = ch;
    slot.graphics_api = api;
}


void gn_patch_set_chop_output(gonodes_patch_s* p, const char* node_id,
                              const char* channel_name,
                              const float* samples, int count) {
    if (!p || !node_id || !channel_name || !samples || count <= 0) return;

    int to_copy = count;
    if (to_copy > 4096) {
        to_copy = 4096;
        /* Warn once per overflow to help diagnose truncation. */
        fprintf(stderr, "[libgonodes] CHOP output '%s.%s' truncated: %d → 4096 samples\n",
                node_id, channel_name, count);
    }

    for (int i = 0; i < p->chop_output_count; ++i) {
        if (strcmp(p->chop_outputs[i].node_id, node_id) == 0 &&
            strcmp(p->chop_outputs[i].channel_name, channel_name) == 0) {
            memcpy(p->chop_outputs[i].samples, samples, (size_t)to_copy * sizeof(float));
            p->chop_outputs[i].sample_count = to_copy;
            return;
        }
    }
    if (p->chop_output_count >= GONODES_MAX_OUTPUT_SLOTS) return;
    auto& slot = p->chop_outputs[p->chop_output_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    snprintf(slot.channel_name, sizeof(slot.channel_name), "%s", channel_name);
    memcpy(slot.samples, samples, (size_t)to_copy * sizeof(float));
    slot.sample_count = to_copy;
}


void gn_patch_set_dat_output(gonodes_patch_s* p, const char* node_id,
                             const char* json_data) {
    if (!p || !node_id) return;

    for (int i = 0; i < p->dat_output_count; ++i) {
        if (strcmp(p->dat_outputs[i].node_id, node_id) == 0) {
            free(p->dat_outputs[i].json_data);
            p->dat_outputs[i].json_data = gn_strdup(json_data);
            return;
        }
    }
    if (p->dat_output_count >= GONODES_MAX_OUTPUT_SLOTS) return;
    auto& slot = p->dat_outputs[p->dat_output_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.json_data = gn_strdup(json_data);
}


void gn_patch_set_param_output(gonodes_patch_s* p, const char* node_id,
                               const char* param_name, const char* value_json) {
    if (!p || !node_id || !param_name) return;

    for (int i = 0; i < p->param_output_count; ++i) {
        if (strcmp(p->param_outputs[i].node_id, node_id) == 0 &&
            strcmp(p->param_outputs[i].param_name, param_name) == 0) {
            free(p->param_outputs[i].value_json);
            p->param_outputs[i].value_json = gn_strdup(value_json);
            return;
        }
    }
    if (p->param_output_count >= GONODES_MAX_OUTPUT_SLOTS) return;
    auto& slot = p->param_outputs[p->param_output_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    snprintf(slot.param_name, sizeof(slot.param_name), "%s", param_name);
    slot.value_json = gn_strdup(value_json);
}


void gn_patch_set_nodes_json(gonodes_patch_s* p, const char* json) {
    if (!p) return;
    gn_free_cached(&p->cached_nodes_json);
    p->cached_nodes_json = gn_strdup(json);
}

void gn_patch_set_connections_json(gonodes_patch_s* p, const char* json) {
    if (!p) return;
    gn_free_cached(&p->cached_connections_json);
    p->cached_connections_json = gn_strdup(json);
}

void gn_patch_set_node_info_json(gonodes_patch_s* p, const char* node_id, const char* json) {
    if (!p || !node_id) return;
    /* Node info is stored as a single cached string. When multiple node IDs
     * are queried, only the last one persists — same behavior as before.
     * The caller (list_parameters, get_node_info) will query immediately
     * after the GDScript side publishes. */
    gn_free_cached(&p->cached_node_info_json);
    p->cached_node_info_json = gn_strdup(json);
}

void gn_patch_set_params_json(gonodes_patch_s* p, const char* node_id, const char* json) {
    if (!p || !node_id) return;
    gn_free_cached(&p->cached_params_json);
    p->cached_params_json = gn_strdup(json);
}

void gn_patch_set_host_io_json(gonodes_patch_s* p, const char* json) {
    if (!p) return;
    gn_free_cached(&p->cached_host_io_json);
    p->cached_host_io_json = gn_strdup(json);
}

void gn_patch_set_stats(gonodes_patch_s* p, double cook_ms, int node_count) {
    if (!p) return;
    p->last_cook_time_ms = cook_ms;
    p->last_cooked_count = node_count;
}

void gn_patch_set_transport_time(gonodes_patch_s* p, double time) {
    if (!p) return;
    p->transport_time = time;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Active Instance (for GNHostBridge pointer registration)                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

static gonodes_instance_s* s_active_inst = nullptr;

void gn_set_active_instance(gonodes_instance_s* inst) {
    s_active_inst = inst;

    /*
     * Write the instance pointer as a one-time env var so GNEmbeddedHost
     * (the GDScript autoload) can pass it to GNHostBridge.set_instance().
     * This is the ONLY env var used by the bridge — set once during init,
     * never touched per-frame.
     */
    if (inst) {
        char buf[64];
        snprintf(buf, sizeof(buf), "%" PRIu64,
                 (uint64_t)(uintptr_t)inst);
#if defined(_WIN32)
        _putenv_s("GONODES_BRIDGE_INSTANCE_PTR", buf);
#else
        setenv("GONODES_BRIDGE_INSTANCE_PTR", buf, 1);
#endif
    } else {
#if defined(_WIN32)
        _putenv_s("GONODES_BRIDGE_INSTANCE_PTR", "");
#else
        setenv("GONODES_BRIDGE_INSTANCE_PTR", "", 1);
#endif
    }
}

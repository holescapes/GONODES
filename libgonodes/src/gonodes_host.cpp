/*
 * gonodes_host.cpp — Public C API implementation.
 *
 * Every gonodes_*() function validates its handle, then either:
 *   (a) directly manipulates the instance state (set_auto_reload, stats), or
 *   (b) marshals a call into the running Godot SceneTree via ClassDB to reach
 *       the GNEmbeddedHost autoload singleton in GDScript.
 *
 * GDScript bridge protocol:
 *   GNEmbeddedHost registers itself via Engine.register_singleton("GNEmbeddedHost")
 *   in _ready().  This file calls ClassDB::instance() → call("method", ...) to
 *   invoke GDScript methods.  All calls happen on the main thread during
 *   gn_bootstrap_iteration(), so no mutex is needed.
 *
 * Build with -DGONODES_BUILDING_LIBRARY to export symbols.
 */

#define GONODES_BUILDING_LIBRARY
#include "../include/gonodes_host.h"
#include "gonodes_bootstrap.h"

#include <cstring>
#include <cstdlib>
#include <cstdio>

/* Validate instance handle.  Returns the given error value on failure. */
#define VALIDATE(inst, retval) \
    if (!(inst)) { return (retval); }

#define VALIDATE_VOID(inst) \
    if (!(inst)) { return; }

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Lifecycle                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

gonodes_instance_t gonodes_create(
    const char* project_path,
    const gonodes_gpu_context_t* gpu_context
) {
    if (!project_path) return nullptr;

    /* Allocate instance state. */
    auto* inst = (gonodes_instance_s*)calloc(1, sizeof(gonodes_instance_s));
    if (!inst) return nullptr;

    /* Record GPU config. */
    if (gpu_context) {
        inst->graphics_api = gpu_context->graphics_api;
        inst->owns_gpu_device = 0;
    } else {
        inst->graphics_api = GONODES_GFX_AUTO;
        inst->owns_gpu_device = 1;
    }

    /* Boot LibGodot. */
    inst->godot_handle = gn_bootstrap_init(project_path, gpu_context);
    if (!inst->godot_handle) {
        gn_set_error(inst, "Failed to initialize LibGodot");
        free(inst);
        return nullptr;
    }

    /* Run a few warmup iterations to let autoloads (_ready) execute.
     * GNEmbeddedHost registers itself as a singleton in _ready(). */
    for (int i = 0; i < 3; ++i) {
        gn_bootstrap_iteration(inst->godot_handle, 0.016);
    }

    return inst;
}


void gonodes_destroy(gonodes_instance_t inst) {
    VALIDATE_VOID(inst);

    gn_bootstrap_shutdown(inst->godot_handle);

    /* Free cached strings. */
    gn_free_cached(&inst->last_error);
    gn_free_cached(&inst->cached_nodes_json);
    gn_free_cached(&inst->cached_node_info_json);
    gn_free_cached(&inst->cached_params_json);
    gn_free_cached(&inst->cached_connections_json);
    gn_free_cached(&inst->cached_table_json);
    gn_free_cached(&inst->cached_param_value_json);
    gn_free_cached(&inst->cached_host_io_json);

    free(inst);
}


void gonodes_get_version(int* major, int* minor, int* patch) {
    if (major) *major = GONODES_API_VERSION_MAJOR;
    if (minor) *minor = GONODES_API_VERSION_MINOR;
    if (patch) *patch = GONODES_API_VERSION_PATCH;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Patch Management                                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

/*
 * Patch load/unload/reload are delegated to the GNEmbeddedHost singleton
 * in GDScript.  The C API stores the path locally for auto-reload polling.
 *
 * GNEmbeddedHost.load_patch(path: String) -> int:
 *   Loads a .gnpatch file, builds the network, boots the cook engine.
 *   Returns 0 on success, negative error code on failure.
 *
 * GNEmbeddedHost.unload_patch():
 *   Tears down the cook engine and frees all operator nodes.
 *
 * GNEmbeddedHost.reload_patch() -> int:
 *   Stateful reload — preserves runtime values across topology rebuild.
 */

int gonodes_load_patch(gonodes_instance_t inst, const char* patch_path) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!patch_path) return GONODES_ERR_FILE_NOT_FOUND;

    /* Store path for auto-reload. */
    size_t len = strlen(patch_path);
    if (len >= sizeof(inst->patch_path)) len = sizeof(inst->patch_path) - 1;
    memcpy(inst->patch_path, patch_path, len);
    inst->patch_path[len] = '\0';

    /*
     * Marshal to GDScript:
     *   GNEmbeddedHost.load_patch(patch_path) -> int
     *
     * In the real implementation this calls into the Godot ClassDB singleton.
     * For now we record the path and let the next iteration pick it up via
     * a flag that GNEmbeddedHost checks in _process().
     */

    /* Write path to env var that GNEmbeddedHost reads on next frame. */
#if defined(_WIN32)
    _putenv_s("GONODES_LOAD_PATCH", inst->patch_path);
#else
    setenv("GONODES_LOAD_PATCH", inst->patch_path, 1);
#endif

    /* Run one iteration so GNEmbeddedHost picks up the command. */
    gn_bootstrap_iteration(inst->godot_handle, 0.0);

    inst->patch_loaded = 1;
    inst->patch_mtime = gn_file_mtime(inst->patch_path);
    inst->frame_number = 0;

    return GONODES_OK;
}


void gonodes_unload_patch(gonodes_instance_t inst) {
    VALIDATE_VOID(inst);

#if defined(_WIN32)
    _putenv_s("GONODES_UNLOAD_PATCH", "1");
#else
    setenv("GONODES_UNLOAD_PATCH", "1", 1);
#endif

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    inst->patch_loaded = 0;
    inst->patch_path[0] = '\0';
}


int gonodes_reload_patch(gonodes_instance_t inst) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!inst->patch_loaded) return GONODES_ERR_NOT_LOADED;

#if defined(_WIN32)
    _putenv_s("GONODES_RELOAD_PATCH", "1");
#else
    setenv("GONODES_RELOAD_PATCH", "1", 1);
#endif

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    inst->patch_mtime = gn_file_mtime(inst->patch_path);
    return GONODES_OK;
}


void gonodes_set_auto_reload(gonodes_instance_t inst, int enable, double interval) {
    VALIDATE_VOID(inst);
    inst->auto_reload_enabled = enable;
    inst->auto_reload_interval = (interval > 0.0) ? interval : 0.5;
    inst->auto_reload_timer = 0.0;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Frame Loop                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gonodes_cook_frame(gonodes_instance_t inst, double delta_seconds) {
    VALIDATE_VOID(inst);

    /* Auto-reload check. */
    if (inst->auto_reload_enabled && inst->patch_loaded) {
        inst->auto_reload_timer += delta_seconds;
        if (inst->auto_reload_timer >= inst->auto_reload_interval) {
            inst->auto_reload_timer = 0.0;
            uint64_t current_mtime = gn_file_mtime(inst->patch_path);
            if (current_mtime != 0 && current_mtime != inst->patch_mtime) {
                inst->patch_mtime = current_mtime;
                gonodes_reload_patch(inst);
            }
        }
    }

    /* Run one Godot frame (process + physics + render). */
    gn_bootstrap_iteration(inst->godot_handle, delta_seconds);
    inst->frame_number++;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Input Injection  (host → GONODES)                                        */
/*                                                                           */
/*  These functions write to environment variables (or shared memory) that    */
/*  the bridge operators (HostInTOP, HostInCHOP, HostInDAT) read each cook.  */
/*  In a production build, they'd call directly into the Godot ClassDB       */
/*  singleton GNEmbeddedHost.                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_input_texture(
    gonodes_instance_t inst,
    const char* node_id,
    uint64_t texture_handle,
    int width, int height,
    int format
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id) return GONODES_ERR_NODE_NOT_FOUND;

    /*
     * Store the texture handle in a command buffer that GNEmbeddedHost
     * flushes before each cook.  The HostInTOP reads its assigned handle
     * from GNEmbeddedHost._texture_inputs[node_id].
     *
     * For shared GPU contexts, this is zero-copy: the handle is a
     * VkImage / GLuint / MTLTexture* on the same device.
     * For non-shared contexts, GNEmbeddedHost does a CPU readback + upload.
     */

    char env_key[256];
    char env_val[256];
    snprintf(env_key, sizeof(env_key), "GONODES_TEX_%s", node_id);
    snprintf(env_val, sizeof(env_val), "%" PRIu64 ",%d,%d,%d",
             texture_handle, width, height, format);

#if defined(_WIN32)
    _putenv_s(env_key, env_val);
#else
    setenv(env_key, env_val, 1);
#endif

    return GONODES_OK;
}


int gonodes_set_input_chop(
    gonodes_instance_t inst,
    const char* node_id,
    const char* channel_name,
    const float* samples,
    int num_samples
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !channel_name || !samples || num_samples <= 0)
        return GONODES_ERR_NODE_NOT_FOUND;

    /*
     * CHOP data is passed through a shared memory page or tmpfile
     * for large sample arrays.  For small payloads (< 64 samples),
     * encode as a compact env-var string.
     *
     * GNEmbeddedHost._chop_inputs[node_id][channel_name] = PackedFloat32Array
     */

    /* For the env-var path: node_id:channel_name = "v0,v1,v2,..." */
    char env_key[512];
    snprintf(env_key, sizeof(env_key), "GONODES_CHOP_%s_%s", node_id, channel_name);

    /* Encode samples as comma-separated values. */
    size_t buf_size = (size_t)num_samples * 16 + 1;
    char* buf = (char*)malloc(buf_size);
    if (!buf) return GONODES_ERR_INTERNAL;

    size_t offset = 0;
    for (int i = 0; i < num_samples; ++i) {
        int written = snprintf(buf + offset, buf_size - offset,
                               "%s%.6g", (i > 0 ? "," : ""), (double)samples[i]);
        if (written > 0) offset += (size_t)written;
    }

#if defined(_WIN32)
    _putenv_s(env_key, buf);
#else
    setenv(env_key, buf, 1);
#endif

    free(buf);
    return GONODES_OK;
}


int gonodes_set_input_table(
    gonodes_instance_t inst,
    const char* node_id,
    const char* json_data
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !json_data) return GONODES_ERR_NODE_NOT_FOUND;

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_DAT_%s", node_id);

#if defined(_WIN32)
    _putenv_s(env_key, json_data);
#else
    setenv(env_key, json_data, 1);
#endif

    return GONODES_OK;
}


int gonodes_set_parameter(
    gonodes_instance_t inst,
    const char* node_id,
    const char* param_name,
    const char* value_json
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !param_name || !value_json)
        return GONODES_ERR_PARAM_NOT_FOUND;

    char env_key[512];
    snprintf(env_key, sizeof(env_key), "GONODES_PARAM_%s_%s", node_id, param_name);

#if defined(_WIN32)
    _putenv_s(env_key, value_json);
#else
    setenv(env_key, value_json, 1);
#endif

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output Reading  (GONODES → host)                                         */
/*                                                                           */
/*  These functions read cached results from GNEmbeddedHost, which           */
/*  populates them at the end of each cook frame.  The bridge operators      */
/*  (HostOutTOP, HostOutCHOP, HostOutDAT) write their output data into the   */
/*  singleton's output registries.                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

uint64_t gonodes_get_output_texture(
    gonodes_instance_t inst,
    const char* node_id,
    int* out_width, int* out_height
) {
    VALIDATE(inst, 0);
    if (!node_id) return 0;

    /*
     * In the real implementation, this queries:
     *   GNEmbeddedHost._texture_outputs[node_id] →
     *     { handle: uint64, width: int, height: int }
     *
     * For shared GPU contexts, the handle is the native texture ID
     * (VkImage / GLuint / MTLTexture*) from the TOP's SubViewport.
     *
     * For now: reads from env var written by GNEmbeddedHost._process().
     */

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_OUT_TEX_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) return 0;

    uint64_t handle = 0;
    int w = 0, h = 0;
    if (sscanf(val, "%" SCNu64 ",%d,%d", &handle, &w, &h) >= 1) {
        if (out_width) *out_width = w;
        if (out_height) *out_height = h;
    }
    return handle;
}


int gonodes_get_output_chop(
    gonodes_instance_t inst,
    const char* node_id,
    const char* channel_name,
    float* out_buffer,
    int buffer_size
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !channel_name || !out_buffer || buffer_size <= 0)
        return GONODES_ERR_NODE_NOT_FOUND;

    char env_key[512];
    snprintf(env_key, sizeof(env_key), "GONODES_OUT_CHOP_%s_%s", node_id, channel_name);

    const char* val = getenv(env_key);
    if (!val) return 0;

    /* Parse comma-separated floats. */
    int count = 0;
    const char* p = val;
    while (*p && count < buffer_size) {
        char* end = nullptr;
        double v = strtod(p, &end);
        if (end == p) break;
        out_buffer[count++] = (float)v;
        p = end;
        if (*p == ',') ++p;
    }
    return count;
}


const char* gonodes_get_output_table(
    gonodes_instance_t inst,
    const char* node_id
) {
    VALIDATE(inst, nullptr);
    if (!node_id) return nullptr;

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_OUT_DAT_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) return nullptr;

    /* Cache the result so the pointer is stable until next cook. */
    gn_free_cached(&inst->cached_table_json);
    inst->cached_table_json = gn_strdup(val);
    return inst->cached_table_json;
}


const char* gonodes_get_parameter(
    gonodes_instance_t inst,
    const char* node_id,
    const char* param_name
) {
    VALIDATE(inst, nullptr);
    if (!node_id || !param_name) return nullptr;

    char env_key[512];
    snprintf(env_key, sizeof(env_key), "GONODES_OUT_PARAM_%s_%s", node_id, param_name);

    const char* val = getenv(env_key);
    if (!val) return nullptr;

    gn_free_cached(&inst->cached_param_value_json);
    inst->cached_param_value_json = gn_strdup(val);
    return inst->cached_param_value_json;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Introspection                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

/*
 * Introspection delegates to GNEmbeddedHost singleton methods which
 * query the in-memory GNNetwork and serialize to JSON.
 */

const char* gonodes_list_nodes(gonodes_instance_t inst) {
    VALIDATE(inst, nullptr);

    const char* val = getenv("GONODES_LIST_NODES");
    if (!val) return nullptr;

    gn_free_cached(&inst->cached_nodes_json);
    inst->cached_nodes_json = gn_strdup(val);
    return inst->cached_nodes_json;
}


const char* gonodes_get_node_info(
    gonodes_instance_t inst,
    const char* node_id
) {
    VALIDATE(inst, nullptr);
    if (!node_id) return nullptr;

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_NODE_INFO_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) return nullptr;

    gn_free_cached(&inst->cached_node_info_json);
    inst->cached_node_info_json = gn_strdup(val);
    return inst->cached_node_info_json;
}


const char* gonodes_list_parameters(
    gonodes_instance_t inst,
    const char* node_id
) {
    VALIDATE(inst, nullptr);
    if (!node_id) return nullptr;

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_LIST_PARAMS_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) return nullptr;

    gn_free_cached(&inst->cached_params_json);
    inst->cached_params_json = gn_strdup(val);
    return inst->cached_params_json;
}


const char* gonodes_list_connections(gonodes_instance_t inst) {
    VALIDATE(inst, nullptr);

    const char* val = getenv("GONODES_LIST_CONNECTIONS");
    if (!val) return nullptr;

    gn_free_cached(&inst->cached_connections_json);
    inst->cached_connections_json = gn_strdup(val);
    return inst->cached_connections_json;
}


const char* gonodes_get_host_io(gonodes_instance_t inst) {
    VALIDATE(inst, nullptr);

    const char* val = getenv("GONODES_HOST_IO");
    if (!val) return "{}";

    gn_free_cached(&inst->cached_host_io_json);
    inst->cached_host_io_json = gn_strdup(val);
    return inst->cached_host_io_json;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Callbacks                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gonodes_set_on_param_changed(
    gonodes_instance_t inst,
    gonodes_param_changed_fn callback,
    void* user_data
) {
    VALIDATE_VOID(inst);
    inst->on_param_changed = callback;
    inst->on_param_changed_userdata = user_data;
}


void gonodes_set_log_callback(
    gonodes_instance_t inst,
    gonodes_log_fn callback,
    void* user_data
) {
    VALIDATE_VOID(inst);
    inst->log_callback = callback;
    inst->log_callback_userdata = user_data;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Utilities                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

const char* gonodes_get_last_error(gonodes_instance_t inst) {
    VALIDATE(inst, "Invalid handle");
    return inst->last_error ? inst->last_error : "";
}


void gonodes_get_stats(
    gonodes_instance_t inst,
    double* out_cook_time_ms,
    int* out_node_count,
    int* out_frame_number
) {
    VALIDATE_VOID(inst);
    if (out_cook_time_ms) *out_cook_time_ms = inst->last_cook_time_ms;
    if (out_node_count)   *out_node_count   = inst->last_cooked_count;
    if (out_frame_number) *out_frame_number  = inst->frame_number;
}

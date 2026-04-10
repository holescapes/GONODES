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

    /* Defaults for transport (Gap 6). */
    inst->transport_state = GONODES_TRANSPORT_PLAY;
    inst->transport_speed = 1.0;
    inst->transport_time  = 0.0;

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
    gn_free_cached(&inst->cached_texture_info_json);

    /* Free geometry buffers. */
    free(inst->geo_positions_buf);
    free(inst->geo_normals_buf);
    free(inst->geo_uvs_buf);
    free(inst->geo_colors_buf);
    free(inst->geo_indices_buf);
    free(inst->pixel_readback_buf);

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


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 2 — Texture Info & Format Negotiation                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_get_texture_info(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_texture_info_t* out_info
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_info) return GONODES_ERR_NODE_NOT_FOUND;

    memset(out_info, 0, sizeof(gonodes_texture_info_t));

    /*
     * GNEmbeddedHost writes: GONODES_TEXINFO_{node_id} = "handle,w,h,fmt,channels,api"
     * This extends the output texture path with format metadata for
     * host-side format negotiation (like TouchEngine's TEInstanceGetTextureDescription).
     */
    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_TEXINFO_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) {
        /* Fallback: try the basic texture output. */
        int w = 0, h = 0;
        uint64_t handle = gonodes_get_output_texture(inst, node_id, &w, &h);
        if (handle == 0) return GONODES_ERR_NODE_NOT_FOUND;
        out_info->native_handle = handle;
        out_info->width = w;
        out_info->height = h;
        out_info->format = GONODES_FORMAT_RGBA8;
        out_info->channels = 4;
        out_info->graphics_api = inst->graphics_api;
        return GONODES_OK;
    }

    uint64_t handle = 0;
    int w = 0, h = 0, fmt = 0, ch = 4, api = 0;
    sscanf(val, "%" SCNu64 ",%d,%d,%d,%d,%d", &handle, &w, &h, &fmt, &ch, &api);

    out_info->native_handle = handle;
    out_info->width = w;
    out_info->height = h;
    out_info->format = fmt;
    out_info->channels = ch;
    out_info->graphics_api = (api != 0) ? api : inst->graphics_api;

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 3 — CPU Pixel Input                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int gn_bytes_per_pixel(int format) {
    switch (format) {
        case GONODES_FORMAT_RGBA8:   return 4;
        case GONODES_FORMAT_BGRA8:   return 4;
        case GONODES_FORMAT_RGBA16F: return 8;
        case GONODES_FORMAT_RGBA32F: return 16;
        case GONODES_FORMAT_R8:      return 1;
        case GONODES_FORMAT_RG8:     return 2;
        case GONODES_FORMAT_R16F:    return 2;
        case GONODES_FORMAT_RG16F:   return 4;
        default: return 4;
    }
}

int gonodes_set_input_pixels(
    gonodes_instance_t inst,
    const char* node_id,
    const void* pixels,
    int width, int height,
    int format,
    int row_stride
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !pixels || width <= 0 || height <= 0)
        return GONODES_ERR_NODE_NOT_FOUND;

    /*
     * Write pixel data to a temp file that GNEmbeddedHost reads.
     * The file path is communicated via env var.
     * GNEmbeddedHost creates an Image from the raw bytes and uploads
     * as a Texture2D into the HostInTOP node.
     *
     * This follows the same pattern as TouchEngine's CPU texture path and
     * VUO's VuoImage_makeFromBuffer().
     */

    int bpp = gn_bytes_per_pixel(format);
    int tight_stride = width * bpp;
    int actual_stride = (row_stride > 0) ? row_stride : tight_stride;
    size_t data_size = (size_t)height * (size_t)actual_stride;

    /* Write to a deterministic temp path per node. */
    char tmp_path[4096];
#if defined(_WIN32)
    const char* tmp_dir = getenv("TEMP");
    if (!tmp_dir) tmp_dir = ".";
    snprintf(tmp_path, sizeof(tmp_path), "%s\\gonodes_pix_%s.raw", tmp_dir, node_id);
#else
    snprintf(tmp_path, sizeof(tmp_path), "/tmp/gonodes_pix_%s.raw", node_id);
#endif

    FILE* fp = fopen(tmp_path, "wb");
    if (!fp) {
        gn_set_error(inst, "Failed to write pixel temp file");
        return GONODES_ERR_INTERNAL;
    }

    /* Write tightly-packed rows (strip padding if stride differs). */
    const uint8_t* src = (const uint8_t*)pixels;
    for (int y = 0; y < height; ++y) {
        fwrite(src + (size_t)y * (size_t)actual_stride, 1, (size_t)tight_stride, fp);
    }
    fclose(fp);

    /* Signal the file location + dimensions to GNEmbeddedHost. */
    char env_key[256];
    char env_val[4096];
    snprintf(env_key, sizeof(env_key), "GONODES_PIX_%s", node_id);
    snprintf(env_val, sizeof(env_val), "%s,%d,%d,%d", tmp_path, width, height, format);

#if defined(_WIN32)
    _putenv_s(env_key, env_val);
#else
    setenv(env_key, env_val, 1);
#endif

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 9 — CPU Pixel Readback                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_read_output_pixels(
    gonodes_instance_t inst,
    const char* node_id,
    void* out_pixels,
    int buffer_size,
    int format,
    int* out_width,
    int* out_height
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_pixels || buffer_size <= 0)
        return GONODES_ERR_NODE_NOT_FOUND;

    /*
     * Request a GPU→CPU readback from GNEmbeddedHost.
     * GNEmbeddedHost uses RenderingServer.texture_get_image() to get an
     * Image, then writes the raw bytes to a temp file.
     * We read the bytes back here.
     */

    /* Signal the readback request. */
    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_READBACK_%s", node_id);
    char env_val[128];
    snprintf(env_val, sizeof(env_val), "%d", format);

#if defined(_WIN32)
    _putenv_s(env_key, env_val);
#else
    setenv(env_key, env_val, 1);
#endif

    /* Run one iteration to let the readback happen. */
    gn_bootstrap_iteration(inst->godot_handle, 0.0);

    /* Read the result file. */
    char result_key[256];
    snprintf(result_key, sizeof(result_key), "GONODES_READBACK_RESULT_%s", node_id);
    const char* result = getenv(result_key);
    if (!result) {
        gn_set_error(inst, "Readback failed — no result from engine");
        return GONODES_ERR_INTERNAL;
    }

    /* Parse: "tmp_path,w,h" */
    char tmp_path[4096];
    int w = 0, h = 0;
    if (sscanf(result, "%4095[^,],%d,%d", tmp_path, &w, &h) < 3) {
        gn_set_error(inst, "Readback result parse error");
        return GONODES_ERR_PARSE_ERROR;
    }

    if (out_width) *out_width = w;
    if (out_height) *out_height = h;

    /* Read the pixel data from the temp file. */
    FILE* fp = fopen(tmp_path, "rb");
    if (!fp) {
        gn_set_error(inst, "Readback temp file not found");
        return GONODES_ERR_FILE_NOT_FOUND;
    }

    int bpp = gn_bytes_per_pixel(format);
    int data_size = w * h * bpp;
    int to_read = (data_size < buffer_size) ? data_size : buffer_size;
    int bytes_read = (int)fread(out_pixels, 1, (size_t)to_read, fp);
    fclose(fp);

    return bytes_read;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 4 — Geometry/SOP Exchange                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

const gonodes_geometry_data_t* gonodes_get_output_geometry(
    gonodes_instance_t inst,
    const char* node_id
) {
    VALIDATE(inst, nullptr);
    if (!node_id) return nullptr;

    /*
     * GNEmbeddedHost serializes geometry data from SOP/COMP nodes to a
     * binary temp file + metadata env var.  The binary format is:
     *   positions (float×3×N) | normals (float×3×N) | uvs (float×2×N)
     *   | colors (float×4×N) | indices (uint32×M)
     *
     * Metadata env var: "tmp_path,vertex_count,index_count,has_normals,has_uvs,has_colors,prim_type"
     */

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_GEO_%s", node_id);

    /* Request geometry export. */
#if defined(_WIN32)
    _putenv_s(env_key, "1");
#else
    setenv(env_key, "1", 1);
#endif

    /* Run one iteration for the export. */
    gn_bootstrap_iteration(inst->godot_handle, 0.0);

    char result_key[256];
    snprintf(result_key, sizeof(result_key), "GONODES_GEO_RESULT_%s", node_id);
    const char* result = getenv(result_key);
    if (!result) return nullptr;

    char tmp_path[4096];
    int vtx = 0, idx = 0, has_n = 0, has_uv = 0, has_c = 0, prim = 0;
    if (sscanf(result, "%4095[^,],%d,%d,%d,%d,%d,%d",
               tmp_path, &vtx, &idx, &has_n, &has_uv, &has_c, &prim) < 3) {
        return nullptr;
    }

    FILE* fp = fopen(tmp_path, "rb");
    if (!fp) return nullptr;

    /* Free previous buffers. */
    free(inst->geo_positions_buf);
    free(inst->geo_normals_buf);
    free(inst->geo_uvs_buf);
    free(inst->geo_colors_buf);
    free(inst->geo_indices_buf);

    /* Read positions (always present). */
    inst->geo_positions_buf = (float*)malloc((size_t)vtx * 3 * sizeof(float));
    if (inst->geo_positions_buf)
        fread(inst->geo_positions_buf, sizeof(float), (size_t)vtx * 3, fp);

    /* Read normals (optional). */
    inst->geo_normals_buf = nullptr;
    if (has_n && vtx > 0) {
        inst->geo_normals_buf = (float*)malloc((size_t)vtx * 3 * sizeof(float));
        if (inst->geo_normals_buf)
            fread(inst->geo_normals_buf, sizeof(float), (size_t)vtx * 3, fp);
    }

    /* Read UVs (optional). */
    inst->geo_uvs_buf = nullptr;
    if (has_uv && vtx > 0) {
        inst->geo_uvs_buf = (float*)malloc((size_t)vtx * 2 * sizeof(float));
        if (inst->geo_uvs_buf)
            fread(inst->geo_uvs_buf, sizeof(float), (size_t)vtx * 2, fp);
    }

    /* Read colors (optional). */
    inst->geo_colors_buf = nullptr;
    if (has_c && vtx > 0) {
        inst->geo_colors_buf = (float*)malloc((size_t)vtx * 4 * sizeof(float));
        if (inst->geo_colors_buf)
            fread(inst->geo_colors_buf, sizeof(float), (size_t)vtx * 4, fp);
    }

    /* Read indices (optional). */
    inst->geo_indices_buf = nullptr;
    if (idx > 0) {
        inst->geo_indices_buf = (uint32_t*)malloc((size_t)idx * sizeof(uint32_t));
        if (inst->geo_indices_buf)
            fread(inst->geo_indices_buf, sizeof(uint32_t), (size_t)idx, fp);
    }

    fclose(fp);

    /* Populate the return struct. */
    inst->cached_geometry.positions = inst->geo_positions_buf;
    inst->cached_geometry.normals = inst->geo_normals_buf;
    inst->cached_geometry.uvs = inst->geo_uvs_buf;
    inst->cached_geometry.colors = inst->geo_colors_buf;
    inst->cached_geometry.vertex_count = vtx;
    inst->cached_geometry.indices = inst->geo_indices_buf;
    inst->cached_geometry.index_count = idx;
    inst->cached_geometry.primitive_type = prim;

    return &inst->cached_geometry;
}


int gonodes_set_input_geometry(
    gonodes_instance_t inst,
    const char* node_id,
    const float* positions,
    const float* normals,
    const float* uvs,
    int vertex_count,
    const uint32_t* indices,
    int index_count
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !positions || vertex_count <= 0)
        return GONODES_ERR_NODE_NOT_FOUND;

    /*
     * Write geometry to a temp file in the same binary format as the output.
     * GNEmbeddedHost reads it and constructs an ArrayMesh for the HostInSOP.
     */

    char tmp_path[4096];
#if defined(_WIN32)
    const char* tmp_dir = getenv("TEMP");
    if (!tmp_dir) tmp_dir = ".";
    snprintf(tmp_path, sizeof(tmp_path), "%s\\gonodes_geoin_%s.raw", tmp_dir, node_id);
#else
    snprintf(tmp_path, sizeof(tmp_path), "/tmp/gonodes_geoin_%s.raw", node_id);
#endif

    FILE* fp = fopen(tmp_path, "wb");
    if (!fp) {
        gn_set_error(inst, "Failed to write geometry temp file");
        return GONODES_ERR_INTERNAL;
    }

    fwrite(positions, sizeof(float), (size_t)vertex_count * 3, fp);
    if (normals)
        fwrite(normals, sizeof(float), (size_t)vertex_count * 3, fp);
    if (uvs)
        fwrite(uvs, sizeof(float), (size_t)vertex_count * 2, fp);
    if (indices && index_count > 0)
        fwrite(indices, sizeof(uint32_t), (size_t)index_count, fp);
    fclose(fp);

    /* Signal metadata. */
    char env_key[256];
    char env_val[4096];
    snprintf(env_key, sizeof(env_key), "GONODES_GEOIN_%s", node_id);
    snprintf(env_val, sizeof(env_val), "%s,%d,%d,%d,%d",
             tmp_path, vertex_count, index_count,
             normals ? 1 : 0, uvs ? 1 : 0);

#if defined(_WIN32)
    _putenv_s(env_key, env_val);
#else
    setenv(env_key, env_val, 1);
#endif

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 5 — MIDI & OSC Bridge                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_send_midi_event(
    gonodes_instance_t inst,
    const gonodes_midi_event_t* event
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!event) return GONODES_ERR_INTERNAL;

    /*
     * Encode the MIDI event as an env-var that GNEmbeddedHost routes to
     * any MidiInCHOP operators.  Multiple events per frame are supported
     * by appending to a semicolon-separated list.
     *
     * Format: "status,data1,data2,channel,port;..."
     */

    const char* existing = getenv("GONODES_MIDI_EVENTS");
    char buf[256];
    snprintf(buf, sizeof(buf), "%d,%d,%d,%d,%d",
             event->status, event->data1, event->data2,
             event->channel, event->port);

    if (existing && existing[0] != '\0') {
        size_t total = strlen(existing) + strlen(buf) + 2;
        char* combined = (char*)malloc(total);
        if (!combined) return GONODES_ERR_INTERNAL;
        snprintf(combined, total, "%s;%s", existing, buf);
#if defined(_WIN32)
        _putenv_s("GONODES_MIDI_EVENTS", combined);
#else
        setenv("GONODES_MIDI_EVENTS", combined, 1);
#endif
        free(combined);
    } else {
#if defined(_WIN32)
        _putenv_s("GONODES_MIDI_EVENTS", buf);
#else
        setenv("GONODES_MIDI_EVENTS", buf, 1);
#endif
    }

    return GONODES_OK;
}


int gonodes_send_osc_message(
    gonodes_instance_t inst,
    const char* address,
    const char* args
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!address) return GONODES_ERR_INTERNAL;

    /*
     * Encode: "address|args_json" appended to GONODES_OSC_MESSAGES (semicolon-separated).
     */

    char buf[4096];
    snprintf(buf, sizeof(buf), "%s|%s", address, args ? args : "[]");

    const char* existing = getenv("GONODES_OSC_MESSAGES");
    if (existing && existing[0] != '\0') {
        size_t total = strlen(existing) + strlen(buf) + 2;
        char* combined = (char*)malloc(total);
        if (!combined) return GONODES_ERR_INTERNAL;
        snprintf(combined, total, "%s;%s", existing, buf);
#if defined(_WIN32)
        _putenv_s("GONODES_OSC_MESSAGES", combined);
#else
        setenv("GONODES_OSC_MESSAGES", combined, 1);
#endif
        free(combined);
    } else {
#if defined(_WIN32)
        _putenv_s("GONODES_OSC_MESSAGES", buf);
#else
        setenv("GONODES_OSC_MESSAGES", buf, 1);
#endif
    }

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 6 — Timeline / Transport Control                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_transport(gonodes_instance_t inst, int state) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);

    inst->transport_state = state;

    char val[16];
    snprintf(val, sizeof(val), "%d", state);
#if defined(_WIN32)
    _putenv_s("GONODES_TRANSPORT_STATE", val);
#else
    setenv("GONODES_TRANSPORT_STATE", val, 1);
#endif

    return GONODES_OK;
}


int gonodes_set_transport_speed(gonodes_instance_t inst, double speed) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);

    inst->transport_speed = speed;

    char val[64];
    snprintf(val, sizeof(val), "%.6f", speed);
#if defined(_WIN32)
    _putenv_s("GONODES_TRANSPORT_SPEED", val);
#else
    setenv("GONODES_TRANSPORT_SPEED", val, 1);
#endif

    return GONODES_OK;
}


int gonodes_transport_seek(gonodes_instance_t inst, double seconds) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);

    inst->transport_time = seconds;

    char val[64];
    snprintf(val, sizeof(val), "%.6f", seconds);
#if defined(_WIN32)
    _putenv_s("GONODES_TRANSPORT_SEEK", val);
#else
    setenv("GONODES_TRANSPORT_SEEK", val, 1);
#endif

    return GONODES_OK;
}


double gonodes_get_transport_time(gonodes_instance_t inst) {
    if (!inst) return 0.0;

    const char* val = getenv("GONODES_TRANSPORT_TIME");
    if (val) {
        inst->transport_time = strtod(val, nullptr);
    }
    return inst->transport_time;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 7 — Dynamic Graph Editing                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_create_node(
    gonodes_instance_t inst,
    const char* node_id,
    const char* node_type
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!inst->patch_loaded) return GONODES_ERR_NOT_LOADED;
    if (!node_id || !node_type) return GONODES_ERR_NODE_NOT_FOUND;

    /*
     * Command format: "node_id,node_type"
     * GNEmbeddedHost.create_node(id, type) creates a new GNNode in the network.
     */
    char env_val[512];
    snprintf(env_val, sizeof(env_val), "%s,%s", node_id, node_type);

#if defined(_WIN32)
    _putenv_s("GONODES_CREATE_NODE", env_val);
#else
    setenv("GONODES_CREATE_NODE", env_val, 1);
#endif

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


int gonodes_delete_node(
    gonodes_instance_t inst,
    const char* node_id
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!inst->patch_loaded) return GONODES_ERR_NOT_LOADED;
    if (!node_id) return GONODES_ERR_NODE_NOT_FOUND;

#if defined(_WIN32)
    _putenv_s("GONODES_DELETE_NODE", node_id);
#else
    setenv("GONODES_DELETE_NODE", node_id, 1);
#endif

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


int gonodes_connect(
    gonodes_instance_t inst,
    const char* from_node, int from_port,
    const char* to_node, int to_port
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!inst->patch_loaded) return GONODES_ERR_NOT_LOADED;
    if (!from_node || !to_node) return GONODES_ERR_NODE_NOT_FOUND;

    char env_val[512];
    snprintf(env_val, sizeof(env_val), "%s,%d,%s,%d",
             from_node, from_port, to_node, to_port);

#if defined(_WIN32)
    _putenv_s("GONODES_CONNECT", env_val);
#else
    setenv("GONODES_CONNECT", env_val, 1);
#endif

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


int gonodes_disconnect(
    gonodes_instance_t inst,
    const char* from_node, int from_port,
    const char* to_node, int to_port
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!inst->patch_loaded) return GONODES_ERR_NOT_LOADED;
    if (!from_node || !to_node) return GONODES_ERR_NODE_NOT_FOUND;

    char env_val[512];
    snprintf(env_val, sizeof(env_val), "%s,%d,%s,%d",
             from_node, from_port, to_node, to_port);

#if defined(_WIN32)
    _putenv_s("GONODES_DISCONNECT", env_val);
#else
    setenv("GONODES_DISCONNECT", env_val, 1);
#endif

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 8 — Event / Trigger System                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_fire_event(
    gonodes_instance_t inst,
    const char* event_name,
    const char* payload
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!event_name) return GONODES_ERR_INTERNAL;

    /*
     * Events are queued per frame (semicolon-separated).
     * Format: "event_name|payload_json;..."
     */

    char buf[4096];
    snprintf(buf, sizeof(buf), "%s|%s", event_name, payload ? payload : "null");

    const char* existing = getenv("GONODES_EVENTS");
    if (existing && existing[0] != '\0') {
        size_t total = strlen(existing) + strlen(buf) + 2;
        char* combined = (char*)malloc(total);
        if (!combined) return GONODES_ERR_INTERNAL;
        snprintf(combined, total, "%s;%s", existing, buf);
#if defined(_WIN32)
        _putenv_s("GONODES_EVENTS", combined);
#else
        setenv("GONODES_EVENTS", combined, 1);
#endif
        free(combined);
    } else {
#if defined(_WIN32)
        _putenv_s("GONODES_EVENTS", buf);
#else
        setenv("GONODES_EVENTS", buf, 1);
#endif
    }

    return GONODES_OK;
}


void gonodes_set_on_event(
    gonodes_instance_t inst,
    gonodes_event_fn callback,
    void* user_data
) {
    VALIDATE_VOID(inst);
    inst->on_event = callback;
    inst->on_event_userdata = user_data;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Gap 10 — Output Resolution Override                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_output_resolution(
    gonodes_instance_t inst,
    const char* node_id,
    int width, int height
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id) return GONODES_ERR_NODE_NOT_FOUND;

    /*
     * GNEmbeddedHost reads GONODES_RESOLUTION_{node_id} = "w,h"
     * and overrides the node's resolution parameter before cooking.
     * Pass "0,0" to revert to the patch's authored resolution.
     */

    char env_key[256];
    char env_val[64];
    snprintf(env_key, sizeof(env_key), "GONODES_RESOLUTION_%s", node_id);
    snprintf(env_val, sizeof(env_val), "%d,%d", width, height);

#if defined(_WIN32)
    _putenv_s(env_key, env_val);
#else
    setenv(env_key, env_val, 1);
#endif

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy GPU Exchange — VOL                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_input_volume_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    uint64_t texture_handle,
    int width, int height, int depth,
    int channels,
    const char* field_name
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id) return GONODES_ERR_NODE_NOT_FOUND;
    if (texture_handle == 0) return GONODES_ERR_INTERNAL;

    /*
     * Stage the GPU handle for the next cook frame.  GNEmbeddedHost reads
     * staged_vol_gpu_inputs[] and passes the native 3D texture handle
     * directly to HostInVOL._set_host_volume_gpu(), which wraps it in a
     * GNVolumeData with rd_texture pointing to the external resource.
     * No CPU readback or upload — zero-copy on the shared device.
     */
    if (inst->staged_vol_gpu_count >= 16) {
        gn_set_error(inst, "Too many staged VOL GPU inputs (max 16)");
        return GONODES_ERR_BUFFER_TOO_SMALL;
    }

    auto& slot = inst->staged_vol_gpu_inputs[inst->staged_vol_gpu_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.texture_handle = texture_handle;
    slot.width = width;
    slot.height = height;
    slot.depth = depth;
    slot.channels = channels;
    snprintf(slot.field_name, sizeof(slot.field_name), "%s",
             field_name ? field_name : "density");

    return GONODES_OK;
}


int gonodes_get_output_volume_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_volume_gpu_handle_t* out_info
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_info) return GONODES_ERR_NODE_NOT_FOUND;
    memset(out_info, 0, sizeof(gonodes_volume_gpu_handle_t));

    /*
     * GNEmbeddedHost writes: GONODES_VOL_GPU_{node_id} = "handle,w,h,d,ch,fmt,api"
     * The handle is the native 3D texture from RenderingDevice.
     */
    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_VOL_GPU_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) return GONODES_ERR_NODE_NOT_FOUND;

    uint64_t handle = 0;
    int w = 0, h = 0, d = 0, ch = 1, fmt = 0, api = 0;
    if (sscanf(val, "%" SCNu64 ",%d,%d,%d,%d,%d,%d",
               &handle, &w, &h, &d, &ch, &fmt, &api) < 4) {
        return GONODES_ERR_PARSE_ERROR;
    }

    out_info->native_handle = handle;
    out_info->width = w;
    out_info->height = h;
    out_info->depth = d;
    out_info->channels = ch;
    out_info->format = fmt;
    out_info->graphics_api = (api != 0) ? api : inst->graphics_api;

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy GPU Exchange — POP                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_input_particles_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    uint64_t buffer_handle,
    int particle_count,
    int stride,
    int buffer_size
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id) return GONODES_ERR_NODE_NOT_FOUND;
    if (buffer_handle == 0) return GONODES_ERR_INTERNAL;

    if (inst->staged_pop_gpu_count >= 16) {
        gn_set_error(inst, "Too many staged POP GPU inputs (max 16)");
        return GONODES_ERR_BUFFER_TOO_SMALL;
    }

    auto& slot = inst->staged_pop_gpu_inputs[inst->staged_pop_gpu_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.buffer_handle = buffer_handle;
    slot.particle_count = particle_count;
    slot.stride = stride;
    slot.buffer_size = buffer_size;

    return GONODES_OK;
}


int gonodes_get_output_particles_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_particle_gpu_handle_t* out_info
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_info) return GONODES_ERR_NODE_NOT_FOUND;
    memset(out_info, 0, sizeof(gonodes_particle_gpu_handle_t));

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_POP_GPU_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) return GONODES_ERR_NODE_NOT_FOUND;

    uint64_t handle = 0;
    int count = 0, stride = 0, buf_size = 0, api = 0;
    if (sscanf(val, "%" SCNu64 ",%d,%d,%d,%d",
               &handle, &count, &stride, &buf_size, &api) < 3) {
        return GONODES_ERR_PARSE_ERROR;
    }

    out_info->native_handle = handle;
    out_info->particle_count = count;
    out_info->stride = stride;
    out_info->buffer_size = buf_size;
    out_info->graphics_api = (api != 0) ? api : inst->graphics_api;

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy CPU Exchange — CHOP                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_input_chop_direct(
    gonodes_instance_t inst,
    const char* node_id,
    const char** channel_names,
    const float** channel_data,
    const int* sample_counts,
    int num_channels
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !channel_names || !channel_data || !sample_counts || num_channels <= 0)
        return GONODES_ERR_NODE_NOT_FOUND;

    if (inst->staged_chop_count >= 16) {
        gn_set_error(inst, "Too many staged CHOP direct inputs (max 16)");
        return GONODES_ERR_BUFFER_TOO_SMALL;
    }

    auto& slot = inst->staged_chop_inputs[inst->staged_chop_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.channel_names = channel_names;
    slot.channel_data = channel_data;
    slot.sample_counts = sample_counts;
    slot.num_channels = num_channels;

    return GONODES_OK;
}


int gonodes_get_output_chop_direct(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_chop_data_t* out_data
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_data) return GONODES_ERR_NODE_NOT_FOUND;
    memset(out_data, 0, sizeof(gonodes_chop_data_t));

    char env_key[256];
    snprintf(env_key, sizeof(env_key), "GONODES_CHOP_DIRECT_%s", node_id);

    const char* val = getenv(env_key);
    if (!val) return GONODES_ERR_NODE_NOT_FOUND;

    int num_ch = 0;
    float sr = 60.0f;
    if (sscanf(val, "%d,%f", &num_ch, &sr) < 1 || num_ch <= 0)
        return GONODES_ERR_PARSE_ERROR;

    /* Ensure channel info array is large enough. */
    if (num_ch > inst->cached_chop_channels_capacity) {
        free(inst->cached_chop_channels);
        inst->cached_chop_channels = (gonodes_channel_info_t*)calloc(
            (size_t)num_ch, sizeof(gonodes_channel_info_t));
        inst->cached_chop_channels_capacity = num_ch;
    }

    for (int i = 0; i < num_ch; ++i) {
        char ch_key[256];
        snprintf(ch_key, sizeof(ch_key), "GONODES_CHOP_DIRECT_%s_CH%d", node_id, i);
        const char* ch_val = getenv(ch_key);
        if (!ch_val) continue;

        char name_buf[128];
        uint64_t ptr_val = 0;
        int count = 0;
        if (sscanf(ch_val, "%127[^,],%" SCNu64 ",%d", name_buf, &ptr_val, &count) >= 3) {
            inst->cached_chop_channels[i].name = getenv(ch_key);
            inst->cached_chop_channels[i].samples = (const float*)(uintptr_t)ptr_val;
            inst->cached_chop_channels[i].num_samples = count;
        }
    }

    out_data->channels = inst->cached_chop_channels;
    out_data->channel_count = num_ch;
    out_data->sample_rate = sr;

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy CPU Exchange — DAT                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_input_table_direct(
    gonodes_instance_t inst,
    const char* node_id,
    const char* json_data,
    int length
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !json_data) return GONODES_ERR_NODE_NOT_FOUND;

    if (inst->staged_dat_count >= 16) {
        gn_set_error(inst, "Too many staged DAT direct inputs (max 16)");
        return GONODES_ERR_BUFFER_TOO_SMALL;
    }

    auto& slot = inst->staged_dat_inputs[inst->staged_dat_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.json_data = json_data;
    slot.length = (length > 0) ? length : (int)strlen(json_data);

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy CPU Exchange — SOP                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_input_geometry_direct(
    gonodes_instance_t inst,
    const char* node_id,
    const float* positions,
    const float* normals,
    const float* uvs,
    const float* colors,
    int vertex_count,
    const uint32_t* indices,
    int index_count
) {
    VALIDATE(inst, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !positions || vertex_count <= 0)
        return GONODES_ERR_NODE_NOT_FOUND;

    if (inst->staged_sop_count >= 16) {
        gn_set_error(inst, "Too many staged SOP direct inputs (max 16)");
        return GONODES_ERR_BUFFER_TOO_SMALL;
    }

    auto& slot = inst->staged_sop_inputs[inst->staged_sop_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.positions = positions;
    slot.normals = normals;
    slot.uvs = uvs;
    slot.colors = colors;
    slot.vertex_count = vertex_count;
    slot.indices = indices;
    slot.index_count = index_count;

    return GONODES_OK;
}

/*
 * gonodes_host.cpp — Public C API implementation (v2.0 multi-patch).
 *
 * Every gonodes_*() function validates its handle, then either:
 *   (a) directly manipulates struct state (transport, stats, staged data), or
 *   (b) pushes a command to the ring buffer that GNEmbeddedHost reads.
 *
 * v2.0 changes from v1.x:
 *   - Input injection uses either staged arrays (zero-copy CHOP/DAT/SOP/VOL/POP)
 *     or command queue entries (texture, param, MIDI, OSC, graph edits).
 *   - Output reading uses direct struct response slots (zero env-var IPC).
 *   - Only remaining env vars: GPU context injection at bootstrap init (8 calls).
 *   - All I/O, param, introspection, and graph-editing functions take a
 *     gonodes_patch_t handle in addition to the instance handle.
 *
 * Build with -DGONODES_BUILDING_LIBRARY to export symbols.
 */

#define GONODES_BUILDING_LIBRARY
#include "../include/gonodes_host.h"
#include "gonodes_bootstrap.h"

#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <atomic>
#include <cinttypes>

/* ── Build-time version consistency check ────────────────────────────────
 * CMake reads LIBGONODES_VERSION from versions.env and passes it as
 * GONODES_VERSION_FROM_CMAKE_{MAJOR,MINOR,PATCH} compile definitions.
 * If the header macros diverge, the build fails immediately. */
#ifdef GONODES_VERSION_FROM_CMAKE_MAJOR
static_assert(GONODES_API_VERSION_MAJOR == GONODES_VERSION_FROM_CMAKE_MAJOR,
              "gonodes_host.h MAJOR version != versions.env");
static_assert(GONODES_API_VERSION_MINOR == GONODES_VERSION_FROM_CMAKE_MINOR,
              "gonodes_host.h MINOR version != versions.env");
static_assert(GONODES_API_VERSION_PATCH == GONODES_VERSION_FROM_CMAKE_PATCH,
              "gonodes_host.h PATCH version != versions.env");
#endif

/* ── Validation macros ─────────────────────────────────────────────────── */

#define VALIDATE(inst, retval) \
    if (!(inst)) { return (retval); }

#define VALIDATE_VOID(inst) \
    if (!(inst)) { return; }

#define VALIDATE_PATCH(inst, patch, retval) \
    if (!(inst)) { return (retval); } \
    gonodes_patch_s* _p = gn_find_patch((inst), (patch)); \
    if (!_p) { gn_set_error((inst), "Invalid patch handle"); return (retval); }

#define VALIDATE_PATCH_VOID(inst, patch) \
    if (!(inst)) { return; } \
    gonodes_patch_s* _p = gn_find_patch((inst), (patch)); \
    if (!_p) { gn_set_error((inst), "Invalid patch handle"); return; }

/* Forward declarations from bootstrap. */
extern gonodes_patch_s* gn_alloc_patch(gonodes_instance_s* inst);
extern void gn_free_patch(gonodes_instance_s* inst, gonodes_patch_s* patch);
extern void gn_set_active_instance(gonodes_instance_s* inst);

/* Helper: push a simple command with just a key string. */
static int push_cmd(gonodes_instance_s* inst, int type, int patch_id,
                     const char* key) {
    gn_command cmd = {};
    cmd.type = type;
    cmd.patch_id = patch_id;
    if (key) snprintf(cmd.key, sizeof(cmd.key), "%s", key);
    return gn_cmd_push(inst, &cmd);
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Lifecycle                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

static std::atomic<int> s_instance_created{0};

gonodes_instance_t gonodes_create(
    const char* project_path,
    const gonodes_gpu_context_t* gpu_context
) {
    if (!project_path) return nullptr;

    if (s_instance_created) {
        fprintf(stderr, "[GONODES] Only one instance per process is supported. "
                        "Call gonodes_destroy() before creating a new one.\n");
        return nullptr;
    }

    auto* inst = (gonodes_instance_s*)calloc(1, sizeof(gonodes_instance_s));
    if (!inst) return nullptr;

    if (gpu_context) {
        inst->graphics_api = gpu_context->graphics_api;
        inst->owns_gpu_device = 0;
    } else {
        inst->graphics_api = GONODES_GFX_AUTO;
        inst->owns_gpu_device = 1;
    }

    inst->godot_handle = gn_bootstrap_init(project_path, gpu_context);
    if (!inst->godot_handle) {
        gn_set_error(inst, "Failed to initialize LibGodot");
        free(inst);
        return nullptr;
    }

    /* Warmup iterations for autoload _ready(). */
    for (int i = 0; i < 3; ++i) {
        gn_bootstrap_iteration(inst->godot_handle, 0.016);
    }

    gn_set_active_instance(inst);
    s_instance_created = 1;
    return inst;
}


void gonodes_destroy(gonodes_instance_t inst) {
    VALIDATE_VOID(inst);

    gn_set_active_instance(nullptr);

    /* Free all patches. */
    for (int i = 0; i < GONODES_MAX_PATCHES; ++i) {
        if (inst->patches[i]) {
            gn_free_patch(inst, inst->patches[i]);
        }
    }

    gn_bootstrap_shutdown(inst->godot_handle);
    gn_free_cached(&inst->last_error);
    free(inst);
    s_instance_created = 0;
}


void gonodes_get_version(int* major, int* minor, int* patch) {
    if (major) *major = GONODES_API_VERSION_MAJOR;
    if (minor) *minor = GONODES_API_VERSION_MINOR;
    if (patch) *patch = GONODES_API_VERSION_PATCH;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Patch Management                                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

gonodes_patch_t gonodes_load_patch(
    gonodes_instance_t inst, const char* patch_path
) {
    VALIDATE(inst, nullptr);
    if (!patch_path) { gn_set_error(inst, "patch_path is NULL"); return nullptr; }

    gonodes_patch_s* p = gn_alloc_patch(inst);
    if (!p) {
        gn_set_error(inst, "Max patches reached (64)");
        return nullptr;
    }

    size_t len = strlen(patch_path);
    if (len >= sizeof(p->path)) {
        gn_set_error(inst, "Patch path too long (max 4095 bytes)");
        gn_free_patch(inst, p);
        return nullptr;
    }
    memcpy(p->path, patch_path, len);
    p->path[len] = '\0';

    /* Enqueue the load command. */
    gn_command cmd = {};
    cmd.type = GN_CMD_LOAD_PATCH;
    cmd.patch_id = p->id;
    snprintf(cmd.data, sizeof(cmd.data), "%s", p->path);
    gn_cmd_push(inst, &cmd);

    /* Run one iteration so GNEmbeddedHost picks it up. */
    gn_bootstrap_iteration(inst->godot_handle, 0.0);

    p->loaded = 1;
    p->mtime = gn_file_mtime(p->path);
    p->frame_number = 0;

    return p;
}


void gonodes_unload_patch(gonodes_instance_t inst, gonodes_patch_t patch) {
    VALIDATE_PATCH_VOID(inst, patch);

    gn_command cmd = {};
    cmd.type = GN_CMD_UNLOAD_PATCH;
    cmd.patch_id = _p->id;
    gn_cmd_push(inst, &cmd);

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    gn_free_patch(inst, _p);
}


int gonodes_reload_patch(gonodes_instance_t inst, gonodes_patch_t patch) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!_p->loaded) { gn_set_error(inst, "Patch is not loaded"); return GONODES_ERR_NOT_LOADED; }

    gn_command cmd = {};
    cmd.type = GN_CMD_RELOAD_PATCH;
    cmd.patch_id = _p->id;
    gn_cmd_push(inst, &cmd);

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    _p->mtime = gn_file_mtime(_p->path);
    return GONODES_OK;
}


void gonodes_set_auto_reload(
    gonodes_instance_t inst, gonodes_patch_t patch,
    int enable, double interval
) {
    VALIDATE_PATCH_VOID(inst, patch);
    _p->auto_reload_enabled = enable;
    _p->auto_reload_interval = (interval > 0.0) ? interval : 0.5;
    _p->auto_reload_timer = 0.0;
}


int gonodes_get_patch_count(gonodes_instance_t inst) {
    VALIDATE(inst, 0);
    return inst->patch_count;
}


const char* gonodes_get_patch_path(
    gonodes_instance_t inst, gonodes_patch_t patch
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    return _p->path;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Frame Loop                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gonodes_cook_frame(gonodes_instance_t inst, double delta_seconds) {
    VALIDATE_VOID(inst);

    /* Auto-reload check for all patches. */
    for (int i = 0; i < GONODES_MAX_PATCHES; ++i) {
        gonodes_patch_s* p = inst->patches[i];
        if (!p || !p->loaded || !p->auto_reload_enabled) continue;

        p->auto_reload_timer += delta_seconds;
        if (p->auto_reload_timer >= p->auto_reload_interval) {
            p->auto_reload_timer = 0.0;
            uint64_t current_mtime = gn_file_mtime(p->path);
            if (current_mtime != 0 && current_mtime != p->mtime) {
                p->mtime = current_mtime;
                gn_command cmd = {};
                cmd.type = GN_CMD_RELOAD_PATCH;
                cmd.patch_id = p->id;
                gn_cmd_push(inst, &cmd);
            }
        }
    }

    /* Run one Godot frame. */
    gn_bootstrap_iteration(inst->godot_handle, delta_seconds);

    /* Bump frame counters. */
    for (int i = 0; i < GONODES_MAX_PATCHES; ++i) {
        if (inst->patches[i] && inst->patches[i]->loaded)
            inst->patches[i]->frame_number++;
    }
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Input Injection  (host -> GONODES)                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_input_texture(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t texture_handle, int width, int height, int format
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_SET_TEXTURE;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    cmd.uval = texture_handle;
    cmd.ival[0] = width;
    cmd.ival[1] = height;
    cmd.ival[2] = format;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_input_chop(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* channel_name,
    const float* samples, int num_samples
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !channel_name || !samples || num_samples <= 0) {
        gn_set_error(inst, "Invalid arguments to gonodes_set_input_chop()"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    gn_command cmd = {};
    cmd.type = GN_CMD_SET_CHOP;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.key2, sizeof(cmd.key2), "%s", channel_name);

    /* Pass pointer address; GDScript reads via GNHostBridge.read_float32(). */
    snprintf(cmd.data, sizeof(cmd.data), "%" PRIu64,
             (uint64_t)(uintptr_t)samples);
    cmd.ival[0] = num_samples;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_input_table(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* json_data
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !json_data) { gn_set_error(inst, "node_id or json_data is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_SET_TABLE;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);

    /* Pass pointer address + byte length; GDScript reads via GNHostBridge. */
    snprintf(cmd.data, sizeof(cmd.data), "%" PRIu64 ",%d",
             (uint64_t)(uintptr_t)json_data, (int)strlen(json_data));
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_parameter(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* param_name,
    const char* value_json
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !param_name || !value_json) {
        gn_set_error(inst, "node_id, param_name, or value_json is NULL"); return GONODES_ERR_PARAM_NOT_FOUND;
    }

    gn_command cmd = {};
    cmd.type = GN_CMD_SET_PARAM;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.key2, sizeof(cmd.key2), "%s", param_name);
    snprintf(cmd.data, sizeof(cmd.data), "%s", value_json);
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


/* gn_bytes_per_pixel() is defined in gonodes_bootstrap.cpp. */


int gonodes_set_input_pixels(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const void* pixels, int width, int height, int format, int row_stride
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !pixels || width <= 0 || height <= 0) {
        gn_set_error(inst, "Invalid arguments to gonodes_set_input_pixels()"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    int bpp = gn_bytes_per_pixel(format);
    int tight_stride = width * bpp;
    int actual_stride = (row_stride > 0) ? row_stride : tight_stride;

    /* If rows are padded, allocate a tightly-packed copy.  The staging
     * buffer is freed automatically after the Godot iteration completes. */
    const void* data_ptr = pixels;
    if (actual_stride != tight_stride) {
        size_t packed_size = (size_t)tight_stride * (size_t)height;
        uint8_t* packed = (uint8_t*)malloc(packed_size);
        if (!packed) {
            gn_set_error(inst, "Failed to allocate pixel packing buffer");
            return GONODES_ERR_INTERNAL;
        }
        const uint8_t* src = (const uint8_t*)pixels;
        for (int y = 0; y < height; ++y)
            memcpy(packed + (size_t)y * tight_stride,
                   src + (size_t)y * actual_stride, (size_t)tight_stride);
        data_ptr = packed;
        gn_track_staging_buf(inst, packed);
    }

    /* Pass pointer address; GDScript reads via GNHostBridge.read_bytes(). */
    gn_command cmd = {};
    cmd.type = GN_CMD_SET_PIXELS;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.data, sizeof(cmd.data), "%" PRIu64,
             (uint64_t)(uintptr_t)data_ptr);
    cmd.ival[0] = width;
    cmd.ival[1] = height;
    cmd.ival[2] = format;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_input_geometry(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions, const float* normals, const float* uvs,
    int vertex_count, const uint32_t* indices, int index_count
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !positions || vertex_count <= 0) {
        gn_set_error(inst, "Invalid arguments to gonodes_set_input_geometry()"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    /* Pass pointer addresses; GDScript reads via GNHostBridge. */
    gn_command cmd = {};
    cmd.type = GN_CMD_SET_GEOMETRY;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.data, sizeof(cmd.data),
             "%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",0,%" PRIu64,
             (uint64_t)(uintptr_t)positions,
             normals  ? (uint64_t)(uintptr_t)normals  : (uint64_t)0,
             uvs      ? (uint64_t)(uintptr_t)uvs      : (uint64_t)0,
             indices  ? (uint64_t)(uintptr_t)indices   : (uint64_t)0);
    cmd.ival[0] = vertex_count;
    cmd.ival[1] = index_count;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_input_volume(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* voxels, int width, int height, int depth, int channels,
    const char* field_name
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !voxels) { gn_set_error(inst, "node_id or voxels is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    /* Pass pointer address; GDScript reads via GNHostBridge.read_float32(). */
    gn_command cmd = {};
    cmd.type = GN_CMD_SET_VOLUME;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.key2, sizeof(cmd.key2), "%s", field_name ? field_name : "density");
    snprintf(cmd.data, sizeof(cmd.data), "%" PRIu64,
             (uint64_t)(uintptr_t)voxels);
    cmd.ival[0] = width;
    cmd.ival[1] = height;
    cmd.ival[2] = depth;
    cmd.ival[3] = channels;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_input_particles(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions, const float* velocities,
    const float* colors, const float* ages, int particle_count
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !positions) { gn_set_error(inst, "node_id or positions is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    /* Pass pointer addresses; GDScript reads via GNHostBridge. */
    gn_command cmd = {};
    cmd.type = GN_CMD_SET_PARTICLES;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.data, sizeof(cmd.data),
             "%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64,
             (uint64_t)(uintptr_t)positions,
             velocities ? (uint64_t)(uintptr_t)velocities : (uint64_t)0,
             colors     ? (uint64_t)(uintptr_t)colors     : (uint64_t)0,
             ages       ? (uint64_t)(uintptr_t)ages       : (uint64_t)0);
    cmd.ival[0] = particle_count;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


/* ── Direct input variants ─────────────────────────────────────────────── */
/* With the pointer-based command path, these are thin wrappers around
 * the regular functions.  They exist for API convenience (multi-channel
 * CHOP, explicit-length DAT, geometry with colors). */

int gonodes_set_input_chop_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const char** channel_names, const float** channel_data,
    const int* sample_counts, int num_channels
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !channel_names || !channel_data || !sample_counts || num_channels <= 0) {
        gn_set_error(inst, "Invalid arguments to gonodes_set_input_chop_direct()"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    /* Push one GN_CMD_SET_CHOP per channel — each carries its own pointer. */
    for (int i = 0; i < num_channels; ++i) {
        if (!channel_names[i] || !channel_data[i] || sample_counts[i] <= 0)
            continue;
        int rc = gonodes_set_input_chop(inst, patch, node_id,
                                        channel_names[i], channel_data[i],
                                        sample_counts[i]);
        if (rc != GONODES_OK) return rc;
    }
    return GONODES_OK;
}


int gonodes_set_input_table_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* json_data, int length
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !json_data) { gn_set_error(inst, "node_id or json_data is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_SET_TABLE;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    int actual_len = (length > 0) ? length : (int)strlen(json_data);
    snprintf(cmd.data, sizeof(cmd.data), "%" PRIu64 ",%d",
             (uint64_t)(uintptr_t)json_data, actual_len);
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_input_geometry_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions, const float* normals,
    const float* uvs, const float* colors,
    int vertex_count, const uint32_t* indices, int index_count
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !positions || vertex_count <= 0) {
        gn_set_error(inst, "Invalid arguments to gonodes_set_input_geometry_direct()"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    /* Same as gonodes_set_input_geometry but includes the colors pointer. */
    gn_command cmd = {};
    cmd.type = GN_CMD_SET_GEOMETRY;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.data, sizeof(cmd.data),
             "%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64,
             (uint64_t)(uintptr_t)positions,
             normals ? (uint64_t)(uintptr_t)normals : (uint64_t)0,
             uvs     ? (uint64_t)(uintptr_t)uvs     : (uint64_t)0,
             colors  ? (uint64_t)(uintptr_t)colors  : (uint64_t)0,
             indices ? (uint64_t)(uintptr_t)indices  : (uint64_t)0);
    cmd.ival[0] = vertex_count;
    cmd.ival[1] = index_count;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_input_volume_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t texture_handle, int width, int height, int depth, int channels,
    const char* field_name
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || texture_handle == 0) { gn_set_error(inst, "node_id is NULL or texture_handle is 0"); return GONODES_ERR_NODE_NOT_FOUND; }

    if (_p->staged_vol_gpu_count >= GONODES_MAX_STAGED) {
        gn_set_error(inst, "Too many staged VOL GPU inputs");
        return GONODES_ERR_BUFFER_TOO_SMALL;
    }

    auto& slot = _p->staged_vol_gpu_inputs[_p->staged_vol_gpu_count++];
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


int gonodes_set_input_particles_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t buffer_handle, int particle_count, int stride, int buffer_size
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || buffer_handle == 0) { gn_set_error(inst, "node_id is NULL or buffer_handle is 0"); return GONODES_ERR_NODE_NOT_FOUND; }

    if (_p->staged_pop_gpu_count >= GONODES_MAX_STAGED) {
        gn_set_error(inst, "Too many staged POP GPU inputs");
        return GONODES_ERR_BUFFER_TOO_SMALL;
    }

    auto& slot = _p->staged_pop_gpu_inputs[_p->staged_pop_gpu_count++];
    snprintf(slot.node_id, sizeof(slot.node_id), "%s", node_id);
    slot.buffer_handle = buffer_handle;
    slot.particle_count = particle_count;
    slot.stride = stride;
    slot.buffer_size = buffer_size;

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output Reading  (GONODES -> host)                                        */
/*                                                                           */
/*  Outputs are populated by GNEmbeddedHost writing directly into the        */
/*  patch struct's cached fields via the GDExtension bridge. The C API       */
/*  simply reads from those fields.                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

uint64_t gonodes_get_output_texture(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, int* out_width, int* out_height
) {
    VALIDATE_PATCH(inst, patch, 0);
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return 0; }

    for (int i = 0; i < _p->tex_output_count; ++i) {
        if (strcmp(_p->tex_outputs[i].node_id, node_id) == 0) {
            if (out_width)  *out_width  = _p->tex_outputs[i].width;
            if (out_height) *out_height = _p->tex_outputs[i].height;
            return _p->tex_outputs[i].handle;
        }
    }
    gn_set_error(inst, "Output texture not found for specified node");
    return 0;
}


int gonodes_get_output_chop(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* channel_name,
    float* out_buffer, int buffer_size
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !channel_name || !out_buffer || buffer_size <= 0) {
        gn_set_error(inst, "Invalid arguments to gonodes_get_output_chop()"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    for (int i = 0; i < _p->chop_output_count; ++i) {
        if (strcmp(_p->chop_outputs[i].node_id, node_id) == 0 &&
            strcmp(_p->chop_outputs[i].channel_name, channel_name) == 0) {
            int to_copy = _p->chop_outputs[i].sample_count;
            if (to_copy > buffer_size) to_copy = buffer_size;
            memcpy(out_buffer, _p->chop_outputs[i].samples,
                   (size_t)to_copy * sizeof(float));
            return to_copy;
        }
    }
    gn_set_error(inst, "CHOP channel not found for specified node");
    return 0;
}


const char* gonodes_get_output_table(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return nullptr; }

    for (int i = 0; i < _p->dat_output_count; ++i) {
        if (strcmp(_p->dat_outputs[i].node_id, node_id) == 0) {
            return _p->dat_outputs[i].json_data;
        }
    }
    gn_set_error(inst, "Output table not found for specified node");
    return nullptr;
}


const char* gonodes_get_parameter(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* param_name
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    if (!node_id || !param_name) { gn_set_error(inst, "node_id or param_name is NULL"); return nullptr; }

    for (int i = 0; i < _p->param_output_count; ++i) {
        if (strcmp(_p->param_outputs[i].node_id, node_id) == 0 &&
            strcmp(_p->param_outputs[i].param_name, param_name) == 0) {
            return _p->param_outputs[i].value_json;
        }
    }
    gn_set_error(inst, "Parameter not found for specified node");
    return nullptr;
}


int gonodes_get_texture_info(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_texture_info_t* out_info
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_info) { gn_set_error(inst, "node_id or out_info is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    memset(out_info, 0, sizeof(gonodes_texture_info_t));

    for (int i = 0; i < _p->tex_output_count; ++i) {
        if (strcmp(_p->tex_outputs[i].node_id, node_id) == 0) {
            out_info->native_handle = _p->tex_outputs[i].handle;
            out_info->width         = _p->tex_outputs[i].width;
            out_info->height        = _p->tex_outputs[i].height;
            out_info->format        = _p->tex_outputs[i].format;
            out_info->channels      = _p->tex_outputs[i].channels;
            out_info->graphics_api  = _p->tex_outputs[i].graphics_api;
            if (out_info->graphics_api == 0)
                out_info->graphics_api = inst->graphics_api;
            return GONODES_OK;
        }
    }
    gn_set_error(inst, "Texture info not found for specified node");
    return GONODES_ERR_NODE_NOT_FOUND;
}


int gonodes_read_output_pixels(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    void* out_pixels, int buffer_size, int format,
    int* out_width, int* out_height
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_pixels || buffer_size <= 0) {
        gn_set_error(inst, "Invalid arguments to gonodes_read_output_pixels()"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    /* Request readback via the readback slot. */
    snprintf(_p->readback_slot.node_id, sizeof(_p->readback_slot.node_id),
             "%s", node_id);
    _p->readback_slot.format = format;
    _p->readback_slot.requested = 1;
    _p->readback_slot.completed = 0;

    gn_bootstrap_iteration(inst->godot_handle, 0.0);

    if (!_p->readback_slot.completed || !_p->readback_slot.pixel_data) {
        gn_set_error(inst, "Readback failed");
        return GONODES_ERR_INTERNAL;
    }

    int w = _p->readback_slot.width;
    int h = _p->readback_slot.height;
    if (out_width) *out_width = w;
    if (out_height) *out_height = h;

    int bpp = gn_bytes_per_pixel(format);
    int data_size = w * h * bpp;
    int to_copy = (data_size < buffer_size) ? data_size : buffer_size;
    int actual = (to_copy < _p->readback_slot.pixel_data_size)
                 ? to_copy : _p->readback_slot.pixel_data_size;
    memcpy(out_pixels, _p->readback_slot.pixel_data, (size_t)actual);

    _p->readback_slot.requested = 0;
    return actual;
}


const gonodes_geometry_data_t* gonodes_get_output_geometry(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return nullptr; }

    /* Request geometry export via the geo request slot. */
    snprintf(_p->geo_request_slot.node_id, sizeof(_p->geo_request_slot.node_id),
             "%s", node_id);
    _p->geo_request_slot.requested = 1;
    _p->geo_request_slot.completed = 0;

    gn_bootstrap_iteration(inst->godot_handle, 0.0);

    if (!_p->geo_request_slot.completed) { gn_set_error(inst, "Geometry readback not completed for specified node"); return nullptr; }

    /* GNEmbeddedHost populated the geometry buffers directly. */
    return &_p->cached_geometry;
}


const gonodes_volume_data_t* gonodes_get_output_volume(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    (void)node_id;
    gn_set_error(inst, "CPU volume readback not yet supported; use gonodes_get_output_volume_gpu()");
    return nullptr;
}


const gonodes_particle_data_t* gonodes_get_output_particles(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    (void)node_id;
    gn_set_error(inst, "CPU particle readback not yet supported; use gonodes_get_output_particles_gpu()");
    return nullptr;
}


int gonodes_get_output_volume_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_volume_gpu_handle_t* out_info
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_info) { gn_set_error(inst, "node_id or out_info is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }
    memset(out_info, 0, sizeof(gonodes_volume_gpu_handle_t));

    if (_p->cached_vol_gpu.native_handle == 0) {
        gn_set_error(inst, "No GPU volume output available"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    *out_info = _p->cached_vol_gpu;
    if (out_info->graphics_api == 0)
        out_info->graphics_api = inst->graphics_api;
    return GONODES_OK;
}


int gonodes_get_output_particles_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_particle_gpu_handle_t* out_info
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_info) { gn_set_error(inst, "node_id or out_info is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }
    memset(out_info, 0, sizeof(gonodes_particle_gpu_handle_t));

    if (_p->cached_pop_gpu.native_handle == 0) {
        gn_set_error(inst, "No GPU particle output available"); return GONODES_ERR_NODE_NOT_FOUND;
    }

    *out_info = _p->cached_pop_gpu;
    if (out_info->graphics_api == 0)
        out_info->graphics_api = inst->graphics_api;
    return GONODES_OK;
}


int gonodes_get_output_chop_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_chop_data_t* out_data
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id || !out_data) { gn_set_error(inst, "node_id or out_data is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }
    memset(out_data, 0, sizeof(gonodes_chop_data_t));

    /* Build chop_data from per-channel response slots. */
    int num_ch = 0;
    for (int i = 0; i < _p->chop_output_count; ++i) {
        if (strcmp(_p->chop_outputs[i].node_id, node_id) == 0)
            num_ch++;
    }
    if (num_ch == 0) { gn_set_error(inst, "No CHOP channels found for specified node"); return GONODES_ERR_NODE_NOT_FOUND; }

    if (num_ch > _p->cached_chop_channels_capacity) {
        free(_p->cached_chop_channels);
        _p->cached_chop_channels = (gonodes_channel_info_t*)calloc(
            (size_t)num_ch, sizeof(gonodes_channel_info_t));
        if (!_p->cached_chop_channels) {
            _p->cached_chop_channels_capacity = 0;
            gn_set_error(inst, "Failed to allocate CHOP channel cache");
            return GONODES_ERR_NODE_NOT_FOUND;
        }
        _p->cached_chop_channels_capacity = num_ch;
    }

    int idx = 0;
    for (int i = 0; i < _p->chop_output_count && idx < num_ch; ++i) {
        if (strcmp(_p->chop_outputs[i].node_id, node_id) == 0) {
            _p->cached_chop_channels[idx].name = _p->chop_outputs[i].channel_name;
            _p->cached_chop_channels[idx].samples = _p->chop_outputs[i].samples;
            _p->cached_chop_channels[idx].num_samples = _p->chop_outputs[i].sample_count;
            idx++;
        }
    }

    out_data->channels = _p->cached_chop_channels;
    out_data->channel_count = num_ch;
    out_data->sample_rate = 60.0f;

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Introspection                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

const char* gonodes_list_nodes(
    gonodes_instance_t inst, gonodes_patch_t patch
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    return _p->cached_nodes_json;
}


const char* gonodes_get_node_info(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return nullptr; }
    return _p->cached_node_info_json;
}


const char* gonodes_list_parameters(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return nullptr; }
    return _p->cached_params_json;
}


const char* gonodes_list_connections(
    gonodes_instance_t inst, gonodes_patch_t patch
) {
    VALIDATE_PATCH(inst, patch, nullptr);
    return _p->cached_connections_json;
}


const char* gonodes_get_host_io(
    gonodes_instance_t inst, gonodes_patch_t patch
) {
    VALIDATE_PATCH(inst, patch, "{}");
    return _p->cached_host_io_json ? _p->cached_host_io_json : "{}";
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Callbacks                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gonodes_set_on_param_changed(
    gonodes_instance_t inst,
    gonodes_param_changed_fn callback, void* user_data
) {
    VALIDATE_VOID(inst);
    inst->on_param_changed = callback;
    inst->on_param_changed_userdata = user_data;
}


void gonodes_set_log_callback(
    gonodes_instance_t inst,
    gonodes_log_fn callback, void* user_data
) {
    VALIDATE_VOID(inst);
    inst->log_callback = callback;
    inst->log_callback_userdata = user_data;
}


void gonodes_set_on_event(
    gonodes_instance_t inst,
    gonodes_event_fn callback, void* user_data
) {
    VALIDATE_VOID(inst);
    inst->on_event = callback;
    inst->on_event_userdata = user_data;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Utilities                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

const char* gonodes_get_last_error(gonodes_instance_t inst) {
    VALIDATE(inst, "Invalid handle");
    return inst->last_error ? inst->last_error : "";
}


void gonodes_get_stats(
    gonodes_instance_t inst, gonodes_patch_t patch,
    double* out_cook_time_ms, int* out_node_count, int* out_frame_number
) {
    VALIDATE_PATCH_VOID(inst, patch);
    if (out_cook_time_ms) *out_cook_time_ms = _p->last_cook_time_ms;
    if (out_node_count)   *out_node_count   = _p->last_cooked_count;
    if (out_frame_number) *out_frame_number  = _p->frame_number;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  MIDI & OSC                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_send_midi_event(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const gonodes_midi_event_t* event
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!event) { gn_set_error(inst, "MIDI event is NULL"); return GONODES_ERR_INTERNAL; }

    gn_command cmd = {};
    cmd.type = GN_CMD_MIDI_EVENT;
    cmd.patch_id = _p->id;
    snprintf(cmd.data, sizeof(cmd.data), "%d,%d,%d,%d,%d",
             event->status, event->data1, event->data2,
             event->channel, event->port);
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_send_osc_message(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* address, const char* args
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!address) { gn_set_error(inst, "OSC address is NULL"); return GONODES_ERR_INTERNAL; }

    gn_command cmd = {};
    cmd.type = GN_CMD_OSC_MESSAGE;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", address);
    snprintf(cmd.data, sizeof(cmd.data), "%s", args ? args : "[]");
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Transport                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_transport(
    gonodes_instance_t inst, gonodes_patch_t patch, int state
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    _p->transport_state = state;

    gn_command cmd = {};
    cmd.type = GN_CMD_SET_TRANSPORT;
    cmd.patch_id = _p->id;
    cmd.ival[0] = state;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_set_transport_speed(
    gonodes_instance_t inst, gonodes_patch_t patch, double speed
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    _p->transport_speed = speed;

    gn_command cmd = {};
    cmd.type = GN_CMD_TRANSPORT_SPEED;
    cmd.patch_id = _p->id;
    cmd.dval = speed;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


int gonodes_transport_seek(
    gonodes_instance_t inst, gonodes_patch_t patch, double seconds
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    _p->transport_time = seconds;

    gn_command cmd = {};
    cmd.type = GN_CMD_TRANSPORT_SEEK;
    cmd.patch_id = _p->id;
    cmd.dval = seconds;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


double gonodes_get_transport_time(
    gonodes_instance_t inst, gonodes_patch_t patch
) {
    if (!inst || !patch) return 0.0;
    gonodes_patch_s* p = gn_find_patch(inst, patch);
    if (!p) {
        gn_set_error(inst, "Invalid patch handle");
        return 0.0;
    }
    return p->transport_time;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Dynamic Graph Editing                                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_create_node(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* node_type
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!_p->loaded) { gn_set_error(inst, "Patch is not loaded"); return GONODES_ERR_NOT_LOADED; }
    if (!node_id || !node_type) { gn_set_error(inst, "node_id or node_type is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_CREATE_NODE;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    snprintf(cmd.data, sizeof(cmd.data), "%s", node_type);
    gn_cmd_push(inst, &cmd);

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


int gonodes_delete_node(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!_p->loaded) { gn_set_error(inst, "Patch is not loaded"); return GONODES_ERR_NOT_LOADED; }
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_DELETE_NODE;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    gn_cmd_push(inst, &cmd);

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


int gonodes_connect(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* from_node, int from_port,
    const char* to_node, int to_port
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!_p->loaded) { gn_set_error(inst, "Patch is not loaded"); return GONODES_ERR_NOT_LOADED; }
    if (!from_node || !to_node) { gn_set_error(inst, "from_node or to_node is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_CONNECT;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", from_node);
    snprintf(cmd.key2, sizeof(cmd.key2), "%s", to_node);
    cmd.ival[0] = from_port;
    cmd.ival[1] = to_port;
    gn_cmd_push(inst, &cmd);

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


int gonodes_disconnect(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* from_node, int from_port,
    const char* to_node, int to_port
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!_p->loaded) { gn_set_error(inst, "Patch is not loaded"); return GONODES_ERR_NOT_LOADED; }
    if (!from_node || !to_node) { gn_set_error(inst, "from_node or to_node is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_DISCONNECT;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", from_node);
    snprintf(cmd.key2, sizeof(cmd.key2), "%s", to_node);
    cmd.ival[0] = from_port;
    cmd.ival[1] = to_port;
    gn_cmd_push(inst, &cmd);

    gn_bootstrap_iteration(inst->godot_handle, 0.0);
    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Events                                                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_fire_event(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* event_name, const char* payload
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!event_name) { gn_set_error(inst, "event_name is NULL"); return GONODES_ERR_INTERNAL; }

    gn_command cmd = {};
    cmd.type = GN_CMD_FIRE_EVENT;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", event_name);
    snprintf(cmd.data, sizeof(cmd.data), "%s", payload ? payload : "null");
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output Resolution Override                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

int gonodes_set_output_resolution(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, int width, int height
) {
    VALIDATE_PATCH(inst, patch, GONODES_ERR_INVALID_HANDLE);
    if (!node_id) { gn_set_error(inst, "node_id is NULL"); return GONODES_ERR_NODE_NOT_FOUND; }

    gn_command cmd = {};
    cmd.type = GN_CMD_SET_RESOLUTION;
    cmd.patch_id = _p->id;
    snprintf(cmd.key, sizeof(cmd.key), "%s", node_id);
    cmd.ival[0] = width;
    cmd.ival[1] = height;
    gn_cmd_push(inst, &cmd);

    return GONODES_OK;
}

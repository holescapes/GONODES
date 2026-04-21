/*
 * GONODES Host API v2.0 — C interface for embedding GONODES in host applications.
 *
 * Link against libgonodes (.dll / .dylib / .so) and include this header.
 *
 * v2.0 Multi-Patch Architecture:
 *   A single gonodes_instance_t boots ONE Godot engine (one GPU device,
 *   one RenderingServer, one SceneTree).  Multiple patches can be loaded
 *   simultaneously — each patch gets its own cook engine, node graph, and
 *   transport, but they share the GPU context and rendering pipeline.
 *
 *   gonodes_load_patch() returns a gonodes_patch_t handle.  All I/O, param,
 *   introspection, and graph-editing functions take (inst, patch, ...).
 *   One gonodes_cook_frame() call cooks ALL loaded patches.
 *
 * Minimal usage:
 *
 *     gonodes_instance_t gn = gonodes_create("path/to/project", NULL);
 *     gonodes_patch_t p1 = gonodes_load_patch(gn, "effects.gnpatch");
 *     gonodes_patch_t p2 = gonodes_load_patch(gn, "overlay.gnpatch");
 *
 *     // In your frame loop:
 *     gonodes_cook_frame(gn, delta_seconds);
 *     uint64_t tex1 = gonodes_get_output_texture(gn, p1, "out", &w, &h);
 *     uint64_t tex2 = gonodes_get_output_texture(gn, p2, "out", &w2, &h2);
 *
 *     gonodes_unload_patch(gn, p2);
 *     gonodes_destroy(gn);
 *
 * Copyright (c) 2026 GONODES contributors.  MIT License.
 *
 * POINTER LIFETIME:
 *   Functions returning const char* or const struct pointers
 *   (gonodes_list_nodes, gonodes_get_output_table, gonodes_get_parameter,
 *   gonodes_get_output_geometry, gonodes_list_connections, etc.) return
 *   pointers into internal response slots.  These pointers are valid ONLY
 *   until the next call to gonodes_cook_frame() — after that, the slots
 *   are repopulated and previous pointers become stale.  Copy any data
 *   you need to retain across frames.
 *
 * BUFFER LIMITS:
 *   - Max 64 output slots per data type per patch (GONODES_MAX_OUTPUT_SLOTS)
 *   - Max 4096 samples per CHOP channel output
 *   - Max 64 concurrent patches per instance (GONODES_MAX_PATCHES)
 *   - Command queue: 256 entries (GN_CMD_QUEUE_SIZE)
 *   Functions silently clamp when limits are exceeded; check
 *   gonodes_get_last_error() after operations that may overflow.
 */

#ifndef GONODES_HOST_H
#define GONODES_HOST_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Version                                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

#define GONODES_API_VERSION_MAJOR 2
#define GONODES_API_VERSION_MINOR 5
#define GONODES_API_VERSION_PATCH 0

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Export / Import                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

#if defined(_WIN32)
  #if defined(GONODES_BUILDING_LIBRARY)
    #define GONODES_API __declspec(dllexport)
  #else
    #define GONODES_API __declspec(dllimport)
  #endif
#elif defined(__GNUC__) || defined(__clang__)
  #define GONODES_API __attribute__((visibility("default")))
#else
  #define GONODES_API
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Types                                                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Opaque handle to a GONODES engine instance (one per process). */
typedef struct gonodes_instance_s* gonodes_instance_t;

/** Opaque handle to a loaded patch within an instance. */
typedef struct gonodes_patch_s* gonodes_patch_t;

/** Graphics API selector. */
enum gonodes_graphics_api {
    GONODES_GFX_AUTO   = 0,
    GONODES_GFX_VULKAN = 1,
    GONODES_GFX_METAL  = 2,
    GONODES_GFX_OPENGL = 3,
    GONODES_GFX_MOBILE = 4,
};

/** Texture pixel format hint. */
enum gonodes_texture_format {
    GONODES_FORMAT_RGBA8   = 0,
    GONODES_FORMAT_RGBA16F = 1,
    GONODES_FORMAT_RGBA32F = 2,
    GONODES_FORMAT_R8      = 3,
    GONODES_FORMAT_RG8     = 4,
    GONODES_FORMAT_BGRA8   = 5,
    GONODES_FORMAT_R16F    = 6,
    GONODES_FORMAT_RG16F   = 7,
};

/** Error codes. */
enum gonodes_error {
    GONODES_OK                  =  0,
    GONODES_ERR_INVALID_HANDLE  = -1,
    GONODES_ERR_FILE_NOT_FOUND  = -2,
    GONODES_ERR_PARSE_ERROR     = -3,
    GONODES_ERR_GPU_INIT_FAILED = -4,
    GONODES_ERR_NODE_NOT_FOUND  = -5,
    GONODES_ERR_PARAM_NOT_FOUND = -6,
    GONODES_ERR_BUFFER_TOO_SMALL= -7,
    GONODES_ERR_NOT_LOADED      = -8,
    GONODES_ERR_MAX_PATCHES     = -9,
    GONODES_ERR_UNSUPPORTED     = -10,
    GONODES_ERR_TYPE_MISMATCH   = -11,
    GONODES_ERR_INTERNAL        = -99,
};

/** GPU context descriptor. */
typedef struct gonodes_gpu_context {
    void* vulkan_instance;
    void* vulkan_physical_device;
    void* vulkan_device;
    void* vulkan_queue;
    uint32_t vulkan_queue_family;
    void* metal_device;
    void* metal_command_queue;
    void* gl_context;
    int graphics_api;
} gonodes_gpu_context_t;

/** Callback for parameter changes (includes patch handle). */
typedef void (*gonodes_param_changed_fn)(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* param_name,
    const char* value_json, void* user_data
);

/** Callback for log messages. */
typedef void (*gonodes_log_fn)(
    int level, const char* category, const char* message, void* user_data
);

/** Callback for events from a patch. */
typedef void (*gonodes_event_fn)(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* event_name, const char* payload, void* user_data
);

typedef struct gonodes_texture_info {
    int width, height, format, channels;
    uint64_t native_handle;
    int graphics_api;
} gonodes_texture_info_t;

typedef struct gonodes_geometry_data {
    const float* positions;
    const float* normals;
    const float* uvs;
    const float* colors;
    int vertex_count;
    const uint32_t* indices;
    int index_count;
    int primitive_type;
} gonodes_geometry_data_t;

typedef struct gonodes_volume_data {
    const float* voxels;
    int width, height, depth, channels;
    const char* field_name;
} gonodes_volume_data_t;

typedef struct gonodes_particle_data {
    const float* positions;
    const float* velocities;
    const float* colors;
    const float* ages;
    int particle_count;
} gonodes_particle_data_t;

typedef struct gonodes_volume_gpu_handle {
    uint64_t native_handle;
    int width, height, depth, channels, format, graphics_api;
} gonodes_volume_gpu_handle_t;

typedef struct gonodes_particle_gpu_handle {
    uint64_t native_handle;
    int particle_count, stride, buffer_size, graphics_api;
} gonodes_particle_gpu_handle_t;

typedef struct gonodes_channel_info {
    const char* name;
    const float* samples;
    int num_samples;
} gonodes_channel_info_t;

typedef struct gonodes_chop_data {
    const gonodes_channel_info_t* channels;
    int channel_count;
    float sample_rate;
} gonodes_chop_data_t;

enum gonodes_transport_state {
    GONODES_TRANSPORT_PLAY  = 0,
    GONODES_TRANSPORT_PAUSE = 1,
    GONODES_TRANSPORT_STOP  = 2,
};

typedef struct gonodes_midi_event {
    int status, data1, data2, channel, port;
} gonodes_midi_event_t;


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Lifecycle                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API gonodes_instance_t gonodes_create(
    const char* project_path,
    const gonodes_gpu_context_t* gpu_context);

GONODES_API void gonodes_destroy(gonodes_instance_t inst);

GONODES_API void gonodes_get_version(int* major, int* minor, int* patch);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Patch Management  (v2.0 — multi-patch)                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API gonodes_patch_t gonodes_load_patch(
    gonodes_instance_t inst, const char* patch_path);

GONODES_API void gonodes_unload_patch(
    gonodes_instance_t inst, gonodes_patch_t patch);

GONODES_API int gonodes_reload_patch(
    gonodes_instance_t inst, gonodes_patch_t patch);

GONODES_API void gonodes_set_auto_reload(
    gonodes_instance_t inst, gonodes_patch_t patch,
    int enable, double interval);

GONODES_API int gonodes_get_patch_count(gonodes_instance_t inst);

GONODES_API const char* gonodes_get_patch_path(
    gonodes_instance_t inst, gonodes_patch_t patch);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Frame Loop                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API void gonodes_cook_frame(
    gonodes_instance_t inst, double delta_seconds);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Input Injection  (host -> GONODES)                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API int gonodes_set_input_texture(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t texture_handle, int width, int height, int format);

GONODES_API int gonodes_set_input_chop(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* channel_name,
    const float* samples, int num_samples);

GONODES_API int gonodes_set_input_table(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* json_data);

GONODES_API int gonodes_set_parameter(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* param_name,
    const char* value_json);

GONODES_API int gonodes_set_input_pixels(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const void* pixels, int width, int height, int format, int row_stride);

GONODES_API int gonodes_set_input_geometry(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions, const float* normals, const float* uvs,
    int vertex_count, const uint32_t* indices, int index_count);

GONODES_API int gonodes_set_input_volume(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* voxels, int width, int height, int depth, int channels,
    const char* field_name);

GONODES_API int gonodes_set_input_particles(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions, const float* velocities,
    const float* colors, const float* ages, int particle_count);

GONODES_API int gonodes_set_input_chop_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const char** channel_names, const float** channel_data,
    const int* sample_counts, int num_channels);

GONODES_API int gonodes_set_input_table_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* json_data, int length);

GONODES_API int gonodes_set_input_geometry_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions, const float* normals,
    const float* uvs, const float* colors,
    int vertex_count, const uint32_t* indices, int index_count);

GONODES_API int gonodes_set_input_volume_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t texture_handle, int width, int height, int depth, int channels,
    const char* field_name);

GONODES_API int gonodes_set_input_particles_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t buffer_handle, int particle_count, int stride, int buffer_size);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output Reading  (GONODES -> host)                                        */
/*  NOTE: All const char* / const struct* returns are valid only until the   */
/*  next gonodes_cook_frame() call.  Copy data you need across frames.       */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API uint64_t gonodes_get_output_texture(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, int* out_width, int* out_height);

GONODES_API int gonodes_get_output_chop(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* channel_name,
    float* out_buffer, int buffer_size);

GONODES_API const char* gonodes_get_output_table(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id);

GONODES_API const char* gonodes_get_parameter(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* param_name);

GONODES_API int gonodes_get_texture_info(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_texture_info_t* out_info);

GONODES_API int gonodes_read_output_pixels(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    void* out_pixels, int buffer_size, int format,
    int* out_width, int* out_height);

GONODES_API const gonodes_geometry_data_t* gonodes_get_output_geometry(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id);

GONODES_API const gonodes_volume_data_t* gonodes_get_output_volume(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id);

GONODES_API const gonodes_particle_data_t* gonodes_get_output_particles(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id);

GONODES_API int gonodes_get_output_volume_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_volume_gpu_handle_t* out_info);

GONODES_API int gonodes_get_output_particles_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_particle_gpu_handle_t* out_info);

GONODES_API int gonodes_get_output_chop_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, gonodes_chop_data_t* out_data);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Introspection  — returned strings valid until next gonodes_cook_frame()  */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API const char* gonodes_list_nodes(
    gonodes_instance_t inst, gonodes_patch_t patch);

GONODES_API const char* gonodes_get_node_info(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id);

GONODES_API const char* gonodes_list_parameters(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id);

GONODES_API const char* gonodes_list_connections(
    gonodes_instance_t inst, gonodes_patch_t patch);

GONODES_API const char* gonodes_get_host_io(
    gonodes_instance_t inst, gonodes_patch_t patch);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Callbacks                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API void gonodes_set_on_param_changed(
    gonodes_instance_t inst,
    gonodes_param_changed_fn callback, void* user_data);

GONODES_API void gonodes_set_log_callback(
    gonodes_instance_t inst,
    gonodes_log_fn callback, void* user_data);

GONODES_API void gonodes_set_on_event(
    gonodes_instance_t inst,
    gonodes_event_fn callback, void* user_data);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Utilities                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API const char* gonodes_get_last_error(gonodes_instance_t inst);

GONODES_API void gonodes_get_stats(
    gonodes_instance_t inst, gonodes_patch_t patch,
    double* out_cook_time_ms, int* out_node_count, int* out_frame_number);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  MIDI & OSC                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API int gonodes_send_midi_event(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const gonodes_midi_event_t* event);

GONODES_API int gonodes_send_osc_message(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* address, const char* args);


/* ═════════════════════════════════════════════════════════════════════════════ */
/*  Transport Control                                                          */
/* ═════════════════════════════════════════════════════════════════════════════ */

GONODES_API int gonodes_set_transport(
    gonodes_instance_t inst, gonodes_patch_t patch, int state);

GONODES_API int gonodes_set_transport_speed(
    gonodes_instance_t inst, gonodes_patch_t patch, double speed);

GONODES_API int gonodes_transport_seek(
    gonodes_instance_t inst, gonodes_patch_t patch, double seconds);

GONODES_API double gonodes_get_transport_time(
    gonodes_instance_t inst, gonodes_patch_t patch);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Dynamic Graph Editing                                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API int gonodes_create_node(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, const char* node_type);

GONODES_API int gonodes_delete_node(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id);

GONODES_API int gonodes_connect(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* from_node, int from_port,
    const char* to_node, int to_port);

GONODES_API int gonodes_disconnect(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* from_node, int from_port,
    const char* to_node, int to_port);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Events                                                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API int gonodes_fire_event(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* event_name, const char* payload);


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output Resolution Override                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

GONODES_API int gonodes_set_output_resolution(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id, int width, int height);


#ifdef __cplusplus
}
#endif

#endif /* GONODES_HOST_H */

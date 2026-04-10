/*
 * gonodes_bootstrap.h — LibGodot initialization helpers.
 *
 * Wraps the LibGodot C API (godot_create / godot_iteration / godot_destroy)
 * and handles GPU context injection, project path resolution, and the
 * GDScript ↔ C bridge setup.
 */

#ifndef GONODES_BOOTSTRAP_H
#define GONODES_BOOTSTRAP_H

#include "gonodes_host.h"

/* Forward-declare LibGodot C API types (from gdextension_interface.h). */
typedef void* GDExtensionInstanceHandle;

/* Internal state for one GONODES engine instance. */
struct gonodes_instance_s {
    /* LibGodot engine handle. */
    GDExtensionInstanceHandle godot_handle;

    /* Rendering API in use. */
    int graphics_api;

    /* Whether this instance owns the GPU device (vs. sharing the host's). */
    int owns_gpu_device;

    /* Patch state. */
    int patch_loaded;
    char patch_path[4096];

    /* Auto-reload. */
    int   auto_reload_enabled;
    double auto_reload_interval;
    double auto_reload_timer;
    uint64_t patch_mtime;

    /* Cached JSON strings (freed on next call / destroy). */
    char* last_error;
    char* cached_nodes_json;
    char* cached_node_info_json;
    char* cached_params_json;
    char* cached_connections_json;
    char* cached_table_json;
    char* cached_param_value_json;
    char* cached_host_io_json;

    /* Callbacks. */
    gonodes_param_changed_fn on_param_changed;
    void* on_param_changed_userdata;
    gonodes_log_fn log_callback;
    void* log_callback_userdata;
    gonodes_event_fn on_event;
    void* on_event_userdata;

    /* Stats. */
    double last_cook_time_ms;
    int    last_cooked_count;
    int    frame_number;

    /* Transport state (Gap 6). */
    int    transport_state;     /* gonodes_transport_state enum value. */
    double transport_speed;     /* 1.0 = normal. */
    double transport_time;      /* Accumulated time in seconds. */

    /* Geometry cache (Gap 4). */
    gonodes_geometry_data_t cached_geometry;
    float* geo_positions_buf;   /* Owned buffer for positions. */
    float* geo_normals_buf;     /* Owned buffer for normals. */
    float* geo_uvs_buf;         /* Owned buffer for UVs. */
    float* geo_colors_buf;      /* Owned buffer for colors. */
    uint32_t* geo_indices_buf;  /* Owned buffer for indices. */

    /* Pixel readback buffer (Gap 9). */
    void*  pixel_readback_buf;
    int    pixel_readback_size;

    /* Texture info cache (Gap 2). */
    char* cached_texture_info_json;

    /* ── v1.2.0: Zero-copy staging ─────────────────────────────────────── */

    /* CHOP direct input: staged pointers valid for one cook frame. */
    struct {
        char node_id[256];
        const char** channel_names;
        const float** channel_data;
        const int*    sample_counts;
        int           num_channels;
    } staged_chop_inputs[16];    /* Max 16 concurrent HostInCHOP nodes. */
    int staged_chop_count;

    /* DAT direct input: staged pointer valid for one cook frame. */
    struct {
        char node_id[256];
        const char* json_data;
        int length;
    } staged_dat_inputs[16];
    int staged_dat_count;

    /* SOP direct input: staged pointers valid for one cook frame. */
    struct {
        char node_id[256];
        const float* positions;
        const float* normals;
        const float* uvs;
        const float* colors;
        int vertex_count;
        const uint32_t* indices;
        int index_count;
    } staged_sop_inputs[16];
    int staged_sop_count;

    /* VOL GPU input: staged handle valid for one cook frame. */
    struct {
        char node_id[256];
        uint64_t texture_handle;
        int width, height, depth, channels;
        char field_name[64];
    } staged_vol_gpu_inputs[16];
    int staged_vol_gpu_count;

    /* POP GPU input: staged handle valid for one cook frame. */
    struct {
        char node_id[256];
        uint64_t buffer_handle;
        int particle_count;
        int stride;
        int buffer_size;
    } staged_pop_gpu_inputs[16];
    int staged_pop_gpu_count;

    /* VOL GPU output cache. */
    gonodes_volume_gpu_handle_t cached_vol_gpu;

    /* POP GPU output cache. */
    gonodes_particle_gpu_handle_t cached_pop_gpu;

    /* CHOP direct output cache. */
    gonodes_chop_data_t cached_chop_direct;
    gonodes_channel_info_t* cached_chop_channels;   /* Heap-allocated array. */
    int cached_chop_channels_capacity;
};

/* ── Internal helpers (not part of public API) ────────────────────────────── */

/**
 * Initialize LibGodot with optional shared GPU context.
 * Returns a godot engine handle, or NULL on failure.
 */
GDExtensionInstanceHandle gn_bootstrap_init(
    const char* project_path,
    const gonodes_gpu_context_t* gpu
);

/**
 * Run one engine iteration (process + render).
 */
void gn_bootstrap_iteration(GDExtensionInstanceHandle handle, double delta);

/**
 * Shut down LibGodot and free the engine handle.
 */
void gn_bootstrap_shutdown(GDExtensionInstanceHandle handle);

/**
 * Free a cached JSON string and set the pointer to NULL.
 */
void gn_free_cached(char** ptr);

/**
 * Duplicate a string into a malloc'd buffer (for cached JSON).
 */
char* gn_strdup(const char* src);

/**
 * Set the last error message on an instance.
 */
void gn_set_error(gonodes_instance_s* inst, const char* msg);

/**
 * Get the modification time of a file (for auto-reload).
 * Returns 0 if the file doesn't exist.
 */
uint64_t gn_file_mtime(const char* path);

#endif /* GONODES_BOOTSTRAP_H */

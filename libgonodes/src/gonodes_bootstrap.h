/*
 * gonodes_bootstrap.h — Internal structs for libgonodes v2.5.
 *
 * Two struct tiers:
 *   gonodes_patch_s   — per-loaded-patch state (network, I/O, caches)
 *   gonodes_instance_s — global engine state (LibGodot, GPU, patch list)
 */

#ifndef GONODES_BOOTSTRAP_H
#define GONODES_BOOTSTRAP_H

#include "gonodes_host.h"

#include <atomic>

typedef void* GDExtensionInstanceHandle;

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Per-Patch State                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

#define GONODES_MAX_STAGED 16

/** State for one loaded patch.  Each patch has its own cook engine,
 *  node graph, I/O registries, transport, and caches. */
struct gonodes_patch_s {
    /* ── Identity ────────────────────────────────────────────────────── */
    int    id;                      /* Unique ID (1-based, never reused within an instance). */
    int    loaded;                  /* 1 if actively loaded. */
    char   path[4096];              /* Absolute path to .gnpatch file. */

    /* ── Auto-reload ─────────────────────────────────────────────────── */
    int    auto_reload_enabled;
    double auto_reload_interval;
    double auto_reload_timer;
    uint64_t mtime;

    /* ── Transport ───────────────────────────────────────────────────── */
    int    transport_state;
    double transport_speed;
    double transport_time;

    /* ── Stats ───────────────────────────────────────────────────────── */
    double last_cook_time_ms;
    int    last_cooked_count;
    int    frame_number;

    /* ── Cached JSON strings (freed on next call or destroy) ─────────── */
    char* cached_nodes_json;
    char* cached_node_info_json;
    char* cached_params_json;
    char* cached_connections_json;
    char* cached_table_json;
    char* cached_param_value_json;
    char* cached_host_io_json;
    char* cached_texture_info_json;

    /* ── Output response slots (populated by GNEmbeddedHost each frame) ── */

    /** Per-node texture output: "handle,width,height" keyed by node_id hash.
     *  GNEmbeddedHost writes these after _collect_outputs(). */
    #define GONODES_MAX_OUTPUT_SLOTS 64

    struct {
        char node_id[256];
        uint64_t handle;
        int width, height, format, channels, graphics_api;
    } tex_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int tex_output_count;

    struct {
        char node_id[256];
        char channel_name[128];
        float samples[4096];    /* Max 4096 samples per channel per output. */
        int sample_count;
    } chop_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int chop_output_count;

    struct {
        char node_id[256];
        char* json_data;        /* Heap-allocated, freed on update/destroy. */
    } dat_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int dat_output_count;

    struct {
        char node_id[256];
        char param_name[256];
        char* value_json;       /* Heap-allocated, freed on update/destroy. */
    } param_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int param_output_count;

    /* Readback request/response (synchronous, one at a time). */
    struct {
        int requested;          /* 1 = C side requested readback. */
        int completed;          /* 1 = GDScript filled the result. */
        char node_id[256];
        int format;
        int width, height;
        void* pixel_data;       /* Heap-allocated by GDScript side. */
        int pixel_data_size;
    } readback_slot;

    /* Geometry readback (synchronous). */
    struct {
        int requested;
        int completed;
        char node_id[256];
    } geo_request_slot;

    /* ── Geometry cache ──────────────────────────────────────────────── */
    gonodes_geometry_data_t cached_geometry;
    float* geo_positions_buf;
    float* geo_normals_buf;
    float* geo_uvs_buf;
    float* geo_colors_buf;
    uint32_t* geo_indices_buf;

    /* ── Pixel readback ──────────────────────────────────────────────── */
    void*  pixel_readback_buf;
    int    pixel_readback_size;

    /* ── GPU staging (input injection) ──────────────────────────────── */
    /* CPU data types (pixels, geometry, volume, particles, CHOP, DAT)
     * pass pointer addresses through the command queue — no staging. */

    struct { char node_id[256]; uint64_t texture_handle;
             int width, height, depth, channels;
             char field_name[64]; } staged_vol_gpu_inputs[GONODES_MAX_STAGED];
    int staged_vol_gpu_count;

    struct { char node_id[256]; uint64_t buffer_handle;
             int particle_count, stride, buffer_size;
           } staged_pop_gpu_inputs[GONODES_MAX_STAGED];
    int staged_pop_gpu_count;

    /* ── GPU output caches ───────────────────────────────────────────── */
    gonodes_volume_gpu_handle_t cached_vol_gpu;
    gonodes_particle_gpu_handle_t cached_pop_gpu;
    gonodes_chop_data_t cached_chop_direct;
    gonodes_channel_info_t* cached_chop_channels;
    int cached_chop_channels_capacity;
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Command Queue  — replaces env-var protocol                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Command types written by the C API and read by GNEmbeddedHost. */
enum gn_cmd_type {
    GN_CMD_NONE = 0,
    GN_CMD_LOAD_PATCH,
    GN_CMD_UNLOAD_PATCH,
    GN_CMD_RELOAD_PATCH,
    GN_CMD_SET_TEXTURE,
    GN_CMD_SET_CHOP,
    GN_CMD_SET_TABLE,
    GN_CMD_SET_PARAM,
    GN_CMD_SET_PIXELS,
    GN_CMD_SET_GEOMETRY,
    GN_CMD_SET_VOLUME,
    GN_CMD_SET_PARTICLES,
    GN_CMD_SET_TRANSPORT,
    GN_CMD_TRANSPORT_SEEK,
    GN_CMD_TRANSPORT_SPEED,
    GN_CMD_CREATE_NODE,
    GN_CMD_DELETE_NODE,
    GN_CMD_CONNECT,
    GN_CMD_DISCONNECT,
    GN_CMD_FIRE_EVENT,
    GN_CMD_MIDI_EVENT,
    GN_CMD_OSC_MESSAGE,
    GN_CMD_SET_RESOLUTION,
    /* Zero-copy: staged data is stored in the patch struct, not queued. */
};

/** A single command in the queue. */
struct gn_command {
    int type;           /* gn_cmd_type */
    int patch_id;       /* Which patch this targets (0 = instance-level). */
    char key[256];      /* node_id, param_name, event_name, etc. */
    char key2[256];     /* Second key (param_name, channel_name, etc.). */
    char data[8192];    /* Payload (path, JSON, csv, etc.). */
    int  ival[4];       /* Integer params (width, height, format, ...). */
    double dval;        /* Double param (speed, seek time, ...). */
    uint64_t uval;      /* uint64 param (texture handle, ...). */
};

#define GN_CMD_QUEUE_SIZE 256

/** Per-instance command queue — lock-free single-producer / single-consumer. */
struct gn_command_queue {
    gn_command commands[GN_CMD_QUEUE_SIZE];
    std::atomic<int> write_pos{0};  /* Next slot to write (C API side). */
    std::atomic<int> read_pos{0};   /* Next slot to read (GDScript side). */
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Per-Instance State                                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

#define GONODES_MAX_PATCHES 64

struct gonodes_instance_s {
    /* LibGodot engine handle. */
    GDExtensionInstanceHandle godot_handle;

    /* GPU config. */
    int graphics_api;
    int owns_gpu_device;

    /* Patch management — array of pointers (NULL = empty slot). */
    gonodes_patch_s* patches[GONODES_MAX_PATCHES];
    int patch_count;        /* Number of currently loaded patches. */
    int next_patch_id;      /* Monotonically increasing ID counter. */

    /* Command queue — written by C API, read by GNEmbeddedHost. */
    gn_command_queue cmd_queue;

    /* Instance-level state. */
    char* last_error;

    /* Staging buffer cleanup — owned buffers allocated by the C API for
     * stride-packed pixel copies, packed geometry, etc.  Freed after each
     * Godot iteration completes (pointer is only borrowed for one frame). */
    #define GONODES_MAX_STAGING_BUFS 128
    void* staging_bufs[GONODES_MAX_STAGING_BUFS];
    int staging_buf_count;

    /* Callbacks (instance-level, cover all patches). */
    gonodes_param_changed_fn on_param_changed;
    void* on_param_changed_userdata;
    gonodes_log_fn log_callback;
    void* log_callback_userdata;
    gonodes_event_fn on_event;
    void* on_event_userdata;
};


/* ── Internal helpers ──────────────────────────────────────────────────── */

GDExtensionInstanceHandle gn_bootstrap_init(
    const char* project_path, const gonodes_gpu_context_t* gpu);
void gn_bootstrap_iteration(GDExtensionInstanceHandle handle, double delta);
void gn_bootstrap_shutdown(GDExtensionInstanceHandle handle);

void gn_free_cached(char** ptr);
char* gn_strdup(const char* src);
void gn_set_error(gonodes_instance_s* inst, const char* msg);
uint64_t gn_file_mtime(const char* path);

/** Enqueue a command.  Returns 1 on success, 0 if queue is full. */
int gn_cmd_push(gonodes_instance_s* inst, const gn_command* cmd);

/** Find a patch by its opaque handle. Returns NULL if invalid. */
gonodes_patch_s* gn_find_patch(gonodes_instance_s* inst, gonodes_patch_t handle);

/** Bytes per pixel for a given format enum value. */
int gn_bytes_per_pixel(int format);

/** Track an owned staging buffer for cleanup after the frame. */
void gn_track_staging_buf(gonodes_instance_s* inst, void* buf);

/** Free all tracked staging buffers (called after godot_iteration). */
void gn_free_staging_bufs(gonodes_instance_s* inst);

/* ── Response slot helpers (called by GNEmbeddedHost via singleton) ────── */

/** Set a texture output slot for the given node. */
void gn_patch_set_tex_output(gonodes_patch_s* p, const char* node_id,
                             uint64_t handle, int w, int h, int fmt, int ch, int api);

/** Set a CHOP output slot (one channel). */
void gn_patch_set_chop_output(gonodes_patch_s* p, const char* node_id,
                              const char* channel_name,
                              const float* samples, int count);

/** Set a DAT output slot. */
void gn_patch_set_dat_output(gonodes_patch_s* p, const char* node_id,
                             const char* json_data);

/** Set a parameter value output slot. */
void gn_patch_set_param_output(gonodes_patch_s* p, const char* node_id,
                               const char* param_name, const char* value_json);

/** Set introspection JSON strings. */
void gn_patch_set_nodes_json(gonodes_patch_s* p, const char* json);
void gn_patch_set_connections_json(gonodes_patch_s* p, const char* json);
void gn_patch_set_node_info_json(gonodes_patch_s* p, const char* node_id, const char* json);
void gn_patch_set_params_json(gonodes_patch_s* p, const char* node_id, const char* json);
void gn_patch_set_host_io_json(gonodes_patch_s* p, const char* json);

/** Set cook stats. */
void gn_patch_set_stats(gonodes_patch_s* p, double cook_ms, int node_count);

/** Set transport time (read back from cook engine). */
void gn_patch_set_transport_time(gonodes_patch_s* p, double time);

/** Set the active instance and write the pointer address to
 *  GONODES_BRIDGE_INSTANCE_PTR env var (one-time init).
 *  Called from gonodes_create() after instance allocation. */
void gn_set_active_instance(gonodes_instance_s* inst);

#endif /* GONODES_BOOTSTRAP_H */

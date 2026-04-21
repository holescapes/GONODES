/*
 * gn_bridge_structs.h — Minimal struct layout mirroring gonodes_bootstrap.h.
 *
 * These definitions MUST match the layout in libgonodes/src/gonodes_bootstrap.h.
 * GNHostBridge uses them to read the command queue and write response slots
 * directly, eliminating the per-frame env-var bridge layer.
 *
 * Only the fields that GNHostBridge actually accesses are included.
 * The full struct has additional fields (GPU staging, geometry cache, etc.)
 * that are laid out AFTER the fields declared here — but since we access
 * by pointer through the real struct, the padding/offset is correct as long
 * as the leading fields match exactly.
 *
 * IMPORTANT: If gonodes_bootstrap.h changes, update this file to match.
 */

#ifndef GN_BRIDGE_STRUCTS_H
#define GN_BRIDGE_STRUCTS_H

#include <cstdint>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Command Queue (read by drain_commands)                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

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
};

struct gn_command {
    int type;
    int patch_id;
    char key[256];
    char key2[256];
    char data[8192];
    int  ival[4];
    double dval;
    uint64_t uval;
};

#define GN_CMD_QUEUE_SIZE 256

struct gn_command_queue {
    gn_command commands[GN_CMD_QUEUE_SIZE];
    volatile int write_pos;
    volatile int read_pos;
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Per-Patch Response Slots (written by set_*_output)                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

#define GONODES_MAX_OUTPUT_SLOTS 64
#define GONODES_MAX_STAGED 16

struct gonodes_patch_s {
    /* ── Identity ────────────────────────────────────────────────────── */
    int    id;
    int    loaded;
    char   path[4096];

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

    /* ── Cached JSON strings ─────────────────────────────────────────── */
    char* cached_nodes_json;
    char* cached_node_info_json;
    char* cached_params_json;
    char* cached_connections_json;
    char* cached_table_json;
    char* cached_param_value_json;
    char* cached_host_io_json;
    char* cached_texture_info_json;

    /* ── Output response slots ───────────────────────────────────────── */

    struct {
        char node_id[256];
        uint64_t handle;
        int width, height, format, channels, graphics_api;
    } tex_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int tex_output_count;

    struct {
        char node_id[256];
        char channel_name[128];
        float samples[4096];
        int sample_count;
    } chop_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int chop_output_count;

    struct {
        char node_id[256];
        char* json_data;
    } dat_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int dat_output_count;

    struct {
        char node_id[256];
        char param_name[256];
        char* value_json;
    } param_outputs[GONODES_MAX_OUTPUT_SLOTS];
    int param_output_count;

    /* ── Readback slots ──────────────────────────────────────────────── */
    struct {
        int requested;
        int completed;
        char node_id[256];
        int format;
        int width, height;
        void* pixel_data;
        int pixel_data_size;
    } readback_slot;

    struct {
        int requested;
        int completed;
        char node_id[256];
    } geo_request_slot;

    /* We don't access fields beyond this point from GNHostBridge.
     * The real struct has geometry cache, pixel readback, GPU staging,
     * etc. after this, but we never touch them. */
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Per-Instance State (top-level struct)                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef void* GDExtensionInstanceHandle;

#define GONODES_MAX_PATCHES 64
#define GONODES_MAX_STAGING_BUFS 128

/* Forward-declare callback types to match layout. */
typedef void (*gonodes_param_changed_fn)(void*, int, const char*, const char*, const char*);
typedef void (*gonodes_log_fn)(void*, int, const char*);
typedef void (*gonodes_event_fn)(void*, int, const char*, const char*);

struct gonodes_instance_s {
    GDExtensionInstanceHandle godot_handle;

    int graphics_api;
    int owns_gpu_device;

    gonodes_patch_s* patches[GONODES_MAX_PATCHES];
    int patch_count;
    int next_patch_id;

    gn_command_queue cmd_queue;

    char* last_error;

    void* staging_bufs[GONODES_MAX_STAGING_BUFS];
    int staging_buf_count;

    gonodes_param_changed_fn on_param_changed;
    void* on_param_changed_userdata;
    gonodes_log_fn log_callback;
    void* log_callback_userdata;
    gonodes_event_fn on_event;
    void* on_event_userdata;
};

#endif /* GN_BRIDGE_STRUCTS_H */

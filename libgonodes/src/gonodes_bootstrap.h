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

    /* Callbacks. */
    gonodes_param_changed_fn on_param_changed;
    void* on_param_changed_userdata;
    gonodes_log_fn log_callback;
    void* log_callback_userdata;

    /* Stats. */
    double last_cook_time_ms;
    int    last_cooked_count;
    int    frame_number;
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

/*
 * GONODES Host API — C interface for embedding GONODES in host applications.
 *
 * Link against libgonodes (.dll / .dylib / .so) and include this header.
 * All functions are thread-safe: calls are marshalled to the engine's main
 * thread internally.  gonodes_cook_frame() must be called regularly from the
 * host's render/update loop.
 *
 * Minimal usage:
 *
 *     gonodes_gpu_context_t gpu = {0};
 *     gpu.graphics_api = GONODES_GFX_VULKAN;
 *     gpu.vulkan_instance        = my_vk_instance;
 *     gpu.vulkan_physical_device = my_vk_phys_dev;
 *     gpu.vulkan_device          = my_vk_device;
 *
 *     gonodes_instance_t gn = gonodes_create("path/to/project", &gpu);
 *     gonodes_load_patch(gn, "path/to/show.gnpatch");
 *
 *     // In your frame loop:
 *     gonodes_cook_frame(gn, delta_seconds);
 *     uint64_t tex = gonodes_get_output_texture(gn, "main_out", &w, &h);
 *     // 'tex' is a VkImage / GLuint / MTLTexture* on the shared device.
 *
 *     gonodes_destroy(gn);
 *
 * Copyright (c) 2026 GONODES contributors.  MIT License.
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

#define GONODES_API_VERSION_MAJOR 1
#define GONODES_API_VERSION_MINOR 0
#define GONODES_API_VERSION_PATCH 0

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Export / Import macros                                                   */
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

/** Opaque handle to a GONODES engine instance. */
typedef struct gonodes_instance_s* gonodes_instance_t;

/** Graphics API selector. */
enum gonodes_graphics_api {
    GONODES_GFX_AUTO   = 0,  /**< Let LibGodot choose (Vulkan > Metal > GL). */
    GONODES_GFX_VULKAN = 1,  /**< Vulkan (Forward+ renderer).               */
    GONODES_GFX_METAL  = 2,  /**< Metal (Forward+ on macOS).                */
    GONODES_GFX_OPENGL = 3,  /**< OpenGL 3.3+ (Compatibility renderer).     */
};

/** Texture pixel format hint (matches common GPU formats). */
enum gonodes_texture_format {
    GONODES_FORMAT_RGBA8   = 0,  /**< 8-bit RGBA (sRGB).      */
    GONODES_FORMAT_RGBA16F = 1,  /**< 16-bit float RGBA (HDR). */
    GONODES_FORMAT_RGBA32F = 2,  /**< 32-bit float RGBA.       */
    GONODES_FORMAT_R8      = 3,  /**< Single channel 8-bit.    */
    GONODES_FORMAT_RG8     = 4,  /**< Dual channel 8-bit.      */
};

/** Error codes returned by API functions. */
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
    GONODES_ERR_INTERNAL        = -99,
};

/**
 * GPU context descriptor.
 *
 * The host fills in the fields for its active graphics API.  Fields for
 * unused APIs must be NULL / 0.  If the entire struct is zeroed (or a NULL
 * pointer is passed to gonodes_create), LibGodot creates its own device.
 *
 * When a device is shared, GONODES renders on the same device and all
 * texture handles returned by gonodes_get_output_texture() are directly
 * usable by the host — zero-copy.
 */
typedef struct gonodes_gpu_context {
    /* Vulkan (set all three, or leave all NULL) */
    void* vulkan_instance;          /**< VkInstance              */
    void* vulkan_physical_device;   /**< VkPhysicalDevice        */
    void* vulkan_device;            /**< VkDevice                */
    void* vulkan_queue;             /**< VkQueue (graphics queue) — optional, can be NULL */
    uint32_t vulkan_queue_family;   /**< Queue family index       */

    /* Metal (macOS / iOS) */
    void* metal_device;             /**< id<MTLDevice>           */
    void* metal_command_queue;      /**< id<MTLCommandQueue> — optional */

    /* OpenGL */
    void* gl_context;               /**< Platform-specific GL context handle:
                                         Windows: HGLRC
                                         macOS:   NSOpenGLContext*
                                         Linux:   EGLContext or GLXContext */

    /* Which graphics API the host is providing. */
    int graphics_api;               /**< One of gonodes_graphics_api values. */
} gonodes_gpu_context_t;

/**
 * Callback for parameter change notifications.
 * Fired when an expression, script, or CHOP export modifies a parameter.
 *
 * @param inst       The GONODES instance.
 * @param node_id    The node whose parameter changed.
 * @param param_name The parameter name.
 * @param value_json JSON-encoded new value.
 * @param user_data  Opaque pointer passed during registration.
 */
typedef void (*gonodes_param_changed_fn)(
    gonodes_instance_t inst,
    const char* node_id,
    const char* param_name,
    const char* value_json,
    void* user_data
);

/**
 * Callback for log/error messages from the engine.
 *
 * @param level      0=debug, 1=info, 2=warn, 3=error.
 * @param category   Logger category string (e.g., "CookEngine", "Network").
 * @param message    The log message.
 * @param user_data  Opaque pointer passed during registration.
 */
typedef void (*gonodes_log_fn)(
    int level,
    const char* category,
    const char* message,
    void* user_data
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Lifecycle                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Create a GONODES engine instance.
 *
 * Boots LibGodot, initializes the rendering device (shared with host if
 * gpu_context is provided), loads the GONODES project, and prepares the
 * cook engine.
 *
 * @param project_path  Path to the GONODES project directory (contains
 *                      project.godot, addons/gonodes/, etc.).
 * @param gpu_context   GPU context to share with the host.  Pass NULL to
 *                      let LibGodot create its own device.
 * @return              Engine instance handle, or NULL on failure.
 */
GONODES_API gonodes_instance_t gonodes_create(
    const char* project_path,
    const gonodes_gpu_context_t* gpu_context
);

/**
 * Destroy a GONODES engine instance and release all resources.
 * The handle is invalid after this call.
 */
GONODES_API void gonodes_destroy(gonodes_instance_t inst);

/**
 * Query the API version of the loaded library.
 */
GONODES_API void gonodes_get_version(int* major, int* minor, int* patch);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Patch Management                                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Load a .gnpatch file into the engine.  Unloads any previously loaded patch.
 *
 * @return GONODES_OK on success, or an error code.
 */
GONODES_API int gonodes_load_patch(gonodes_instance_t inst, const char* patch_path);

/**
 * Unload the current patch, releasing all operator resources.
 */
GONODES_API void gonodes_unload_patch(gonodes_instance_t inst);

/**
 * Reload the current patch from disk.  Attempts to preserve runtime state
 * (CHOP channel values, timer positions, feedback textures) across the
 * reload.  Only graph topology is reconstituted.
 *
 * @return GONODES_OK on success, or an error code.
 */
GONODES_API int gonodes_reload_patch(gonodes_instance_t inst);

/**
 * Enable or disable file-watching on the loaded patch.  When enabled,
 * the engine polls the .gnpatch file and auto-reloads on change.
 *
 * @param enable    1 to enable, 0 to disable.
 * @param interval  Poll interval in seconds (default: 0.5).
 */
GONODES_API void gonodes_set_auto_reload(gonodes_instance_t inst,
                                          int enable, double interval);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Frame Loop                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Cook one frame.  The host must call this regularly (typically once per
 * render frame).  All queued input injections are flushed, the cook engine
 * runs one topological pass, and output textures/data are updated.
 *
 * @param delta_seconds  Time elapsed since last cook (seconds).  Pass 0
 *                       on the first frame.
 */
GONODES_API void gonodes_cook_frame(gonodes_instance_t inst, double delta_seconds);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Input Injection  (host → GONODES)                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Push a texture into a HostInTOP node.
 *
 * The texture_handle is API-specific:
 *   - Vulkan: cast of VkImage
 *   - Metal:  cast of id<MTLTexture>
 *   - OpenGL: GLuint texture name
 *
 * When the host's GPU context is shared, this is zero-copy — the engine
 * wraps the handle directly.  Otherwise a CPU readback + upload occurs.
 *
 * @param node_id         ID of a HostInTOP node in the patch.
 * @param texture_handle  API-specific texture handle.
 * @param width           Texture width in pixels.
 * @param height          Texture height in pixels.
 * @param format          One of gonodes_texture_format values.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_texture(
    gonodes_instance_t inst,
    const char* node_id,
    uint64_t texture_handle,
    int width, int height,
    int format
);

/**
 * Push channel data into a HostInCHOP node.
 *
 * @param node_id       ID of a HostInCHOP node.
 * @param channel_name  Name of the channel (e.g., "tx", "lfo", "cc1").
 * @param samples       Array of float samples.
 * @param num_samples   Number of samples in the array.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_chop(
    gonodes_instance_t inst,
    const char* node_id,
    const char* channel_name,
    const float* samples,
    int num_samples
);

/**
 * Push table/text data into a HostInDAT node.
 *
 * @param node_id    ID of a HostInDAT node.
 * @param json_data  JSON string: either a 2D array (table mode) or a plain
 *                   string (text mode).
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_table(
    gonodes_instance_t inst,
    const char* node_id,
    const char* json_data
);

/**
 * Set a parameter value on any node.
 *
 * @param node_id     Node ID.
 * @param param_name  Parameter name.
 * @param value_json  JSON-encoded value.  Type must match the parameter:
 *                    float: "3.14"
 *                    int:   "42"
 *                    bool:  "true"
 *                    string: "\"hello\""
 *                    color: "[1.0, 0.5, 0.0, 1.0]"
 *                    vec2:  "[100, 200]"
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_parameter(
    gonodes_instance_t inst,
    const char* node_id,
    const char* param_name,
    const char* value_json
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output Reading  (GONODES → host)                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Get the output texture from any TOP or HostOutTOP node.
 *
 * Returns an API-specific texture handle (VkImage / GLuint / MTLTexture*).
 * The texture is valid until the next gonodes_cook_frame() call.
 *
 * @param node_id   Node ID (must be a TOP-family or HostOutTOP node).
 * @param out_width   [out] Texture width.
 * @param out_height  [out] Texture height.
 * @return Texture handle (0 if not available or node not found).
 */
GONODES_API uint64_t gonodes_get_output_texture(
    gonodes_instance_t inst,
    const char* node_id,
    int* out_width, int* out_height
);

/**
 * Read channel data from any CHOP or HostOutCHOP node.
 *
 * @param node_id        Node ID.
 * @param channel_name   Channel name (e.g. "out", "tx").
 * @param out_buffer     [out] Buffer to fill with float samples.
 * @param buffer_size    Size of out_buffer in floats.
 * @return Number of samples written, or a negative error code.
 */
GONODES_API int gonodes_get_output_chop(
    gonodes_instance_t inst,
    const char* node_id,
    const char* channel_name,
    float* out_buffer,
    int buffer_size
);

/**
 * Read table data from any DAT or HostOutDAT node.
 *
 * @param node_id  Node ID.
 * @return JSON string (2D array for table, plain string for text).
 *         The pointer is valid until the next gonodes_cook_frame() call.
 *         Returns NULL if the node is not found.
 */
GONODES_API const char* gonodes_get_output_table(
    gonodes_instance_t inst,
    const char* node_id
);

/**
 * Read a parameter's current value from any node.
 *
 * @param node_id     Node ID.
 * @param param_name  Parameter name.
 * @return JSON-encoded value string.  Valid until next cook frame.
 *         Returns NULL if not found.
 */
GONODES_API const char* gonodes_get_parameter(
    gonodes_instance_t inst,
    const char* node_id,
    const char* param_name
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Introspection                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * List all nodes in the current patch.
 *
 * @return JSON array of objects:
 *         [{"id":"noise1", "type":"noisetop", "family":"TOP"}, ...]
 *         Valid until next cook frame.  NULL if no patch loaded.
 */
GONODES_API const char* gonodes_list_nodes(gonodes_instance_t inst);

/**
 * Get detailed info about a node.
 *
 * @return JSON object: {"id", "type", "family", "inputs":[...],
 *         "outputs":[...], "parameters":[...], "cook_time_ms", "active"}
 *         NULL if not found.
 */
GONODES_API const char* gonodes_get_node_info(
    gonodes_instance_t inst,
    const char* node_id
);

/**
 * List all parameters on a node.
 *
 * @return JSON array: [{"name":"scale", "type":"float", "value":1.0,
 *         "min":0, "max":10, "description":"..."}, ...]
 *         NULL if node not found.
 */
GONODES_API const char* gonodes_list_parameters(
    gonodes_instance_t inst,
    const char* node_id
);

/**
 * List all connections in the current patch.
 *
 * @return JSON array: [{"from":"noise1","from_port":0,"to":"comp1","to_port":0}, ...]
 */
GONODES_API const char* gonodes_list_connections(gonodes_instance_t inst);

/**
 * Get the Host I/O manifest for the loaded patch.
 *
 * Returns a JSON object describing the patch's standardized interface:
 * - "inputs":  array of {label, family, node, required} for HostIn* nodes
 * - "outputs": array of {label, family, node} for HostOut* nodes
 * - "parameters": array of {label, node, param, type, range} for exposed controls
 *
 * If the patch author didn't write a manifest, one is auto-generated from
 * any HostIn/HostOut bridge operators in the network.
 *
 * Host apps use this to auto-create UI bindings, texture slots, and
 * audio routing.  The same patch works across all host applications.
 *
 * @return JSON string.  "{}" if no patch is loaded or no bridge ops found.
 *         Valid until next cook frame or patch load.
 *
 * Example:
 * @code
 *     const char* io = gonodes_get_host_io(gn);
 *     // Parse JSON → discover 2 texture inputs, 1 CHOP output, etc.
 * @endcode
 */
GONODES_API const char* gonodes_get_host_io(gonodes_instance_t inst);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Callbacks                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Register a callback for parameter change notifications.
 * Pass NULL to unregister.
 */
GONODES_API void gonodes_set_on_param_changed(
    gonodes_instance_t inst,
    gonodes_param_changed_fn callback,
    void* user_data
);

/**
 * Register a log callback.  GONODES routes all engine log messages
 * through this callback instead of printing to stdout.
 * Pass NULL to unregister (reverts to stdout).
 */
GONODES_API void gonodes_set_log_callback(
    gonodes_instance_t inst,
    gonodes_log_fn callback,
    void* user_data
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Utilities                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Get the last error message (human-readable).
 * The pointer is valid until the next API call on the same instance.
 */
GONODES_API const char* gonodes_get_last_error(gonodes_instance_t inst);

/**
 * Get cook performance stats for the last frame.
 *
 * @param out_cook_time_ms  [out] Total cook time in milliseconds.
 * @param out_node_count    [out] Number of nodes cooked.
 * @param out_frame_number  [out] Current frame number.
 */
GONODES_API void gonodes_get_stats(
    gonodes_instance_t inst,
    double* out_cook_time_ms,
    int* out_node_count,
    int* out_frame_number
);

#ifdef __cplusplus
}
#endif

#endif /* GONODES_HOST_H */

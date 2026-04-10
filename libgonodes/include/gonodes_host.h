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
#define GONODES_API_VERSION_MINOR 2
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
    GONODES_FORMAT_BGRA8   = 5,  /**< 8-bit BGRA (common on Metal/DX). */
    GONODES_FORMAT_R16F    = 6,  /**< Single channel 16-bit float.     */
    GONODES_FORMAT_RG16F   = 7,  /**< Dual channel 16-bit float.       */
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
    GONODES_ERR_MAX_INSTANCES    = -9,  /**< Instance limit reached (multi-instance). */
    GONODES_ERR_UNSUPPORTED      = -10, /**< Feature not available on this platform/build. */
    GONODES_ERR_TYPE_MISMATCH    = -11, /**< Node family doesn't match the operation. */
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

/**
 * Texture info descriptor returned by gonodes_get_texture_info().
 * Gives the host full metadata about an output texture.
 */
typedef struct gonodes_texture_info {
    int width;                      /**< Width in pixels.         */
    int height;                     /**< Height in pixels.        */
    int format;                     /**< One of gonodes_texture_format. */
    int channels;                   /**< Number of channels (1-4). */
    uint64_t native_handle;         /**< API-specific handle (VkImage/GLuint/MTLTexture*). */
    int graphics_api;               /**< Which API the handle belongs to. */
} gonodes_texture_info_t;

/**
 * Geometry buffer descriptor returned by gonodes_get_output_geometry().
 * Provides raw vertex data for SOP/COMP geometry exchange.
 *
 * All pointers are valid until the next gonodes_cook_frame() call.
 * The host must NOT free these pointers.
 */
typedef struct gonodes_geometry_data {
    const float* positions;         /**< Interleaved xyz positions (3 floats per vertex). */
    const float* normals;           /**< Interleaved xyz normals (3 floats per vertex, or NULL). */
    const float* uvs;               /**< Interleaved uv coords (2 floats per vertex, or NULL). */
    const float* colors;            /**< Interleaved rgba colors (4 floats per vertex, or NULL). */
    int vertex_count;               /**< Number of vertices. */
    const uint32_t* indices;        /**< Triangle index buffer (or NULL for non-indexed). */
    int index_count;                /**< Number of indices (0 if non-indexed). */
    int primitive_type;             /**< 0=triangles, 1=lines, 2=points. */
} gonodes_geometry_data_t;

/**
 * Volume data descriptor for VOL family exchange.
 * Provides raw 3D voxel grids between host and engine.
 *
 * All pointers are valid until the next gonodes_cook_frame() call.
 * The host must NOT free these pointers.
 */
typedef struct gonodes_volume_data {
    const float* voxels;            /**< Flat voxel data (channels-interleaved). */
    int width;                      /**< X resolution in voxels.  */
    int height;                     /**< Y resolution in voxels.  */
    int depth;                      /**< Z resolution in voxels.  */
    int channels;                   /**< Channels per voxel (1 for density, 4 for RGBA). */
    const char* field_name;         /**< Semantic label ("density", "velocity", "temperature"). */
} gonodes_volume_data_t;

/**
 * Particle data descriptor for POP family exchange.
 * Provides per-particle attribute arrays between host and engine.
 *
 * All pointers are valid until the next gonodes_cook_frame() call.
 * The host must NOT free these pointers.
 */
typedef struct gonodes_particle_data {
    const float* positions;         /**< Interleaved xyz positions (3 floats per particle). */
    const float* velocities;        /**< Interleaved xyz velocities (3 per particle, or NULL). */
    const float* colors;            /**< Interleaved rgba colors (4 per particle, or NULL). */
    const float* ages;              /**< Per-particle age in seconds (or NULL). */
    int particle_count;             /**< Number of particles. */
} gonodes_particle_data_t;

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy Data Descriptors                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * GPU volume handle for zero-copy VOL exchange (v1.2.0).
 *
 * When the host shares its GPU context, volumes can be exchanged as native
 * 3D texture handles — no CPU readback/upload at the boundary.
 * Falls back to the CPU float* path (gonodes_volume_data_t) when contexts
 * are not shared or the host prefers CPU access.
 */
typedef struct gonodes_volume_gpu_handle {
    uint64_t native_handle;         /**< VkImage (3D) / GLuint / MTLTexture* (3D). */
    int width;                      /**< X resolution in voxels. */
    int height;                     /**< Y resolution in voxels. */
    int depth;                      /**< Z resolution in voxels. */
    int channels;                   /**< 1=density (R32F), 4=RGBA (R32G32B32A32F). */
    int format;                     /**< RenderingDevice format enum value. */
    int graphics_api;               /**< Which API the handle belongs to. */
} gonodes_volume_gpu_handle_t;

/**
 * GPU particle buffer handle for zero-copy POP exchange (v1.2.0).
 *
 * When the host shares its GPU context, particle data lives in a single
 * SSBO (Storage Buffer Object) with a fixed 64-byte stride per particle:
 *
 *   offset  0: vec4 position  (xyz, w=0)
 *   offset 16: vec4 velocity  (xyz, w=0)
 *   offset 32: vec4 color     (rgba)
 *   offset 48: float age, float life, float mass, float pscale
 *
 * The host can bind this buffer directly as a VkBuffer / GLuint SSBO /
 * MTLBuffer for compute or rendering — no readback needed.
 */
typedef struct gonodes_particle_gpu_handle {
    uint64_t native_handle;         /**< VkBuffer / GLuint (SSBO name) / MTLBuffer*. */
    int particle_count;             /**< Number of active particles. */
    int stride;                     /**< Bytes per particle (64 for standard layout). */
    int buffer_size;                /**< Total buffer size in bytes. */
    int graphics_api;               /**< Which API the handle belongs to. */
} gonodes_particle_gpu_handle_t;

/**
 * Channel data for zero-copy CHOP exchange (v1.2.0).
 *
 * Replaces the string-encoded env-var transport with direct float* pointers.
 * The samples array is valid until the next gonodes_cook_frame() call.
 * The host must NOT free the pointer.
 */
typedef struct gonodes_channel_info {
    const char* name;               /**< Channel name (e.g. "tx", "lfo"). */
    const float* samples;           /**< Sample data array. */
    int num_samples;                /**< Number of samples in this channel. */
} gonodes_channel_info_t;

/**
 * Multi-channel CHOP data returned by gonodes_get_output_chop_all() (v1.2.0).
 *
 * All pointers are valid until the next gonodes_cook_frame() call.
 */
typedef struct gonodes_chop_data {
    const gonodes_channel_info_t* channels;  /**< Array of channel descriptors. */
    int channel_count;                        /**< Number of channels. */
    float sample_rate;                        /**< Sample rate in Hz. */
} gonodes_chop_data_t;

/**
 * Transport state for timeline/playback control.
 */
enum gonodes_transport_state {
    GONODES_TRANSPORT_PLAY    = 0,  /**< Normal playback.        */
    GONODES_TRANSPORT_PAUSE   = 1,  /**< Paused (time frozen).   */
    GONODES_TRANSPORT_STOP    = 2,  /**< Stopped (reset to 0).   */
};

/**
 * MIDI event descriptor for gonodes_send_midi_event().
 */
typedef struct gonodes_midi_event {
    int status;                     /**< MIDI status byte (0x80-0xFF). */
    int data1;                      /**< First data byte (0-127).     */
    int data2;                      /**< Second data byte (0-127).    */
    int channel;                    /**< MIDI channel (0-15).         */
    int port;                       /**< Virtual port index (0 = default). */
} gonodes_midi_event_t;

/**
 * Callback for event/trigger notifications from the patch.
 *
 * @param inst       The GONODES instance.
 * @param event_name Named event from a HostOutEvent trigger.
 * @param payload    JSON-encoded payload (or NULL for simple triggers).
 * @param user_data  Opaque pointer passed during registration.
 */
typedef void (*gonodes_event_fn)(
    gonodes_instance_t inst,
    const char* event_name,
    const char* payload,
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

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Texture Info & Format Negotiation  (Gap 2)                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Query full metadata about an output texture.
 *
 * Unlike gonodes_get_output_texture() which only returns the handle + size,
 * this function returns format, channel count, and graphics API information —
 * enabling the host to negotiate texture compatibility (like TouchEngine's
 * TEInstanceGetTextureDescription or VUO/FxPlug supportedFormats).
 *
 * @param node_id  Node ID (must be a TOP-family or HostOutTOP).
 * @param out_info [out] Filled with texture metadata.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_get_texture_info(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_texture_info_t* out_info
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  CPU Pixel Input  (Gap 3)                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Push raw CPU pixel data into a HostInTOP node.
 *
 * This is the non-GPU alternative to gonodes_set_input_texture().  The host
 * provides a CPU byte buffer and GONODES uploads it to the GPU internally.
 * Useful when the host doesn't have a shared GPU context or the source
 * data comes from a camera capture / file decode on the CPU side.
 *
 * Comparable to TouchEngine's CPU texture path and VUO's
 * VuoImage_makeFromBuffer().
 *
 * @param node_id    ID of a HostInTOP node.
 * @param pixels     Pointer to pixel data (row-major, top-to-bottom).
 * @param width      Image width in pixels.
 * @param height     Image height in pixels.
 * @param format     Pixel format (one of gonodes_texture_format).
 * @param row_stride Bytes per row (0 = tightly packed, i.e. width × bpp).
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_pixels(
    gonodes_instance_t inst,
    const char* node_id,
    const void* pixels,
    int width, int height,
    int format,
    int row_stride
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  CPU Pixel Readback  (Gap 9)                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Read an output texture's pixels into a CPU buffer.
 *
 * Performs a GPU→CPU readback of the texture from any TOP or HostOutTOP.
 * The host provides a pre-allocated buffer; the function copies pixel data
 * into it in the requested format.
 *
 * Comparable to TouchEngine's CPU readback path and VUO's
 * VuoImage_copyBuffer().
 *
 * @param node_id     Node ID (TOP-family or HostOutTOP).
 * @param out_pixels  [out] Pre-allocated buffer for pixel data.
 * @param buffer_size Size of out_pixels in bytes.
 * @param format      Desired pixel format (one of gonodes_texture_format).
 * @param out_width   [out] Actual texture width.
 * @param out_height  [out] Actual texture height.
 * @return Number of bytes written, or a negative error code.
 */
GONODES_API int gonodes_read_output_pixels(
    gonodes_instance_t inst,
    const char* node_id,
    void* out_pixels,
    int buffer_size,
    int format,
    int* out_width,
    int* out_height
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Geometry/SOP Exchange  (Gap 4)                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Read geometry data from any SOP or COMP node.
 *
 * Returns interleaved vertex buffers (positions, normals, UVs, colors) and
 * an optional index buffer.  Comparable to TouchEngine's geometry object
 * export and VUO's VuoMesh exchange.
 *
 * The returned pointer and all its internal pointers are valid until the
 * next gonodes_cook_frame() call.  The host must NOT free the pointer.
 *
 * @param node_id  Node ID (must be SOP-family or COMP with GNGeoData output).
 * @return Pointer to geometry data, or NULL if not available.
 */
GONODES_API const gonodes_geometry_data_t* gonodes_get_output_geometry(
    gonodes_instance_t inst,
    const char* node_id
);

/**
 * Push geometry data into a HostInSOP node.
 *
 * The host provides vertex buffers which are assembled into a GNGeoData
 * mesh inside the engine.
 *
 * @param node_id       ID of a HostInSOP node.
 * @param positions     Interleaved xyz positions (3 floats per vertex).
 * @param normals       Interleaved xyz normals (or NULL for auto-compute).
 * @param uvs           Interleaved uv coords (or NULL).
 * @param vertex_count  Number of vertices.
 * @param indices       Triangle index buffer (or NULL for non-indexed).
 * @param index_count   Number of indices.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_geometry(
    gonodes_instance_t inst,
    const char* node_id,
    const float* positions,
    const float* normals,
    const float* uvs,
    int vertex_count,
    const uint32_t* indices,
    int index_count
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Volume/VOL Exchange                                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Read volume data from a VOL-family node.
 *
 * Returns a 3D voxel grid (density, velocity, temperature, etc.).
 * Use cases: medical imaging hosts reading processed volumes, game engines
 * reading fluid simulation output, VJ tools reading volumetric effects.
 *
 * The returned pointer and its internal pointers are valid until the next
 * gonodes_cook_frame() call.  The host must NOT free the pointer.
 *
 * @param node_id  Node ID (must be VOL-family or HostOutVOL).
 * @return Pointer to volume data, or NULL if not available.
 */
GONODES_API const gonodes_volume_data_t* gonodes_get_output_volume(
    gonodes_instance_t inst,
    const char* node_id
);

/**
 * Push volume data into a HostInVOL node.
 *
 * The host provides a flat voxel array which is converted into a GPU 3D
 * texture inside the engine for downstream VOL operators.
 *
 * @param node_id       ID of a HostInVOL node.
 * @param voxels        Flat voxel data (width * height * depth * channels floats).
 * @param width         X resolution in voxels.
 * @param height        Y resolution in voxels.
 * @param depth         Z resolution in voxels.
 * @param channels      Channels per voxel (1 = scalar density, 4 = RGBA).
 * @param field_name    Semantic label (e.g. "density").  NULL defaults to "density".
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_volume(
    gonodes_instance_t inst,
    const char* node_id,
    const float* voxels,
    int width, int height, int depth,
    int channels,
    const char* field_name
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Particle/POP Exchange                                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Read particle data from a POP-family node or HostOutPOP.
 *
 * Returns per-particle attribute arrays (positions, velocities, colors, ages).
 * Use cases: game engines reading GONODES particle simulations, physics
 * engines exchanging point clouds, VJ tools visualizing particle effects.
 *
 * The returned pointer and its internal pointers are valid until the next
 * gonodes_cook_frame() call.  The host must NOT free the pointer.
 *
 * @param node_id  Node ID (must be POP-family or HostOutPOP).
 * @return Pointer to particle data, or NULL if not available.
 */
GONODES_API const gonodes_particle_data_t* gonodes_get_output_particles(
    gonodes_instance_t inst,
    const char* node_id
);

/**
 * Push particle data into a HostInPOP node.
 *
 * The host provides per-particle attribute arrays which are packed into a
 * GPU SSBO for downstream POP operators.
 *
 * @param node_id         ID of a HostInPOP node.
 * @param positions       Interleaved xyz positions (3 floats per particle).
 * @param velocities      Interleaved xyz velocities (or NULL).
 * @param colors          Interleaved rgba colors (or NULL).
 * @param ages            Per-particle age in seconds (or NULL).
 * @param particle_count  Number of particles.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_particles(
    gonodes_instance_t inst,
    const char* node_id,
    const float* positions,
    const float* velocities,
    const float* colors,
    const float* ages,
    int particle_count
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  MIDI & OSC Bridge Input  (Gap 5)                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Send a MIDI event into the engine.
 *
 * The event is routed to any MidiInCHOP operators in the patch, as if it
 * arrived from a physical MIDI device.  Comparable to VDMX's MIDI routing
 * to TouchDesigner layers and VUO's MIDI protocol nodes.
 *
 * @param inst   Engine instance.
 * @param event  MIDI event descriptor.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_send_midi_event(
    gonodes_instance_t inst,
    const gonodes_midi_event_t* event
);

/**
 * Send an OSC message into the engine.
 *
 * The message is routed to any OscInCHOP / OscInDAT operators in the patch.
 *
 * @param inst     Engine instance.
 * @param address  OSC address pattern (e.g. "/control/fader1").
 * @param args     JSON-encoded argument array (e.g. "[0.75]",
 *                 "[1, \"hello\", 3.14]").  NULL for no arguments.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_send_osc_message(
    gonodes_instance_t inst,
    const char* address,
    const char* args
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Timeline / Transport Control  (Gap 6)                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Set the playback transport state.
 *
 * Controls the engine's internal time base — play, pause, or stop.
 * Comparable to TouchEngine's timeline transport and VUO's composition
 * time control.
 *
 * @param inst   Engine instance.
 * @param state  One of gonodes_transport_state values.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_transport(
    gonodes_instance_t inst,
    int state
);

/**
 * Set the playback speed multiplier.
 *
 * @param inst   Engine instance.
 * @param speed  Speed multiplier (1.0 = normal, 0.5 = half, 2.0 = double).
 *               Negative values reverse playback.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_transport_speed(
    gonodes_instance_t inst,
    double speed
);

/**
 * Seek to an absolute time position.
 *
 * @param inst     Engine instance.
 * @param seconds  Absolute time position in seconds.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_transport_seek(
    gonodes_instance_t inst,
    double seconds
);

/**
 * Get the current transport time in seconds.
 *
 * @param inst  Engine instance.
 * @return Current time in seconds (0.0 if no patch loaded).
 */
GONODES_API double gonodes_get_transport_time(gonodes_instance_t inst);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Dynamic Graph Editing  (Gap 7)                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Create a new node in the loaded patch at runtime.
 *
 * Comparable to VUO's dynamic composition modification.  Note that
 * TouchEngine does not support runtime graph editing — this goes beyond
 * what TouchEngine offers.
 *
 * @param inst       Engine instance.
 * @param node_id    Desired node ID (must be unique in the patch).
 * @param node_type  Operator type name (e.g. "NoiseTOP", "MathCHOP").
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_create_node(
    gonodes_instance_t inst,
    const char* node_id,
    const char* node_type
);

/**
 * Delete a node from the loaded patch at runtime.
 *
 * All connections to/from the node are removed automatically.
 *
 * @param inst     Engine instance.
 * @param node_id  Node ID to remove.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_delete_node(
    gonodes_instance_t inst,
    const char* node_id
);

/**
 * Create a connection between two nodes.
 *
 * @param inst       Engine instance.
 * @param from_node  Source node ID.
 * @param from_port  Source output port index.
 * @param to_node    Destination node ID.
 * @param to_port    Destination input port index.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_connect(
    gonodes_instance_t inst,
    const char* from_node, int from_port,
    const char* to_node, int to_port
);

/**
 * Remove a connection between two nodes.
 *
 * @param inst       Engine instance.
 * @param from_node  Source node ID.
 * @param from_port  Source output port index.
 * @param to_node    Destination node ID.
 * @param to_port    Destination input port index.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_disconnect(
    gonodes_instance_t inst,
    const char* from_node, int from_port,
    const char* to_node, int to_port
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Event / Trigger System  (Gap 8)                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Fire a named event/trigger into the patch.
 *
 * Comparable to TouchEngine's pulse parameters and VUO's
 * firePublishedInputPortEvent().  Unlike sustained parameter values, events
 * are one-shot triggers that operators can respond to in a single cook frame.
 *
 * Any HostInEvent operators in the patch with a matching event_name will
 * fire on the next cook frame.
 *
 * @param inst        Engine instance.
 * @param event_name  Named event identifier.
 * @param payload     JSON-encoded payload (or NULL for a bare trigger).
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_fire_event(
    gonodes_instance_t inst,
    const char* event_name,
    const char* payload
);

/**
 * Register a callback for events/triggers emitted by the patch.
 * Pass NULL to unregister.
 */
GONODES_API void gonodes_set_on_event(
    gonodes_instance_t inst,
    gonodes_event_fn callback,
    void* user_data
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Output Resolution Override  (Gap 10)                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Override the output resolution of a TOP or HostOutTOP node.
 *
 * Comparable to VUO/FxPlug's renderOutput:atSize: — the host controls the
 * final output texture dimensions regardless of what the patch specifies.
 * Pass 0,0 to revert to the patch's authored resolution.
 *
 * @param node_id Node ID (TOP-family or HostOutTOP).
 * @param width   Desired width (0 = use patch default).
 * @param height  Desired height (0 = use patch default).
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_output_resolution(
    gonodes_instance_t inst,
    const char* node_id,
    int width, int height
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy GPU Exchange — VOL                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Push a GPU 3D texture into a HostInVOL node — zero-copy.
 *
 * The host provides a native 3D texture handle on the shared GPU device.
 * GONODES wraps the handle directly — no CPU readback or upload.
 * Falls back to CPU path (gonodes_set_input_volume) if contexts are not shared.
 *
 * @param node_id         ID of a HostInVOL node.
 * @param texture_handle  API-specific 3D texture handle (VkImage/GLuint/MTLTexture*).
 * @param width           X resolution in voxels.
 * @param height          Y resolution in voxels.
 * @param depth           Z resolution in voxels.
 * @param channels        1 for scalar (R32F), 4 for RGBA (R32G32B32A32F).
 * @param field_name      Semantic label (e.g. "density"). NULL defaults to "density".
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_volume_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    uint64_t texture_handle,
    int width, int height, int depth,
    int channels,
    const char* field_name
);

/**
 * Get the GPU 3D texture handle from a VOL output — zero-copy.
 *
 * Returns the native 3D texture handle (VkImage/GLuint/MTLTexture*) for the
 * volume's RenderingDevice texture. The handle is valid until the next
 * gonodes_cook_frame() call.
 *
 * @param node_id    Node ID (must be VOL-family or HostOutVOL).
 * @param out_info   [out] Filled with GPU handle metadata.
 * @return GONODES_OK, or an error code if no GPU volume is available.
 */
GONODES_API int gonodes_get_output_volume_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_volume_gpu_handle_t* out_info
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy GPU Exchange — POP                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Push a GPU SSBO into a HostInPOP node — zero-copy.
 *
 * The host provides a native storage buffer handle containing particle data
 * in the standard 64-byte stride layout (see gonodes_particle_gpu_handle_t).
 * GONODES binds the buffer directly — no CPU readback or upload.
 *
 * @param node_id         ID of a HostInPOP node.
 * @param buffer_handle   API-specific buffer handle (VkBuffer/GLuint SSBO/MTLBuffer*).
 * @param particle_count  Number of active particles.
 * @param stride          Bytes per particle (must be 64 for standard layout).
 * @param buffer_size     Total buffer size in bytes.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_particles_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    uint64_t buffer_handle,
    int particle_count,
    int stride,
    int buffer_size
);

/**
 * Get the GPU SSBO handle from a POP output — zero-copy.
 *
 * Returns the native storage buffer handle containing particle data in the
 * standard 64-byte stride layout. The handle is valid until the next
 * gonodes_cook_frame() call.
 *
 * @param node_id    Node ID (must be POP-family or HostOutPOP).
 * @param out_info   [out] Filled with GPU handle metadata.
 * @return GONODES_OK, or an error code if no GPU buffer is available.
 */
GONODES_API int gonodes_get_output_particles_gpu(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_particle_gpu_handle_t* out_info
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy CPU Exchange — CHOP                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Push multiple channels into a HostInCHOP node in one call — zero-copy.
 *
 * Unlike gonodes_set_input_chop() which encodes samples as strings, this
 * function passes float* pointers directly. The pointers must remain valid
 * until the next gonodes_cook_frame() call (frame-scoped lending).
 *
 * @param node_id        ID of a HostInCHOP node.
 * @param channel_names  Array of channel name strings.
 * @param channel_data   Array of float* sample arrays (one per channel).
 * @param sample_counts  Array of sample counts (one per channel).
 * @param num_channels   Number of channels.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_chop_direct(
    gonodes_instance_t inst,
    const char* node_id,
    const char** channel_names,
    const float** channel_data,
    const int* sample_counts,
    int num_channels
);

/**
 * Read all channel data from a CHOP output — zero-copy pointers.
 *
 * Returns direct pointers into the engine's channel buffers.  All pointers
 * are valid until the next gonodes_cook_frame() call. The host must NOT
 * free any returned pointers.
 *
 * @param node_id    Node ID (must be CHOP-family or HostOutCHOP).
 * @param out_data   [out] Filled with channel descriptors.
 * @return GONODES_OK, or an error code if not available.
 */
GONODES_API int gonodes_get_output_chop_direct(
    gonodes_instance_t inst,
    const char* node_id,
    gonodes_chop_data_t* out_data
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy CPU Exchange — DAT                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Push a string pointer into a HostInDAT node — zero-copy.
 *
 * The host provides a direct const char* pointer instead of going through
 * env-var encoding. The pointer must remain valid until the next
 * gonodes_cook_frame() call.
 *
 * @param node_id    ID of a HostInDAT node.
 * @param json_data  JSON string (table or text). Must remain valid until next cook.
 * @param length     String length in bytes (0 = use strlen).
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_table_direct(
    gonodes_instance_t inst,
    const char* node_id,
    const char* json_data,
    int length
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  v1.2.0: Zero-Copy CPU Exchange — SOP                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Push geometry into a HostInSOP node via direct pointers — zero-copy.
 *
 * Unlike gonodes_set_input_geometry() which copies data through temp files,
 * this function passes float* pointers directly. The pointers must remain
 * valid until the next gonodes_cook_frame() call (frame-scoped lending).
 *
 * @param node_id       ID of a HostInSOP node.
 * @param positions     Interleaved xyz positions (3 floats per vertex).
 * @param normals       Interleaved xyz normals (or NULL for auto-compute).
 * @param uvs           Interleaved uv coords (or NULL).
 * @param colors        Interleaved rgba colors (4 floats per vertex, or NULL).
 * @param vertex_count  Number of vertices.
 * @param indices       Triangle index buffer (or NULL for non-indexed).
 * @param index_count   Number of indices.
 * @return GONODES_OK or an error code.
 */
GONODES_API int gonodes_set_input_geometry_direct(
    gonodes_instance_t inst,
    const char* node_id,
    const float* positions,
    const float* normals,
    const float* uvs,
    const float* colors,
    int vertex_count,
    const uint32_t* indices,
    int index_count
);

#ifdef __cplusplus
}
#endif

#endif /* GONODES_HOST_H */

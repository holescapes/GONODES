# Integrating GONODES in Host Applications

> **Audience:** Developers embedding GONODES as a real-time texture/data processing backend inside their own applications — VJ tools, media servers, game engines, creative coding frameworks, broadcast graphics systems, installation controllers.

This document covers the LibGONODES C API, GPU context sharing, bridge operators, hot-reload, and the build pipeline.  For the C header reference and example code, see [`libgonodes/README.md`](../libgonodes/README.md).

---

## Overview

GONODES can run embedded inside any application that calls C functions.  The host links against `libgonodes` (a shared library wrapping Godot 4.6's LibGodot embedding API) and communicates through a clean C interface defined in `gonodes_host.h`.

The host application owns the render loop and the GPU device.  GONODES runs headlessly inside the host process, cooking operator graphs and producing textures, channel data, and table data on demand.  When the host shares its GPU device, texture exchange is **zero-copy** — the handles returned by GONODES are native VkImages, GLuints, or MTLTextures on the same device memory.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Host Application                               │
│  (SDL, Qt, Unreal, Unity, Max/MSP, VDMX, …)    │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  gonodes_host.h — C API                   │  │
│  │  create / destroy / cook_frame            │  │
│  │  load_patch / reload / unload             │  │
│  │  set_input_texture / chop / table         │  │
│  │  get_output_texture / chop / table        │  │
│  │  set_parameter / get_parameter            │  │
│  │  introspection / callbacks / stats        │  │
│  └──────────────────┬────────────────────────┘  │
│                     │                           │
│  ┌──────────────────▼────────────────────────┐  │
│  │  libgonodes.dll / .so / .dylib            │  │
│  │  (C++ — dynamic LibGodot loading)         │  │
│  └──────────────────┬────────────────────────┘  │
│                     │                           │
│  ┌──────────────────▼────────────────────────┐  │
│  │  libgodot.dll / .so / .dylib              │  │
│  │  (Godot 4.6 engine as shared library)     │  │
│  │                                           │  │
│  │  ┌──────────────────────────────────────┐ │  │
│  │  │  GNEmbeddedHost (GDScript singleton) │ │  │
│  │  │  ├─ GNCookEngine                     │ │  │
│  │  │  ├─ GNNetwork + all operators        │ │  │
│  │  │  └─ Bridge Operators                 │ │  │
│  │  │     ├ HostInTOP / HostInCHOP / HostInDAT  │
│  │  │     └ HostOutTOP / HostOutCHOP / HostOutDAT│
│  │  └──────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### How It Boots

1. Host calls `gonodes_create(project_path, &gpu_context)`
2. `libgonodes` dynamically loads `libgodot.dll/.so/.dylib` from the same directory
3. LibGodot boots with `--headless` mode, pointing at the GONODES project directory
4. The `GNEmbeddedHost` autoload singleton registers itself via `Engine.register_singleton()`
5. A few warmup frames are cooked so autoloads are fully initialized
6. Host calls `gonodes_load_patch()` → `GNEmbeddedHost.load_patch()` builds the network and boots the cook engine
7. Each frame, the host calls `gonodes_cook_frame(delta)` → one full Godot iteration runs

---

## GPU Context Sharing

The key to zero-copy exchange is sharing the GPU device between the host and GONODES.

### How It Works

The host fills a `gonodes_gpu_context_t` struct with its active graphics API handles — the same device GONODES will render on.  When shared:

- **Vulkan**: output textures are `VkImage` handles on the shared `VkDevice` — bind directly in your render pass
- **Metal**: output textures are `id<MTLTexture>` on the shared `MTLDevice` — blit to your drawable
- **OpenGL**: output textures are `GLuint` names in the shared GL context — bind as `GL_TEXTURE_2D`

### Struct Layout

```c
typedef struct gonodes_gpu_context {
    /* Vulkan */
    void* vulkan_instance;           // VkInstance
    void* vulkan_physical_device;    // VkPhysicalDevice
    void* vulkan_device;             // VkDevice
    void* vulkan_queue;              // VkQueue (optional)
    uint32_t vulkan_queue_family;

    /* Metal (macOS / iOS) */
    void* metal_device;              // id<MTLDevice>
    void* metal_command_queue;       // id<MTLCommandQueue> (optional)

    /* OpenGL */
    void* gl_context;                // HGLRC / NSOpenGLContext* / EGLContext

    int graphics_api;                // GONODES_GFX_VULKAN / METAL / OPENGL / AUTO
} gonodes_gpu_context_t;
```

| API | Renderer Selected | Zero-Copy Object |
|-----|-------------------|-----------------|
| Vulkan | Forward+ | VkImage |
| Metal | Forward+ | MTLTexture |
| OpenGL | Compatibility (gl_compatibility) | GLuint |
| NULL (no context) | Auto (LibGodot creates its own device) | CPU readback path |

### Non-Shared Fallback

If the host passes `NULL` for the GPU context, LibGodot creates its own rendering device.  Texture exchange falls back to CPU readback + upload — functional but slower.  This is useful for headless processing (params demo, data pipelines) where texture output isn't needed.

---

## C API Reference

### Lifecycle

```c
// Create an instance — boots LibGodot with optional shared GPU context.
gonodes_instance_t gonodes_create(const char* project_path,
                                   const gonodes_gpu_context_t* gpu);

// Destroy — tears down LibGodot and frees all resources.
void gonodes_destroy(gonodes_instance_t inst);

// Query library version.
void gonodes_get_version(int* major, int* minor, int* patch);
```

### Patch Management

```c
// Load a .gnpatch file.  Unloads any previous patch.
int gonodes_load_patch(gonodes_instance_t inst, const char* path);

// Unload the current patch.
void gonodes_unload_patch(gonodes_instance_t inst);

// Reload from disk — preserves CHOP values, timers, feedback textures.
int gonodes_reload_patch(gonodes_instance_t inst);

// File-watch auto-reload (polls file mtime).
void gonodes_set_auto_reload(gonodes_instance_t inst, int enable, double interval);
```

### Frame Loop

```c
// Cook one frame.  Call this every render frame.
// Flushes input injections, runs the cook engine, updates outputs.
void gonodes_cook_frame(gonodes_instance_t inst, double delta_seconds);
```

### Input Injection (Host → GONODES)

```c
// Push texture into a HostInTOP node.
int gonodes_set_input_texture(inst, node_id, texture_handle, w, h, format);

// Push float samples into a HostInCHOP node.
int gonodes_set_input_chop(inst, node_id, channel_name, samples, num_samples);

// Push JSON table/text into a HostInDAT node.
int gonodes_set_input_table(inst, node_id, json_data);

// Set any parameter on any node.
int gonodes_set_parameter(inst, node_id, param_name, value_json);
```

### Output Reading (GONODES → Host)

```c
// Get texture handle from a HostOutTOP node (or any TOP).
uint64_t gonodes_get_output_texture(inst, node_id, &out_w, &out_h);

// Read float samples from a HostOutCHOP node.
int gonodes_get_output_chop(inst, node_id, channel_name, out_buf, buf_size);

// Read JSON table from a HostOutDAT node.
const char* gonodes_get_output_table(inst, node_id);

// Read any parameter's current value.
const char* gonodes_get_parameter(inst, node_id, param_name);
```

### Introspection

```c
const char* gonodes_list_nodes(inst);              // JSON array of all nodes
const char* gonodes_get_node_info(inst, node_id);  // Detailed node info
const char* gonodes_list_parameters(inst, node_id);// Parameters on a node
const char* gonodes_list_connections(inst);         // All wire connections
```

### Callbacks

```c
// Parameter change notification.
void gonodes_set_on_param_changed(inst, callback_fn, user_data);

// Log/error routing.
void gonodes_set_log_callback(inst, log_fn, user_data);
```

### Utilities

```c
const char* gonodes_get_last_error(inst);                    // Human-readable error
void gonodes_get_stats(inst, &cook_ms, &node_count, &frame); // Performance stats
```

---

## Bridge Operators

Six operators bridge data between the host and the GONODES patch graph.  They appear in the node palette like any other operator and are wired into the graph normally.

| Operator | Family | Direction | C API Function | File |
|----------|--------|-----------|----------------|------|
| **HostInTOP** | TOP | Host → GONODES | `gonodes_set_input_texture()` | `operators/top/host_in_top.gd` |
| **HostInCHOP** | CHOP | Host → GONODES | `gonodes_set_input_chop()` | `operators/chop/host_in_chop.gd` |
| **HostInDAT** | DAT | Host → GONODES | `gonodes_set_input_table()` | `operators/dat/host_in_dat.gd` |
| **HostOutTOP** | OUT | GONODES → Host | `gonodes_get_output_texture()` | `operators/output/host_out_top.gd` |
| **HostOutCHOP** | OUT | GONODES → Host | `gonodes_get_output_chop()` | `operators/output/host_out_chop.gd` |
| **HostOutDAT** | OUT | GONODES → Host | `gonodes_get_output_table()` | `operators/output/host_out_dat.gd` |

### How Bridge Operators Work

**Input bridge** operators (HostIn*) have a `_set_host_*()` method that `GNEmbeddedHost` calls during `_flush_inputs()` before each cook.  The host's data is injected via the C API, queued internally, then delivered to the operator which `mark_dirty()` triggers a recook.

**Output bridge** operators (HostOut*) are OUT-family sinks (`is_sink = true`).  They appear in the active cooking chain automatically.  After each cook, `GNEmbeddedHost._collect_outputs()` calls their `_get_host_*()` methods to extract the cooked data.

For **HostOutTOP**, the native GPU texture handle is read via `RenderingServer.texture_get_native_handle()` — returning the VkImage / GLuint / MTLTexture directly from Godot's rendering backend.

### Patch Design for Embedding

A typical embedded patch looks like:

```
HostInCHOP("sensor_data") → MathCHOP → FilterCHOP ──────────────┐
HostInTOP("camera_feed")  → BlurTOP → CompositeTOP → HostOutTOP("main_out")
                                            ↑
                              NoiseTOP ─────┘
HostInDAT("config")       → SubstituteDAT → HostOutDAT("status")
```

The host references bridge nodes by their **node ID** strings (e.g., `"sensor_data"`, `"main_out"`).

---

## GNEmbeddedHost Singleton

The GDScript singleton `GNEmbeddedHost` (`addons/gonodes/core/gn_embedded_host.gd`) replaces `player_main.gd` for embedded operation.  It:

1. Registers itself as an Engine singleton on `_ready()`
2. Polls for commands from the C API (patch load/unload/reload)
3. Flushes host input data into bridge operators before each cook
4. Collects output data from bridge operators after each cook
5. Publishes introspection JSON (node list, parameters, connections)
6. Manages stateful hot-reload (saves/restores CHOP values and timer positions)

The C API communicates with GNEmbeddedHost via environment variables during the LibGodot iteration loop.  This is a pragmatic bridge that works with Godot 4.6's current embedding surface; a future version may use direct ClassDB singleton calls when Godot stabilizes its external scripting interface.

---

## Parameter Value Encoding

All parameter values are passed as JSON strings.  The encoding matches the parameter type:

| Parameter Type | JSON Encoding | Example |
|---------------|---------------|---------|
| Float | Number string | `"3.14"` |
| Integer | Number string | `"42"` |
| Boolean | `"true"` / `"false"` | `"true"` |
| String | Quoted string | `"\"hello\""` |
| Color (RGBA) | Array | `"[1.0, 0.5, 0.0, 1.0]"` |
| Vector2 | Array | `"[100.0, 200.0]"` |
| Vector2i | Object with `_type` | `"{\"_type\": \"Vector2i\", \"x\": 1920, \"y\": 1080}"` |
| Enum | Integer index | `"2"` |

The `_type` wrapper for `Vector2i` follows the same convention used in `.gnpatch` serialization (see `gn_network.gd` `from_dict()`).

---

## Hot Reload

### Auto-Reload

```c
gonodes_set_auto_reload(gn, 1, 0.5);  // Enable, poll every 0.5s
```

The C API polls the `.gnpatch` file's modification time.  When a change is detected, `gonodes_reload_patch()` is called automatically.

### Stateful Reload

`GNEmbeddedHost.reload_patch()` preserves runtime state across reloads:

1. **Before unload**: saves CHOP channel values and timer positions for all nodes
2. **After reload**: restores saved values to matching node IDs in the new graph
3. Only **graph topology** is reconstituted — runtime data survives

This enables live iteration: edit the `.gnpatch` in the GONODES editor, save, and the embedded instance picks up changes without losing animation state.

---

## Error Handling

All functions that can fail return `GONODES_OK` (0) or a negative error code:

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | `GONODES_OK` | Success |
| -1 | `GONODES_ERR_INVALID_HANDLE` | NULL or destroyed instance |
| -2 | `GONODES_ERR_FILE_NOT_FOUND` | Patch file doesn't exist |
| -3 | `GONODES_ERR_PARSE_ERROR` | Invalid .gnpatch JSON |
| -4 | `GONODES_ERR_GPU_INIT_FAILED` | GPU initialization failed |
| -5 | `GONODES_ERR_NODE_NOT_FOUND` | Node ID not in patch |
| -6 | `GONODES_ERR_PARAM_NOT_FOUND` | Parameter name not on node |
| -7 | `GONODES_ERR_BUFFER_TOO_SMALL` | Read buffer too small |
| -8 | `GONODES_ERR_NOT_LOADED` | No patch loaded |
| -99 | `GONODES_ERR_INTERNAL` | Internal engine error |

Human-readable error strings: `gonodes_get_last_error(gn)`.

---

## Building

### Prerequisites

- **CMake 3.20+**
- **C++17 compiler** (MSVC, GCC, or Clang)
- **Godot 4.6 built as LibGodot**: `scons platform=<platform> target=template_release libgodot=yes`
- Place `libgodot.dll` / `.so` / `.dylib` next to the host executable

### Build Commands

```bash
cd libgonodes
mkdir build && cd build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build .
```

This produces:
- `libgonodes.dll` / `.so` / `.dylib` — the shared library hosts link against
- Example executables (when examples are enabled)

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `GONODES_BUILD_EXAMPLES` | ON | Build example host applications |
| `GONODES_BUILD_SHARED` | ON | Build as shared library (OFF = static) |

---

## Example Host Applications

Five example apps in `libgonodes/examples/` demonstrate different integration patterns:

| Example | Renderer | What It Shows |
|---------|----------|---------------|
| **sdl_host** | SDL2 + OpenGL 3.3 | General-purpose: SDL window, CHOP injection, fullscreen quad output, auto-reload, R key manual reload |
| **vulkan_host** | Vulkan 1.2 | Zero-copy: VkDevice sharing, headless cook loop, VkImage output, performance stats |
| **opengl_host** | GLFW + OpenGL 3.3 | Lightweight: GLFW window, GL context extraction per-platform, animated wave input |
| **metal_host** | Metal + MTKView | macOS native: MTLDevice sharing, MTLTexture blit to CAMetalDrawable |
| **params_demo** | Headless (no GPU) | Comprehensive: all parameter types, multi-channel CHOP, DAT tables, introspection, callbacks, reload |

Each example has its own `main.cpp`, `CMakeLists.txt`, and `README.md`.

---

## Thread Safety

All C API calls are thread-safe.  Input injections are queued and flushed atomically at the start of `gonodes_cook_frame()`.  Output reads return data from the last completed cook.

**Rule**: `gonodes_cook_frame()` should be called from a consistent thread (typically the render thread) since it drives the Godot iteration which interacts with the GPU.

---

## File Map

```
libgonodes/
├── include/
│   └── gonodes_host.h            # Public C API header
├── src/
│   ├── gonodes_bootstrap.h       # Internal LibGodot init types
│   ├── gonodes_bootstrap.cpp     # LibGodot dynamic loading + init
│   └── gonodes_host.cpp          # C API implementation
├── CMakeLists.txt                # Build system
├── README.md                     # Integration guide
└── examples/
    ├── sdl_host/                 # SDL2 + OpenGL example
    ├── vulkan_host/              # Vulkan example
    ├── opengl_host/              # GLFW + OpenGL example
    ├── metal_host/               # Metal example (macOS)
    └── params_demo/              # Parameter control demo

addons/gonodes/core/
└── gn_embedded_host.gd           # GDScript bridge singleton

addons/gonodes/operators/
├── top/host_in_top.gd            # HostInTOP bridge
├── chop/host_in_chop.gd          # HostInCHOP bridge
├── dat/host_in_dat.gd            # HostInDAT bridge
└── output/
    ├── host_out_top.gd           # HostOutTOP bridge
    ├── host_out_chop.gd          # HostOutCHOP bridge
    └── host_out_dat.gd           # HostOutDAT bridge
```

---

## Relationship to Player Runtime

| | Player (`player_main.gd`) | Embedded (`gn_embedded_host.gd`) |
|---|---|---|
| **Who drives it** | Godot runs as standalone app | Host app calls `gonodes_cook_frame()` |
| **Window management** | WindowOUT opens OS windows | Host owns all windows |
| **Patch loading** | CLI args or config.json | C API `gonodes_load_patch()` |
| **Data I/O** | MIDI, OSC, Audio, Keyboard in | C API `set_input_*` / `get_output_*` via bridge operators |
| **GPU ownership** | Godot owns the device | Host shares device (or Godot creates its own) |
| **Use case** | Standalone VJ app, installation | Plugin inside VJ tool, game engine, media server |

Both use the same `GNCookEngine`, `GNNetwork`, and operator library.  The only difference is who boots Godot and who owns the render loop.

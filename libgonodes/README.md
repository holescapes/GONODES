# LibGONODES — Embed GONODES in Any Application

LibGONODES is a C shared library that wraps the GONODES visual processing
engine (built on Godot 4.6's LibGodot embedding API) into a clean, portable
C interface.  Any application that can call C functions — game engines, VJ
tools, media servers, creative coding frameworks — can embed GONODES as a
real-time texture/data processing backend.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Host Application (SDL, Qt, Unreal, Unity, Max/MSP…)    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  gonodes_host.h — C API                         │    │
│  │  • gonodes_create / destroy                     │    │
│  │  • gonodes_load_patch / reload / unload         │    │
│  │  • gonodes_cook_frame                           │    │
│  │  • gonodes_set_input_texture / chop / table     │    │
│  │  • gonodes_get_output_texture / chop / table    │    │
│  │  • gonodes_set_parameter / get_parameter        │    │
│  │  • Introspection, callbacks, stats              │    │
│  └────────────────────┬────────────────────────────┘    │
│                       │                                 │
│  ┌────────────────────▼────────────────────────────┐    │
│  │  libgonodes.dll / .so / .dylib                  │    │
│  │  (C++ implementation)                           │    │
│  └────────────────────┬────────────────────────────┘    │
│                       │                                 │
│  ┌────────────────────▼────────────────────────────┐    │
│  │  libgodot.dll / .so / .dylib                    │    │
│  │  (Godot 4.6 engine as a shared library)         │    │
│  │                                                 │    │
│  │  ┌─────────────────────────────────────────┐    │    │
│  │  │  GNEmbeddedHost (GDScript singleton)    │    │    │
│  │  │  ├─ GNCookEngine                        │    │    │
│  │  │  ├─ GNNetwork                           │    │    │
│  │  │  └─ Bridge Operators                    │    │    │
│  │  │     ├─ HostInTOP / HostInCHOP / HostInDAT    │    │
│  │  │     └─ HostOutTOP / HostOutCHOP / HostOutDAT │    │
│  │  └─────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Build

```bash
mkdir libgonodes/build && cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build .
```

Produces:
- `libgonodes.dll` / `.so` / `.dylib`
- Example executables (sdl_host, vulkan_host, opengl_host, metal_host, params_demo)

### 2. Get LibGodot

Build Godot 4.6 from source with LibGodot enabled:

```bash
scons platform=windows target=template_release libgodot=yes
```

This produces `libgodot.dll` / `.so` / `.dylib`.  Place it in the same
directory as your host executable.

### 3. Embed in Your App

```c
#include <gonodes_host.h>

// Share your Vulkan device for zero-copy texture access.
gonodes_gpu_context_t gpu = {0};
gpu.graphics_api          = GONODES_GFX_VULKAN;
gpu.vulkan_instance       = my_vk_instance;
gpu.vulkan_physical_device = my_vk_phys_dev;
gpu.vulkan_device         = my_vk_device;

// Boot GONODES.
gonodes_instance_t gn = gonodes_create("path/to/project", &gpu);
gonodes_load_patch(gn, "path/to/show.gnpatch");

// In your frame loop:
gonodes_cook_frame(gn, delta_seconds);
uint64_t tex = gonodes_get_output_texture(gn, "main_out", &w, &h);
// 'tex' is a VkImage on the shared device — bind it directly.

gonodes_destroy(gn);
```

## GPU Context Sharing

The key to zero-copy texture exchange is sharing the GPU device.  When the
host provides its device handle, GONODES renders on the **same physical
device**, so texture handles are directly usable by both sides.

| API | Context Struct Fields | GONODES Renderer |
|-----|----------------------|-----------------|
| **Vulkan** | `vulkan_instance`, `vulkan_physical_device`, `vulkan_device`, `vulkan_queue` | Forward+ |
| **Metal** | `metal_device`, `metal_command_queue` | Forward+ |
| **OpenGL** | `gl_context` (HGLRC / NSOpenGLContext* / EGLContext) | Compatibility |

Pass `NULL` for the GPU context to let LibGodot create its own device (no
zero-copy, but still works — CPU readback/upload path).

## Bridge Operators

Six operators bridge data between the host and the GONODES patch:

| Operator | Family | Direction | Purpose |
|----------|--------|-----------|---------|
| **HostInTOP** | TOP | Host → GONODES | Inject texture from host |
| **HostInCHOP** | CHOP | Host → GONODES | Inject float channels from host |
| **HostInDAT** | DAT | Host → GONODES | Inject table/text from host |
| **HostOutTOP** | OUT | GONODES → Host | Export texture to host |
| **HostOutCHOP** | OUT | GONODES → Host | Export float channels to host |
| **HostOutDAT** | OUT | GONODES → Host | Export table/text to host |

Place these in your `.gnpatch` and reference them by **node ID** from the
C API.

## Parameter Control

Every parameter on every node can be controlled from the host:

```c
// Float
gonodes_set_parameter(gn, "noise1", "scale", "8.0");

// Integer
gonodes_set_parameter(gn, "noise1", "seed", "42");

// Boolean
gonodes_set_parameter(gn, "noise1", "monochrome", "false");

// String
gonodes_set_parameter(gn, "text1", "text", "\"Hello\"");

// Color (RGBA array)
gonodes_set_parameter(gn, "const1", "color", "[1.0, 0.3, 0.0, 1.0]");

// Vector2i (requires _type wrapper)
gonodes_set_parameter(gn, "noise1", "resolution",
    "{\"_type\": \"Vector2i\", \"x\": 1920, \"y\": 1080}");
```

Read parameters back:
```c
const char* val = gonodes_get_parameter(gn, "noise1", "scale");
// val = "8.0"
```

## Hot Reload

Enable file-watching for live iteration:

```c
gonodes_set_auto_reload(gn, 1, 0.5);  // Poll every 0.5 seconds
```

GONODES preserves CHOP channel values, timer positions, and feedback
textures across reloads — only graph topology is reconstituted.

Manual reload:
```c
gonodes_reload_patch(gn);
```

## Introspection

Query the patch structure at runtime:

```c
const char* nodes = gonodes_list_nodes(gn);
// [{"id":"noise1","type":"noise","family":"TOP"}, ...]

const char* info = gonodes_get_node_info(gn, "noise1");
// {"id":"noise1","type":"noise","family":"TOP","inputs":[...],"outputs":[...],...}

const char* params = gonodes_list_parameters(gn, "noise1");
// [{"name":"scale","type":"float","value":8.0,"min":0.1,"max":100}, ...]

const char* conns = gonodes_list_connections(gn);
// [{"from":"noise1","from_port":0,"to":"comp1","to_port":0}, ...]
```

## Examples

| Example | Renderer | Description |
|---------|----------|-------------|
| [sdl_host](examples/sdl_host/) | OpenGL 3.3 | SDL2 window, fullscreen quad rendering |
| [vulkan_host](examples/vulkan_host/) | Vulkan 1.2 | Device sharing, headless cook loop |
| [opengl_host](examples/opengl_host/) | OpenGL 3.3 | GLFW window, GL context sharing |
| [metal_host](examples/metal_host/) | Metal | macOS MTKView, MTLTexture blit |
| [params_demo](examples/params_demo/) | Headless | All parameter types, CHOP/DAT I/O |

### Example Patches

Two ready-to-use `.gnpatch` files are included in [`examples/patches/`](examples/patches/):

- **`show.gnpatch`** — Used by the visual examples (SDL, OpenGL, Vulkan, Metal). Contains a `HostInCHOP` (host_lfo) → `NoiseTOP` (noise1) → `HostOutTOP` (host_out) chain.
- **`params_test.gnpatch`** — Used by params_demo. Contains all 6 bridge operators + NoiseTOP, TextTOP, ConstantTOP for exercising the full C API.

## Error Handling

All functions that can fail return `GONODES_OK` (0) on success or a
negative error code:

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | `GONODES_OK` | Success |
| -1 | `GONODES_ERR_INVALID_HANDLE` | NULL or destroyed instance |
| -2 | `GONODES_ERR_FILE_NOT_FOUND` | Patch file doesn't exist |
| -3 | `GONODES_ERR_PARSE_ERROR` | Invalid .gnpatch JSON |
| -4 | `GONODES_ERR_GPU_INIT_FAILED` | LibGodot GPU init failed |
| -5 | `GONODES_ERR_NODE_NOT_FOUND` | Node ID not in patch |
| -6 | `GONODES_ERR_PARAM_NOT_FOUND` | Parameter name not on node |
| -7 | `GONODES_ERR_BUFFER_TOO_SMALL` | Output buffer too small |
| -8 | `GONODES_ERR_NOT_LOADED` | No patch loaded |
| -99 | `GONODES_ERR_INTERNAL` | Internal engine error |

Human-readable error strings via `gonodes_get_last_error(gn)`.

## Thread Safety

All API calls are thread-safe.  Input injections are queued and flushed
at the start of `gonodes_cook_frame()`.  Output reads return data from
the last completed cook.

**One rule**: `gonodes_cook_frame()` must be called from a consistent
thread (typically your render thread).

## Requirements

- Godot 4.6+ (built with LibGodot: `scons libgodot=yes`)
- C++17 compiler (MSVC, GCC, Clang)
- CMake 3.20+
- The full GONODES project directory (addons/gonodes/, project.godot, etc.)

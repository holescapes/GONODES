# LibGONODES — Embed GONODES in Any Application

LibGONODES is a C shared library that wraps the GONODES visual processing
engine (built on Godot 4.6's LibGodot embedding API) into a clean, portable
C interface.  Any application that can call C functions — game engines, VJ
tools, media servers, creative coding frameworks — can embed GONODES as a
real-time texture/data processing backend.

**v2.5 Direct Bridge Architecture:** A single `gonodes_instance_t` boots ONE
Godot engine, but can load **multiple patches simultaneously**.  Each patch
gets its own cook engine, node graph, transport, and I/O registries, while
sharing the GPU context and rendering pipeline.  All I/O functions take a
`gonodes_patch_t` handle to address a specific patch.

v2.5 eliminates the per-frame environment-variable IPC layer.  The GNHostBridge
GDExtension reads the C command queue and writes response slots directly via
pointer access — single memcpy per data type, zero string formatting overhead.

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
│  │  │  ├─ Patch 1:                            │    │    │
│  │  │  │  ├─ GNCookEngine                     │    │    │
│  │  │  │  ├─ GNNetwork                        │    │    │
│  │  │  │  └─ Bridge Operators                 │    │    │
│  │  │  ├─ Patch 2:                            │    │    │
│  │  │  │  ├─ GNCookEngine                     │    │    │
│  │  │  │  └─ ...                              │    │    │
│  │  │  └─ (up to 64 concurrent patches)       │    │    │
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
- Example executables (sdl_host, vulkan_host, opengl_host, metal_host, params_demo, geometry_host, graph_edit_demo, midi_osc_host)

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

// Load multiple patches — each gets its own cook engine.
gonodes_patch_t effects = gonodes_load_patch(gn, "effects.gnpatch");
gonodes_patch_t overlay = gonodes_load_patch(gn, "overlay.gnpatch");

// In your frame loop — one call cooks ALL loaded patches:
gonodes_cook_frame(gn, delta_seconds);
uint64_t tex1 = gonodes_get_output_texture(gn, effects, "main_out", &w, &h);
uint64_t tex2 = gonodes_get_output_texture(gn, overlay, "title", &w2, &h2);
// tex1/tex2 are VkImages on the shared device — bind directly.

gonodes_unload_patch(gn, overlay);
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

Twelve operators bridge data between the host and the GONODES patch:

| Operator | Family | Direction | Purpose |
|----------|--------|-----------|---------|
| **HostInTOP** | TOP | Host → GONODES | Inject texture from host |
| **HostInCHOP** | CHOP | Host → GONODES | Inject float channels from host |
| **HostInDAT** | DAT | Host → GONODES | Inject table/text from host |
| **HostInSOP** | SOP | Host → GONODES | Inject geometry (vertices, normals, UVs, indices) |
| **HostInVOL** | VOL | Host → GONODES | Inject 3D voxel grid (density, velocity, etc.) |
| **HostInPOP** | POP | Host → GONODES | Inject particle data (positions, velocities, colors) |
| **HostOutTOP** | OUT | GONODES → Host | Export texture to host |
| **HostOutCHOP** | OUT | GONODES → Host | Export float channels to host |
| **HostOutDAT** | OUT | GONODES → Host | Export table/text to host |
| **HostOutSOP** | OUT | GONODES → Host | Export processed geometry to host |
| **HostOutVOL** | OUT | GONODES → Host | Export 3D voxel grid to host |
| **HostOutPOP** | OUT | GONODES → Host | Export particle data to host |

Place these in your `.gnpatch` and reference them by **node ID** from the
C API.

> **Sink design:** All HostOut* operators are **structural sinks** (`is_sink = true`).
> The cook engine seeds its active-set BFS from every sink node and walks upstream
> through all connections.  This guarantees the entire processing chain above a
> HostOut* operator cooks every frame — even though no GONODES node reads its
> output.  The host reads the result externally via the C API after
> `gonodes_cook_frame()` returns.  Without the sink flag, HostOut* nodes would be
> excluded from the active set, and the host would read stale/empty data.

## Data Exchange Reference

LibGONODES supports bidirectional exchange of **9 data contexts** between
host and engine.  This is a unique capability — no other embeddable
node-graph engine provides this breadth of data exchange through a single
C API.

### Comparison with TouchEngine and VUO

| Context | LibGONODES | TouchEngine SDK | VUO/FxPlug |
|---------|-----------|----------------|-----------|
| **Texture (GPU)** | Bidirectional, zero-copy via shared device | Bidirectional, zero-copy | Bidirectional via `VuoImage` |
| **Texture (CPU pixels)** | Bidirectional (`set_input_pixels` / `read_output_pixels`) | Bidirectional | Bidirectional (`makeFromBuffer` / `copyBuffer`) |
| **Channels (CHOP)** | Bidirectional (`set_input_chop` / `get_output_chop`) | Bidirectional (float arrays) | Limited (single-value ports only) |
| **Tables (DAT)** | Bidirectional (`set_input_table` / `get_output_table`) | Bidirectional (string tables) | No table/grid equivalent |
| **Geometry (SOP)** | **Bidirectional** (`set_input_geometry` / `get_output_geometry`) | **Read-only** (`TEInstanceLinkGetObjectValue`) | Bidirectional via `VuoMesh` (compositor protocol only) |
| **Volumes (VOL)** | **Bidirectional** — CPU input + GPU zero-copy I/O (CPU output planned) | **Not supported** | **Not supported** |
| **Particles (POP)** | **Bidirectional** — CPU input + GPU zero-copy I/O (CPU output planned) | **Not supported** | **Not supported** |
| **MIDI** | Host → engine (`send_midi_event`) | Via parameter mapping only | Native nodes (not injectable) |
| **OSC** | Host → engine (`send_osc_message`) | Via parameter mapping only | Native nodes (not injectable) |
| **Events/Triggers** | **Bidirectional** (`fire_event` / `set_on_event`) | Pulse params (host→engine only) | `firePublishedInputPortEvent` (host→engine only) |
| **Parameters** | Bidirectional (all types) | Bidirectional | Bidirectional |
| **Graph editing** | Full CRUD (`create_node` / `delete_node` / `connect`) | **Not supported** | Runtime rewiring via `VuoRunner` |

### 1. Textures (TOP Family)

**GPU path (zero-copy):** When the host shares its GPU device handle via
`gonodes_gpu_context_t`, texture exchange is zero-copy — both sides
reference the same VkImage / MTLTexture / GLuint.

```c
// Write: inject host texture into patch
gonodes_set_input_texture(gn, p, "cam_in", my_vk_image, 1920, 1080);

// Read: get processed texture out
uint64_t tex = gonodes_get_output_texture(gn, p, "host_out", &w, &h);

// Query format/channels/API:
gonodes_texture_info_t info;
gonodes_get_texture_info(gn, p, "host_out", &info);
// info.format, info.channels, info.native_handle, info.graphics_api
```

**CPU path (pixel buffers):** For hosts without GPU context sharing —
camera capture, video decode, recording, streaming.

```c
// Write: push raw pixels into patch
gonodes_set_input_pixels(gn, p, "cam_in", rgba_data, 1920, 1080,
                         GONODES_FORMAT_RGBA8, 0);

// Read: pull rendered pixels to CPU
uint8_t* buf = malloc(w * h * 4);
gonodes_read_output_pixels(gn, p, "host_out", buf, w*h*4,
                           GONODES_FORMAT_RGBA8, &w, &h);
```

Supported pixel formats: `RGBA8`, `RGBA16F`, `RGBA32F`, `R8`, `RG8`,
`BGRA8`, `R16F`, `RG16F`.

### 2. Channels (CHOP Family)

Multi-channel float arrays — audio samples, sensor streams, animation
curves, analysis data.

```c
// Write: push samples one channel at a time
float left[480], right[480];
gonodes_set_input_chop(gn, p, "audio_in", "left", left, 480);
gonodes_set_input_chop(gn, p, "audio_in", "right", right, 480);

// Read: retrieve processed channel into a buffer
float fft_buf[256];
int n = gonodes_get_output_chop(gn, p, "fft_out", "magnitude", fft_buf, 256);
// n = number of samples written into fft_buf
```

### 3. Tables (DAT Family)

String-based row × column grids — CSV data, OSC address maps, metadata.

```c
// Write: send table as JSON
gonodes_set_input_table(gn, p, "data_in",
    "[[\"x\",\"y\",\"z\"],[\"1.0\",\"2.0\",\"3.0\"]]");

// Read: retrieve table as JSON string
const char* json = gonodes_get_output_table(gn, p, "data_out");
// json is valid until next gonodes_cook_frame() call
```

### 4. Geometry (SOP Family)

Vertex buffers with positions, normals, UVs, vertex colors, and triangle
indices.  This is the data type that neither TouchEngine (read-only) nor
VUO (compositor-protocol-only) expose as a fully bidirectional C API.

```c
// Write: push a mesh into the engine
float positions[] = { /* xyz × vertex_count */ };
float normals[]   = { /* xyz × vertex_count, or NULL */ };
float uvs[]       = { /* uv  × vertex_count, or NULL */ };
uint32_t indices[] = { /* triangle indices, or NULL for non-indexed */ };

gonodes_set_input_geometry(gn, p, "host_geo",
    positions, normals, uvs, vertex_count,
    indices, index_count);

// Read: get processed geometry back
const gonodes_geometry_data_t* geo =
    gonodes_get_output_geometry(gn, p, "mesh_out");

// geo->positions      — float* (xyz interleaved)
// geo->normals        — float* (xyz interleaved, may be NULL)
// geo->uvs            — float* (uv interleaved, may be NULL)
// geo->colors         — float* (rgba interleaved, may be NULL)
// geo->vertex_count   — int
// geo->indices        — uint32_t*
// geo->index_count    — int
// geo->primitive_type — 0 = triangles, 1 = lines, 2 = points
```

**Use cases:** Projection mapping (host reads fixture geometry from SOP
chain), game-engine mesh exchange (import procedural geometry into Unity/
Unreal), LED layout generation (host pushes fixture positions, reads back
mapped coordinates).

### 5. Volumes (VOL Family)

3D voxel grids — density fields, velocity fields, temperature maps.
Neither TouchEngine nor VUO support volume exchange through their
embedding APIs.  GONODES is the only engine offering this.

```c
// Write: push a 128³ density field into the engine
float density[128*128*128];
// ... fill with voxel data ...
gonodes_set_input_volume(gn, p, "ct_scan_in", density, 128, 128, 128, 1, "density");

// GPU zero-copy path: share a native 3D texture handle
gonodes_set_input_volume_gpu(gn, p, "ct_scan_in", tex_handle, 128, 128, 128, 1, "density");

// Read: GPU output handle (preferred)
gonodes_volume_gpu_handle_t vol_gpu;
gonodes_get_output_volume_gpu(gn, p, "fluid_out", &vol_gpu);
// vol_gpu.native_handle, vol_gpu.width, vol_gpu.height, vol_gpu.depth
```

> **Note:** `gonodes_get_output_volume()` (CPU readback) is not yet
> implemented — use `gonodes_get_output_volume_gpu()` instead.

**Use cases:** Medical imaging hosts push CT/MRI volumes for processing,
simulation hosts push fluid fields for visualization, game engines read
back marching-cubes isosurface extraction results.

### 6. Particles (POP Family)

Per-particle attribute arrays — positions, velocities, colors, ages.
Neither TouchEngine nor VUO support particle data exchange through their
embedding APIs.  GONODES is the only engine offering this.

```c
// Write: push 10,000 particles into the engine
float positions[10000 * 3];  // xyz per particle
float velocities[10000 * 3]; // xyz per particle
float colors[10000 * 4];     // rgba per particle
// ... fill with particle data ...
gonodes_set_input_particles(gn, p, "physics_in",
    positions, velocities, colors, NULL, 10000);

// GPU zero-copy path: share a native GPU buffer handle
gonodes_set_input_particles_gpu(gn, p, "physics_in", buffer_handle, 10000, stride, size);

// Read: GPU output handle (preferred)
gonodes_particle_gpu_handle_t pop_gpu;
gonodes_get_output_particles_gpu(gn, p, "sim_out", &pop_gpu);
// pop_gpu.native_handle, pop_gpu.particle_count
```

> **Note:** `gonodes_get_output_particles()` (CPU readback) is not yet
> implemented — use `gonodes_get_output_particles_gpu()` instead.

**Use cases:** Game engines feed physics particle positions into GONODES
for visual processing (turbulence, color aging), then read back results.
VJ tools push audio-reactive particle sources, read back advected clouds.
Scientific visualization hosts push point cloud datasets for rendering.

### 7. MIDI Events

Direct injection into `MidiInCHOP` operators without parameter decomposition.

```c
gonodes_midi_event_t ev = {
    .status  = 0x90,  // Note On
    .data1   = 60,    // C4
    .data2   = 127,   // velocity
    .channel = 0,
    .port    = 0
};
gonodes_send_midi_event(gn, p, &ev);
```

### 8. OSC Messages

Direct injection into `OscInCHOP` / `OscInDAT` operators.

```c
gonodes_send_osc_message(gn, p, "/control/fader1", "[0.75]");
gonodes_send_osc_message(gn, p, "/cue/fire", "[\"scene_2\", 1.0]");
```

### 9. Events/Triggers

Bidirectional one-shot events — beat triggers, scene changes, cues.

```c
// Host → engine:
gonodes_fire_event(gn, p, "beat", "{\"bpm\": 128}");

// Engine → host:
void my_handler(const char* name, const char* payload, void* ud) {
    printf("Event: %s = %s\n", name, payload);
}
gonodes_set_on_event(gn, my_handler, nullptr);
```

## Parameter Control

Every parameter on every node can be controlled from the host:

```c
// Float
gonodes_set_parameter(gn, p, "noise1", "scale", "8.0");

// Integer
gonodes_set_parameter(gn, p, "noise1", "seed", "42");

// Boolean
gonodes_set_parameter(gn, p, "noise1", "monochrome", "false");

// String
gonodes_set_parameter(gn, p, "text1", "text", "\"Hello\"");

// Color (RGBA array)
gonodes_set_parameter(gn, p, "const1", "color", "[1.0, 0.3, 0.0, 1.0]");

// Vector2i (requires _type wrapper)
gonodes_set_parameter(gn, p, "noise1", "resolution",
    "{\"_type\": \"Vector2i\", \"x\": 1920, \"y\": 1080}");
```

Read parameters back:
```c
const char* val = gonodes_get_parameter(gn, p, "noise1", "scale");
// val = "8.0"
```

## Hot Reload

Enable file-watching for live iteration (per-patch):

```c
gonodes_set_auto_reload(gn, p, 1, 0.5);  // Poll every 0.5 seconds
```

GONODES preserves CHOP channel values, timer positions, and feedback
textures across reloads — only graph topology is reconstituted.

Manual reload:
```c
gonodes_reload_patch(gn, p);
```

## Introspection

Query the patch structure at runtime:

```c
const char* nodes = gonodes_list_nodes(gn, p);
// [{"id":"noise1","type":"noise","family":"TOP"}, ...]

const char* info = gonodes_get_node_info(gn, p, "noise1");
// {"id":"noise1","type":"noise","family":"TOP","inputs":[...],"outputs":[...],...}

const char* params = gonodes_list_parameters(gn, p, "noise1");
// [{"name":"scale","type":"float","value":8.0,"min":0.1,"max":100}, ...]

const char* conns = gonodes_list_connections(gn, p);
// [{"from":"noise1","from_port":0,"to":"comp1","to_port":0}, ...]
```

## Host I/O Manifest

Each `.gnpatch` can declare a standardized interface via the `host_io` key.
The host queries it after loading to discover inputs, outputs, and exposed
parameters without hardcoding node IDs:

```c
const char* io = gonodes_get_host_io(gn, p);
// {
//   "inputs":  [{"label":"Camera A", "family":"TOP", "node":"cam_a", "required":true}, ...],
//   "outputs": [{"label":"Mixed output", "family":"TOP", "node":"main_out"}],
//   "parameters": [{"label":"Mix amount", "node":"comp1", "param":"mix", "type":"float", "range":[0,1]}]
// }
```

If the patch author didn't write a manifest, one is auto-generated from any
HostIn/HostOut bridge operators found in the network.  See
[INTEGRATION.md](../dev_docs/INTEGRATION.md) for the full format spec.

## v2.0.0 — Multi-Patch Architecture

API version 2.0.0 is a **breaking change** that enables multiple concurrent
patches per instance.  One `gonodes_instance_t` boots a single Godot engine,
but can host up to 64 patches simultaneously.  All patches share the GPU
context and rendering pipeline, but each has its own cook engine, node graph,
transport, and I/O registries.

### Key Changes

| v1.x | v2.0 |
|------|------|
| `gonodes_load_patch(gn, path)` returns `int` | Returns `gonodes_patch_t` (opaque handle) |
| `gonodes_unload_patch(gn)` | `gonodes_unload_patch(gn, patch)` |
| All I/O: `func(gn, node_id, ...)` | `func(gn, patch, node_id, ...)` |
| `GONODES_ERR_MAX_INSTANCES` | `GONODES_ERR_MAX_PATCHES` |
| Single patch per instance | Up to 64 concurrent patches |
| Env-var IPC internally | Command queue + response slots (no env-var IPC) |

### Multi-Patch Usage

```c
gonodes_instance_t gn = gonodes_create("project/", &gpu);

// Load two patches.
gonodes_patch_t effects = gonodes_load_patch(gn, "effects.gnpatch");
gonodes_patch_t hud     = gonodes_load_patch(gn, "hud.gnpatch");

// Each patch has independent inputs/outputs.
gonodes_set_input_chop(gn, effects, "audio", "bass", &bass, 1);
gonodes_set_parameter(gn, hud, "text1", "text", "\"Score: 42\"");

// One cook call processes ALL patches.
gonodes_cook_frame(gn, delta);

// Read outputs from each patch independently.
uint64_t fx_tex  = gonodes_get_output_texture(gn, effects, "out", &w, &h);
uint64_t hud_tex = gonodes_get_output_texture(gn, hud, "overlay", &w2, &h2);

// Unload individually.
gonodes_unload_patch(gn, hud);
printf("Remaining patches: %d\n", gonodes_get_patch_count(gn));  // 1

gonodes_destroy(gn);  // Frees all remaining patches.
```

## Advanced Capabilities

The v2.0 API provides comprehensive I/O for all six GONODES data families, MIDI/OSC bridges, transport control, dynamic graph editing, and event triggers.

### Texture Format Query

```c
gonodes_texture_info_t info;
gonodes_get_texture_info(gn, p, "host_out", &info);
// info.format = GONODES_FORMAT_RGBA8, info.channels = 4, etc.
```

### CPU Pixel Input & Readback

```c
// Push CPU pixels into the engine (no GPU handle needed):
gonodes_set_input_pixels(gn, p, "cam_in", rgba_data, 1920, 1080, GONODES_FORMAT_RGBA8, 0);

// Read output pixels to CPU (GPU→CPU readback):
uint8_t* buf = malloc(1920 * 1080 * 4);
gonodes_read_output_pixels(gn, p, "host_out", buf, 1920*1080*4, GONODES_FORMAT_RGBA8, &w, &h);
```

### Geometry/SOP Exchange

```c
// Read geometry from SOP nodes:
const gonodes_geometry_data_t* geo = gonodes_get_output_geometry(gn, p, "sphere1");
// geo->positions, geo->normals, geo->uvs, geo->vertex_count, etc.

// Push geometry into the engine:
gonodes_set_input_geometry(gn, p, "host_geo", positions, normals, uvs, 1024, indices, 3072);
```

### MIDI & OSC Bridge

```c
gonodes_midi_event_t ev = {0x90, 60, 127, 0, 0};  // Note On, C4, vel 127
gonodes_send_midi_event(gn, p, &ev);

gonodes_send_osc_message(gn, p, "/control/fader1", "[0.75]");
```

### Timeline/Transport Control

```c
gonodes_set_transport(gn, p, GONODES_TRANSPORT_PAUSE);
gonodes_set_transport_speed(gn, p, 0.5);   // half speed
gonodes_transport_seek(gn, p, 30.0);       // jump to 30s
double t = gonodes_get_transport_time(gn, p);
```

### Dynamic Graph Editing

```c
gonodes_create_node(gn, p, "my_blur", "BlurTOP");
gonodes_connect(gn, p, "noise1", 0, "my_blur", 0);
gonodes_connect(gn, p, "my_blur", 0, "host_out", 0);
gonodes_delete_node(gn, p, "my_blur");  // auto-removes connections
```

### Event/Trigger System

```c
// Fire one-shot event into the patch:
gonodes_fire_event(gn, p, "beat", "{\"bpm\": 128}");

// Receive events from the patch:
gonodes_set_on_event(gn, my_event_handler, nullptr);
```

### Output Resolution Override

```c
gonodes_set_output_resolution(gn, p, "host_out", 3840, 2160);  // 4K
gonodes_set_output_resolution(gn, p, "host_out", 0, 0);        // revert to patch default
```

## Zero-Copy Data Exchange

True zero-copy paths for all six data families.
GPU data (VOL, POP) uses native texture/buffer handle exchange on a shared
device.  CPU data (CHOP, DAT, SOP) uses pointer lending with frame-scoped
lifetime — pointers passed to `set_input_*_direct()` must remain valid
until the next `gonodes_cook_frame()` call.

### GPU Zero-Copy: Volumes (VOL)

Push and read native 3D texture handles directly — no CPU readback or
upload.  Requires shared GPU context.

```c
// Push a 3D texture handle (VkImage3D / MTLTexture / GLuint).
gonodes_set_input_volume_gpu(gn, p, "host_vol_in",
    my_3d_texture,      // native handle
    64, 64, 64,         // width, height, depth
    1,                  // channels (1=scalar, 4=RGBA)
    "density");         // field name

gonodes_cook_frame(gn, delta);

// Read output 3D texture handle.
gonodes_volume_gpu_handle_t vol;
gonodes_get_output_volume_gpu(gn, p, "host_vol_out", &vol);
// vol.native_handle — directly usable on the shared device
// vol.width/height/depth, vol.channels, vol.format
```

### GPU Zero-Copy: Particles (POP)

Push and read native SSBO handles — the compute pipeline operates on the
buffer in-place.

```c
// Push a particle SSBO (VkBuffer / MTLBuffer / GL buffer object).
gonodes_set_input_particles_gpu(gn, p, "host_pop_in",
    my_ssbo,    // native buffer handle
    10000,      // particle count
    64,         // stride (bytes per particle)
    640000);    // total buffer size in bytes

gonodes_cook_frame(gn, delta);

// Read output SSBO handle.
gonodes_particle_gpu_handle_t pop;
gonodes_get_output_particles_gpu(gn, p, "host_pop_out", &pop);
// pop.native_handle, pop.particle_count, pop.stride, pop.buffer_size
```

### CPU Zero-Copy: Channels (CHOP)

Push multi-channel float data via pointer lending — no env-var encoding or
JSON serialization.  Arrays must stay valid until the next cook.

```c
float lfo[480], rms[480];
const char*  names[]  = {"lfo", "rms"};
const float* data[]   = {lfo, rms};
const int    counts[] = {480, 480};

gonodes_set_input_chop_direct(gn, p, "host_audio",
    names, data, counts, 2);

gonodes_cook_frame(gn, delta);

// Read output channels (pointer lending — valid until next cook).
gonodes_chop_data_t chop;
gonodes_get_output_chop_direct(gn, p, "host_chop_out", &chop);
for (int i = 0; i < chop.channel_count; ++i) {
    printf("  %s: %d samples\n",
           chop.channels[i].name, chop.channels[i].num_samples);
}
```

### CPU Zero-Copy: Tables (DAT)

Push JSON table data via string pointer — no temp files.

```c
const char* json = "[[\"x\",\"y\"],[\"1.0\",\"2.0\"]]";
gonodes_set_input_table_direct(gn, p, "host_data",
    json, (int)strlen(json));
```

### CPU Zero-Copy: Geometry (SOP)

Push vertex attribute arrays via pointer lending — no temp files.

```c
gonodes_set_input_geometry_direct(gn, p, "host_geo",
    positions,   // float* xyz × vertex_count
    normals,     // float* xyz × vertex_count (or NULL)
    uvs,         // float* uv  × vertex_count (or NULL)
    colors,      // float* rgba × vertex_count (or NULL)
    vertex_count,
    indices,     // uint32_t* triangle indices (or NULL)
    index_count);
```

### Data Exchange Summary

| Family | Legacy Path | Zero-Copy Path | Copy Count |
|--------|-------------|----------------------|------------|
| TOP | `set_input_texture` / `get_output_texture` | Same (already zero-copy) | 0 |
| VOL | `set_input_volume` (CPU upload) | `set_input_volume_gpu` / `get_output_volume_gpu` | 0 |
| POP | `set_input_particles` (CPU upload) | `set_input_particles_gpu` / `get_output_particles_gpu` | 0 |
| CHOP | `set_input_chop` (serialized) | `set_input_chop_direct` / `get_output_chop_direct` | 0 |
| DAT | `set_input_table` (serialized) | `set_input_table_direct` | 0 |
| SOP | `set_input_geometry` (temp file) | `set_input_geometry_direct` | 0 |

## Examples

| Example | Renderer | Description |
|---------|----------|-------------|
| [sdl_host](examples/sdl_host/) | OpenGL 3.3 | SDL2 window, fullscreen quad, pixel readback, resolution override |
| [vulkan_host](examples/vulkan_host/) | Vulkan 1.2 | Device sharing, headless cook loop |
| [opengl_host](examples/opengl_host/) | OpenGL 3.3 | GLFW window, GL context sharing |
| [metal_host](examples/metal_host/) | Metal | macOS MTKView, MTLTexture blit |
| [params_demo](examples/params_demo/) | Headless | All parameter types, CHOP/DAT I/O, transport, events |
| [geometry_host](examples/geometry_host/) | Headless | Geometry/SOP exchange, mesh read/write |
| [graph_edit_demo](examples/graph_edit_demo/) | Headless | Runtime node creation, wiring, deletion |
| [midi_osc_host](examples/midi_osc_host/) | Headless | MIDI event injection, OSC routing, event triggers |

### Example Patches

| Patch | Inputs | Outputs | Purpose |
|-------|--------|---------|---------|
| [show.gnpatch](examples/patches/show.gnpatch) | 1 CHOP | 1 TOP | Basic noise visualization (used by visual hosts) |
| [params_test.gnpatch](examples/patches/params_test.gnpatch) | 3 CHOP + 1 DAT | 1 TOP + 1 CHOP + 1 DAT | Full parameter/I/O demo |
| [video_mixer.gnpatch](examples/patches/video_mixer.gnpatch) | 2 TOP + 1 CHOP | 1 TOP | Two-camera composite mixer |
| [data_pipeline.gnpatch](examples/patches/data_pipeline.gnpatch) | 1 DAT + 1 CHOP | 1 DAT + 1 CHOP | Headless data processing (no textures) |
| [sensor_viz.gnpatch](examples/patches/sensor_viz.gnpatch) | 1 CHOP | 1 TOP + 1 CHOP | Cross-family sensor visualization |
| [geometry_demo.gnpatch](examples/patches/geometry_demo.gnpatch) | 1 SOP | 1 SOP + 1 TOP | Geometry exchange — push/read vertex data |
| [graph_edit_base.gnpatch](examples/patches/graph_edit_base.gnpatch) | — | 1 TOP | Minimal base for runtime graph editing |
| [midi_osc_demo.gnpatch](examples/patches/midi_osc_demo.gnpatch) | MIDI + OSC | 1 TOP + 1 CHOP | Protocol bridge with MIDI/OSC inputs |
| [transport_readback.gnpatch](examples/patches/transport_readback.gnpatch) | — | 1 TOP + 1 CHOP | Transport control + CPU pixel readback |

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
| -9 | `GONODES_ERR_MAX_PATCHES` | Patch limit reached (64 per instance) |
| -10 | `GONODES_ERR_UNSUPPORTED` | Feature not available on this platform |
| -11 | `GONODES_ERR_TYPE_MISMATCH` | Node family doesn't match operation |
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

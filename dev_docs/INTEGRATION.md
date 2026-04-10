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
│  │  set_input: texture / chop / table / vol / pop│  │
│  │  get_output: texture / chop / table / vol / pop│ │
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
│  │  │     ├ HostIn:  TOP / CHOP / DAT / VOL / POP│
│  │  │     └ HostOut: TOP / CHOP / DAT / VOL / POP│
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

// v1.2.0: Zero-copy direct injection (pointer lending, frame-scoped).
int gonodes_set_input_volume_gpu(inst, node_id, tex_handle, w, h, d, ch, field);
int gonodes_set_input_particles_gpu(inst, node_id, buf_handle, count, stride, size);
int gonodes_set_input_chop_direct(inst, node_id, names, data, counts, num_ch);
int gonodes_set_input_table_direct(inst, node_id, json_data, length);
int gonodes_set_input_geometry_direct(inst, node_id, pos, nrm, uv, col, vc, idx, ic);
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

// v1.2.0: Zero-copy GPU output (native handles, no CPU readback).
int gonodes_get_output_volume_gpu(inst, node_id, &vol_handle);
int gonodes_get_output_particles_gpu(inst, node_id, &pop_handle);
int gonodes_get_output_chop_direct(inst, node_id, &chop_data);
```

### Introspection

```c
const char* gonodes_list_nodes(inst);              // JSON array of all nodes
const char* gonodes_get_node_info(inst, node_id);  // Detailed node info
const char* gonodes_list_parameters(inst, node_id);// Parameters on a node
const char* gonodes_list_connections(inst);         // All wire connections
const char* gonodes_get_host_io(inst);             // Host I/O manifest (see below)
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

### Texture Info & Format Negotiation (v1.1.0)

```c
// Query full metadata about an output texture — format, channels, API, handle.
// Comparable to TouchEngine's TEInstanceGetTextureDescription().
int gonodes_get_texture_info(inst, node_id, &out_info);
```

`gonodes_texture_info_t` fields:

| Field | Type | Description |
|-------|------|-------------|
| `width` | int | Width in pixels |
| `height` | int | Height in pixels |
| `format` | int | `gonodes_texture_format` enum value |
| `channels` | int | Number of channels (1–4) |
| `native_handle` | uint64_t | VkImage / GLuint / MTLTexture* |
| `graphics_api` | int | Which API the handle belongs to |

### CPU Pixel Input (v1.1.0)

```c
// Push raw CPU pixel data into a HostInTOP — no GPU handle needed.
// Comparable to VuoImage_makeFromBuffer() and TouchEngine's CPU path.
int gonodes_set_input_pixels(inst, node_id, pixels, width, height, format, row_stride);
```

| Parameter | Description |
|-----------|-------------|
| `pixels` | `const void*` — row-major, top-to-bottom pixel data |
| `format` | `gonodes_texture_format` — determines bytes per pixel |
| `row_stride` | Bytes per row (0 = tightly packed) |

### CPU Pixel Readback (v1.1.0)

```c
// Read output texture pixels into a CPU buffer (GPU→CPU readback).
// Comparable to VuoImage_copyBuffer() and TouchEngine's CPU readback.
int gonodes_read_output_pixels(inst, node_id, out_pixels, buffer_size, format,
                                &out_width, &out_height);
```

Returns number of bytes written, or a negative error code.  The host pre-allocates `out_pixels`.

### Geometry/SOP Exchange (v1.1.0)

```c
// Read geometry data from any SOP or COMP node.
const gonodes_geometry_data_t* gonodes_get_output_geometry(inst, node_id);

// Push geometry into a HostInSOP node.
int gonodes_set_input_geometry(inst, node_id, positions, normals, uvs,
                                vertex_count, indices, index_count);
```

`gonodes_geometry_data_t` fields:

| Field | Type | Description |
|-------|------|-------------|
| `positions` | `const float*` | xyz × vertex_count (3 floats per vertex) |
| `normals` | `const float*` | xyz normals (or NULL) |
| `uvs` | `const float*` | uv coords (2 floats per vertex, or NULL) |
| `colors` | `const float*` | rgba colors (4 floats per vertex, or NULL) |
| `vertex_count` | int | Number of vertices |
| `indices` | `const uint32_t*` | Triangle index buffer (or NULL) |
| `index_count` | int | Number of indices (0 if non-indexed) |
| `primitive_type` | int | 0=triangles, 1=lines, 2=points |

### MIDI & OSC Bridge (v1.1.0)

```c
// Send a MIDI event into the engine — routed to MidiInCHOP operators.
int gonodes_send_midi_event(inst, &midi_event);

// Send an OSC message — routed to OscInCHOP / OscInDAT operators.
int gonodes_send_osc_message(inst, "/address/pattern", "[0.75, 1.0]");
```

`gonodes_midi_event_t` fields: `status` (0x80–0xFF), `data1` (0–127), `data2` (0–127), `channel` (0–15), `port` (virtual port index, 0 = default).

### Timeline / Transport Control (v1.1.0)

```c
int    gonodes_set_transport(inst, GONODES_TRANSPORT_PAUSE);  // play/pause/stop
int    gonodes_set_transport_speed(inst, 0.5);                // half speed
int    gonodes_transport_seek(inst, 60.0);                    // jump to 60 seconds
double gonodes_get_transport_time(inst);                      // query current time
```

Transport states: `GONODES_TRANSPORT_PLAY` (0), `GONODES_TRANSPORT_PAUSE` (1), `GONODES_TRANSPORT_STOP` (2).

### Dynamic Graph Editing (v1.1.0)

```c
// Create a node at runtime — surpasses TouchEngine (read-only graphs).
int gonodes_create_node(inst, "my_blur", "BlurTOP");

// Delete a node — connections are removed automatically.
int gonodes_delete_node(inst, "my_blur");

// Wire two nodes together.
int gonodes_connect(inst, "noise1", 0, "my_blur", 0);

// Remove a wire.
int gonodes_disconnect(inst, "noise1", 0, "my_blur", 0);
```

### Event / Trigger System (v1.1.0)

```c
// Fire a named one-shot event into the patch.
// Comparable to VUO's firePublishedInputPortEvent().
int gonodes_fire_event(inst, "beat_trigger", "{\"bpm\": 120}");

// Register callback for events FROM the patch.
void gonodes_set_on_event(inst, my_callback, user_data);
```

Callback signature: `void (*gonodes_event_fn)(inst, event_name, payload_json, user_data)`.

### Output Resolution Override (v1.1.0)

```c
// Override output texture resolution — like VUO's renderOutput:atSize:.
int gonodes_set_output_resolution(inst, "host_out", 3840, 2160);

// Revert to patch default:
int gonodes_set_output_resolution(inst, "host_out", 0, 0);
```

### Zero-Copy GPU: Volumes (v1.2.0)

```c
// Push native 3D texture (VkImage3D / MTLTexture / GLuint) into HostInVOL.
int gonodes_set_input_volume_gpu(inst, node_id, texture_handle,
    width, height, depth, channels, field_name);

// Read native 3D texture handle from HostOutVOL.
gonodes_volume_gpu_handle_t vol;
int gonodes_get_output_volume_gpu(inst, node_id, &vol);
// vol.native_handle, vol.width/height/depth, vol.channels, vol.format
```

### Zero-Copy GPU: Particles (v1.2.0)

```c
// Push native SSBO (VkBuffer / MTLBuffer / GL buffer) into HostInPOP.
int gonodes_set_input_particles_gpu(inst, node_id, buffer_handle,
    particle_count, stride, buffer_size);

// Read native SSBO handle from HostOutPOP.
gonodes_particle_gpu_handle_t pop;
int gonodes_get_output_particles_gpu(inst, node_id, &pop);
// pop.native_handle, pop.particle_count, pop.stride, pop.buffer_size
```

### Zero-Copy CPU: Channels (v1.2.0)

```c
// Push multi-channel float data via pointer lending (no env-var encoding).
int gonodes_set_input_chop_direct(inst, node_id,
    channel_names, channel_data, sample_counts, num_channels);

// Read channel data via pointer lending (frame-scoped lifetime).
gonodes_chop_data_t chop;
int gonodes_get_output_chop_direct(inst, node_id, &chop);
// chop.channels[i].name, chop.channels[i].samples, chop.channels[i].num_samples
```

### Zero-Copy CPU: Tables (v1.2.0)

```c
// Push JSON table data via string pointer (no temp file).
int gonodes_set_input_table_direct(inst, node_id, json_data, length);
```

### Zero-Copy CPU: Geometry (v1.2.0)

```c
// Push vertex attribute arrays via pointer lending (no temp file).
int gonodes_set_input_geometry_direct(inst, node_id,
    positions, normals, uvs, colors, vertex_count,
    indices, index_count);
```

---

## Bridge Operators

Twelve operators bridge data between the host and the GONODES patch graph.  They appear in the node palette like any other operator and are wired into the graph normally.  Bridge operators cover six data domains — textures (TOP), channels (CHOP), tables (DAT), geometry (SOP), volumetric grids (VOL), and particle systems (POP).

| Operator | Family | Direction | C API Function | File |
|----------|--------|-----------|----------------|------|
| **HostInTOP** | TOP | Host → GONODES | `gonodes_set_input_texture()` | `operators/top/host_in_top.gd` |
| **HostInCHOP** | CHOP | Host → GONODES | `gonodes_set_input_chop()` | `operators/chop/host_in_chop.gd` |
| **HostInDAT** | DAT | Host → GONODES | `gonodes_set_input_table()` | `operators/dat/host_in_dat.gd` |
| **HostInSOP** | SOP | Host → GONODES | `gonodes_set_input_geometry()` | C API only (see `gonodes_host.cpp`) |
| **HostInVOL** | VOL | Host → GONODES | `gonodes_set_input_volume()` | `operators/vol/host_in_vol.gd` |
| **HostInPOP** | POP | Host → GONODES | `gonodes_set_input_particles()` | `operators/pop/host_in_pop.gd` |
| **HostOutTOP** | OUT | GONODES → Host | `gonodes_get_output_texture()` | `operators/output/host_out_top.gd` |
| **HostOutCHOP** | OUT | GONODES → Host | `gonodes_get_output_chop()` | `operators/output/host_out_chop.gd` |
| **HostOutDAT** | OUT | GONODES → Host | `gonodes_get_output_table()` | `operators/output/host_out_dat.gd` |
| **HostOutSOP** | OUT | GONODES → Host | `gonodes_get_output_geometry()` | C API only (see `gonodes_host.cpp`) |
| **HostOutVOL** | OUT | GONODES → Host | `gonodes_get_output_volume()` | `operators/output/host_out_vol.gd` |
| **HostOutPOP** | OUT | GONODES → Host | `gonodes_get_output_particles()` | `operators/output/host_out_pop.gd` |

> **Note:** HostInSOP / HostOutSOP are implemented in the C API layer only (`gonodes_host.cpp`) because SOP geometry conversion requires access to Godot's `MeshDataTool` internals.  The other 10 bridge operators have GDScript implementations.

### How Bridge Operators Work

**Input bridge** operators (HostIn*) have a `_set_host_*()` method that `GNEmbeddedHost` calls during `_flush_inputs()` before each cook.  The host's data is injected via the C API, queued internally, then delivered to the operator which `mark_dirty()` triggers a recook.

**Output bridge** operators (HostOut*) are OUT-family sinks (`is_sink = true`).  They appear in the active cooking chain automatically.  After each cook, `GNEmbeddedHost._collect_outputs()` calls their `_get_host_*()` methods to extract the cooked data.

For **HostOutTOP**, the native GPU texture handle is read via `RenderingServer.texture_get_native_handle()` — returning the VkImage / GLuint / MTLTexture directly from Godot's rendering backend.

### The Sink Design Pattern

All HostOut* operators are **structural sink nodes** — `is_sink = true` in their base class `GNOutBase`.  This is a deliberate, load-bearing design choice:

1. **Cook engine BFS seeding** — `GNCookEngine._compute_active_set()` begins a breadth-first walk from every node whose `is_sink` flag is set, traversing upstream through connections.  Every node in the reachable subtree is added to the active set and will cook that frame.
2. **No downstream consumer required** — A HostOutTOP wired at the end of a chain does not need anything downstream in GONODES to consume its output.  The `is_sink` flag alone is sufficient to pull the entire upstream chain into the active set.
3. **Host reads are external** — The host application reads data from HostOut* nodes via the C API *after* the cook completes.  This read happens outside the operator graph.  Without the sink flag, the cook engine would see HostOut* as "unconnected leaves" and exclude them — and their entire upstream — from the active set.
4. **Entire upstream chain stays alive** — If you wire `NoiseVOL → BlurVOL → HostOutVOL`, the sink flag on HostOutVOL ensures all three nodes cook, even though no GONODES operator reads HostOutVOL's output.

```
                  ┌─────────────────────────────────────────────────────┐
                  │  GNCookEngine._compute_active_set()                │
                  │                                                    │
   BFS seeds:     │  WindowOUT ──┐                                     │
   (is_sink=true) │  HostOutTOP ─┤── seed the active-set BFS          │
                  │  HostOutCHOP ┤   → walks upstream through all      │
                  │  HostOutDAT ─┤     connections                     │
                  │  HostOutVOL ─┤   → every reachable node is         │
                  │  HostOutPOP ─┘     marked active and will cook     │
                  └─────────────────────────────────────────────────────┘
```

Without `is_sink = true` on HostOut* nodes, the host would always read stale or empty data because the upstream processing chain would never cook.

### Detailed Bridge Operator Reference

#### HostInTOP / HostOutTOP — Texture Exchange

**HostInTOP** receives pixel data or a GPU texture handle from the host and makes it available as a standard TOP output.  The host pushes data via `gonodes_set_input_texture()`, passing either raw RGBA pixels (CPU path) or a shared GPU texture handle (zero-copy path when GPU contexts are shared).

**HostOutTOP** is a sink that accepts any TOP input and exposes it to the host.  After cooking, `gonodes_get_output_texture()` returns the native GPU handle (VkImage / GLuint / MTLTexture), or the host can call `gonodes_read_output_pixels()` for a CPU readback.

**Use cases:**
- **Camera feed injection** — Push a webcam or SDI capture frame into the patch for processing (blur, color grade, composite), then read the result back for display or streaming
- **Render-to-texture pipeline** — A game engine renders a scene, pushes the texture into GONODES for post-processing (ISF effects, feedback loops, SDF compositing), then reads back the processed frame for final display
- **Multi-output VJ setup** — Push the same camera feed into the patch, apply different effect chains, and read multiple HostOutTOPs for projection mapping zones
- **Video analysis** — Push frames in, use OpenCV operators (BlobTrackIMG, ContourIMG, ColorTrackIMG), then read the processed overlay via HostOutTOP and analysis data via HostOutCHOP/DAT

#### HostInCHOP / HostOutCHOP — Channel Data Exchange

**HostInCHOP** receives multi-channel time-series data from the host.  The host calls `gonodes_set_input_chop()` with channel names and float arrays.  Typical sources: audio buffers, sensor readings, animation curves, UI slider values.

**HostOutCHOP** is a sink that accepts any CHOP input and exposes it.  After cooking, `gonodes_get_output_chop()` returns the channel names and sample arrays.

**Use cases:**
- **Audio analysis pipeline** — Push an audio buffer in, run it through FFT, BeatDetect, and Filter CHOPs, export the analysis results (beat triggers, frequency bands, RMS levels) back to the host for VJ beat sync
- **Sensor data processing** — Push IMU accelerometer/gyroscope data in, apply noise filtering and smoothing CHOPs, export clean values for controlling robotics or projection mapping
- **Animation export** — A GONODES patch generates LFO, noise, or MIDI-driven animation curves; the host reads the cooked CHOP output to drive parameters in Unity/Unreal
- **Machine learning features** — Push raw sensor arrays in, process through ML inference operators, read classification or regression output channels

#### HostInDAT / HostOutDAT — Table/Text Data Exchange

**HostInDAT** receives a 2D string table from the host via `gonodes_set_input_table()`.  The table is a grid of rows × columns where each cell is a string.

**HostOutDAT** is a sink that accepts any DAT input and exposes the table.  After cooking, `gonodes_get_output_table()` returns the cell grid.

**Use cases:**
- **Configuration injection** — Push a settings table (key-value pairs) into the patch to control operator parameters without using the parameter API
- **Metadata export** — A patch that processes video with OpenCV exports detection results (bounding boxes, labels, confidence scores) as a structured table the host can parse
- **OSC address mapping** — Push an address-to-parameter mapping table that the patch uses to route OSC messages dynamically
- **Show control** — Push cue lists or timecode event tables; the patch reads them to trigger scene changes, media playback, or lighting cues

#### HostInSOP / HostOutSOP — Geometry Exchange

**HostInSOP** receives mesh geometry from the host via `gonodes_set_input_geometry()` — positions, normals, UVs, colors, and an index buffer.  The data is packed into a `gonodes_geometry_data_t` struct.

**HostOutSOP** is a sink that reads from the processed SOP chain and exposes the geometry.  `gonodes_get_output_geometry()` returns a `gonodes_geometry_data_t` containing the cooked mesh.

> Both SOP bridge operators are implemented in the C API layer (`gonodes_host.cpp`) rather than GDScript, because geometry conversion requires direct access to Godot's `MeshDataTool`.

**Use cases:**
- **Projection mapping geometry** — Push an architectural 3D model from the host, use GONODES SOP operators (Transform, Subdivide, Deform) to warp it, then read the deformed mesh back for projection calibration
- **Procedural geometry pipeline** — Push a base mesh in, run it through noise deformation, instancing, and boolean SOPs, export the result for rendering in the host's engine
- **Physics mesh exchange** — A physics engine generates collision meshes; push them into GONODES for visualization or further processing, then read modified geometry back
- **Scan processing** — Push raw point cloud or photogrammetry mesh data in for SOP-based cleanup (smooth, decimate, remesh), export the processed geometry

#### HostInVOL / HostOutVOL — Volumetric Data Exchange

**HostInVOL** receives a 3D voxel grid from the host via `gonodes_set_input_volume()`.  The data is a flat `PackedFloat32Array` (or `float*` in C) with dimensions `width × height × depth × channels`.  If the GPU compute backend is available, the data is uploaded to a 3D texture for GPU-accelerated VOL processing; otherwise it falls back to CPU-side arrays.

**HostOutVOL** is a sink that accepts any VOL input and performs a GPU→CPU readback via `RenderingDevice.texture_get_data()` on the 3D texture.  The host then reads the voxel data via `gonodes_get_output_volume()`, which returns a `gonodes_volume_data_t` struct containing the flattened voxels, resolution, channel count, and field name.

**C API struct:**
```c
typedef struct {
    const float* voxels;       // width * height * depth * channels floats
    int          width;
    int          height;
    int          depth;
    int          channels;     // 1=density, 3=velocity, 4=RGBA
    const char*  field_name;   // "density", "temperature", "velocity", etc.
} gonodes_volume_data_t;
```

**Use cases:**
- **Medical imaging** — Push CT or MRI scan slices as a 3D volume, apply GONODES VOL operators (threshold, blur3D, gradient), export the processed volume for custom rendering or analysis
- **Fluid simulation exchange** — A host runs a FLIP/MPM fluid solver and pushes the density, velocity, or temperature field into GONODES for volumetric rendering (PyroVOL, RayMarchVOL), or GONODES generates volumes that the host reads back for coupling
- **Volumetric video** — Push depth-camera point clouds reconstructed into voxel grids, process with VOL operators, export for holographic display systems
- **Signed distance field exchange** — Push an SDF from the host's geometry pipeline, use GONODES VOL operators for ray-marched visualization, boolean operations, or morphological transforms

> **Competitive note:** Neither TouchDesigner's TouchEngine nor VUO supports volumetric data exchange through their embedding APIs.  HostInVOL / HostOutVOL are unique to GONODES.

#### HostInPOP / HostOutPOP — Particle System Exchange

**HostInPOP** receives per-particle data from the host via `gonodes_set_input_particles()`.  The data includes position, velocity, color, and age arrays for each particle.  If the GPU compute backend is available, particles are packed into the standard 64-byte SSBO stride layout (`vec3 pos + float age + vec3 vel + float life + vec4 color + vec4 custom`) for GPU-accelerated POP processing; otherwise it falls back to CPU-side arrays.

**HostOutPOP** is a sink that accepts any POP input and performs an SSBO readback — unpacking the standard 64-byte stride back into per-attribute arrays.  The host reads via `gonodes_get_output_particles()`, which returns a `gonodes_particle_data_t`.

**C API struct:**
```c
typedef struct {
    const float*    positions;       // xyz × particle_count (3 floats each)
    const float*    velocities;      // xyz × particle_count (3 floats each)
    const float*    colors;          // rgba × particle_count (4 floats each)
    const float*    ages;            // 1 float per particle
    int             particle_count;
} gonodes_particle_data_t;
```

**Use cases:**
- **Physics engine coupling** — A host runs its own particle physics (Bullet, PhysX, custom SPH) and pushes particle state into GONODES for visual rendering (GPU instanced sprites, trails, volumetric rendering via PopToVOL), or GONODES runs POP simulations and exports particle data for the host's physics/render engine
- **Point cloud processing** — Push LiDAR or depth-sensor point clouds as particles, run POP operators (noise, attract, limit, sort), export processed point clouds for visualization or analysis
- **Crowd / agent simulation** — A host runs agent AI; push agent positions and states as particles, use GONODES POP operators for visual effects (trails, color mapping by speed), read back modified positions for steering corrections
- **Creative coding / installations** — A GONODES patch generates a complex particle system (audio-reactive, physics-driven, flocking), and the host reads the particle data every frame to render with its own custom renderer

> **Competitive note:** Neither TouchDesigner's TouchEngine nor VUO supports particle data exchange through their embedding APIs.  HostInPOP / HostOutPOP are unique to GONODES.

### Patch Design for Embedding

A typical embedded patch uses HostIn* operators as sources and HostOut* sinks as exports.  The host references bridge nodes by their **node ID** strings:

```
HostInCHOP("sensor_data")  → MathCHOP → FilterCHOP ──────────────┐
HostInTOP("camera_feed")   → BlurTOP → CompositeTOP → HostOutTOP("main_out")
                                             ↑
                               NoiseTOP ─────┘
HostInDAT("config")        → SubstituteDAT → HostOutDAT("status")
HostInVOL("ct_scan")       → ThresholdVOL → BlurVOL → HostOutVOL("processed_vol")
HostInPOP("lidar_points")  → NoisePOP → LimitPOP → HostOutPOP("clean_points")
```

Because every HostOut* operator is a sink, even branches with no downstream GONODES consumer still cook.  The entire upstream chain from `HostInPOP` through `NoisePOP` and `LimitPOP` to `HostOutPOP` cooks every frame — the host simply calls `gonodes_get_output_particles()` after `gonodes_cook_frame()` to read the result.

---

## Host I/O Manifest

The **Host I/O manifest** is a standardized contract that declares a patch's interface for embedded host applications.  It lives as the top-level `"host_io"` key in `.gnpatch` files and is accessible at runtime via the `gonodes_get_host_io()` C API function.

### Why

Without a manifest, every host app must discover bridge operators through introspection and guess which node IDs to bind.  Node IDs are arbitrary — one patch uses `"cam1"`, another uses `"video_input"`.  The manifest solves this by giving bridge nodes semantic labels, declaring required vs. optional inputs, and exposing selected parameters as first-class controls.

The same `.gnpatch` file works across Unity, Unreal, Max/MSP, VDMX, or any custom host.  The host reads the manifest, auto-creates UI bindings and texture slots, and wires to the declared node IDs.

### Format

```json
{
  "version": "1.0.0",
  "host_io": {
    "inputs": [
      {"label": "Camera Feed", "family": "TOP", "node": "host_cam_in", "required": true},
      {"label": "Audio Analysis", "family": "CHOP", "node": "host_audio_in", "required": false},
      {"label": "Config Table", "family": "DAT", "node": "host_config_in", "required": false},
      {"label": "CT Scan Volume", "family": "VOL", "node": "host_vol_in", "required": false},
      {"label": "LiDAR Points", "family": "POP", "node": "host_pop_in", "required": false}
    ],
    "outputs": [
      {"label": "Main Output", "family": "TOP", "node": "host_main_out"},
      {"label": "Data Export", "family": "CHOP", "node": "host_data_out"},
      {"label": "Processed Volume", "family": "VOL", "node": "host_vol_out"},
      {"label": "Clean Points", "family": "POP", "node": "host_pop_out"}
    ],
    "parameters": [
      {"label": "Intensity", "node": "level1", "param": "brightness", "type": "float", "range": [0.0, 1.0]},
      {"label": "Tint Color", "node": "bg1", "param": "color", "type": "color"}
    ]
  },
  "nodes": { ... },
  "connections": [ ... ]
}
```

### Fields

| Key | Required | Description |
|-----|----------|-------------|
| `inputs` | no | Array of HostIn* bridge operator descriptors |
| `outputs` | no | Array of HostOut* bridge operator descriptors |
| `parameters` | no | Array of exposed parameters from any node in the graph |

**Input/Output entries:**

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Human-readable name (for host UI generation) |
| `family` | string | Data family: `"TOP"`, `"CHOP"`, `"DAT"`, `"SOP"`, `"VOL"`, or `"POP"` |
| `node` | string | Node ID in the patch (used with `gonodes_set_input_*` / `gonodes_get_output_*`) |
| `required` | bool | (inputs only) Whether the host must provide this input |

**Parameter entries:**

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Display name for host UI |
| `node` | string | Node ID containing the parameter |
| `param` | string | Parameter name on the node |
| `type` | string | Parameter type: `"float"`, `"int"`, `"bool"`, `"string"`, `"color"`, `"vector2"` |
| `range` | array | (optional) `[min, max]` for numeric types |

### Auto-Generation

If no manifest is authored, `GNNetwork.generate_host_io()` scans the network for HostIn*/HostOut* bridge operators and builds one automatically.  Labels are taken from each bridge operator's `label` parameter (falls back to the node ID).

The auto-generated manifest does not include the `parameters` array — that must be authored manually by the patch designer to select which controls to expose.

### C API

```c
// Returns the host_io manifest as a JSON string.
// Auto-generates from bridge operators if not authored.
// Returns "{}" if no patch loaded or no bridge operators found.
const char* gonodes_get_host_io(gonodes_instance_t inst);
```

### Editor Workflow

The **Host I/O** button on the editor toolbar opens a dialog showing the current manifest as editable JSON.  Use **Regenerate from Bridge Operators** to scan the network, or edit the JSON directly and click **Apply Changes**.  The manifest is saved with the patch on the next File > Save.

### Backward Compatibility

Patches without a `host_io` key work exactly as before — the host uses introspection APIs (`gonodes_list_nodes`, `gonodes_get_node_info`) to discover bridge operators by type.  The manifest is purely additive.

### Coexistence with WindowOUT

A patch can have both WindowOUTs (for standalone Player mode) and HostOutTOPs (for embedded mode).  The manifest only references HostOut* nodes.  When running as a Player, WindowOUTs work normally; when embedded, the host reads from HostOutTOPs and WindowOUTs are ignored (no OS windows in headless).

---

## GNEmbeddedHost Singleton

The GDScript singleton `GNEmbeddedHost` (`addons/gonodes/core/gn_embedded_host.gd`) replaces `player_main.gd` for embedded operation.  It:

1. Registers itself as an Engine singleton on `_ready()`
2. Polls for commands from the C API (patch load/unload/reload)
3. Flushes host input data into bridge operators before each cook
4. Collects output data from bridge operators after each cook
5. Publishes introspection JSON (node list, parameters, connections, host I/O manifest)
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
| -9 | `GONODES_ERR_MAX_INSTANCES` | Instance limit reached (multi-instance) |
| -10 | `GONODES_ERR_UNSUPPORTED` | Feature not available on this platform/build |
| -11 | `GONODES_ERR_TYPE_MISMATCH` | Node family doesn't match the operation |
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

Eight example apps in `libgonodes/examples/` demonstrate different integration patterns:

| Example | Renderer | What It Shows |
|---------|----------|---------------|
| **sdl_host** | SDL2 + OpenGL 3.3 | General-purpose: SDL window, CHOP injection, fullscreen quad output, auto-reload, R key manual reload, pixel readback, resolution override |
| **vulkan_host** | Vulkan 1.2 | Zero-copy: VkDevice sharing, headless cook loop, VkImage output, performance stats |
| **opengl_host** | GLFW + OpenGL 3.3 | Lightweight: GLFW window, GL context extraction per-platform, animated wave input |
| **metal_host** | Metal + MTKView | macOS native: MTLDevice sharing, MTLTexture blit to CAMetalDrawable |
| **params_demo** | Headless (no GPU) | Comprehensive: all parameter types, multi-channel CHOP, DAT tables, introspection, callbacks, transport, events, reload |
| **geometry_host** | Headless | Geometry exchange: push/read vertex data, SOP output extraction, bidirectional mesh pipeline |
| **graph_edit_demo** | Headless | Dynamic graph editing: create/delete nodes, wire connections, build processing chains at runtime |
| **midi_osc_host** | Headless | Protocol bridge: MIDI note/CC injection, OSC message routing, event-driven triggers |

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
    ├── params_demo/              # Parameter control + transport + events demo
    ├── geometry_host/            # Geometry/SOP exchange demo
    ├── graph_edit_demo/          # Dynamic graph editing demo
    ├── midi_osc_host/            # MIDI & OSC protocol bridge demo
    └── patches/                  # Demo .gnpatch files for all examples

addons/gonodes/core/
└── gn_embedded_host.gd           # GDScript bridge singleton

addons/gonodes/operators/
├── top/host_in_top.gd            # HostInTOP bridge
├── chop/host_in_chop.gd          # HostInCHOP bridge
├── dat/host_in_dat.gd            # HostInDAT bridge
├── vol/host_in_vol.gd            # HostInVOL bridge
├── pop/host_in_pop.gd            # HostInPOP bridge
└── output/
    ├── host_out_top.gd           # HostOutTOP bridge (sink)
    ├── host_out_chop.gd          # HostOutCHOP bridge (sink)
    ├── host_out_dat.gd           # HostOutDAT bridge (sink)
    ├── host_out_vol.gd           # HostOutVOL bridge (sink)
    └── host_out_pop.gd           # HostOutPOP bridge (sink)
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

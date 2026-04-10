# LibGONODES vs VDMX Integration of TouchDesigner & VUO — Gap Audit

> **Version:** 1.1.0 (API bump from 1.0.0)
> **Date:** 2026-04
> **Audience:** LibGONODES contributors, host-app integrators, anyone evaluating GONODES as a VDMX/VJ-tool plugin backend.

---

## Purpose

VDMX is the reference benchmark for how a professional VJ tool integrates external visual-processing engines.  It hosts two engines via different SDK pathways:

- **TouchDesigner** via TouchEngine SDK (C/C++ shared library)
- **VUO** via FxPlug / VUO SDK (Objective-C / C compositor nodes)

This document audits the LibGONODES C API (v1.0.0) against both of those integration surfaces, identifies the 10 concrete gaps, and documents the v1.1.0 fixes that close every gap.

---

## Methodology

1. **TouchEngine SDK surface** — reviewed `TEInstanceCreate`, `TEInstanceLink*` getters/setters, `TEInstanceConfigure`, texture description queries, geometry object access, timeline transport, CPU pixel path functions.
2. **VUO/FxPlug surface** — reviewed `VuoRunner`, `VuoImage_makeFromBuffer()`, `VuoImage_copyBuffer()`, `VuoMesh` exchange, `firePublishedInputPortEvent()`, `renderOutput:atSize:`, dynamic composition editing, format negotiation.
3. **LibGONODES v1.0.0 surface** — 25 exported C functions in `gonodes_host.h` covering lifecycle, patch management, frame loop, I/O injection, introspection, callbacks, utilities.
4. **Gap identification** — each capability present in either TouchEngine or VUO that was absent from LibGONODES v1.0.0 was catalogued.

---

## Quick Reference — All 10 Gaps

| # | Gap | TouchEngine | VUO/FxPlug | LibGONODES v1.0.0 | v1.1.0 Fix |
|---|-----|-------------|-----------|-------------------|------------|
| 1 | Multi-Instance | Multiple `TEInstance` per host | Separate `VuoRunner` per composition | Single sentinel handle | Proper per-instance allocation |
| 2 | Texture Format Query | `TEInstanceGetTextureDescription()` | `supportedFormats` protocol | No format/channel info | `gonodes_get_texture_info()` |
| 3 | CPU Pixel Input | CPU buffer path via `TEInstanceLinkSetTextureValue()` | `VuoImage_makeFromBuffer()` | GPU handles only | `gonodes_set_input_pixels()` |
| 4 | Geometry/SOP Exchange | `TEInstanceLinkGetObjectValue()` for meshes | `VuoMesh` exchange | No geometry API | `gonodes_get/set_input_geometry()` |
| 5 | MIDI/OSC Bridge | Native MIDI/OSC protocol routing | MIDI/OSC protocol nodes | Manual param mapping | `gonodes_send_midi_event()` / `send_osc_message()` |
| 6 | Timeline/Transport | SDK transport (play/pause/seek/speed) | Composition time control | Only `delta_seconds` | `gonodes_set_transport()` / `seek()` / `speed()` |
| 7 | Dynamic Graph Editing | Read-only (not supported) | `VuoRunner` rewiring | Not supported | `create_node()` / `delete_node()` / `connect()` / `disconnect()` |
| 8 | Event/Trigger System | `TEInstanceLinkSetBooleanValue()` pulse | `firePublishedInputPortEvent()` | No trigger mechanism | `gonodes_fire_event()` / `set_on_event()` |
| 9 | CPU Texture Readback | CPU readback via `TEInstanceLinkGetTextureValue()` | `VuoImage_copyBuffer()` | GPU handle only | `gonodes_read_output_pixels()` |
| 10 | Output Resolution Override | Host-requested format/resolution | `renderOutput:atSize:` | Baked in patch | `gonodes_set_output_resolution()` |

---

## Detailed Gap Analysis

### Gap 1 — Multi-Instance Support

**The problem**

TouchEngine allocates independent `TEInstance` handles — a VJ host like VDMX creates one per layer or effect slot.  VUO similarly instantiates separate `VuoRunner` objects for each composition.

LibGONODES v1.0.0's `gn_bootstrap_init()` returned a sentinel `(void*)1`.  Only one GONODES engine could exist per process.

**The fix (v1.1.0)**

`gonodes_create()` now allocates a proper `gonodes_instance_s` struct per call, each with its own LibGodot iteration state, transport state, event callbacks, and geometry/pixel caches.  Instance count is bounded by a compile-time `GONODES_MAX_INSTANCES` (default 16).  Exceeding the limit returns `GONODES_ERR_MAX_INSTANCES`.

**Host impact:** Hosts can now create multiple GONODES instances — one per layer, effect slot, or preview — exactly like they do with TouchEngine.

---

### Gap 2 — Texture Format Query / Negotiation

**The problem**

TouchEngine provides `TEInstanceGetTextureDescription()` which returns the full format, channel count, and dimensions of any output texture.  VUO negotiates formats via the `supportedFormats` protocol.

LibGONODES v1.0.0's `gonodes_get_output_texture()` returned only the GPU handle and dimensions (width, height) — no format or channel information.  Hosts had to guess or hardcode RGBA8.

**The fix (v1.1.0)**

New function: `gonodes_get_texture_info(inst, node_id, &info)` fills a `gonodes_texture_info_t` struct containing:

```c
typedef struct gonodes_texture_info {
    int      width;
    int      height;
    int      format;          // gonodes_texture_format enum
    int      channels;        // 1-4
    uint64_t native_handle;   // VkImage / GLuint / MTLTexture*
    int      graphics_api;    // which API the handle belongs to
} gonodes_texture_info_t;
```

Three new texture formats were also added: `GONODES_FORMAT_BGRA8` (5), `GONODES_FORMAT_R16F` (6), `GONODES_FORMAT_RG16F` (7).

**Host impact:** Hosts can query exact output format before binding textures, enabling automatic format conversion or shader selection.

---

### Gap 3 — CPU Pixel Input (Non-GPU Path)

**The problem**

TouchEngine accepts both GPU texture handles AND CPU pixel buffers as input via `TEInstanceLinkSetTextureValue()`.  VUO provides `VuoImage_makeFromBuffer()` for CPU-to-GPU upload.

LibGONODES v1.0.0's `gonodes_set_input_texture()` only accepted GPU handles.  Hosts that receive camera frames, file decodes, or network video on the CPU had to upload to GPU themselves before injecting.

**The fix (v1.1.0)**

New function:

```c
int gonodes_set_input_pixels(
    gonodes_instance_t inst,
    const char* node_id,
    const void* pixels,
    int width, int height,
    int format,
    int row_stride      // 0 = tightly packed
);
```

The host provides a raw byte buffer; LibGONODES handles the CPU→GPU upload internally.

**Host impact:** Camera capture, video decode, and network stream hosts can inject frames without managing GPU uploads.

---

### Gap 4 — SOP/Geometry Exchange

**The problem**

TouchEngine provides `TEInstanceLinkGetObjectValue()` for reading geometry data (vertices, normals, UVs, indices).  VUO exchanges `VuoMesh` objects through its compositor protocol.

LibGONODES v1.0.0 had no way to read or write geometry — only TOP (texture), CHOP (channel), and DAT (table) data was bridged.

**The fix (v1.1.0)**

Two new functions:

```c
// Read geometry from SOP/COMP nodes
const gonodes_geometry_data_t* gonodes_get_output_geometry(
    gonodes_instance_t inst,
    const char* node_id
);

// Push geometry into HostInSOP nodes
int gonodes_set_input_geometry(
    gonodes_instance_t inst,
    const char* node_id,
    const float* positions,    // xyz × vertex_count
    const float* normals,      // xyz × vertex_count (or NULL)
    const float* uvs,          // uv × vertex_count (or NULL)
    int vertex_count,
    const uint32_t* indices,   // triangle indices (or NULL)
    int index_count
);
```

The `gonodes_geometry_data_t` struct includes positions, normals, UVs, colors, vertex count, triangle indices, and primitive type.

**Host impact:** Game engines can exchange 3D meshes bidirectionally; VJ tools can read SOP output for projection mapping or LED fixture geometry.

---

### Gap 5 — MIDI/OSC Bridge Input

**The problem**

VDMX routes MIDI and OSC messages dynamically to TouchDesigner layers as first-class protocol inputs.  VUO has native MIDI/OSC protocol nodes that receive events directly.

LibGONODES v1.0.0 had no C API for pushing MIDI events or OSC bundles.  Hosts had to manually decompose protocol messages into individual parameter values.

**The fix (v1.1.0)**

Two new functions:

```c
int gonodes_send_midi_event(inst, &midi_event);
int gonodes_send_osc_message(inst, "/address/pattern", "[arg1, arg2]");
```

MIDI events are routed to any `MidiInCHOP` operators in the patch.  OSC messages are routed to any `OscInCHOP` / `OscInDAT` operators.

**Host impact:** VDMX/VJ hosts can forward their MIDI controller and OSC input directly into GONODES without manual parameter decomposition.

---

### Gap 6 — Timeline/Transport Control

**The problem**

TouchEngine SDK provides timeline transport control — play, pause, seek, speed.  VUO allows setting composition time base and controlling playback via `VuoRunner`.

LibGONODES v1.0.0 only accepted `delta_seconds` per frame via `gonodes_cook_frame()`.  The host could not pause, seek, or control playback speed independently.

**The fix (v1.1.0)**

Four new functions:

```c
int    gonodes_set_transport(inst, GONODES_TRANSPORT_PLAY);  // play/pause/stop
int    gonodes_set_transport_speed(inst, 2.0);               // 2× speed
int    gonodes_transport_seek(inst, 30.0);                   // jump to 30s
double gonodes_get_transport_time(inst);                     // query current time
```

Transport state is tracked per-instance: `transport_state`, `transport_speed`, `transport_time`.

**Host impact:** VJ tools can synchronize GONODES playback to their own timeline, scrub through time-based effects, and implement speed ramping.

---

### Gap 7 — Dynamic Graph Editing (Runtime Node Creation/Deletion/Wiring)

**The problem**

VUO supports runtime composition modification — creating/deleting nodes and rewiring connections via `VuoRunner::setInputPortValue()`.  TouchEngine does NOT support this (read-only graphs).

LibGONODES v1.0.0 required loading complete `.gnpatch` files.  No runtime graph mutation was possible.

**The fix (v1.1.0)**

Four new functions:

```c
int gonodes_create_node(inst, "my_noise", "NoiseTOP");
int gonodes_delete_node(inst, "my_noise");
int gonodes_connect(inst, "my_noise", 0, "comp1", 1);
int gonodes_disconnect(inst, "my_noise", 0, "comp1", 1);
```

This goes BEYOND what TouchEngine offers — it matches and exceeds VUO's dynamic composition capabilities.

**Host impact:** Hosts can build generative node graphs programmatically, implement visual-programming UIs, or adapt processing chains at runtime.

---

### Gap 8 — Event/Trigger System

**The problem**

TouchEngine provides `TEInstanceLinkSetBooleanValue()` for pulse/trigger parameters.  VUO provides `firePublishedInputPortEvent()` — a fire-and-forget trigger mechanism.

LibGONODES v1.0.0 only supported sustained parameter values.  There was no way to send one-shot triggers.

**The fix (v1.1.0)**

Two new functions:

```c
// Fire a named event into the patch
int gonodes_fire_event(inst, "bang", "{\"intensity\": 1.0}");

// Register callback for events FROM the patch
void gonodes_set_on_event(inst, my_event_callback, user_data);
```

Events are bidirectional — the host can fire triggers INTO the patch (matched to `HostInEvent` operators), and receive events FROM the patch via the callback.

**Host impact:** VJ tools can trigger beat-synced effects, scene transitions, and one-shot animations without polling parameter values.

---

### Gap 9 — CPU Texture Readback

**The problem**

TouchEngine provides CPU readback of output textures via `TEInstanceLinkGetTextureValue()`.  VUO provides `VuoImage_copyBuffer()` for GPU→CPU readback.

LibGONODES v1.0.0's `gonodes_get_output_texture()` only returned a GPU handle.  Hosts that needed pixel data on the CPU (for recording, streaming, or analysis) had to perform their own GPU readback.

**The fix (v1.1.0)**

New function:

```c
int gonodes_read_output_pixels(
    gonodes_instance_t inst,
    const char* node_id,
    void* out_pixels,       // pre-allocated buffer
    int buffer_size,        // in bytes
    int format,             // desired pixel format
    int* out_width,
    int* out_height
);
```

Returns the number of bytes written.  The host provides a pre-allocated buffer; GONODES performs the GPU→CPU readback internally.

**Host impact:** Hosts can encode output to H.264/HEVC for streaming, save to disk, perform CPU-side analysis (motion detection, color sampling), or display in non-GPU UI frameworks.

---

### Gap 10 — Output Resolution Override

**The problem**

TouchEngine allows hosts to request output in specific resolutions.  VUO/FxPlug provides `renderOutput:atSize:` — the host controls the final output texture dimensions.

LibGONODES v1.0.0 used the resolution baked into the patch.  The host had no way to override it.

**The fix (v1.1.0)**

New function:

```c
int gonodes_set_output_resolution(inst, "host_out", 3840, 2160);

// Revert to patch default:
int gonodes_set_output_resolution(inst, "host_out", 0, 0);
```

**Host impact:** The same patch works at any resolution — 1080p for preview, 4K for output, 8K for LED walls — without patch modification.

---

## API Surface Summary

### v1.0.0 (original — 25 functions)

| Category | Functions |
|----------|-----------|
| Lifecycle | `create`, `destroy`, `get_version` |
| Patch | `load_patch`, `unload_patch`, `reload_patch`, `set_auto_reload` |
| Frame | `cook_frame` |
| Input | `set_input_texture`, `set_input_chop`, `set_input_table`, `set_parameter` |
| Output | `get_output_texture`, `get_output_chop`, `get_output_table`, `get_parameter` |
| Introspection | `list_nodes`, `get_node_info`, `list_parameters`, `list_connections`, `get_host_io` |
| Callbacks | `set_on_param_changed`, `set_log_callback` |
| Utilities | `get_last_error`, `get_stats` |

### v1.1.0 additions (~20 new functions)

| Category | Functions | Gap |
|----------|-----------|-----|
| Texture Info | `get_texture_info` | #2 |
| CPU Pixel Input | `set_input_pixels` | #3 |
| CPU Pixel Readback | `read_output_pixels` | #9 |
| Geometry Exchange | `get_output_geometry`, `set_input_geometry` | #4 |
| Volume Exchange | `get_output_volume`, `set_input_volume` | — |
| Particle Exchange | `get_output_particles`, `set_input_particles` | — |
| MIDI/OSC | `send_midi_event`, `send_osc_message` | #5 |
| Transport | `set_transport`, `set_transport_speed`, `transport_seek`, `get_transport_time` | #6 |
| Graph Editing | `create_node`, `delete_node`, `connect`, `disconnect` | #7 |
| Events | `fire_event`, `set_on_event` | #8 |
| Resolution | `set_output_resolution` | #10 |

### New types & enums

| Type | Purpose |
|------|---------|
| `gonodes_texture_info_t` | Texture metadata (format, channels, handle, API) |
| `gonodes_geometry_data_t` | Geometry buffer descriptor (positions, normals, UVs, colors, indices) |
| `gonodes_volume_data_t` | Volume voxel descriptor (3D grid, resolution, channels, field name) |
| `gonodes_particle_data_t` | Particle attribute descriptor (positions, velocities, colors, ages) |
| `gonodes_midi_event_t` | MIDI event (status, data1, data2, channel, port) |
| `gonodes_transport_state` | Transport enum (PLAY, PAUSE, STOP) |
| `gonodes_event_fn` | Event callback typedef |
| `GONODES_ERR_MAX_INSTANCES` | New error code (-9) |
| `GONODES_ERR_UNSUPPORTED` | New error code (-10) |
| `GONODES_ERR_TYPE_MISMATCH` | New error code (-11) |
| `GONODES_FORMAT_BGRA8/R16F/RG16F` | New texture formats (5, 6, 7) |

---

## Competitive Position After v1.1.0

| Capability | TouchEngine | VUO/FxPlug | LibGONODES v1.1.0 |
|-----------|-------------|-----------|-------------------|
| Multi-instance | Yes | Yes | **Yes** |
| Texture format query | Yes | Yes | **Yes** |
| CPU pixel input | Yes | Yes | **Yes** |
| CPU pixel readback | Yes | Yes | **Yes** |
| GPU zero-copy texture | Yes | Limited | **Yes** |
| Geometry exchange | Yes | Yes | **Yes** |
| Volume exchange | **No** | **No** | **Yes (unique)** |
| Particle exchange | **No** | **No** | **Yes (unique)** |
| MIDI/OSC bridge | Via params | Native nodes | **Direct injection** |
| Timeline transport | Yes | Yes | **Yes** |
| Dynamic graph editing | **No** | Yes | **Yes** |
| Event/trigger system | Pulse params | Fire events | **Bidirectional events** |
| Resolution override | Yes | Yes | **Yes** |
| Host I/O manifest | No | No | **Yes (unique)** |
| Introspection API | Limited | Limited | **Full JSON introspection** |
| Hot-reload with state | No | No | **Yes (unique)** |

LibGONODES v1.1.0 now matches or exceeds both TouchEngine and VUO/FxPlug on every integration dimension.  Four capabilities remain unique to GONODES:

1. **Host I/O Manifest** — standardized JSON contract declaring patch inputs, outputs, and exposed parameters.  Neither TouchEngine nor VUO offer this.
2. **Stateful Hot-Reload** — preserves CHOP values, timer positions, and feedback textures across patch reloads.  Neither competitor offers this.
3. **Volume Exchange** — bidirectional 3D voxel grid exchange via `gonodes_set_input_volume()` / `gonodes_get_output_volume()`.  Neither TouchEngine nor VUO can exchange volumetric data through their embedding APIs.
4. **Particle Exchange** — bidirectional per-particle attribute exchange via `gonodes_set_input_particles()` / `gonodes_get_output_particles()`.  Neither competitor offers particle-level data exchange.

---

## Files Changed

| File | Changes |
|------|---------|
| `libgonodes/include/gonodes_host.h` | API version bump to 1.1.0; 3 new error codes; 3 new texture formats; 5 new structs/typedefs; ~20 new function declarations |
| `libgonodes/src/gonodes_bootstrap.h` | Extended `gonodes_instance_s` with transport, geometry, event, pixel readback fields |
| `libgonodes/src/gonodes_host.cpp` | ~600 lines of new implementations for all 10 gaps; updated `create()` and `destroy()` |

---

## See Also

- [INTEGRATION.md](INTEGRATION.md) — Full C API reference and integration guide
- [libgonodes README](../libgonodes/README.md) — Quick-start and build instructions
- [gonodes_host.h](../libgonodes/include/gonodes_host.h) — Public C API header

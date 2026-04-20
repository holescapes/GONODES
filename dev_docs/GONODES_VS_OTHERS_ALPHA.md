# GONODES vs Others (Alpha Assessment)

> **Date:** 2026-04-15
> **Status:** Alpha — comprehensive competitive landscape analysis
> **Audience:** Core developers, prospective contributors, strategic roadmap planning
> **Purpose:** Exhaustive feature-by-feature comparison between GONODES and its three primary competitors: **TouchDesigner**, **vvvv**, and **Jitter** (Max/MSP/Cycling '74). Covers every significant axis — from cook architecture to host embedding, operator coverage to community ecosystem.
>
> This document complements `GONODES_VS_THE_REST.md` (which focuses on cook-flow architecture and optimization) with a broader product-level and strategic comparison. Where the existing doc answers "how does GONODES compare technically?", this doc answers "**where does GONODES stand as a product and what should the roadmap prioritize?**"

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [The Contenders — Identity & Positioning](#2-the-contenders--identity--positioning)
3. [Licensing, Cost & Business Model](#3-licensing-cost--business-model)
4. [Cook Architecture & Evaluation Strategy](#4-cook-architecture--evaluation-strategy)
5. [GPU Pipeline & Rendering](#5-gpu-pipeline--rendering)
6. [CPU Performance & Language](#6-cpu-performance--language)
7. [Operator / Node Coverage](#7-operator--node-coverage)
8. [Data Types & Families](#8-data-types--families)
9. [Host Embedding — The libgonodes Advantage](#9-host-embedding--the-libgonodes-advantage)
10. [3D Engine Integration](#10-3d-engine-integration)
11. [Scripting & Extensibility](#11-scripting--extensibility)
12. [Shader Authoring](#12-shader-authoring)
13. [I/O Protocols & External Integration](#13-io-protocols--external-integration)
14. [Asset & Project Management](#14-asset--project-management)
15. [UI & Editor Experience](#15-ui--editor-experience)
16. [Cross-Platform & Deployment](#16-cross-platform--deployment)
17. [Audio Pipeline](#17-audio-pipeline)
18. [Physics & Simulation](#18-physics--simulation)
19. [Machine Learning & Computer Vision](#19-machine-learning--computer-vision)
20. [Community, Ecosystem & Learning Resources](#20-community-ecosystem--learning-resources)
21. [Performance Benchmarks (Qualitative)](#21-performance-benchmarks-qualitative)
22. [Unique Strengths Per Tool](#22-unique-strengths-per-tool)
23. [Feature Gap Matrix — What GONODES Is Missing](#23-feature-gap-matrix--what-gonodes-is-missing)
24. [Roadmap Priorities Derived From This Analysis](#24-roadmap-priorities-derived-from-this-analysis)
25. [Conclusion](#25-conclusion)

---

## 1. Executive Summary

| Dimension | TouchDesigner | vvvv | Jitter (Max/MSP) | GONODES |
|-----------|--------------|------|-------------------|---------|
| **Maturity** | 20+ years, industry standard | 25+ years (beta→gamma transition) | 25+ years, deep audio roots | Alpha — 1 year of development |
| **Operator count** | ~300+ built-in | ~700+ (gamma nodes) | ~200+ Jitter objects + 400+ Max objects | **537 operators** across 14 families |
| **Cost** | $2,200+ / $600 non-comm. | Free (gamma) | $399 (perpetual) or $99/yr sub | **Free, open source (MIT)** |
| **GPU pipeline** | DirectX 11/12, OpenGL, Vulkan | DirectX 11 (beta) / Stride+Vulkan (gamma) | OpenGL (legacy) / Metal (modern) | Vulkan + GLES3 via Godot 4.6 |
| **Host embedding** | TouchEngine SDK | No | Max for Live; no general SDK | **libgonodes — full C API, 9 data contexts** |
| **3D engine** | Built-in (limited) | Stride (gamma) | OpenGL/Metal (via `jit.gl.*`) | **Full Godot 4.6** (physics, audio, VR) |
| **Best for** | AV installations, VJing, media art | Generative art, data visualization, installations | Audio-visual performance, experimental music | Real-time AV, VJing, generative art, embedded processing |

**Bottom line:** GONODES is architecturally competitive with tools that have decades of development. Its unique advantages — open source, Godot engine integration, libgonodes host embedding, volumetric/SDF pipelines, and 3-tier scripting (GDScript/Python/C++) — position it for scenarios that no single competitor addresses. The honest gaps are maturity, community size, serial GPU cook, and adaptive quality degradation.

---

## 2. The Contenders — Identity & Positioning

### TouchDesigner (Derivative)
- **Born:** 2004 (evolved from Houdini's PRISMS/TouchDesigner lineage)
- **Identity:** The industry standard for real-time interactive media, AV installations, projection mapping, and VJ performance
- **Philosophy:** Monolithic application — everything built in, commercial license, Windows-first (macOS experimental)
- **User base:** Thousands of studios, artists, installers worldwide. Dominant in corporate events, museum installations, music tours
- **Key strength:** Breadth of built-in functionality, massive community, battle-tested in production for 20+ years

### vvvv (vvvv group)
- **Born:** 1998 (beta) → 2020+ (gamma/VL rewrite)
- **Identity:** Visual programming for creative coding, installations, and data visualization. European art/design community stronghold
- **Philosophy:** Two distinct versions — beta (DirectX 11, everything evaluates every frame, Boygrouping) and gamma (modern .NET/Stride, hybrid evaluation, cross-platform)
- **User base:** Thousands, concentrated in Germany/Europe. Popular in art installations, architecture visualization, and creative tech studios
- **Key strength:** vvvv gamma's VL (visual language) — a genuinely innovative visual programming paradigm with .NET JIT performance. Boygroup multi-client synchronization (beta)

### Jitter (Cycling '74 / Max/MSP)
- **Born:** 2001 (as part of Max/MSP 4.5; Max itself dates to 1988 at IRCAM)
- **Identity:** The visual component of Max/MSP — a real-time matrix/video/3D processing environment. Max is primarily an audio/MIDI tool; Jitter adds visual processing
- **Philosophy:** Audio-first architecture with video grafted on. Everything is a "matrix" (N-dimensional typed array). Strong academic and experimental music roots
- **User base:** Academic institutions, experimental musicians, media artists, interactive art. Smaller than TD for pure visual work, but the Max ecosystem is massive
- **Key strength:** Deep, seamless audio-visual integration. Max's dataflow paradigm, IRCAM heritage, Gen~ code generation for audio/GPU, and integration with Ableton Live (Max for Live)

### GONODES
- **Born:** 2025 (alpha)
- **Identity:** Open-source real-time node-based visual framework built on Godot 4.6, inspired by TouchDesigner
- **Philosophy:** Leverage a modern open-source game engine (Godot) for rendering, audio, physics, and cross-platform export. Extension architecture for modular I/O. C API (libgonodes) for embedding in host applications
- **Key strength:** Open source, Godot engine integration, embeddable via libgonodes, 3-tier scripting, volumetric/SDF compute pipelines, cross-platform (including web/mobile export)

---

## 3. Licensing, Cost & Business Model

| Aspect | TouchDesigner | vvvv | Jitter (Max/MSP) | GONODES |
|--------|--------------|------|-------------------|---------|
| **License type** | Commercial (subscription or perpetual) | Free (gamma); beta: legacy free non-comm | Perpetual ($399) or subscription ($99/yr) | MIT open source |
| **Non-commercial** | Free (1280×1280 cap, watermark) | Free (no restrictions in gamma) | Education discount; no free tier | Free (no restrictions) |
| **Commercial** | $2,200 (perpetual) or $600/yr | Free (gamma); $2,400/yr (beta enterprise) | $399 perpetual | Free |
| **Resolution limits** | Free: 1280×1280. Commercial: unlimited | None | None | **None** |
| **Source available** | No (proprietary) | No (gamma: closed .NET) | No (proprietary) | **Yes — full source** |
| **Deployment license** | Included in commercial license; free version adds watermark | Free | Included | **Free — no licensing for deployment** |
| **Revenue model** | Software license sales | Community + consulting | Software license + Ableton partnership | None (community-driven) |

**GONODES advantage:** Zero cost at any scale. No resolution limits, no watermarks, no deployment fees, no dongles. Full source code access. This is a profound differentiator for students, artists, small studios, and anyone building custom installations. The only cost is development time and hardware.

**Risk for GONODES:** No revenue model means development depends on contributor goodwill and (potentially) grants/sponsorship. Competitors have dedicated engineering teams funded by license revenue.

---

## 4. Cook Architecture & Evaluation Strategy

| Aspect | TouchDesigner | vvvv beta | vvvv gamma | Jitter | GONODES |
|--------|-------------|-----------|------------|--------|---------|
| **Paradigm** | Pull (demand-driven) | Push (everything runs) | Hybrid (mutation tracking) | Pull-ish (lazy scheduler) | Push, triple-guarded |
| **Dirty propagation** | Node-level subtree cascade | None | .NET mutation tracking | Object dirty flags | Expression dep map + input hash |
| **Inactive subgraph cost** | Zero | Full | Reduced | Near-zero | Zero (active set culling) |
| **Multi-output demand** | All ports always computed | All outputs run | Improved | All outlets fire | Per-port demand culling |
| **Steady-state cost** | 0 cooks (clean graph) | All nodes cook | Reduced | Near-zero | 0 cooks (hash guard) |
| **Cascade stopping** | Never (full subtree) | N/A | Partial | Limited | **Yes — hash guard stops cascade** |

### Jitter's Evaluation Model

Jitter operates within Max's scheduler, which has two threads: the **main (low-priority) thread** for UI and most message passing, and the **audio (high-priority) thread** for MSP signal processing. Jitter objects (`jit.*`) typically run in the main thread.

Jitter uses a **lazy pull** model — `jit.gl.*` rendering objects request matrices from upstream when they need to render. Standard `jit.*` matrix processors are triggered by messages (`bang`, `jit_matrix`) flowing through patch cords. This is effectively push-triggered but demand-gated: a `jit.gl.render` object requests its scene graph every frame, cascading upstream.

Jitter does **not** have a sophisticated dirty propagation system. Objects process whenever they receive a message. If you send a `bang` to `jit.noise`, it generates a new matrix and sends it downstream — regardless of whether anything changed. There is no hash guard or input comparison.

For OpenGL/Metal rendering, `jit.gl.render` drives a frame loop. Connected `jit.gl.*` objects participate in a render pass. Objects not connected to a render context have zero GPU cost.

### GONODES Advantages Over Jitter

- **Input hash guard** prevents unnecessary cooks when inputs haven't changed — Jitter re-processes on every received message
- **Active set culling** ensures disconnected subgraphs have zero cost — comparable to Jitter's render-context model but applied to all families, not just GL
- **Multi-output demand culling** — Jitter sends all outlets on every cook; GONODES only computes demanded ports
- **Non-realtime mode** — Jitter lacks deterministic offline rendering (tied to Max's scheduler clock)

### Jitter Advantages Over GONODES

- **Lower per-message latency** — Max's lightweight message passing has minimal overhead per object
- **Audio-synchronized scheduling** — Jitter can lock to MSP's sample-accurate audio clock, ensuring video-audio sync at the scheduler level. GONODES relies on Godot's `_process()` frame loop

---

## 5. GPU Pipeline & Rendering

| Aspect | TouchDesigner | vvvv beta | vvvv gamma | Jitter | GONODES |
|--------|-------------|-----------|------------|--------|---------|
| **Graphics API** | DX11/12, OpenGL, Vulkan | DirectX 11 | Stride (Vulkan/DX) | OpenGL (legacy) / Metal | Vulkan + GLES3 (Godot) |
| **GPU compute** | Full (GLSL/HLSL compute) | Limited | Stride compute | Gen (codegen→GLSL) | RenderingDevice compute |
| **Shader language** | GLSL, HLSL | HLSL | Stride SDSL shaders | GLSL (Gen) | GLSL (canvas_item + compute) |
| **Multi-stream GPU** | **Yes** — parallel command queues | No | Partial (Stride) | No | No (Godot limitation) |
| **Multi-GPU** | **Yes** | No | No | No | No |
| **Texture pooling** | **Yes** | DX11 resource mgmt | Stride pools | OpenGL texture objects | No (per-node SubViewport) |
| **Render pipeline** | Custom (Derivative engine) | DX11 immediate | Stride deferred/forward | OpenGL fixed+shader | Godot Forward+ / Compatibility |
| **Ray tracing** | No | No | No | No | No (Godot has experimental) |

### Jitter's GPU Architecture

Jitter's GPU story has evolved significantly:

- **Legacy (`jit.gl.*`):** OpenGL immediate mode (2.x era) with display lists and basic GLSL shaders. Still widely used but showing its age.
- **Modern (`jit.gl.*`):** Metal support on macOS (since Max 8.3), improved shader compilation, MRT (multiple render targets).
- **Gen for GPU:** `jit.gl.pix` and `jit.gl.mesh` compile Gen patches to GLSL fragment/vertex shaders. This is Jitter's most powerful GPU feature — visual shader programming with automatic GLSL code generation.
- **Texture2D pipeline:** `jit.gl.texture` + `jit.gl.slab` (shader processing) + `jit.gl.node` (render-to-texture) form a GPU TOP-like chain. Slab applies fragment shaders to textures.

**Key limitation:** Jitter lacks GPU compute shaders entirely (no counterpart to ComputeShaderTOP). Gen compiles to fragment/vertex shaders only. SSBO-based particle systems (like GONODES POP) and volumetric compute (like GONODES VOL) have no equivalent in Jitter.

### GONODES vs Jitter GPU Comparison

| Capability | Jitter | GONODES |
|-----------|--------|---------|
| Fragment shader processing | `jit.gl.slab` + Gen→GLSL | CustomShaderTOP, ISF, Shadertoy |
| Compute shaders | **Not available** | ComputeShaderTOP, POP compute, VOL compute |
| GPU particles | None (CPU `jit.phys.*` only) | **13 POP operators — SSBO compute pipeline** |
| GPU volumes | None | **15 VOL operators — 3D texture compute** |
| SDF rendering | None | **29 SDF operators** |
| Render-to-texture | `jit.gl.node` | SubViewport per TOP |
| Visual shader editor | Gen (codegen) | None (text-based GLSL) |

GONODES has a significantly more capable GPU compute pipeline than Jitter. Jitter's Gen is elegant for visual shader programming, but it can only target fragment/vertex shaders — no compute shader output.

---

## 6. CPU Performance & Language

| Aspect | TouchDesigner | vvvv beta | vvvv gamma | Jitter | GONODES |
|--------|-------------|-----------|------------|--------|---------|
| **Core language** | C++ | C++ | .NET C# (RyuJIT) | C (Max SDK) + Java (MXJ) | GDScript + 93 C++ GDExtension |
| **User scripting** | Python | None (visual only) | VL (.NET JIT) | JavaScript (Node for Max), Java, Gen | GDScript, Python, C++ |
| **Expression eval** | Python (interpreted) | N/A (pin-based) | .NET IL (JIT) | Max expressions (interpreted) | GDScript Expression |
| **Data throughput** | ~1M pts/frame (C++ SOPs) | ~1M pts/frame (C++) | ~500K pts/frame (.NET) | ~50K–200K cells/frame (Jitter matrix) | ~100K–500K pts/frame (native), ~10K–50K (GDScript) |
| **Thread model** | Multi-threaded (Thread CHOP) | Some parallelism | .NET Task parallelism | Main thread + audio thread | WorkerThreadPool per topo level |

### Jitter's Performance Profile

Jitter's core matrix operations (`jit.op`, `jit.expr`, `jit.bfg`) are written in C and are fast for their time, but they show their age:

- **Matrix ops are single-threaded** by default. `@parallel 1` enables per-plane parallelism on some objects, but threading granularity is coarse.
- **No SIMD vectorization** in most standard objects — C code predates SSE/AVX era optimizations.
- **Gen code generation** produces efficient C code for custom operations, compiled to native. This is Jitter's best CPU performance path.
- **JavaScript (Node for Max)** is V8-based and significantly faster than Max's built-in expression evaluator, but adds latency from IPC (Max↔Node run in separate processes).

For typical VJ workflows (720p–1080p video processing), Jitter's CPU performance is adequate. For 4K or high-resolution matrix operations, it falls behind TD and GONODES's native operators.

### Performance Hierarchy (approximate, for per-element CPU work)

```
Fastest ──────────────────────────────────────── Slowest

Houdini VEX (LLVM JIT)
  │
TD C++ operators
  │
vvvv gamma VL (.NET JIT)
  │
GONODES native C++ (GDExtension)
  │
Jitter Gen (compiled C)
  │
Jitter C objects (jit.op, etc.)
  │
GONODES Python+NumPy (vectorized)
  │
TD Python scripting
  │
Jitter JavaScript (Node for Max, V8)
  │
Max expressions / JS (legacy)
  │
GONODES GDScript (interpreted)
```

---

## 7. Operator / Node Coverage

| Family / Category | TouchDesigner | vvvv gamma | Jitter / Max | GONODES |
|-------------------|--------------|-----------|-------------|---------|
| **Texture/image processing** | ~90 TOPs | ~100+ nodes | ~60 `jit.gl.*` + `jit.*` | **139 TOPs + 37 IMGs** |
| **Signal/channel processing** | ~70 CHOPs | ~80+ nodes | ~200+ MSP objects†† | **82 CHOPs** |
| **Geometry/mesh** | ~50 SOPs | ~40+ nodes | ~30 `jit.gl.*` mesh ops | **74 SOPs** |
| **Data tables/text** | ~30 DATs | ~20+ nodes | ~10 `jit.cellblock` etc. | **47 DATs** |
| **Materials** | ~10 MATs | ~15+ (Stride materials) | ~5 shader objects | **12 MATs** |
| **Scene composition** | ~25 COMPs | ~30+ nodes | ~15 `jit.gl.*` scene | **23 COMPs** |
| **GPU particles** | Particle SOP (legacy) | None built-in | None | **13 POP operators** |
| **3D Volumes** | Not native | Not native | None | **15 VOL operators** |
| **SDF rendering** | Not native | None | None | **29 SDF operators** |
| **UI widgets** | Panel COMP widgets | ~30+ UI nodes | Max UI objects (separate) | **36 UI operators** |
| **Output/export** | Built-in (Record, etc.) | Built-in | `jit.record`, `jit.movie` | **11 OUT operators** |
| **Networking/subnets** | — | — | — | **15 NET operators** |
| **Script operators** | Python DAT/callbacks | VL (visual code) | Gen, JavaScript | **3 SCRIPT operators** |
| **Total** | **~300+ built-in** | **~700+ nodes** | **~200+ Jitter + 400+ Max** | **537 operators** |

†† Max/MSP's ~400+ audio objects (MSP `~` objects) are a separate domain from Jitter's visual objects. Counting them together inflates Max's numbers but misrepresents the visual processing capability. Jitter alone has ~200 objects.

### Where GONODES Leads in Operator Coverage

1. **GPU Volume pipeline:** 15 VOL operators (Navier-Stokes fluid, raymarching, marching cubes, pyro). No competitor has this built-in.
2. **SDF rendering:** 29 operators (ray-marched signed distance fields). No competitor offers this natively.
3. **GPU Particles:** 13 POP operators (SSBO compute). TD has legacy Particle SOP; vvvv and Jitter have nothing built-in.
4. **Texture operators:** 139 TOPs + 37 IMGs = 176 texture/image operators — exceeds all competitors.
5. **Geometry operators:** 74 SOPs — exceeds TD (~50) and Jitter (~30), comparable to vvvv.

### Where GONODES Trails

1. **Audio synthesis:** Max/MSP has 400+ audio objects — an entire audio programming language. GONODES has 8 audio CHOPs. This is the single largest coverage gap, but audio synthesis is not GONODES's primary domain.
2. **Time-tested edge cases:** TD's ~300 operators have been refined through 20 years of production use. Edge cases, error handling, and parameter ranges are battle-hardened. GONODES operators are new and may have undiscovered issues.
3. **Specialized video I/O:** TD has native support for dozens of video capture cards, LED controllers, DMX universes, and laser DACs. GONODES covers the major protocols via extensions but lacks the breadth of TD's hardware partner integrations.

---

## 8. Data Types & Families

| Data concept | TouchDesigner | vvvv | Jitter | GONODES |
|-------------|--------------|------|--------|---------|
| **GPU texture** | TOP (2D texture) | Texture (Stride) | `jit.gl.texture` (2D) | TOP (SubViewport texture) |
| **CPU image** | TOP (CPU mode) | Image | `jit.matrix` (char/float planes) | IMG (Image-based) |
| **Multi-channel float** | CHOP (channels) | Spread (beta) / Sequence (gamma) | `jit.matrix` (1D float array) | CHOP (Dictionary of PackedFloat32Array) |
| **Table/text** | DAT (rows×cols) | Spreadsheet (gamma) | `jit.cellblock` / Dictionary | DAT (GNTableData) |
| **Geometry/mesh** | SOP (point/poly) | Mesh (Stride) | `jit.gl.mesh` + `jit.matrix` (vertex data) | SOP (ArrayMesh via GNGeoData) |
| **Material** | MAT | Material (Stride) | Shader/texture bindings | MAT (ShaderMaterial/Standard) |
| **3D scene graph** | COMP hierarchy | SceneGraph (Stride) | `jit.gl.render` context | COMP (Godot Node3D tree) |
| **GPU particles** | Not typed | Not typed | Not typed | **POP (SSBO particle buffers)** |
| **3D volumes** | Not typed | Not typed | Not typed | **VOL (Texture3D voxel grids)** |
| **SDF** | Not typed | Not typed | Not typed | **SDF (ray-marched fields)** |

### Jitter's Matrix Model

Jitter's core data type is `jit.matrix` — an N-dimensional typed array. Any Jitter object can process matrices of arbitrary dimension, plane count, and type (char, long, float32, float64). This is extremely flexible:

- A 320×240 RGBA image is a `jit.matrix 4 char 320 240` (2D, 4 planes, 8-bit)
- A 480-sample stereo audio buffer is a `jit.matrix 2 float32 480` (1D, 2 planes, 32-bit)
- A 100-particle position buffer is a `jit.matrix 3 float32 100` (1D, 3 planes)

This universality means Jitter objects can do things like "blur audio" or "apply video effects to geometry data" — they don't care about semantics, just array dimensions. This is both a strength (flexibility) and a weakness (no type safety, no family-specific optimization).

### GONODES Advantage: Type-Safe Families

GONODES's 13 distinct families (TOP, IMG, CHOP, DAT, SOP, POP, VOL, COMP, MAT, OUT, UI, SDF, SCRIPT) provide:
- **Port-level type checking** — can't connect a CHOP output to a TOP input accidentally
- **Family-specific base classes** with optimized infrastructure (SubViewport for TOPs, SSBO for POPs, Texture3D for VOLs)
- **Family-aware palette filtering** — drop a wire and only compatible operators appear
- **Data-specific viewer rendering** — waveforms for CHOP, orbit camera for SOP, slice viewer for VOL

Jitter's typeless matrix model trades this safety for flexibility. For beginners learning visual programming, GONODES's typed families are significantly less confusing.

---

## 9. Host Embedding — The libgonodes Advantage

This is GONODES's most unique capability and the area where it has clear superiority over all competitors.

### Comparison Matrix

| Capability | TouchEngine SDK | vvvv | Jitter / Max | libgonodes |
|-----------|----------------|------|-------------|------------|
| **Embed in host apps** | Yes (TouchEngine) | No | Max for Live only (Ableton) | **Yes — any C-calling app** |
| **GPU context sharing** | Yes (shared device) | N/A | No | **Yes (Vulkan, Metal, OpenGL)** |
| **Bidirectional textures** | Yes (zero-copy) | N/A | No | **Yes (zero-copy)** |
| **Bidirectional channels** | Yes (float arrays) | N/A | Limited (Live API) | **Yes (multi-channel CHOP)** |
| **Bidirectional tables** | Yes (string tables) | N/A | No | **Yes (row×col tables)** |
| **Bidirectional geometry** | **Read-only** | N/A | No | **Yes (full bidirectional)** |
| **Bidirectional volumes** | **Not supported** | N/A | No | **Yes** |
| **Bidirectional particles** | **Not supported** | N/A | No | **Yes** |
| **MIDI injection** | Parameter mapping only | N/A | Native (Ableton→Max) | **Direct MIDI events** |
| **OSC injection** | Parameter mapping only | N/A | Native `udpreceive` | **Direct OSC messages** |
| **Bidirectional events** | Pulse params (host→only) | N/A | No | **Yes (fire_event / on_event)** |
| **Graph editing from host** | **Not supported** | N/A | No | **Full CRUD (create/delete/connect)** |
| **Parameter control** | Yes (all types) | N/A | Limited (Live API params) | **Yes (all types)** |
| **Hot reload** | Yes | N/A | No | **Yes (with state preservation)** |
| **Data contexts** | 4 (texture, channels, table, limited geo) | 0 | 1 (Ableton params) | **9 (texture, channels, table, geo, volume, particles, MIDI, OSC, events)** |

### What This Means

**libgonodes is the only embeddable node-graph engine that supports bidirectional exchange of 9 data contexts through a single C API.** No other tool comes close:

- **TouchEngine** is the nearest competitor but lacks bidirectional geometry, volume, and particle exchange. It also can't edit the graph at runtime from the host.
- **vvvv** has no embedding capability at all.
- **Jitter** can be embedded only within Ableton Live (Max for Live), with extremely limited data exchange — essentially just parameter automation and MIDI.

### Use Cases This Enables (That No Competitor Can)

1. **Game engine integration:** Unity/Unreal/Godot apps embed libgonodes for real-time visual processing. Host pushes game geometry → GONODES processes (fluid sim, particle effects) → host reads back results. Impossible with TouchEngine (no bidirectional geometry).

2. **VJ software plugins:** VDMX, Resolume, or custom VJ tools embed libgonodes as an FxPlug/VST-like plugin. GPU context sharing means zero-copy texture exchange. Hot reload enables live patch editing during performance.

3. **Scientific visualization:** Hosts push volumetric data (CT scans, fluid simulations) into GONODES for GPU-accelerated rendering (raymarching, marching cubes, slicing). Impossible with any competitor — no other tool supports volume data exchange through an embedding API.

4. **Media servers:** LED mapping tools push fixture geometry → GONODES processes → tool reads back mapped color data. Bidirectional SOP exchange makes this seamless.

5. **Runtime graph editing:** Host applications can create nodes, make connections, and modify the processing graph entirely from the C API — enabling procedural graph construction for generative systems. TouchEngine has no graph editing capability.

### Example Host Integration Code

```c
#include <gonodes_host.h>

// Boot GONODES with shared Vulkan device
gonodes_gpu_context_t gpu = {
    .graphics_api = GONODES_GFX_VULKAN,
    .vulkan_instance = my_instance,
    .vulkan_physical_device = my_phys_dev,
    .vulkan_device = my_device
};
gonodes_instance_t gn = gonodes_create("project/", &gpu);
gonodes_load_patch(gn, "effects.gnpatch");

// Frame loop
gonodes_set_input_texture(gn, "cam_in", vk_image, 1920, 1080);
gonodes_set_input_chop(gn, "audio_in", fft_data, 2, 512);
gonodes_cook_frame(gn, delta);
uint64_t result = gonodes_get_output_texture(gn, "main_out", &w, &h);
// result is a VkImage on the shared device — bind directly
```

---

## 10. 3D Engine Integration

| Feature | TouchDesigner | vvvv beta | vvvv gamma | Jitter | GONODES |
|---------|-------------|-----------|------------|--------|---------|
| **Underlying engine** | Custom (Derivative) | Custom (DX11) | Stride (Vulkan-based) | None (raw GL/Metal) | **Godot 4.6** |
| **Physics** | Bullet (legacy) | Box2D/Bullet plugins | Bepu Physics (Stride) | None built-in | **Jolt Physics (modern)** |
| **Scene graph** | COMP hierarchy | SceneGraph | Stride SceneGraph | `jit.gl.render` context | **Godot Node3D tree** |
| **Lighting** | Basic (legacy pipeline) | DX11 deferred | Stride PBR | OpenGL fixed-function + GLSL | **Godot Forward+ PBR** |
| **Shadows** | Basic shadowmaps | VSM, CSM plugins | Stride shadowmaps | Manual (fragment shader) | **Godot CSM + PCF** |
| **Post-processing** | GLSL TOPs (manual) | Plugins | Stride post-process | Manual slab chains | **Built-in (glow, DOF, SSAO, SSIL, SSR, fog)** |
| **VR/AR** | OpenVR/OpenXR plugin | Plugin | Partial | None | **Godot OpenXR** |
| **PBR materials** | Phong + custom shaders | PBR (DX11 plugins) | Stride PBR | Manual shaders | **StandardMaterial3D (full PBR)** |
| **Animation** | Basic + CHOP-driven | Timeline | Stride animation | None | **AnimationCOMP + KeyframeCHOP** |
| **Instancing** | Instance COMP | Instancing (DX11) | Stride instancing | `jit.gl.mesh @draw_mode instanced` | **InstanceCOMP (MultiMesh)** |
| **Terrain** | Not built-in | Not built-in | Not built-in | Not built-in | **HeightfieldSOP** |

### Jitter's 3D Capabilities

Jitter's 3D pipeline is functional but dated:

- No built-in scene graph — users manually manage render order with `jit.gl.render @erase_color` and draw callbacks
- No built-in physics (third-party `jit.phys.*` package by Robert Ramirez is discontinued)
- Lighting is basic OpenGL per-vertex or per-fragment with manual shader setup
- No PBR material system — users write GLSL manually
- No shadows without manual implementation
- No post-processing pipeline — everything is manual slab chains

### GONODES Advantage: Full Godot Engine

GONODES operators run inside Godot 4.6, which means:
- **Full PBR rendering pipeline** with Forward+ or mobile Compatibility renderer
- **Jolt physics** (rigid body, soft body, vehicle, constraints) out of the box
- **Audio engine** with spatial 3D audio, bus effects, spectrum analysis
- **OpenXR** for VR/AR experiences
- **Particle systems** (Godot GPUParticles3D available alongside GONODES POP)
- **Navigation/pathfinding**, **animation**, **terrain**, **decals**, **volumetric fog**

No competitor offers this breadth of engine features. TD has a custom engine that's competent but doesn't match a modern game engine's rendering quality. vvvv gamma's Stride is capable but newer and less feature-complete. Jitter has almost nothing built-in for 3D.

---

## 11. Scripting & Extensibility

| Feature | TouchDesigner | vvvv gamma | Jitter / Max | GONODES |
|---------|-------------|-----------|-------------|---------|
| **Built-in scripting** | Python | VL (visual .NET) | JavaScript, Gen, Java | GDScript |
| **User code tiers** | 1 (Python only) | 1 (VL/.NET only) | 3 (JavaScript, Gen, Java/C) | **3 (GDScript, Python+NumPy, C++)** |
| **C/C++ plugin SDK** | **No** | Yes (vvvv SDK) | Yes (Max SDK, C/C++) | **GDExtension + UserNative hot-reload** |
| **Python ecosystem** | Embedded Python (limited imports) | No Python | No Python (Node.js instead) | **Full Python (NumPy, OpenCV, scipy)** |
| **Hot-reload C++** | Not possible | N/A (.NET hot-reload) | No (must rebuild external) | **Yes — 2–8s compile + reload** |
| **Visual code gen** | No | **VL** (genuine innovation) | **Gen** (GLSL/MSP code gen) | No |
| **Shader authoring** | GLSL TOP | HLSL/SDSL | Gen→GLSL | GLSL + ISF + Shadertoy |
| **Event scripting** | Script CHOP/DAT | Reactive (VL) | `js` object, `coll`, `buddy` | CallbackDAT |
| **Asset packaging** | `.tox` | NuGet packages | Max patchers + packages | `.gnasset` (JSON) |

### Jitter/Max Extensibility Deep Dive

Max has a mature but complex extension story:

- **Max SDK (C):** Write "externals" — compiled C objects that plug into Max. Powerful but low-level. Must compile per-platform. No hot-reload (must restart Max).
- **Gen:** Visual code generation — a patching environment within Max that compiles to optimized C (for MSP audio) or GLSL (for Jitter GPU). This is genuinely innovative and has no equivalent in GONODES.
- **JavaScript (Node for Max):** V8-based JS runtime running in a separate Node.js process. Good performance, modern API, but IPC latency between Max and Node processes can be noticeable.
- **Java (MXJ):** JVM-based objects. Mostly used in academic settings. Performance is adequate.
- **Max packages:** Distribution format for sharing objects, help files, and media. Well-established ecosystem on Max's package manager.

### GONODES's 3-Tier Advantage

GONODES's three scripting tiers directly address different user profiles:

| Tier | Language | Performance | Setup | Target User |
|------|----------|-------------|-------|-------------|
| 1 | GDScript | ~10–50× slower than C++ | Zero | Beginners, quick prototyping |
| 2 | Python + NumPy | ~2–5× slower than C++ (vectorized) | Install Python | TD refugees, data scientists |
| 3 | C++ (GDExtension) | Native speed | Compiler toolchain | Power users, performance-critical |

**No other tool offers this progression.** TD is Python-only (no C++ path). vvvv is VL-only. Jitter has Gen+JS+Java+C, but the C SDK requires restarting Max and has no integrated editor.

GONODES's C++ path includes an in-editor code editor, templates, examples, and 2–8 second hot-reload — closer to Unreal's Live Coding than to Houdini's HDK.

---

## 12. Shader Authoring

| Feature | TouchDesigner | vvvv | Jitter | GONODES |
|---------|-------------|------|--------|---------|
| **Fragment shaders** | GLSL TOP | HLSL (beta), SDSL (gamma) | Gen→GLSL, raw GLSL | CustomShaderTOP (GLSL) |
| **Compute shaders** | GLSL Compute TOP | Stride compute (gamma) | **Not available** | ComputeShaderTOP |
| **ISF format** | No | No | No | **Yes (gn_ext_isf)** |
| **Shadertoy format** | No | No | No | **Yes (gn_ext_shadertoy)** |
| **Visual shader editor** | No | **VL→shader** (partial) | **Gen** (visual codegen) | No |
| **Shader presets** | No | No | No | **Yes (factory + user)** |
| **GLSL hot-reload** | Manual | Manual | Via Gen patching | **Automatic (file watcher)** |
| **Multi-pass** | Manual chain | Manual | Manual slab chain | FeedbackTOP + shader chain |

### Jitter Gen — A Unique Approach

Gen is Jitter's standout shader feature: a visual patching environment that compiles to GLSL (for GPU) or optimized C (for CPU audio). Users patch with math operators, and Gen generates the shader code. This lowers the barrier to GPU programming significantly — no GLSL syntax knowledge needed.

GONODES has no visual shader editor, but compensates with:
- **ISF support** — Interactive Shader Format, a cross-platform shader standard with a large community library
- **Shadertoy support** — one-click import of thousands of shaders from shadertoy.com
- **Shader presets** — save/load custom shader configurations with factory examples

The visual shader editing gap is real but less critical given ISF/Shadertoy compatibility and the wealth of existing shaders available in those formats.

---

## 13. I/O Protocols & External Integration

| Protocol | TouchDesigner | vvvv | Jitter / Max | GONODES |
|----------|-------------|------|-------------|---------|
| **OSC** | Built-in | Built-in | Built-in (`udpsend/receive`) | Built-in (In/Out) |
| **MIDI** | Built-in (In/Out) | Built-in | **Built-in (core strength)** | gn_ext_midi (RtMidi) |
| **NDI** | Built-in | Plugin | No | gn_ext_ndi (4 ops) |
| **Spout** | Built-in | Built-in (DX11) | Spout plugin (Mac: no) | gn_ext_spout |
| **Syphon** | Built-in | No | Syphon plugin | gn_ext_syphon |
| **Video capture** | Built-in (extensive) | Built-in | `jit.grab` (basic) | gn_ext_video_capture |
| **Serial** | Built-in | Built-in | Built-in (`serial`) | gn_ext_serial |
| **DMX/Art-Net** | Built-in (extensive) | Plugins | `dmxusbpro` (limited) | DmxOutCHOP + DmxInCHOP + ArtnetDAT |
| **MQTT/IoT** | Python plugin | Plugin | None | **MqttDAT (built-in)** |
| **WebSocket** | Built-in | Plugin | Node for Max | WebSocketDAT |
| **HTTP server** | Built-in | Plugin | Node for Max | WebServerDAT |
| **Depth sensors** | Kinect, RealSense, ZED, Leap | Kinect, Nuitrack, RealSense | None | gn_ext_depth_sensor (3 backends) |
| **Blackmagic** | Built-in | Plugin | None | gn_ext_blackmagic (scaffold) |
| **ML inference** | TensorFlow, MediaPipe plugins | ML.NET, ONNX | None | gn_ext_ml (ONNX Runtime, 7 ops) |
| **Projection mapping** | Stoner, Kantan Mapper | Badmapper | None | gn_ext_mapper (10 ops) |
| **Laser DAC** | Via Python/plugins | None | None | Not yet |
| **Ableton Live** | Not integrated | No | **Max for Live (deep integration)** | Not integrated |
| **Hardware I/O breadth** | **Best in class** (decades of hardware partnerships) | Good (community plugins) | Good (Max packages) | Good (extension architecture) |

### Jitter/Max I/O Strength: MIDI & Audio

Max's I/O heritage is audio and MIDI — it was literally built for this. MIDI in Max is first-class: `notein`, `ctlin`, `bendin`, `pgmin`, `sysexin` — dedicated objects for every MIDI message type with sample-accurate timing. This reflects decades of focus on electronic music performance.

For MIDI, Max/Jitter is the gold standard. GONODES's MIDI extension (via RtMidi) is functional but less refined.

### GONODES's Extension Architecture Advantage

GONODES's GDExtension addon system (`gn_ext_*`) makes adding new I/O protocols a well-defined process:
- Declarative manifest (`gn_extension.cfg`)
- Automatic operator registration via GNExtensionRegistry
- Help patches, presets, and tests in self-contained addon directories
- CI/CD for cross-platform native builds (`build/gn_build.py`)

This is more structured than TD's "write a Python plugin" or Max's "write a C external" approach. Adding a new I/O protocol to GONODES is a defined, repeatable process with tooling support.

---

## 14. Asset & Project Management

| Feature | TouchDesigner | vvvv | Jitter / Max | GONODES |
|---------|-------------|------|-------------|---------|
| **Project format** | `.toe` (binary) | `.vl` (XML in gamma) | `.maxpat` (JSON) | `.gnpatch` (JSON) |
| **Version control friendly** | No (binary) | Partial (XML) | **Yes (JSON)** | **Yes (JSON)** |
| **Reusable assets** | `.tox` (COMP export) | NuGet packages | Max patchers + packages | `.gnasset` (JSON, self-contained) |
| **Asset promotion** | Manual | N/A | Subpatch encapsulation | **Wizard-based (spare params → interface)** |
| **Instance sync** | Inline (auto-update) | NuGet versioning | Package versioning | Global `.gnasset` sync on save |
| **Read-only assets** | No | N/A | No | **Yes (lock + "Make Editable" escape hatch)** |
| **Help patches per node** | Yes (~1 per node) | Yes | Yes (~2–3 per node) | **Yes (3+ per node, 1,413 total)** |
| **Package manager** | No (community sharing) | NuGet | **Max Package Manager** | No (file-based) |
| **OS drag-and-drop** | Limited | No | No | **Yes (.gnpatch + .gnasset files)** |
| **Undo/redo** | Yes | Yes | Yes | **Yes (compound actions)** |
| **Copy/paste** | Yes | Yes | Yes | **Yes (JSON clipboard)** |

### Jitter/Max's Package Ecosystem

Max has a mature package manager that's a genuine strength — thousands of community packages covering MIDI controllers, audio effects, video processing, ML, and more. `jit.mo` (motion), `jit.bfg` (noise), the VIZZIE library (beginner-friendly video effects) — all installable from within Max.

GONODES has no package manager yet. The extension architecture (`gn_ext_*`) provides the foundation, but there's no discovery/install mechanism beyond manually placing addons.

---

## 15. UI & Editor Experience

| Feature | TouchDesigner | vvvv | Jitter / Max | GONODES |
|---------|-------------|------|-------------|---------|
| **Node graph style** | Wired, left→right flow | Wired, spread-based (beta); VL (gamma) | Wired, top→down patcher | Wired, left→right (Godot GraphEdit) |
| **Live node previews** | Yes (TOP thumbnails) | Yes (pins show data) | No (patchers are static) | **Yes (per-node toggle)** |
| **Parameter inspector** | Right-click dialog | Inspector (gamma) | Object inspector | **Docked inspector panel** |
| **Performance profiling** | Yes (per-node cook time) | Yes (frame profiler) | No (manual timing) | **Yes (per-node + per-expression µs)** |
| **Debug tools** | Probe, Info CHOP | Tooltip pins, Renderer | `print`, `jit.print` | **Debug panel (F2, 3 tabs, 5 overlay layers)** |
| **Code editor** | External (Atom, etc.) | Integrated (VL) | Integrated (Gen) | **Integrated (GNCodeEditor, syntax HL)** |
| **Context menus** | Yes | Yes | Yes | **Yes (right-click, copy as JSON)** |
| **Network boxes** | Not built-in | No | None | **Yes (annotations + sticky notes)** |
| **Timeline** | Basic | Basic | Transport bar | **TimelineCHOP + CueDAT + Editor UI** |
| **Keyboard shortcuts** | Extensive | Extensive | Extensive | Growing |
| **Multi-monitor** | Yes (separate windows) | Yes | Yes | WindowOUT (separate windows) |
| **Float field control** | Slider + text field | Slider | Number box + slider | **Houdini-style (drag, ladder tiers, Shift/Ctrl modifiers)** |

### Jitter/Max Editor Experience

Max's patcher window is fundamentally different from node-graph tools:
- **Top-down flow** (messages flow down, not left-to-right)
- **No live previews** — you can't see texture thumbnails on nodes (must open a `jit.pwindow` or `jit.gl.render` window)
- **Locked/unlocked modes** — edit mode (unlock) vs performance mode (lock). In performance mode, UI objects become interactive. This is unique and powerful for building custom interfaces.
- **Presentation mode** — a second visual layer where you arrange UI elements for end-user interaction, hiding the patcher underneath

Max's UI building story (presentation mode, bpatcher embedding, Max for Live device creation) is more mature than GONODES's UI operators, though GONODES's UI family provides a node-graph-integrated approach that's arguably more flexible for generative/reactive UIs.

---

## 16. Cross-Platform & Deployment

| Platform | TouchDesigner | vvvv beta | vvvv gamma | Jitter / Max | GONODES |
|----------|-------------|-----------|------------|-------------|---------|
| **Windows** | Primary | Yes | Yes | Yes | **Yes** |
| **macOS** | Experimental | No | Yes | Yes | **Yes** |
| **Linux** | No | No | Yes | No | **Yes** |
| **Web (HTML5)** | No | No | No (planned) | No | **Yes (Godot export)** |
| **iOS** | No | No | No | No (MIRA remote only) | **Yes (Godot export)** |
| **Android** | No | No | No | No | **Yes (Godot export)** |
| **Standalone export** | Yes (Player, TouchEngine) | Yes (exe) | Yes (.exe, runtime) | No (requires Max) | **Yes (Godot export templates)** |
| **Headless/server** | Limited (TouchEngine) | Yes (beta server) | Yes (.NET console) | No | **Yes (exported player)** |
| **ARM64** | No | No | Planned | Apple Silicon (Rosetta) | **Yes (native ARM64)** |

### GONODES's Platform Advantage

GONODES inherits Godot's exceptional cross-platform story:
- **6 target platforms** with native builds (Windows, macOS, Linux, iOS, Android, Web)
- **ARM64 native** on all platforms (not Rosetta emulation)
- **Web exports** via Emscripten — run GONODES patches in a browser
- **Mobile exports** — generative art on phones/tablets
- **Standalone player** — exported patches run without GONODES editor

No competitor matches this breadth:
- **TD** is Windows-primary (macOS is experimental/incomplete, no Linux, no mobile, no web)
- **vvvv gamma** is Windows/macOS/Linux but no mobile or web
- **Max/Jitter** is Windows/macOS only, requires Max runtime (except embedded in Ableton), no standalone export

For artists creating installations on Raspberry Pi, web-based generative art, or mobile interactive experiences, GONODES is the only option among these tools.

---

## 17. Audio Pipeline

| Feature | TouchDesigner | vvvv | Jitter / Max | GONODES |
|---------|-------------|------|-------------|---------|
| **Audio synthesis** | Limited (via CHOP) | Limited | **400+ MSP objects — complete audio language** | Limited (8 audio CHOPs) |
| **Sample-accurate timing** | No (frame-based) | No | **Yes (MSP signal vector)** | No (frame-based) |
| **Audio effects** | Basic (via CHOP math) | Basic | **Complete (EQ, reverb, delay, compression, etc.)** | AudioDynamicsCHOP (compressor/limiter/gate) |
| **FFT analysis** | AudioSpectrum CHOP | Plugins | `pfft~` (phase vocoder) | AudioSpectrumCHOP + AudioBandCHOP |
| **Audio I/O** | 1 device | Basic | **ASIO, CoreAudio, multi-device** | 1 device (Godot AudioServer) |
| **MIDI→audio** | Via CHOP→audio | Via nodes | **Native (noteout~, etc.)** | Via CHOP→AudioDeviceOUT |
| **DAW integration** | No | No | **Max for Live (full Ableton integration)** | No |
| **Spatial audio** | No | No | `mc.` (multichannel) | **Godot AudioStreamPlayer3D** |
| **Audio recording** | Via FFmpeg | No | `sfrecord~` (WAV/AIFF) | RecordOUT (via FFmpeg) |

### Jitter/Max's Audio Dominance

This is Jitter's (or rather, Max/MSP's) strongest category and the biggest gap between GONODES and the Max ecosystem. Max/MSP is fundamentally an audio programming environment with 35+ years of development. The MSP signal processing layer runs at audio sample rate (typically 44100 Hz) with buffer sizes of 64–512 samples — giving sub-millisecond latency for audio processing.

Key MSP capabilities with no GONODES equivalent:
- **Synthesis:** Oscillators, wavetable, granular, FM, additive, physical modeling
- **Spatial:** `mc.` multichannel objects, ambisonics (`hoa.*`), binaural HRTF
- **Analysis:** FFT with phase vocoder, pitch tracking, onset detection, MFCCs
- **Effects:** Biquad filters, reverb, delay, chorus, distortion, ring modulation
- **MIDI sequencing:** Pattern generators, arpeggiators, step sequencers

**However:** This gap is less critical than it appears for GONODES's target use case. GONODES targets **visual art and VJing**, not audio production. Audio analysis (FFT, beat detection) and basic audio output exist. Full audio synthesis is a different domain, and users who need it likely already use Ableton/Max, SuperCollider, or a DAW.

### Roadmap Consideration

GONODES's audio gap analysis (see `GONODES_VS_THE_REST.md` §18.8) identifies 13 missing audio operators across 3 tiers. Implementing Tier 1 (AudioOscillatorCHOP, AudioFilterCHOP, AudioMixCHOP, AudioParaEQCHOP) would enable basic audio-reactive synthesis chains. Full audio synthesis parity with Max is neither achievable nor desirable — it would be reinventing a 35-year-old wheel.

---

## 18. Physics & Simulation

| Feature | TouchDesigner | vvvv | Jitter / Max | GONODES |
|---------|-------------|------|-------------|---------|
| **Physics engine** | Bullet (legacy) | Box2D, Bullet plugins | None built-in (deprecated `jit.phys.*`) | **Jolt Physics (modern)** |
| **Rigid body** | Bullet | Plugins | Deprecated | **RigidBodyCOMP** |
| **Soft body** | No | No | No | **SoftBodyCOMP** |
| **Cloth** | Not built-in | No | No | **ClothSOP (Verlet PBD)** |
| **Vehicle physics** | No | No | No | **VehicleCOMP (Jolt)** |
| **Constraints/joints** | Basic | Basic | No | **JointCOMP (6 joint types)** |
| **Fluid sim** | Plugin/GLSL workaround | No | No | **FluidVOL (3D Navier-Stokes) + Fluid2DTOP** |
| **Particle sim** | Legacy Particle SOP | No | Deprecated `jit.phys.*` | **14 POP operators (GPU compute)** |
| **Pyro (fire/smoke)** | Not built-in | No | No | **PyroVOL** |
| **Navigation/pathfinding** | No | No | No | **NavigationCOMP** |

GONODES has the strongest physics/simulation offering of all four tools, thanks to Godot's Jolt integration and the custom GPU compute pipelines (POP, VOL).

---

## 19. Machine Learning & Computer Vision

| Feature | TouchDesigner | vvvv | Jitter / Max | GONODES |
|---------|-------------|------|-------------|---------|
| **ML framework** | TensorFlow, PyTorch plugins | ML.NET, ONNX (gamma) | None built-in | **gn_ext_ml (ONNX Runtime)** |
| **Object detection** | MediaPipe plugin | YOLO plugin | None | **ObjectDetectDAT** |
| **Pose estimation** | MediaPipe plugin | None | None | **PoseDetectCHOP** |
| **Face detection** | MediaPipe plugin | None | None | **FaceDetectCHOP** |
| **Hand tracking** | MediaPipe plugin | None | None | **HandDetectCHOP** |
| **Style transfer** | Plugin | None | None | **StyleTransferTOP** |
| **Depth estimation** | Plugin | None | None | **DepthEstimateTOP** |
| **Segmentation** | Plugin | None | None | **SegmentationTOP** |
| **Custom models** | Yes (Python) | Yes (.NET) | No | **OnnxInferenceTOP (any ONNX model)** |
| **Depth sensors** | Kinect, RealSense, ZED, Leap, Orbbec | Kinect, RealSense, Nuitrack | None | **gn_ext_depth_sensor (3 backends)** |

All four tools have ML capabilities through extensions or plugins. GONODES's gn_ext_ml with 7 dedicated operators provides a well-integrated experience, but TD's MediaPipe integration is more mature and covers more models.

---

## 20. Community, Ecosystem & Learning Resources

| Aspect | TouchDesigner | vvvv | Jitter / Max | GONODES |
|--------|-------------|------|-------------|---------|
| **Community size** | Large (tens of thousands) | Medium (thousands, EU-focused) | Large (Max community; Jitter subset) | **Small (early alpha)** |
| **Forum** | forum.derivative.ca (very active) | discourse.vvvv.org | cycling74.com/forums | N/A |
| **Tutorials** | Hundreds (YouTube, courses) | Good documentation + tutorials | Extensive (30+ years of books, courses) | Minimal (help patches only) |
| **Books** | Several third-party | "vvvv — a Multipurpose Toolkit" | Dozens (Max/MSP, Jitter, Gen) | None |
| **Courses** | Interactive & Immersive HQ, YouTube channels | NODE festival workshops | Kadenze, Berklee, many universities | None |
| **Package ecosystem** | Palette (community .tox) | NuGet (gamma), Contribution (beta) | **Max Package Manager (thousands)** | gn_ext_* addons (manual) |
| **Industrial adoption** | High (studios, agencies, events) | Medium (installations, architecture) | Medium (academic, music) | None yet |
| **Job market** | Growing (TD-specific job postings) | Niche | Academic + music industry | None |
| **Documentation** | Good (wiki + Forum) | Good (gamma), aging (beta) | Extensive (Max docs + Jitter tutorials) | 1,413 help patches + dev docs |
| **Example database** | Palette examples | Girlpower demo folder | Jitter-examples, Recipe series | 1,413 help patches |

### This Is GONODES's Biggest Gap

Community and ecosystem are arguably more important than technical features for adoption. All three competitors have:
- Years of community-contributed content, tutorials, and examples
- Paid courses and educational partnerships
- Studio adoption and production track records
- Established forums with active support

GONODES has none of this yet. The 1,413 help patches provide excellent per-operator documentation, but there are no tutorials, no courses, no community creators, and no production track record.

**Mitigation strategy:**
1. The open-source model can attract contributors faster than commercial tools
2. The Godot ecosystem (2M+ developers) is a potential recruitment pool
3. TD's high cost ($2,200+) creates a natural market for a free alternative
4. Quality documentation (help patches, dev docs) lowers the learning curve

---

## 21. Performance Benchmarks (Qualitative)

Precise benchmarks depend on hardware and workload, but qualitative performance tiers are well-established:

### Scenario: 1080p Shader Chain (10 GPU TOPs)

| Tool | Expected Performance | Why |
|------|---------------------|-----|
| TouchDesigner | 60 fps, low latency | C++ engine, multi-stream GPU, battle-tested optimization |
| vvvv gamma | 55–60 fps | Stride/Vulkan still maturing |
| Jitter | 45–60 fps | OpenGL/Metal, single-threaded GL context |
| GONODES | 55–60 fps | Godot RenderingDevice, single render thread, hash guard prevents wasted redraw |

### Scenario: Heavy CPU SOP Processing (50K vertices, 5 deformers)

| Tool | Expected Performance | Why |
|------|---------------------|-----|
| TouchDesigner | Rock-solid 60 fps | C++ SOPs, internally threaded |
| vvvv gamma | 50–60 fps | .NET JIT, good but not C++-level |
| Jitter | 30–50 fps | C matrix ops but single-threaded, no SOP-equivalent |
| GONODES (native ops) | 50–60 fps | C++ GDExtension, WorkerThreadPool |
| GONODES (GDScript ops) | 20–40 fps | GDScript interpretation bottleneck |

### Scenario: 200-Node Mixed Network

| Tool | Expected Performance | Why |
|------|---------------------|-----|
| TouchDesigner | 60 fps (pull skips untouched branches) | Mature optimizer |
| vvvv gamma | 40–55 fps (depending on mutation tracking efficiency) | .NET GC pauses possible |
| Jitter | Not applicable (200 objects in Max is unusual/impractical) | Max wasn't designed for large networks |
| GONODES | 50–60 fps (hash guard + active set = minimal unnecessary work) | Alpha — less optimization |

**Note:** Jitter/Max patches rarely reach 200 objects for visual processing alone. Max's top-down patcher UI becomes unwieldy at that scale. TD and GONODES are designed for larger networks.

---

## 22. Unique Strengths Per Tool

### TouchDesigner — Only In TD

1. **Multi-stream GPU cook** — parallel command queues for independent TOP chains
2. **Adaptive quality degradation** — automatic resolution/quality reduction to hit frame targets
3. **Multi-GPU distribution** — split chains across GPUs
4. **Deepest hardware I/O** — decades of hardware manufacturer partnerships (Blackmagic, AJA, NVIDIA, Intel RealSense, Ultraleap, etc.)
5. **TouchEngine SDK** — embed TD processing in other apps (limited vs libgonodes, but mature and battle-tested)
6. **Industry adoption** — the de facto standard; clients request TD by name

### vvvv — Only In vvvv

1. **VL (Visual Language)** — a genuinely innovative visual OOP system compiled to .NET IL. This is a unique programming paradigm
2. **Boygroup** — multi-client synchronized rendering for multi-screen installations (beta only, being rebuilt for gamma)
3. **Stride integration** — a proper game engine (Stride, Vulkan-based) inside a node-based tool
4. **Free gamma** — no cost, no restrictions, .NET ecosystem access
5. **European creative tech community** — strong presence in Germany/Austria/Switzerland art and design

### Jitter / Max — Only In Max

1. **Audio-visual integration** — seamless bridge between world-class audio (MSP) and visual processing (Jitter). No other tool can synthesize audio, process video, and sync them with sample-accurate timing in one environment
2. **Gen** — visual code generation to optimized C (audio) or GLSL (GPU). Lower barrier to GPU programming than writing GLSL
3. **Max for Live** — deep integration with Ableton Live for audio-visual performance. Millions of Ableton users are potential Max users
4. **Presentation mode** — build custom end-user interfaces without coding by arranging UI objects on a separate visual layer
5. **Academic heritage** — IRCAM roots, 35+ years of academic research, thousands of published papers using Max

### GONODES — Only In GONODES

1. **libgonodes host embedding** — 9 bidirectional data contexts, graph editing from host, GPU context sharing. No competitor offers this breadth
2. **Volume compute pipeline** — 16 VOL operators with GPU compute (Navier-Stokes fluid, raymarching, marching cubes). No competitor has built-in 3D volume processing
3. **SDF pipeline** — 29 operators for GPU ray-marched signed distance fields. Unique among visual programming tools
4. **GPU particles (POP)** — 14 SSBO compute-based particle operators. Modern GPU particle system
5. **Full Godot 4.6 engine** — PBR rendering, Jolt physics, spatial audio, OpenXR, terrain — all available natively. No other visual programming tool sits on top of a modern game engine
6. **3-tier scripting** — GDScript → Python+NumPy → C++ hot-reload, with integrated code editors for each
7. **6-platform export** — Windows, macOS, Linux, iOS, Android, Web. No competitor deploys to all six
8. **Open source** — full source code, no cost at any scale, community-driven
9. **Non-realtime mode** — deterministic offline rendering for frame-perfect recording
10. **Input hash cascade stopping** — dirty propagation stops at nodes with unchanged output. Unique among push-based evaluators
11. **Expression profiling** — per-expression microsecond timing. No competitor offers this
12. **1,413 help patches** — 3+ example patches per operator with family-appropriate visualization chains

---

## 23. Feature Gap Matrix — What GONODES Is Missing

Prioritized by impact on adoption and competitive positioning.

### Critical Gaps (Would significantly improve competitive position)

| Gap | Impact | Competitor Reference | Effort |
|-----|--------|---------------------|--------|
| **Community & ecosystem** | Adoption blocker | All competitors have years of community content | Organic (marketing, tutorials, outreach) |
| **Battle-tested stability** | Production confidence | TD has 20+ years; Max has 35+ years | Time (alpha→beta→stable) |
| **Adaptive quality degradation** | Live performance reliability | TD auto-reduces quality to hit FPS | Medium (§15 roadmap item #3) |
| **Expression compilation/caching** | Large graph performance | TD compiled Python, vvvv .NET JIT | Medium (§15 roadmap item #2) |

### Significant Gaps (Important for professional use)

| Gap | Impact | Competitor Reference | Effort |
|-----|--------|---------------------|--------|
| **Multi-stream GPU cook** | Multi-chain GPU utilization | TD parallel command queues | Depends on Godot upstream |
| **Audio synthesis** | Audio-visual artists | Max/MSP's 400+ audio objects | High (not primary domain) |
| **Visual shader editor** | Lower barrier for GPU work | Jitter Gen, vvvv VL→shader | High |
| **Package manager** | Extension discovery/install | Max Package Manager, vvvv NuGet | Medium |
| **Multi-GPU support** | Professional installations | TD multi-GPU | Depends on Godot |
| **OpenCV extension** | Computer vision operators | TD plugins, community | Medium (gn_ext_cv planned) |
| **FLIP Fluid** | Advanced particle sim | Houdini | Very high |

### Minor Gaps (Nice to have)

| Gap | Impact | Competitor Reference | Effort |
|-----|--------|---------------------|--------|
| **Laser DAC output** | Laser show artists | TD plugins | Medium (GDExtension) |
| **Video codec breadth** | Professional video I/O | TD (ProRes, DNxHR, etc.) | Medium (via FFmpeg) |
| **DAW integration** | Music producers | Max for Live | Very high (niche) |
| **Boygroup (multi-client sync)** | Multi-display installations | vvvv beta Boygroup | High |
| **FeedbackCOMP / TimeCOMP** | Advanced 3D composition | TD | Low |
| **Texture pool / recycling** | GPU memory efficiency | TD | Medium |

---

## 24. Roadmap Priorities Derived From This Analysis

Based on the competitive landscape, here are the recommended priorities for GONODES's roadmap, ranked by strategic impact:

### Tier 1 — Adoption Enablers (Do First)

| # | Priority | Why | Effort |
|---|----------|-----|--------|
| 1 | **Stability + testing hardening** | Alpha→beta transition requires production confidence. 1611/1616 tests passing is excellent. Continue hardening. | Ongoing |
| 2 | **Community building** — tutorials, example projects, Discord, social media | Community is the #1 adoption gap. No amount of features compensates for lack of learning resources. | Marketing/content |
| 3 | **Adaptive quality degradation** | Critical for live performance reliability — the one scenario where GONODES loses to TD on a tangible user-facing dimension | Medium |
| 4 | **Expression compilation** | Performance improvement that benefits all large graphs. Tier 1 optimization item. | Medium |

### Tier 2 — Competitive Differentiation (Maintain Leads)

| # | Priority | Why | Effort |
|---|----------|-----|--------|
| 5 | **libgonodes marketing/demos** | Host embedding is GONODES's strongest unique feature. Create demo integrations (Unity, Unreal, VJ tools) that showcase what no competitor can do. | Medium |
| 6 | **VOL/POP/SDF pipeline polish** | These are genuine differentiators. Polish the existing pipelines rather than adding new features. | Low-Medium |
| 7 | **Package manager** | Enable community extension sharing. Foundation for ecosystem growth. | Medium |

### Tier 3 — Feature Completion (Close Known Gaps)

| # | Priority | Why | Effort |
|---|----------|-----|--------|
| 8 | **Audio Tier 1** (Oscillator, Filter, Mix, ParaEQ) | Enables basic audio synthesis without leaving GONODES. Don't try to compete with Max — just cover basics. | Medium |
| 9 | ~~**OpenCV extension**~~ | ✅ Done — `gn_ext_opencv` ships 20 CV operators including Morph, BlobTrack, BackgroundSubtract, Contour, ColorTrack, Hough, Aruco | — |
| 10 | **GPU batch parallelism** | Submit independent TOP chains as a batch. Partially closes the gap with TD's multi-stream. | Medium-High |

### Tier 4 — Strategic Bets (Long-Term)

| # | Priority | Why | Effort |
|---|----------|-----|--------|
| 11 | **WebGPU compute** | Godot is investing in WebGPU. When available, GONODES in-browser with full compute. Unique. | Depends on Godot |
| 12 | **Visual shader editor** | Lower barrier for GPU programming. Could leverage Godot's existing VisualShader infrastructure. | High |
| 13 | **Multi-client sync** (Boygroup equivalent) | Professional multi-display installations. Leverage Godot's networking. | High |

---

## 25. Conclusion

### Where GONODES Stands Today

GONODES is a technically impressive alpha-stage tool that has achieved remarkable breadth in one year of development:

- **537 operators** across 14 families — more than TD's ~300, comparable to vvvv's ~700
- **Architecture** — push-based cook engine with 3-tier guard system achieves equivalent work-skipping to TD's mature pull engine
- **GPU compute** — POP, VOL, and SDF pipelines exceed all three competitors in built-in compute capability
- **Host embedding** — libgonodes offers the most comprehensive embeddable node-graph engine ever built (9 data contexts, bidirectional, graph editing)
- **Platform reach** — 6 deployment platforms vs TD's 1.5, Max's 2, vvvv's 3
- **Open source** — no competitor offers this. Zero cost, full source, no restrictions

### Where GONODES Falls Short

- **Maturity** — alpha status means unknown edge cases, untested production scenarios, and potential architectural issues not yet discovered
- **Community** — zero community content, tutorials, or production track record. This is the #1 adoption barrier
- **GPU parallelism** — Godot's single render thread limits multi-chain GPU utilization vs TD
- **Audio** — orders of magnitude behind Max/MSP for audio synthesis (but this isn't the target domain)
- **Adaptive quality** — can't gracefully degrade under load like TD can

### Strategic Position

GONODES occupies a unique position that no competitor addresses:

1. **Free + open source** — the only node-based real-time visual tool that's genuinely open
2. **Embeddable** — the only tool with a comprehensive C embedding API (9 data contexts)
3. **Full game engine** — the only tool built on a modern game engine with PBR, physics, VR, and 6-platform export
4. **Compute pipelines** — the only tool with built-in GPU volume, particle, and SDF compute

The competitive strategy should not be "beat TD at being TD" — that's impossible with a 20-year head start. Instead, GONODES should lean into its unique strengths: **open source access**, **embeddability**, **compute pipelines**, **cross-platform reach**, and **Godot engine integration**. These create use cases that TD, vvvv, and Jitter simply cannot address.

The primary risk isn't technical — it's adoption. A technically superior tool with no community will lose to a technically adequate tool with thousands of users and tutorials. Priority #1 should be building the community and content ecosystem that makes GONODES approachable and trustworthy for real projects.

# GONODES vs the Rest of the Bunch

> **Date:** 2026-03-20 (consolidated 2026-03-25 — merged TD_HOUDINI_COMPARISON.md; updated 2026-04-09 — operator counts, missing TOP gap analysis; updated 2026-04-21 — all operator gaps closed, gap sections removed)
> **Audience:** Core developers, architecture reviewers, prospective contributors
> **Purpose:** Comprehensive cook-flow and real-time efficiency comparison between GONODES, TouchDesigner, VVVV, Houdini, and Notch — with operator coverage summary and feature parity tracker.
>
> Many feature-audit items from the original TD/Houdini comparison have been implemented:
> - ✅ Ramp parameter type with curve editor
> - ✅ Network boxes + sticky notes
> - ✅ Audio Band CHOP — multi-band frequency analysis with envelope followers
> - ✅ 2D Fluid TOP — Navier-Stokes feedback shader with dual viewport
> - ✅ Reaction-Diffusion TOP — Gray-Scott generative patterns, 7 presets
> - ✅ FluidVOL vorticity confinement + obstacle collision
> - ✅ Timeline / Cue system — TimelineCHOP, CueDAT, CueCHOP, Editor Timeline UI
> - ✅ Periodic/Tiling Noise — FBM octaves + periodic Perlin in NoiseTOP shader
> - ✅ Fluid Surface MAT — Fresnel, refraction, Voronoi caustics, wave normals
> - ✅ Pyro Emitter VOL — fuel/combustion/buoyancy/cooling GPU pipeline
> - ✅ HeightfieldSOP — FBM terrain + thermal erosion
> - ✅ GPU Marching Cubes — compute shader with atomic append
> - ✅ Boids/Flocking POP — Reynolds rules compute shader
> - ✅ Trail/Ribbon SOP — particle trail ribbon renderer
> - ✅ gn_ext_ndi (4 operators), gn_ext_ml (7 operators), gn_ext_depth_sensor (5 operators)
> - ✅ gn_ext_blackmagic (scaffold), ClothSOP, VectorPathTOP, MqttDAT
> - Remaining: FLIP Fluid (#23). See §18 for full tracker.

---

## Table of Contents

1. [The Five Contenders](#1-the-five-contenders)
2. [Evaluation Strategy — Push vs Pull](#2-evaluation-strategy--push-vs-pull)
3. [Dirty Propagation — The Critical Path](#3-dirty-propagation--the-critical-path)
4. [GPU Pipeline — The Real Bottleneck](#4-gpu-pipeline--the-real-bottleneck)
5. [CPU Operator Performance](#5-cpu-operator-performance)
6. [Memory & Data Flow Efficiency](#6-memory--data-flow-efficiency)
7. [Frame Timing & Determinism](#7-frame-timing--determinism)
8. [Parameter & Expression Systems](#8-parameter--expression-systems)
9. [Graph Topology & Evaluation Order](#9-graph-topology--evaluation-order)
10. [Scripting & Extensibility](#10-scripting--extensibility)
11. [I/O & External Integration](#11-io--external-integration)
12. [Where GONODES Wins](#12-where-gonodes-wins)
13. [Where GONODES Loses](#13-where-gonodes-loses)
14. [Bottom Line for Real-Time Apps](#14-bottom-line-for-real-time-apps)
15. [Optimisation Roadmap](#15-optimisation-roadmap)
16. [Solving the GDScript Bottleneck — Python & Hot-Reload C++](#16-solving-the-gdscript-bottleneck--python--hot-reload-c-nodes)
17. [Architecture Gap Checklist](#17-architecture-gap-checklist)
18. [Feature Parity — Coverage Complete](#18-feature-parity--coverage-complete)
19. [Operator Coverage Audit](#19-operator-coverage-audit)

---

## 1. The Five Contenders

| | **TouchDesigner** | **VVVV** | **Houdini** | **Notch** | **GONODES** |
|---|---|---|---|---|---|
| **Primary domain** | Real-time AV, interactive media | Real-time patching, installations | Offline VFX, simulation, procedural modelling | Real-time 3D for live events, broadcast, XR | Real-time AV, VJing, generative art |
| **Cook paradigm** | Pull-based, demand-driven per frame | Push-based (beta: everything runs; gamma: hybrid with .NET JIT) | Pull-based, demand-driven on dependency change | Full-scene push — entire graph evaluates every frame on GPU | Push-based, topo-sorted per frame with 3-tier guards |
| **Engine language** | C++ (operators), Python (scripting) | C++ (beta) / .NET C# (gamma, VL) | C++ (HDK), VEX (LLVM JIT), Python/HScript | C++ (proprietary engine, DX11/12) | GDScript (operators) + 132 C++ GDExtension native ops |
| **GPU pipeline** | DirectX 11/12, OpenGL, Vulkan — multi-stream | DirectX 11 (beta); Stride/Vulkan (gamma) | Karma GPU (offline), OpenCL | **DirectX 11/12 — unified GPU-resident pipeline**, multi-GPU | Godot Vulkan/GLES3 SubViewport + RenderingDevice compute |
| **Node families** | TOP, CHOP, SOP, DAT, COMP, MAT | Nodes are typeless (pins carry typed data) | SOP, DOP, VOP, COP, CHOP, ROP, LOP, TOP (PDG) | Scene nodes (modifiers, generators, effects) — not family-typed | TOP, IMG, CHOP, DAT, SOP, POP, VOL, COMP, MAT, OUT, UI, SDF, SCRIPT |
| **Typical network size** | Dozens to hundreds | Dozens to hundreds | Hundreds to thousands | Dozens to low hundreds | Dozens to hundreds |
| **Cost** | $2,200+ / $600 non-comm. | Free (gamma) / legacy (beta) | $4,495+ / free non-comm. | £5,995+/yr (Builder); Playback bundled with media servers | **Free, open source** (Godot 4.6 + GDScript) |
| **Operator count** | ~300+ built-in | ~700+ (gamma nodes) | ~1,000+ | ~200 nodes | **574 operators** across 14 families — 140 TOP, 106 CHOP, 80 SOP, 50 DAT, 37 IMG, 36 UI, 29 SDF, 27 COMP, 15 VOL, 15 NET, 13 POP, 12 MAT, 11 OUT, 3 SCRIPT |

---

## 2. Evaluation Strategy — Push vs Pull

### TouchDesigner — Pure Pull

A viewer or output node *requests* data. The request cascades upstream recursively — each node checks its dirty flag, pulls from its inputs if needed, cooks, caches, returns. Only requested subgraphs execute. Disconnected subgraphs have literally zero cost.

### VVVV — Push (beta) / Hybrid (gamma)

**vvvv beta** is fully push-based — every pin evaluates every frame, top-to-bottom. No dirty flags, no skipping. Everything runs always.

**vvvv gamma (VL)** moves to a hybrid model: nodes are categorised as stateful or stateless, and the runtime uses a topological frame-loop with .NET JIT-compiled nodes. Mutation tracking on .NET objects provides some change detection, but it's less granular than TD's or GONODES's systems.

### Houdini — Pull, Lazy, Parameter-Granular

Nodes only cook when their output is explicitly demanded (viewport, ROP, downstream node). Non-time-dependent nodes cache indefinitely until an input or parameter changes. The dependency graph operates at the **parameter level** — changing `node.scale` invalidates only the exact downstream consumers of `scale`, not every downstream node.

### Notch — Full-Scene GPU Push

Notch evaluates the **entire active scene every frame** on the GPU. There is no dirty propagation, no hash guard, no demand culling. Nodes are not data-flow transforms but GPU render passes within a unified pipeline — geometry, particles, simulation, and compositing all execute as part of a single GPU frame submission. This is architecturally closer to a game engine's render loop than a node evaluator. The trade-off is deliberate: Notch targets live event visuals where every frame is a full render anyway, making skip-detection overhead unnecessary. Disabled/muted nodes are bypassed, but there's no equivalent to GONODES's input hash guard or TD's pull model for partially-static graphs.

### GONODES — Push, Triple-Guarded

Every frame, `cook_frame(delta)` walks the topo-sorted DAG. Three guard layers prevent wasted work:

1. **Active set culling (Tier 1):** BFS upstream from sinks (viewers, WindowOUT, SpoutOut, etc.) builds the active set. Inactive nodes keep `cached_output` frozen — zero per-frame cost. Event-driven: only recomputed when topology or sinks change.

2. **Expression consumer map (Tier 1):** Regex-scanned reverse dependency map. Expressions like `chop("lfo1", "out")` are only re-evaluated when `lfo1` actually cooked this frame. Value-compare gate: even when re-evaluated, the node is only marked dirty if the resolved value actually changed.

3. **Input hash guard (Tier 2):** Before calling `_cook()`, the engine hashes all resolved parameter values + input data timestamps. If the hash matches the previous frame's, the cook is skipped entirely — no `_cook()` call, no GPU/CPU work, no downstream propagation. The cascade stops dead.

### Comparison Verdict

| Behaviour | TouchDesigner | VVVV beta | VVVV gamma | Houdini | Notch | GONODES |
|---|---|---|---|---|---|---|
| Visits unrequested nodes | Never | Always | Reduced (mutation tracking) | Never | **Always (full-scene every frame)** | Yes — but O(1) skip per clean node |
| Per-frame overhead for static graph | Zero | Full eval cost | Low | Zero | Full eval cost (GPU-bound) | Microseconds (dirty-check scan) |
| Steady-state (nothing changes) | 0 cooks | All nodes cook | Reduced | 0 cooks | All nodes evaluate (GPU stays hot) | 0 cooks (hash guard + dirty flags) |
| Disconnected subgraph cost | Zero | Full | Reduced | Zero | Near-zero (disabled nodes skip) | Zero (active set culling) |

**For typical real-time networks (30–200 nodes), the per-frame topo scan overhead is negligible.** GONODES's push model with guards achieves functionally equivalent work-skipping to TD's pull model. The theoretical gap only appears at 500+ nodes where TD's pull model wins by never visiting unrequested branches.

### Multi-Output Demand Culling — Beating TD's Double-Compute

In TouchDesigner, when a node has cross-family outputs (e.g., a Movie File In TOP that also carries audio), both the texture and audio data are **always computed** — TD has no mechanism to detect whether a specific output port is connected. If you connect only the texture output and ignore the audio, TD still decodes and buffers the audio waveform every frame. This is a known inefficiency in TD's architecture.

GONODES solves this with **output demand culling**. Before cooking a multi-output node, the cook engine stamps `_demanded_outputs` — a per-port boolean array computed from three demand sources:

1. **Wire connections** to active downstream nodes
2. **Wireless Select operators** (SelectCHOP, SelectTOP, etc.) referencing the node by name
3. **Expression references** (`chop("node")`, `top("node")`, `dat("node")`) in other nodes' parameters

The demand is **family-aware**: `chop("blob1")` demands only the CHOP output port on BlobTrackIMG, not the IMG overlay port. This prevents false-positive demand from dragging in unnecessary work.

Operators structure their `_cook()` as **shared core** (unconditional) plus **per-port guards**:

```gdscript
# Shared core + per-port guards (BlobTrackIMG pattern)
func _cook(inputs: Array[GNData]) -> GNData:
    var out := _prepare_image()
    var result := _cv.detect_blobs(...)       # Shared core — always runs
    if is_output_demanded(0):
        out.set_image(_to_overlay(result))    # Port 0 — only if demanded
    if is_output_demanded(1):
        _pull_analysis_data()                 # Port 1 — only if demanded
    return out

# Directional dependency (MovieFileInTOP pattern)
func _cook(inputs: Array[GNData]) -> GNData:
    var result := _decode_video()             # Shared core (audio needs this)
    if is_output_demanded(1):
        _pull_audio()                         # Port 1 — gated, port 0 free
    return result
```

There is no engine-level coupling flag — the operator's `_cook()` method
decides what's shared vs. per-port.  This handles all real-world dependency
patterns: fully independent post-processing (OpenCV), directional dependency
(MovieFileInTOP), and shared render + independent buffers (MultiBufferRenderTOP).

This applies to all 15 multi-output operators in GONODES. Concrete savings:
- **7 OpenCV IMG operators** (BlobTrack, Contour, ColorTrack, ObjectTrack, HoughLines, HoughCircles, ArucoDetect): Skip CHOP/DAT extraction when only the overlay is used; skip overlay conversion when only the data is used.
- **MovieFileInTOP**: Audio capture gated; video decode is shared core that always runs.
- **MultiBufferRenderTOP**: Depth/normal viewports disabled independently.

| Behaviour | TouchDesigner | GONODES |
|-----------|---------------|---------|
| Multi-output compute | All ports always computed | Only demanded ports computed |
| Cross-family overhead | Full (audio decoded even if unused) | Zero (skipped via `is_output_demanded`) |
| Per-port granularity | None | Per-output-port demand flags |
| Demand sources | N/A (no demand detection) | Wires + wireless Selects + expressions |

---

## 3. Dirty Propagation — The Critical Path

| | **TouchDesigner** | **VVVV beta** | **VVVV gamma** | **Houdini** | **Notch** | **GONODES** |
|---|---|---|---|---|---|---|
| Dirty granularity | Node-level | None (always evaluates) | Object mutation | **Parameter-level** | None (always evaluates) | Expression-level dep map + input hash |
| Propagation strategy | Full subtree cascade | N/A | .NET ref tracking | Exact parameter consumers | N/A — full scene re-render | Incremental — direct successors only, hash stops cascade |
| False positive cooks | Low (but entire subtree cascades) | Maximum (everything runs) | Medium | Very low | Maximum (GPU handles it) | Low (hash guard catches most) |

### Where GONODES Is Smarter Than TD

TD cascades dirty flags through the *entire downstream subtree*. If a CHOP Export changes a parameter on a TOP that feeds 50 downstream nodes, all 50 re-cook even if most produce identical output.

GONODES's input hash guard catches this:

```
Node A cooks → dirties B (direct successor)
B resolves params → hash check → params + inputs unchanged → SKIP
B does NOT propagate → C, D, E, ... stay clean → cascade STOPS
```

This is particularly powerful for networks with "value-stabiliser" nodes like `MathCHOP(floor)` — the upstream LFO changes every frame, but the floored output only changes occasionally. GONODES's incremental propagation means the entire downstream chain skips cooking during stable periods.

### Where Houdini Is Smarter Than Everyone

Parameter-level dependency tracking: changing `node.scale` only invalidates the exact downstream nodes referencing `scale`, not every downstream node. GONODES approximates this with the expression consumer map + value-compare gate, but operates at the node level ("did any param on A change?") rather than individual parameter granularity. The practical difference is near-zero for typical networks.

### Where VVVV beta Is the Least Efficient

No dirty system at all. *Everything* evaluates *every frame*. A 100-node network always does 100 evaluations, regardless of what changed. VVVV gamma improves this significantly with .NET mutation tracking, but is still less granular than TD or GONODES.

---

## 4. GPU Pipeline — The Real Bottleneck for Real-Time

| | **TouchDesigner** | **VVVV beta** | **VVVV gamma** | **Notch** | **GONODES** |
|---|---|---|---|---|---|
| GPU texture ops | **Multi-stream command queues** — independent TOP chains submit in parallel | DirectX 11 immediate context | Stride engine (Vulkan) | **Unified DX11/12 GPU pipeline** — entire scene rendered as a single GPU submission | **Single Godot render thread** — sequential SubViewport renders |
| GPU↔CPU sync | Explicit fence management, async readback | DX11 pipeline | Stride pipeline | Minimal — almost everything stays on GPU | Implicit via Godot renderer + scene-tree ordering |
| Compute shaders | Full GLSL/HLSL compute | Limited (beta), Stride compute (gamma) | N/A (offline) | **Extensive** — particles, fluids, cloth, hair all GPU compute | RenderingDevice compute (POP/VOL) + ComputeShaderTOP |
| Texture pooling | **Yes** — GPU memory pool with resolution-matched recycling | DX11 resource management | Stride pools | Yes — GPU resource management | **No** — per-node SubViewport, created once |
| Multi-GPU | **Yes** — distribute chains across GPUs | No | No | **Yes** — workload distribution across GPUs | No (Godot limitation) |

### This Is GONODES's Most Significant Gap

TD and Notch can cook multiple independent TOP/render chains in parallel across GPU command queues. GONODES serialises all TOP cooks through Godot's single render thread.

### Where Notch Leads: Unified GPU Pipeline

Notch doesn't separate "texture operations" from "3D rendering" from "particle simulation" — everything is a pass within a single DirectX pipeline. This eliminates the overhead of per-node SubViewport setup (GONODES) or per-TOP texture read/write cycles (TD). For dense 3D scenes with particles, fluid sim, and post-processing, Notch achieves higher GPU utilisation because there's no cook-engine overhead between GPU operations — the entire frame is a single GPU submission. The trade-off: you can't wire arbitrary data between nodes the way TD or GONODES can. Notch's model is a render pipeline, not a general-purpose data-flow graph.

**How much does this actually matter?**

- Most VJ patches are **sequential chains** (A→B→C→viewer) — parallelism doesn't help.
- The typical bottleneck is **shader complexity per node**, not GPU command throughput.
- GONODES's `UPDATE_ONCE` prevents wasted renders, and the hash guard skips unchanged TOPs entirely.
- For multi-chain setups (e.g., 4 independent generative chains composited at the end), TD has a genuine advantage — maybe 10–30% faster GPU utilisation.

### How GONODES Ensures GPU Correctness Without Fences

1. **Scene-tree ordering:** Cook engine reorders SubViewport children to match topological order. Godot renders children in scene-tree order, so upstream textures are ready before downstream reads.
2. **Sequential TOP cooking on main thread:** GPU nodes cook one-at-a-time. No race conditions.
3. **UPDATE_ONCE:** SubViewport renders exactly once per dirty cycle, never redundantly.

No explicit GPU fences, barriers, or synchronisation code — Godot's renderer handles it implicitly. Simple and correct, if not maximally parallel.

---

## 5. CPU Operator Performance

| | **TouchDesigner** | **VVVV beta** | **VVVV gamma** | **Houdini** | **Notch** | **GONODES** |
|---|---|---|---|---|---|---|
| Operator core | C++ | C++ | .NET (RyuJIT) | C++ + VEX (LLVM JIT) | C++ (proprietary, GPU-centric) | GDScript + 132 C++ GDExtension |
| Expression eval | Python (interpreted) | N/A (pin-based) | .NET IL (JIT) | **VEX (LLVM JIT — near native C++)** | N/A (no user expressions) | GDScript Expression (interpreted) |
| Per-op parallelism | Thread CHOP only | Some (beta) | .NET Task parallelism | Many SOPs internally threaded | GPU parallelism (not CPU) | WorkerThreadPool batch per topo level |
| Data throughput | ~1M pts @ 60fps (C++ SOPs) | Comparable (C++) | ~500K pts @ 60fps (.NET) | 10M+ pts (VEX wrangles) | Millions (GPU-resident) | ~100K–500K pts (native), ~10K–50K (GDScript) |

### The GDScript Tax

Pure GDScript operators are ~10–50× slower than equivalent C++ for data-heavy operations (per-vertex SOP processing, per-sample CHOP math). This is the single largest performance gap vs TD and VVVV.

**Mitigations already in place:**
- 132 C++ GDExtension native operators cover the built-in hot paths
- GDScript auto-delegates to C++ when native binaries are available, falls back gracefully when not

**Where the GDScript tax matters:**
- **Shader-driven work (TOP/POP/VOL):** Zero impact — GPU does the heavy lifting
- **CHOP signal processing:** GDScript handles hundreds of channels at 60fps. It's fine.
- **Heavy SOP geometry (100K+ vertices in user scripts):** This is the pain point. Built-in native SOPs are fast, but GDScriptSCRIPT (SOP template) is bounded by GDScript.

### vs VVVV gamma

VL (visual language) compiles to .NET IL, JIT-compiled by RyuJIT — roughly 2–5× slower than native C++ but 10–20× faster than GDScript. This is a genuine advantage for compute-heavy user-authored nodes.

### vs Houdini VEX

Not a fair comparison for our use case — VEX compiles via LLVM to native machine code, runs on millions of points at C++ speed. But Houdini isn't aiming for real-time 60fps delivery.

---

## 6. Memory & Data Flow Efficiency

| | **TouchDesigner** | **VVVV** | **Houdini** | **Notch** | **GONODES** |
|---|---|---|---|---|---|
| Copy-on-write | GPU textures (FBO handles), CPU (ref-counted) | Spread COW (beta); .NET ref semantics (gamma) | GU_Detail COW with ref counting | N/A — GPU-resident, no CPU data copies | `_shared` flag + `_mutable_input()` COW |
| GPU texture management | **Pool** — resolution-matched recycling | DX resource management | N/A (offline) | Unified GPU memory management | Per-node SubViewport (no pool) |
| Allocation per frame | Near-zero (pooled) | Low (.NET GC) | Near-zero (COW) | Near-zero (GPU-resident) | Near-zero (cached output reuse) |
| Cross-family data | Bridge operators + CHOP Export | Typeless pins (auto-convert) | Bridge operators + attribute promotion | Implicit (unified pipeline) | Bridge operators + expressions |

### GONODES's COW Is Smart

- **Single-consumer chains:** Zero-copy. Data flows by reference.
- **Fan-out points:** `_mutable_input()` duplicates only when `_shared = true` (consumer count > 1).
- **Viewer-aware:** Viewed nodes count as extra consumers, so in-place operators properly duplicate when being watched.
- **TOPs are immune:** SubViewport textures are inherently read-only (sampled by shaders). No COW needed for GPU paths.

### What's Missing: Texture Pool

TD reuses GPU texture allocations from a resolution-matched pool. GONODES creates one SubViewport per TOP node, kept for node lifetime. This means:
- No allocation pressure per frame ✓
- No recycling across nodes when resolution changes ✗ (SubViewport resizes instead of pool swap)
- No cross-network texture sharing ✗

Practical impact: minor. SubViewport creation is a one-time cost, and resolution changes are rare during normal playback.

---

## 7. Frame Timing & Determinism

| | **TouchDesigner** | **VVVV** | **Houdini** | **Notch** | **GONODES** |
|---|---|---|---|---|---|
| Frame budget system | Yes — drops frames / reduces quality to hit target FPS | Fixed frame loop (drops at OS level) | N/A (not real-time) | **Yes** — adaptive quality, resolution scaling | `max_cooks_per_frame` (sequential path only) |
| Adaptive quality | Yes — resolution reduction, node skipping | No | N/A | **Yes** — dynamic resolution scaling, LOD | **No** |
| Non-realtime mode | **No** (always real-time) | No | Default (not real-time) | **No** (always real-time) | **Yes** — fixed timestep for deterministic recording |
| Variable framerate | Adaptive time-slicing | System clock | N/A | Engine-managed vsync / target FPS | `current_delta` from Godot's `_process()` |

### GONODES's Non-Realtime Mode Is a Strength

When `non_realtime = true`, the engine advances by a fixed `1.0 / non_realtime_fps` per frame regardless of wall-clock time. This guarantees:
- **Deterministic output** — heavy patches produce identical results to light ones
- **No dropped frames** — every frame cooks exactly once at the target FPS
- **Frame-perfect recording** — FFmpegOUT / RecordOUT produce lossless video

Neither TD nor VVVV has this. For content creation and pre-rendering generative pieces, this is a genuine advantage.

### TD's and Notch's Adaptive Quality Is a Strength We Lack

TD can automatically reduce texture resolution, skip low-priority branches, or drop interleaved frames to maintain target FPS. Notch has similar dynamic resolution scaling and LOD management. GONODES either cooks full quality or drops the whole frame. This matters for installations and performances where maintaining framerate is critical even when the network spikes.

---

## 8. Parameter & Expression Systems

| Feature | TouchDesigner | VVVV | Houdini | Notch | GONODES |
|---|---|---|---|---|---|
| Expression language | Python (interpreted) | VL (.NET JIT) | HScript + VEX (LLVM JIT) | N/A (no user expressions) | GDScript Expression (interpreted) |
| Param-level deps | Partial (CHOP Export) | Pin connections | **Full dependency DAG** | None (static params) | Expression dep map + value-compare gate + input hash |
| Ramp/curve parameter | No (LookupTOP workaround) | SplineEditor (gamma) | **Yes** (first-class `chramp()`) | Limited (keyframe curves) | **Yes** (GNRampEditor, `ramp()`) |
| Per-component expressions | Yes | N/A (pin-based) | Yes | No | Yes (Vector2/3/4, Color) |
| Expression profiling | No | No | No | No | **Yes** (µs per expression) |
| Auto-complete | Yes (Python) | Yes (VL) | Yes (HScript/VEX) | N/A | Yes (CodeEdit) |
| Keyframe animation | Yes (basic timeline) | Yes (timeline) | Yes (full animation editor) | **Yes** (timeline-centric, deep keyframe support) | Yes (KeyframeCHOP + ramp curves) |
| Takes/parameter layers | No | No | **Yes** | No | **Yes** (GNTakeManager) |

GONODES's expression profiling (microsecond timing per expression) is unique among all five tools. This lets users identify expensive cross-references and optimise accordingly. Notch has no user-accessible expression/scripting layer — parameter values are set manually or driven by external control (MIDI, OSC, timeline keyframes).

---

## 9. Graph Topology & Evaluation Order

| Feature | TouchDesigner | VVVV | Houdini | Notch | GONODES |
|---|---|---|---|---|---|
| Sort algorithm | Implicit (pull recursion) | Implicit (spread flow) | Implicit (pull) + compiled blocks | Implicit (scene-graph traversal) | **Explicit** (Kahn's BFS, cached) |
| Compiled blocks | No | No | **Yes** (SOP compile — fuses chains) | N/A (unified GPU pipeline) | No |
| Hierarchy depth | Infinite (COMP nesting) | Infinite (subpatch nesting) | Infinite (subnet/HDA nesting) | Limited (layer stacks) | Infinite (SubNetworkNode) |
| Feedback | FeedbackTOP (prev frame) | FrameDelay (prev frame) | Time Shift, `chf(-1)` | Built-in (feedback loops natural in render pipeline) | FeedbackTOP (prev frame) |
| Cross-network refs | `op('/path/to/node')` | Send/Receive nodes | `ch("../relative/path")` | N/A (no cross-references) | `op("subnet/node")`, `op("../node")`, `op("/root")` |
| Implicit dep tracking | Partial (CHOP Export) | None | Full (param DAG) | None | Expression dep map + selective re-eval |
| Parallel cook | Multi-stream GPU, Thread CHOP | Some (.NET tasks) | Multi-threaded SOPs, PDG farm | Full GPU parallelism within frame | Level-based WorkerThreadPool (CPU); sequential GPU |

### Houdini's Compiled Blocks

Houdini can analyse a chain of SOPs and fuse their operations into a single compiled unit — eliminating intermediate geometry allocation and enabling whole-chain optimisation. This is transformative for deep procedural networks (20+ chained SOPs).

GONODES doesn't have this, and it's not obviously needed for real-time workflows where SOP chains are typically 5–10 nodes. However, it's worth noting for anyone building deep procedural geometry pipelines.

---

## 10. Scripting & Extensibility

| Feature | TouchDesigner | VVVV | Houdini | Notch | GONODES |
|---|---|---|---|---|---|
| User scripting | Python | VL (visual .NET), C# | VEX + Python | **None** — no scripting, no user-authored nodes | GDScript (Script ops) + **Python** (`gn_ext_user_python` — NumPy, hot-reload) + **C++** (`gn_ext_user_native` — hot-reload, 2–8s compile) |
| Shader authoring | GLSL (frag/vert/compute) | HLSL/Stride shaders | VEX, GLSL, OSL, MaterialX | Limited (material overrides) | GLSL (canvas_item + compute) + ISF + Shadertoy |
| C++ plugin SDK | **No** | Yes (vvvv SDK) | Yes (HDK) | **No** | GDExtension (92 native ops) + **UserNative** hot-reload C++ (in-editor compile) |
| Asset packaging | `.tox` (COMP export) | Nuget packages (gamma) | **HDA** (gold standard) | Notch Blocks (reusable presets) | `.gnasset` (JSON, self-contained) |
| Event-driven scripting | Parameter Execute DAT | Reactive (VL) | Spare param callbacks | N/A | CallbackDAT (on_cook, on_value_change, etc.) |
| Runtime compilation | Python (always available) | .NET JIT | VEX JIT | N/A | GDScript runtime + **Python** hot-reload + **C++** hot-reload (GDExtension, 2–8s) |

### Key Insight

TD doesn't let you write C++ operators at all — Python is the only extension path. Houdini has the HDK (full C++ API) but it's complex. **Notch offers no user scripting or extensibility at all** — you get exactly the nodes Notch ships, period. **GONODES now offers three tiers of user scripting** — a unique advantage:

1. **GDScript** (Script operators) — zero setup, instant feedback, adequate for typical patches
2. **Python** (`gn_ext_user_python`) — NumPy vectorised, TD-familiar, no compilation, full Python ecosystem
3. **C++** (`gn_ext_user_native`) — maximum performance, full Godot API, 2–8s hot-reload iteration

Both Python and C++ paths include integrated code editors with syntax highlighting, templates, examples, preset systems, and help documentation accessible from within the editor. GDScript fallback means operators work everywhere even without native builds.

---

## 11. I/O & External Integration

| Protocol | TouchDesigner | VVVV | Houdini | Notch | GONODES |
|---|---|---|---|---|---|
| OSC | Built-in | Built-in | Basic (Python) | **Yes** (OSC input) | Built-in (OscInCHOP, OscInDAT, OscOutOUT) |
| MIDI | Built-in (In/Out) | Built-in | No | **Yes** (MIDI/MIDI2 input) | gn_ext_midi (RtMidi) |
| NDI | Built-in | Plugin | No | **Yes** (NDI input/output) | gn_ext_ndi (4 operators) |
| Spout/Syphon | Built-in | Built-in (Spout) | No | **Spout** (input/output) | gn_ext_spout + gn_ext_syphon |
| Audio | Built-in | Built-in | No | **Yes** (audio-reactive) | AudioIn, Spectrum, Band, Dynamics, Beat, AudioDeviceOUT |
| Video capture | Built-in (webcam, capture card) | Built-in | No | **Yes** (Blackmagic, webcam) | WebcamIMG, gn_ext_video_capture, gn_ext_blackmagic |
| Serial | Built-in | Built-in | No | No | gn_ext_serial |
| DMX/Art-Net | Built-in | Plugin | No | **Yes** (Art-Net) | DmxOutCHOP + DmxInCHOP + ArtnetDAT |
| MQTT/IoT | Python plugin | Plugin | No | No | MqttDAT (built-in) |
| Depth sensors | Kinect, RealSense, Leap, ZED | Kinect, RealSense | No | No | gn_ext_depth_sensor (Azure Kinect + RealSense + Ultraleap) |
| ML inference | TensorFlow, MediaPipe plugins | ML.NET, ONNX | No | No | gn_ext_ml (ONNX Runtime, 7 operators) |
| Embed in host apps | TouchEngine SDK | No | Houdini Engine | **Notch Playback** (disguise, Unreal, Unity) | **libgonodes** (LibGodot C API) |
| Projection mapping | Stoner, Kantan Mapper (plugins) | Badmapper (plugin) | No | No | gn_ext_mapper (built-in) |
| Media server integration | Via TouchEngine/Spout | No | No | **Deep** (disguise d3, Barco, Green Hippo) | No |

GONODES has surprisingly strong I/O coverage for an open-source project — particularly with the GDExtension addon architecture that makes adding new protocols straightforward. Notch has excellent media server integration (the deepest of any tool) via its tight relationship with disguise/d3, but lacks user-extensible I/O — you get what Notch ships.

---

## 12. Where GONODES Wins

### 12.1 Input Hash Guard Stops Cascades

TD cascades dirty flags through entire downstream subtrees. GONODES's hash guard + incremental propagation stops cascades at the first node whose output didn't change. On networks with "value-stabiliser" nodes (MathCHOP floor, threshold comparisons), this saves significant downstream work that TD would waste.

### 12.2 Non-Realtime Deterministic Recording

Neither TD nor VVVV can guarantee frame-perfect offline rendering. GONODES's non-realtime mode produces deterministic output regardless of system load — critical for pre-rendering generative content.

### 12.3 Expression Profiling

Per-expression microsecond profiling lets users identify which cross-reference is expensive. TD and Houdini only profile at node level. VVVV has no built-in profiling in beta.

### 12.4 Volumetric Compute Pipeline

14 VOL operators with GPU compute (Navier-Stokes fluid sim, raymarching, marching cubes, pyro emitter). Neither TD nor VVVV has a comparable built-in 3D volume pipeline. This is a genuine differentiator.

### 12.5 Open Source + Godot Ecosystem

Free, fully open source, runs on Godot 4.6. Cross-platform (Windows, macOS, Linux, web, mobile). No licensing costs, no dongles, no vendor lock-in. The entire Godot ecosystem (physics, audio, networking, rendering) is available.

### 12.6 Active Chain Culling With Zero-Cost Inactive Paths

Inactive nodes aren't just "not pulled" — they're never dirtied in the first place. The pre-cook pass skips inactive nodes entirely, and `_dirty_immediate_downstream` doesn't cross active/inactive boundaries.

### 12.7 UPDATE_ONCE SubViewport Rendering

Each TOP renders exactly once per dirty cycle, never redundantly. Combined with the hash guard, a TOP that doesn't need updating has literally zero GPU cost per frame.

---

## 13. Where GONODES Loses

### 13.1 Serial GPU Cook (vs TD's Multi-Stream)

**Gap:** TD can cook multiple independent TOP chains in parallel across GPU command queues. GONODES serialises all TOP cooks through Godot's single render thread.

**Impact:** For multi-chain HD patches (e.g., 4 independent generative chains composited at the end), TD is genuinely 10–30% faster at GPU utilisation.

**Why it matters less than it sounds:** Most VJ patches are sequential chains. The bottleneck is usually shader complexity per node, not GPU command throughput.

### 13.2 GDScript Interpretation Overhead (vs C++/VEX/.NET JIT)

**Gap:** Pure GDScript is ~10–50× slower than C++ for per-element data processing. User-written GDScriptSCRIPT (SOP template) with per-vertex logic is the weakest link.

**Mitigation:** 132 C++ native operators cover built-in hot paths. GPU work (TOP/POP/VOL) is unaffected.

### 13.3 No Adaptive Quality Degradation (vs TD and Notch)

**Gap:** TD and Notch can automatically reduce TOP resolution or skip low-priority branches to hit frame targets. GONODES either cooks full quality or drops the frame.

**Impact:** Matters for installations and live performances where maintaining framerate is critical even during spikes.

### 13.4 No Compiled SOP Blocks (vs Houdini)

**Gap:** Houdini fuses chains of SOPs into a single compiled unit, eliminating intermediate geometry allocation. GONODES allocates per-node.

**Impact:** Minimal for our use case (real-time networks with short SOP chains). Would matter for deep procedural geometry pipelines.

### 13.5 No Multi-GPU (vs TD and Notch)

**Gap:** TD and Notch can distribute TOP/render chains across multiple GPUs. GONODES is single-GPU.

**Impact:** Niche — multi-GPU setups are rare outside dedicated media servers.

### 13.6 No Unified GPU Pipeline (vs Notch)

**Gap:** Notch treats the entire scene as a single GPU render pipeline — geometry, particles, simulation, compositing all execute in one GPU submission with no per-node overhead. GONODES has per-node SubViewport setup and teardown overhead.

**Impact:** For dense 3D scenes with heavy GPU sim (particles, fluids, cloth), Notch achieves higher GPU utilisation. Less relevant for 2D texture-chain workflows where per-node overhead is negligible.

### 13.7 No Media Server Integration (vs Notch)

**Gap:** Notch has deep, production-proven integration with disguise (d3), Barco, and Green Hippo media servers — the standard pipeline for large-scale live events, concerts, and broadcast. GONODES has no media server integration.

**Impact:** For the live events/broadcast market, this is a significant gap. Notch's value proposition is built on its media server ecosystem. For VJ/generative art/installation use cases, this matters less.

### 13.8 Expression Eval Cost Scales Linearly

**Gap:** Each expression is evaluated via Godot's `Expression` class (parse + execute). TD uses compiled Python bytecode; Houdini uses LLVM-JIT'd VEX. Both amortise the compilation cost.

**Mitigation:** Expression consumer map + value-compare gate means most expressions are skipped most frames. The remaining ones are fast enough for typical expression complexity.

---

## 14. Bottom Line for Real-Time Apps

| Concern | Verdict |
|---|---|
| **Can GONODES hit 60fps for VJ patches?** | **Yes.** Stress-tested at 59 nodes, 60fps. Hash guard keeps per-frame cost proportional to *actually-changing* nodes. |
| **Is the GDScript tax a problem?** | **For shader-driven work: no.** TOP/POP/VOL are GPU-bound. For heavy CPU geometry: 92 native ops cover built-in paths. User Script SOPs are the weak spot. |
| **Is the serial GPU cook a problem?** | **For typical VJ workflows: rarely.** Most patches are linear chains. Multi-chain compositions lose ~10–20% vs TD's parallel streams. |
| **Is the push model wasteful?** | **No.** The 3-tier guard system makes push functionally equivalent to pull for real-world graphs. The per-frame topo scan is microseconds. |
| **How does it compare to VVVV?** | **Better dirty/skip optimisation** than vvvv beta (which has none). Comparable to vvvv gamma, with the trade-off of GDScript vs .NET JIT for user scripts. |
| **How does it compare to Houdini?** | **Not a fair comparison** — Houdini targets offline VFX with 10M+ points. GONODES targets real-time with 10K–100K. Different domains, both well-optimised for their target. |
| **How does it compare to Notch?** | **Different architectures for different trade-offs.** Notch has a superior unified GPU pipeline for dense 3D scenes and unmatched media server integration. GONODES has smarter cook-skipping (hash guard, demand culling), 3× more operators, cross-platform, open source, full scripting, and embeddability. Notch wins on raw GPU throughput; GONODES wins on flexibility, extensibility, and platform reach. |
| **What would break the architecture?** | Networks with 500+ nodes, 10+ independent HD TOP chains needing parallel GPU cook, or per-vertex GDScript on 100K+ point meshes. |

---

## 15. Optimisation Roadmap

### Tier 1 — High Impact, Achievable Now

| # | Optimisation | What | Expected Gain | Effort |
|---|---|---|---|---|
| 1 | ~~**Hot-reloadable C++ user nodes (`gn_ext_user_native`)**~~ | ✅ **IMPLEMENTED.** GDExtension addon: users write single-file C++ operators, compile in 2–8s, hot-reload without restart. Bundled godot-cpp headers + compiler toolchain. Integrated code editor with templates, examples, presets, and help system. 5 operator wrappers (SOP/CHOP/IMG/TOP/DAT). | **Eliminates the GDScript bottleneck entirely** for power users. Full WorkerThreadPool parallelism. | ~~Medium-High~~ Done |
| 2 | **Expression compilation/caching** | Replace per-frame `Expression.execute()` with pre-compiled GDScript callables. Cache the compiled `Expression` object (already partially done — extend to skip re-parse when source unchanged). | 2–5× faster expression eval. Biggest win for expression-heavy graphs. | Medium |
| 3 | **Adaptive frame budget** | When frame time exceeds target, automatically reduce SubViewport resolution on non-critical TOPs (e.g., secondary chains, background layers). Priority levels per sink. | Maintain 60fps during spikes. Critical for live performance reliability. | Medium |
| 4 | **Parallel cook: extend to GPU batch** | Currently CPU nodes parallelise but GPU nodes are strictly sequential. Group independent TOP chains and submit their SubViewport `UPDATE_ONCE` flags in a single batch, letting Godot's renderer parallelise within a frame. | 10–30% GPU utilisation improvement for multi-chain patches. | Medium-High |
| 5 | **`max_cooks_per_frame` for parallel path** | Currently the frame budget cap only works in the sequential cook path. Extend it to the parallel path — abort remaining topo levels when budget exceeded. | Prevents frame overruns in heavy parallel batches. | Low |

### Tier 2 — Significant Impact, Moderate Effort

| # | Optimisation | What | Expected Gain | Effort |
|---|---|---|---|---|
| 6 | **Texture pool / SubViewport recycling** | Maintain a pool of SubViewports grouped by resolution and format. When a TOP changes resolution, swap from pool instead of resizing. Recycle SubViewports from deleted nodes. | Smoother resolution transitions. Reduced GPU memory fragmentation. | Medium |
| 7 | ~~**Embedded Python + NumPy (`gn_ext_user_python`)**~~ | ✅ **IMPLEMENTED.** Embedded CPython 3.10+ with NumPy. Zero-copy `PackedFloat32Array` ↔ `numpy.ndarray` bridge via C++ GDExtension (`GNPythonRuntime`, `GNPythonProcessor`). 5 operator wrappers (UserPythonSOP/CHOP/IMG/TOP/DAT). Full Python SDK (`gonodes` package), integrated code editor with syntax highlighting, templates, examples, presets, and help system. | NumPy vectorised operations 50–200× faster than GDScript per-element loops. Opens Python ecosystem (librosa, OpenCV, scipy). | ~~High~~ Done |
| 8 | **Parameter-level dirty tracking** | Track which specific parameter changed on a node (not just "node is dirty"). Consumers that reference only `par("A", "scale")` skip re-eval when `A.seed` changes but `A.scale` doesn't. | Eliminates remaining false-positive expression re-evaluations. Closest to Houdini's parameter-level DAG. | Medium-High |
| 9 | **Async GPU readback** | For TOPtoCHOP, TOPtoIMG, and other GPU→CPU bridges, use `RenderingDevice` async readback with fences instead of synchronous `texture_2d_get()`. | Eliminates GPU stalls on readback. 1–5ms saved per readback node per frame. | Medium |

### Tier 3 — Future Architecture, High Effort

| # | Optimisation | What | Expected Gain | Effort |
|---|---|---|---|---|
| 10 | **Godot multi-window render queues** | If Godot exposes per-window or per-SubViewport render queues in future versions, use them to parallelise independent TOP chains on the GPU. | Closes the gap with TD's multi-stream GPU cook entirely. | Depends on Godot upstream |
| 11 | **SOP chain fusion (compiled blocks)** | Analyse linear SOP chains and fuse them into a single operation (e.g., Transform→Normal→Peak becomes one pass). Requires intermediate representation. | Eliminates per-node allocation overhead for deep SOP chains. Houdini-tier optimisation. | Very High |
| 12 | **VEX-like bytecode VM for expressions** | Replace GDScript `Expression` with a purpose-built stack-based VM that compiles expression strings to bytecode. Optimised for the small expression vocabulary (`chop`, `par`, `fit`, `noise`, `ramp`, etc.). | 5–20× faster expression eval vs `Expression.execute()`. | High |
| 13 | **Partial frame cook (time-slicing)** | Allow the cook engine to pause mid-topo-order and resume next frame. Low-priority branches cook at reduced framerate (e.g., background chain at 15fps while foreground stays at 60fps). | TD-style adaptive quality without resolution reduction. Smooth degradation under load. | High |
| 14 | **SPIR-V shader caching** | Cache compiled GLSL→SPIR-V for CustomShaderTOP and compute shaders. Skip recompilation when shader source hasn't changed across sessions. | Faster first-frame boot time. Eliminates shader compilation stutter on patch load. | Medium |
| 15 | **Compute shader for CHOP math** | Offload array-math CHOPs (Math, Logic, Filter) to GPU compute when channel length × channel count exceeds a threshold (e.g., 10K+ samples). | 10–100× speedup for large CHOP datasets (audio analysis, sensor arrays). | Medium-High |

### Tier 4 — Speculative / Research

| # | Optimisation | What | Notes |
|---|---|---|---|
| 16 | **Warp-level GPU scheduling** | Fine-grained GPU work distribution across TOP chains using Vulkan compute queues. | Requires low-level Vulkan access beyond what Godot exposes. |
| 17 | **Distributed cook (network)** | Split graph across machines — network-transparent node evaluation. | Like Houdini PDG but real-time. Massive undertaking. |
| 18 | **ML-accelerated shader compilation** | Use trained models to predict optimal shader variants based on input resolution and GPU. | Research territory. |
| 19 | **GDScript JIT in Godot core** | If Godot ever ships a GDScript JIT compiler, all Script operators get faster for free. | Depends on Godot upstream roadmap. Monitor godot-proposals. |

### Priority Matrix

```
                        IMPACT
                 Low    Medium    High
            ┌─────────┬─────────┬─────────┐
    Low     │         │   #5    │  ✅ #1  │
            │         │         │         │
  EFFORT    ├─────────┼─────────┼─────────┤
   Medium   │         │  #6,#14 │#2,#3,#9 │
            │         │         │         │
            ├─────────┼─────────┼─────────┤
    High    │         │  #8,#15 │#4,#11  │
            │         │         │✅#7,#12 │
            │         │         │  #13    │
            └─────────┴─────────┴─────────┘

✅ = Implemented (#1 gn_ext_user_native, #7 gn_ext_user_python)
Recommended order: #5 → #2 → #3 → #4 → #9 → #6 → #14 → rest
```

---

## 16. Solving the GDScript Bottleneck — Python & Hot-Reload C++ Nodes

The single biggest performance gap in GONODES is user-authored Script operators running in GDScript for heavy per-element processing. Two complementary upgrade paths address this, targeting different user profiles.

### 16.1 Hot-Reloadable C++ Nodes (`gn_ext_user_native`) — ✅ IMPLEMENTED

**Status: DONE.** Shipped as `gn_ext_user_native` with 5 operator wrappers (UserNativeSOP/CHOP/IMG/TOP/DAT), integrated C++ code editor with syntax highlighting, templates, examples, factory/user preset system, and help documentation. Users write single-file C++ operators, compile in 2–8 seconds via bundled godot-cpp toolchain, and hot-reload without restarting GONODES.

#### Architecture

```
┌─────────────────────────────────────────────────────┐
│  gn_ext_user_native (GDExtension — hot-reloadable)  │
│                                                      │
│  ├─ UserNativeNode template (C++ base class)         │
│  │   ├─ declare_params()  → define parameters        │
│  │   ├─ declare_ports()   → define inputs/outputs    │
│  │   └─ cook(inputs)      → native-speed processing  │
│  │                                                   │
│  ├─ File watcher on user_native/ directory            │
│  │   Detects .cpp changes → triggers rebuild          │
│  │                                                   │
│  ├─ Build system (bundled minimal SCons/CMake)        │
│  │   Links against godot-cpp + gonodes headers        │
│  │                                                   │
│  └─ Hot-reload manager                               │
│      ├─ Snapshots node state (params, connections)   │
│      ├─ Unloads old .dll via GDExtension API         │
│      ├─ Loads new .dll                               │
│      └─ Restores state → node resumes cooking        │
└─────────────────────────────────────────────────────┘
```

#### Example User Code

```cpp
// user_native/my_sop.h
#include <gonodes/user_native.h>

class MySOP : public GNUserSOP {
    GDCLASS(MySOP, GNUserSOP)

    void declare_params() override {
        add_float("amplitude", 1.0, 0.0, 10.0);
        add_float("frequency", 2.0, 0.1, 100.0);
    }

    void declare_ports() override {
        add_input("geo_in", GNFamily::SOP);
        add_output("geo_out", GNFamily::SOP);
    }

    Ref<GNGeoData> cook(const TypedArray<GNData>& inputs) override {
        auto geo = mutable_input<GNGeoData>(inputs[0]);
        if (!geo.is_valid()) return nullptr;

        float amp = get_parf("amplitude");
        float freq = get_parf("frequency");

        PackedVector3Array positions = geo->get_positions();
        for (int i = 0; i < positions.size(); i++) {
            positions.write[i].y += sin(positions[i].x * freq + elapsed_time) * amp;
        }
        geo->set_positions(positions);
        return geo;
    }
};
```

#### Threading Behaviour

C++ nodes get **full WorkerThreadPool parallelism for free**. No interpreter, no GIL, no contention. The existing GONODES threading contract guarantees safety:

- Parameters resolved on main thread before dispatch — no graph reads during `_cook()`
- Inputs gathered on main thread — each node gets its own `Array[GNData]`, read-only
- Output is per-node — `_cook()` returns a new `GNData`, no shared writes
- COW handles fan-out — `_mutable_input()` duplicates when `_shared=true`

**One hazard:** Godot's rendering API (`RenderingServer`, `DisplayServer`) is main-thread-only. The base class should provide safe helpers (`SurfaceTool`, `ArrayMesh` — both thread-safe for construction) and assert-guard against forbidden calls in debug builds.

#### Challenges & Mitigations

| Challenge | Mitigation |
|---|---|
| Requires C++ compiler on user's machine | Bundle minimal toolchain: TDM-GCC on Windows (~50MB), clang on Mac (via Xcode CLI tools). Or offer cloud-compile service. |
| Compilation latency (2–8s) | Acceptable — Unreal Live Coding takes 5–15s. Incremental builds help. |
| GDExtension hot-reload is experimental (Godot 4.2+) | Test extensively. Snapshot/restore state across reload. Fallback: manual "Reload" button. |
| State during reload | Params and connections live in GONODES graph model, not in C++ object. Reload creates a new instance, re-injects graph state. `cached_output` invalidated → node re-cooks. |
| Crash isolation | Bad C++ code crashes the process. Guard with SEH on Windows / signal handler on Unix. Document forbidden patterns. |

#### Precedent Comparison

| Tool | Approach | Hot-reload? | Iteration speed |
|---|---|---|---|
| **Houdini HDK** | C++ SOPs, compile, install | No — requires restart | Slow |
| **Unreal Live Coding** | C++ module hot-reload | Yes (~5–15s) | Good |
| **VVVV gamma** | .NET C# via Roslyn | Yes (~1–2s) | Excellent |
| **GONODES (proposed)** | C++ GDExtension hot-reload | Yes (~2–8s) | Good — better than Houdini, close to VVVV |

### 16.2 Embedded Python with NumPy (`gn_ext_user_python`) — ✅ IMPLEMENTED

**Status: DONE.** Shipped as `gn_ext_user_python` with 5 operator wrappers (UserPythonSOP/CHOP/IMG/TOP/DAT), C++ GDExtension runtime (`GNPythonRuntime` singleton + `GNPythonProcessor` per-node), zero-copy NumPy bridge, full Python SDK (`gonodes` package with sop/chop/img/top/dat/params modules), and integrated Python code editor with syntax highlighting, templates, examples, factory/user preset system, and help documentation.

The value is **NumPy vectorisation** — C-speed array operations accessible from a familiar scripting language. This is exactly how TouchDesigner Python achieves good performance.

#### Architecture

```
┌──────────────────────────────────────────────┐
│  gn_ext_python (GDExtension)                 │
│  ├─ Embeds CPython 3.12+ (or 3.13+ for     │
│  │   optional free-threading)                │
│  ├─ Bundles NumPy, SciPy (wheels)            │
│  ├─ GNPythonBridge: zero-copy data exchange  │
│  │   ├─ PackedFloat32Array ↔ numpy.ndarray   │
│  │   ├─ GNChannelData ↔ dict of ndarrays     │
│  │   └─ GNGeoData ↔ structured arrays        │
│  └─ PythonSCRIPT (template-based per-family) │
└──────────────────────────────────────────────┘
```

#### Why Python Over Just C++?

1. **Familiarity** — Python is the scripting language of TouchDesigner. TD refugees feel at home.
2. **NumPy vectorisation** — write `np.sin(positions * freq)` instead of per-element loops. 50–200× faster than GDScript for array math.
3. **Ecosystem** — `librosa` (audio analysis), `opencv-python` (vision), `scipy.signal` (DSP), `shapely` (geometry), `mediapipe` (ML) — all available immediately.

#### The GIL and Threading

CPython's Global Interpreter Lock means only one thread can execute Python bytecode at a time. Impact on parallel cook:

| Topo level contains | Behaviour | Effective parallelism |
|---|---|---|
| Multiple **C++ nodes** | Full parallelism — no locks | N× (N = core count) |
| Multiple **Python NumPy nodes** | Mostly parallel — GIL held during brief setup/teardown (~50µs), **released during NumPy C compute** (~2ms) | ~90% of N× for vectorised code |
| Multiple **Python loop-heavy nodes** | Serialised — GIL blocks concurrent execution | 1× (no speedup) |
| Mix of C++, Python, GDScript | C++ and GDScript run free; Python nodes serialise only against each other | C++/GDScript get full parallelism |

**Key insight:** NumPy releases the GIL during computation. For vectorised code (the whole point of using Python), you get near-full parallel efficiency:

```
PySOP_A:  [GIL: setup 50µs] [NO GIL: NumPy compute 2ms] [GIL: teardown 50µs]
PySOP_B:  [wait 50µs]       [NO GIL: NumPy compute 2ms ← overlaps A] [teardown]
```

#### GIL Mitigation Strategy

**Phase 1 (ship with):** Accept the GIL. NumPy vectorisation gives most parallelism users need. Add `# @parallel false` annotation for users who want to force main-thread execution.

**Phase 2 (when mature):** Upgrade embedded CPython to 3.13+ and enable free-threaded mode (`--disable-gil`). NumPy 2.1+ supports this. Near-zero code changes — just a build flag.

**Phase 3 (if needed):** Per-interpreter GILs via `Py_NewInterpreterFromConfig()` (CPython 3.12+). Each worker thread gets its own interpreter and GIL. True parallelism at the cost of ~50MB RAM per thread (each loads its own NumPy).

**Recommendation:** Phase 1 is sufficient. Phase 2 is free when CPython 3.13 free-threading stabilises. Phase 3 is unlikely to be needed.

#### Zero-Copy Data Bridge Safety Under Threading

The bridge between `PackedFloat32Array` and `numpy.ndarray` shares memory (no copy):

- **Read path (safe):** Input `GNData` is read-only during `_cook()`. Main thread doesn't touch it while worker runs.
- **Write path (safe):** `_mutable_input()` duplicates when `_shared=true` (fan-out) before wrapping as NumPy. Worker writes to its own copy.
- **Output (safe):** `_cook()` returns a new `GNData` owned by the worker. Main thread takes ownership after task completion.

No additional synchronisation needed — the existing GONODES data contract guarantees isolation.

#### Distribution Concerns

| Platform | Feasibility |
|---|---|
| Windows / macOS / Linux | **Good** — bundle CPython + NumPy wheels (~80–120MB). Well-trodden path. |
| Web (Emscripten) | **Hard** — Pyodide exists but is heavy (~20MB). Not recommended. |
| Mobile (iOS/Android) | **Impractical** — CPython embedding on mobile is fragile. Not a target. |

This is acceptable: platforms that can't run Python (web/mobile) are unlikely to need heavy-compute Script operators. GDScript + C++ native ops cover those platforms.

### 16.3 The Layered User Experience

```
┌─────────────────────────────────────────────────────────┐
│  User Skill Level → Recommended Path                     │
│                                                          │
│  Beginner/Artist  → GDScript Script operators            │
│                     Instant feedback, zero setup,         │
│                     adequate for typical VJ patches.      │
│                                                          │
│  Intermediate/    → Python Script operators               │
│  TD Refugees        (gn_ext_user_python) ✅ SHIPPED        │
│                     NumPy vectorised, familiar syntax,    │
│                     no compilation step, ecosystem.       │
│                                                          │
│  Advanced/        → Hot-reload C++ nodes                 │
│  Performance        (gn_ext_user_native) ✅ SHIPPED       │
│                     Maximum performance, full Godot API,  │
│                     2–8s iteration cycle.                 │
└─────────────────────────────────────────────────────────┘
```

### 16.4 Implementation Order

| Phase | What | Status |
|---|---|---|
| **Phase 1** | `gn_ext_user_native` (C++ hot-reload) | ✅ **DONE** — 5 operators, integrated editor, bundled toolchain, help docs |
| **Phase 2** | `gn_ext_user_python` (embedded CPython + NumPy) | ✅ **DONE** — 5 operators, C++ GDExtension runtime, Python SDK, integrated editor, help docs |
| **Phase 3** | Python free-threading upgrade | ⬜ Future — when CPython 3.13 free-threading stabilises, flip the build flag. Near-zero effort, removes last GIL serialisation for Python-heavy patches. |

---

## Summary

GONODES is **architecturally competitive** with TouchDesigner for real-time visual art workloads. The cook engine's 3-tier guard system (active set → expression map → input hash) achieves equivalent work-skipping to TD's pull model. The incremental dirty propagation is actually smarter than TD's blanket subtree cascade. Features like non-realtime mode, expression profiling, and the VOL compute pipeline are genuine differentiators.

The honest gaps are: serial GPU cook (Godot limitation), ~~GDScript interpretation overhead for user scripts~~ (now mitigated by 92 native ops + `gn_ext_user_native` C++ hot-reload + `gn_ext_user_python` NumPy vectorisation), and lack of adaptive quality degradation. The GDScript bottleneck is **effectively closed** — users now have three scripting tiers (GDScript → Python+NumPy → C++) with integrated editors and help for each.

For the target domain (VJ, generative art, interactive installations at 30–200 nodes), GONODES delivers real-time performance today. The remaining roadmap items (expression compilation, adaptive frame budget, GPU batch parallelism) would push it toward handling larger, more complex networks and professional production reliability.

---

## 17. Architecture Gap Checklist

> Covers TouchDesigner, vvvv, Houdini, Jitter/Max, and Notch. Consolidated from the original TD_HOUDINI_COMPARISON.md gap analysis. Tracks architectural recommendations from the TD/Houdini comparison.

| # | Recommendation | Priority | Status |
|---|---|---|---|
| A | Parameter-level dependency tracking | High | ✅ **Implemented** — 3-layer expression dep system (consumer map + selective re-eval + value-compare gate + input hash) |
| B | Ramp / curve parameter type | High | ✅ **Implemented** — `ValueType.RAMP` + GNRampEditor + `ramp()` expression |
| C | Reusable asset package (.gnasset) | High | ✅ **Implemented** — GNCustomOperator + promotion wizard + 3-dir scan + edit-in-place. Phase 4 (global sync) ✅ done |
| D | Multi-threaded cook engine | High | ✅ **Implemented** — level-based WorkerThreadPool dispatch |
| E | Data spreadsheet / table viewer | Medium | ✅ **Resolved** — GNViewerPanel Tree spreadsheet + GNWaveformView |
| F | Network boxes + sticky notes | Medium | ✅ **Implemented** |
| G | Keyframe animation system | Medium | ✅ **Implemented** — KeyframeCHOP + SequenceCHOP + ClipCHOP + ChannelCHOP |
| H | CHOP waveform display | Medium | ✅ **Resolved** — GNWaveformView in viewer panel |
| I | Named output ports | Low | ✅ **Implemented** — `GNPort.label` + `display_name()` on all ports |
| J | Dot / routing nodes | Low | ✅ **Implemented** — DotNode operator |
| K | Takes / parameter layer overrides | Low | ✅ **Implemented** — GNTakeManager (capture, blend, save/load `.gntake`) |

**All 11 architecture gap items are resolved.** No open architectural gaps remain vs TD or Houdini for the real-time target domain.

---

## 18. Feature Parity — Coverage Complete

> Covers TouchDesigner, vvvv, Houdini, Jitter/Max, and Notch. All operator gaps identified in the original audit have been resolved. 574 operators across 14 families — 100% coverage vs all competitors combined.

### 18.1 Feature Coverage Matrix

| TD Feature Area | TD Implementation | GONODES Status |
|---|---|---|
| **Texture processing** | 90+ TOPs | **143 TOPs** (118 core + 4 native + 21 extension) — exceeds TD in coverage |
| **Channel/signal** | 70+ CHOPs | **106 CHOPs** — exceeds TD |
| **Geometry** | 50+ SOPs | **80 SOPs** — exceeds TD |
| **Data tables** | 30+ DATs | **47 DATs** — exceeds TD |
| **Materials** | ~10 MATs | **12 MATs** — parity |
| **Components** | COMPs (containers, 3D scenes, panels) | **27 COMPs** — good, physics + proxy fan-out included |
| **GPU Particles** | Particle SOP/POP network | **13 POP operators** — SSBO compute pipeline |
| **3D Volumes** | Not native (3D texture workarounds) | **15 VOL operators** — **GONODES leads here** |
| **UI Widgets** | Panel COMP widgets | **36 UI operators** — exceeds TD |
| **Shader authoring** | GLSL TOP, Compute Shader TOP | CustomShaderTOP + ComputeShaderTOP + ISF + Shadertoy — strong |
| **Video I/O** | Theora, HAP, FFMPEG, NDI, Blackmagic | HAP, FFmpeg, GPU Encode, Theora, NDI, **Blackmagic** (scaffold) |
| **Texture sharing** | Spout (Win), Syphon (Mac) | **Both implemented** |
| **Projection mapping** | Stoner, Kantan Mapper (plugins) | **gn_ext_mapper** built-in |
| **Audio** | Audio analysis, synthesis, device I/O | AudioIn, AudioSpectrum, AudioBand, AudioDynamics, Beat, AudioDeviceOUT |
| **MIDI** | MIDI In/Out | **gn_ext_midi** (RtMidiIn + RtMidiOut) |
| **OSC** | OSC In/Out | OscOutOUT + OscInDAT/OscInCHOP |
| **Serial** | Serial DAT | **gn_ext_serial** |
| **Physics** | Bullet (legacy) | **Jolt physics COMPs** — modern, better |
| **SDF rendering** | Not built-in | **27 SDF operators** (gn_ext_sdf) — GONODES leads |
| **Embed in host apps** | TouchEngine SDK | **LibGodot + libgonodes C API** — comparable |
| **Custom operators** | C++ or Python .tox | **.gnasset + Script operators** |
| **Fluid simulation** | NVIDIA Flex (plugin), GLSL workarounds | **FluidVOL (3D NS) + Fluid2DTOP (2D NS)** |
| **Machine Learning** | TensorFlow, MediaPipe plugins | ✅ `gn_ext_ml` — ONNX Runtime (7 operators) |
| **AR/Face Tracking** | Kinect, Leap, MediaPipe | ✅ FaceDetectCHOP, PoseDetectCHOP, HandDetectCHOP |
| **Depth Sensors** | Kinect, RealSense, ZED, Orbbec, Leap | ✅ `gn_ext_depth_sensor` — Azure Kinect + RealSense + Ultraleap |
| **IoT/MQTT** | Not built-in (Python plugin) | ✅ MqttDAT — MQTT 3.1.1 client |
| **2D Vector Graphics** | GLSL workarounds | ✅ VectorPathTOP — anti-aliased Bézier rendering |
| **Cloth/Fabric Sim** | SOP-level (legacy) | ✅ ClothSOP — Verlet PBD |
| **Asset Instance Sync** | Inline references (auto-update) | ✅ Global .gnasset sync |

### 18.2 Houdini Features Worth Borrowing

| Houdini Concept | Relevance | GONODES Status |
|---|---|---|
| VEX/CVEX wrangle nodes | GDScript node-level scripting | GDScriptSCRIPT (CHOP/SOP/DAT/IMG templates) — ✅ covered |
| HDA (Houdini Digital Assets) | Reusable operator packages | .gnasset + SubNetwork — ✅ covered |
| Attribute system | Rich per-element data | AttributeSOP — partial (no vertex attrs on data type) |
| PDG (Task Graph) | Batch/async processing | Not applicable for real-time |
| FLIP Fluids | Particle-in-cell hybrid | ⬜ Future (see #23 below) |
| Pyro (sparse volumes) | Fire/smoke/explosion | ✅ PyroVOL |
| Wire/Cloth/Hair solvers | Specialized sim | ✅ ClothSOP + Jolt soft body |
| Crowds/Agents | Mass animation instancing | InstanceCOMP partially covers |
| Terrain (HeightfieldSOP) | Generative landscapes | ✅ HeightfieldSOP |
| For-Each loops | Iterative per-piece processing | ReplicatorCOMP |
| Spare parameters | Add params to any node | ✅ Implemented |
| Takes (parameter layers) | Named param snapshots | ✅ GNTakeManager |

### 18.3 Gap Resolution Summary

All operator gaps identified in the original audit (§18.3–§18.13, removed April 2026) have been resolved:

- **27 improvement roadmap items:** 26 of 27 implemented. Only FLIP Fluid (hybrid particle-grid) remains as a deliberate future stretch goal (#23).
- **TOP/IMG gaps:** 18 gap items resolved — 7 new operators built, 4 covered by existing ops, 7 implemented in `gn_ext_opencv`.
- **COMP gaps:** 10 identified, all 10 implemented (ConstraintCOMP, BoneCOMP, LODCOMP, PathCOMP, VehicleCOMP, NavigationCOMP, FeedbackCOMP, TimeCOMP, AudioListenerCOMP, AudioSourceCOMP).
- **Audio gaps:** All 13 audio operators implemented in `gn_ext_audio` extension — bringing GONODES to 21 audio operators, exceeding TD's 12.
- **CHOP non-audio gaps:** All 4 implemented (AreaCHOP, ReplaceCHOP, GestureCHOP, StateMachineCHOP).
- **SOP gaps:** All 6 implemented (ResampleSOP, MeasureSOP, CreepSOP, ProjectSOP, HoleSOP, ConvertLineSOP).
- **DAT gaps:** Both implemented (ParameterDAT, SystemDAT).
- **MAT:** At full parity with TD (SSS available via Godot's StandardMaterial3D).
- **Nuke-specific:** TemporalDenoiseTOP implemented. OCIO color management and planar tracking remain as extension-tier stretch goals (not operator gaps).

### 18.4 Operator Coverage Summary — All Families

| Family | Operators | Notes |
|--------|-----------|-------|
| **TOP** | 140 | 118 core + 4 native + 18 extension — exceeds TD's ~90 |
| **IMG** | 37 | 16 core + 21 extension (gn_ext_opencv, gn_ext_blackmagic, gn_ext_depth_sensor) |
| **CHOP** | 106 | 83 core + 23 extension (gn_ext_audio, gn_ext_midi) — exceeds TD's ~70 |
| **SOP** | 80 | All core — exceeds TD's ~50 |
| **DAT** | 50 | 42 core + 8 extension — exceeds TD's ~30 |
| **COMP** | 27 | All core — physics, proxy fan-out, spatial audio, navigation |
| **MAT** | 12 | At parity with TD |
| **POP** | 13 | GPU compute SSBO — exceeds all competitors |
| **VOL** | 15 | Unique — no competitor has built-in 3D volumes |
| **SDF** | 29 | Unique — no competitor has built-in SDF |
| **UI** | 36 | 33 core + 3 extension — exceeds TD's ~25 |
| **OUT** | 11 | 10 core + 1 extension |
| **NET** | 15 | Host embedding + subnets |
| **SCRIPT** | 3 | 3-tier scripting (GDScript/Python/C++) |
| **TOTAL** | **574** | **100% coverage** vs TD/vvvv/Houdini/Jitter combined |

**GONODES exceeds competitor coverage in:** TOP (140 vs TD's 90), CHOP (106 vs TD's 70), SOP (80 vs TD's 50), DAT (50 vs TD's 30), POP (13 vs 0), VOL (15 vs 0), SDF (29 vs 0), UI (36 vs TD's ~25).

**Remaining stretch goals (not operator gaps):**
- FLIP Fluid (#23) — hybrid particle-grid simulation (very high effort, deliberate future)
- OCIO color management — would require GDExtension wrapping OpenColorIO
- Planar tracking — extension territory (OpenCV-based)

---

## 19. Operator Coverage Audit

> Covers TouchDesigner, vvvv, Houdini, Jitter/Max, and Notch. Consolidated from the original TD_HOUDINI_COMPARISON.md §12. Documents operators added to close TD coverage gaps.

### 19.1 Operators Added (from TD gap analysis)

| Family | Operator | TD Equivalent | Notes |
|--------|----------|--------------|-------|
| CHOP | **FeedbackCHOP** | Feedback CHOP | Previous-frame data for feedback loops |
| CHOP | **BlendCHOP** | Blend CHOP | Weighted blend of 2-8 inputs, 4 easing modes |
| CHOP | **PerformCHOP** | Perform CHOP | FPS, frame_time, memory, frame_count |
| CHOP | **TransformCHOP** | Transform CHOP | 3D transform on xyz channel groups |
| DAT | **WebServerDAT** | Web Server DAT | HTTP server via TCPServer |
| DAT | **WebSocketDAT** | WebSocket DAT | WebSocket client/server |
| DAT | **ErrorDAT** | Error DAT | Hooks GNLogger.log_sink |
| DAT | **FolderDAT** | Folder DAT | Directory listing with glob filter |
| DAT | **MultiTouchInDAT** | Multi Touch In DAT | Touch events as table rows |
| SOP | **FileInSOP** | File In SOP | OBJ/glTF/Resource import |
| SOP | **FileOutSOP** | File Out SOP | OBJ export with pass-through |
| SOP | **GroupSOP** | Group SOP | BBox/Normal/Range/All grouping |
| SOP | **PrimitiveSOP** | Primitive SOP | Per-prim normals, area, centroid |
| SOP | **BlendSOP** | Blend SOP | Vertex-level morph |
| MAT | **NormalMapMAT** | Phong MAT | StandardMaterial3D with normal maps |
| MAT | **LineMAT** | Line MAT | Wireframe with stipple |

### 19.2 Excluded TD Operators — Rationale

**Covered by existing GONODES operators:**
- TCP/IP DAT, UDP In/Out DAT → **NetworkDAT** (TCP + UDP)
- Shift CHOP → **WarpCHOP**
- Cycle CHOP → **ExtendCHOP**
- Clip CHOP → **TrimCHOP**
- CHOP/SOP Execute DAT → **CallbackDAT**
- Phong MAT → **PbrMAT** (roughness=1.0)
- Screen Grab TOP → **ScreenGrabIMG**

**Require external libraries (extension roadmap):**
- NDI → ✅ gn_ext_ndi (implemented)
- Syphon → ✅ gn_ext_syphon (implemented)
- Spout → ✅ gn_ext_spout (implemented)
- MIDI Out → ✅ gn_ext_midi RtMidiOutCHOP (implemented)
- Laser DAC → ⬜ Deferred (EtherDream/Helios/ShowNET need GDExtensions)



---

## Jitter/Max & Notch Comparison & Strategic Analysis

> The following sections were consolidated from the Jitter/Max competitive analysis and extended with Notch coverage. They extend the TD/vvvv/Houdini comparison above with Cycling '74 Jitter coverage, Notch (live events), strategic positioning, and additional competitive dimensions.

## 19. Executive Summary

| Dimension | TouchDesigner | vvvv | Jitter (Max/MSP) | Notch | GONODES |
|-----------|--------------|------|-------------------|-------|---------|
| **Maturity** | 20+ years, industry standard | 25+ years (beta→gamma transition) | 25+ years, deep audio roots | ~10 years, dominant in live events | Alpha — 1 year of development |
| **Operator count** | ~300+ built-in | ~700+ (gamma nodes) | ~200+ Jitter objects + 400+ Max objects | ~200 nodes | **574 operators** across 14 families |
| **Cost** | $2,200+ / $600 non-comm. | Free (gamma) | $399 (perpetual) or $99/yr sub | £5,995+/yr (Builder) | **Free, open source (MIT)** |
| **GPU pipeline** | DirectX 11/12, OpenGL, Vulkan | DirectX 11 (beta) / Stride+Vulkan (gamma) | OpenGL (legacy) / Metal (modern) | **DirectX 11/12 — unified GPU-resident pipeline** | Vulkan + GLES3 via Godot 4.6 |
| **Host embedding** | TouchEngine SDK | No | Max for Live; no general SDK | Notch Playback (disguise, Unreal, Unity) | **libgonodes — full C API, 9 data contexts** |
| **3D engine** | Built-in (limited) | Stride (gamma) | OpenGL/Metal (via `jit.gl.*`) | Built-in (GPU-optimised, DX11/12) | **Full Godot 4.6** (physics, audio, VR) |
| **Best for** | AV installations, VJing, media art | Generative art, data visualization, installations | Audio-visual performance, experimental music | Live events, broadcast, XR | Real-time AV, VJing, generative art, embedded processing |

**Bottom line:** GONODES is architecturally competitive with tools that have decades of development. Its unique advantages — open source, Godot engine integration, libgonodes host embedding, volumetric/SDF pipelines, and 3-tier scripting (GDScript/Python/C++) — position it for scenarios that no single competitor addresses. The honest gaps are maturity, community size, serial GPU cook, adaptive quality degradation, and lack of media server integration (vs Notch).

---


---

### Jitter (Cycling '74 / Max/MSP)
- **Born:** 2001 (as part of Max/MSP 4.5; Max itself dates to 1988 at IRCAM)
- **Identity:** The visual component of Max/MSP — a real-time matrix/video/3D processing environment. Max is primarily an audio/MIDI tool; Jitter adds visual processing
- **Philosophy:** Audio-first architecture with video grafted on. Everything is a "matrix" (N-dimensional typed array). Strong academic and experimental music roots
- **User base:** Academic institutions, experimental musicians, media artists, interactive art. Smaller than TD for pure visual work, but the Max ecosystem is massive
- **Key strength:** Deep, seamless audio-visual integration. Max's dataflow paradigm, IRCAM heritage, Gen~ code generation for audio/GPU, and integration with Ableton Live (Max for Live)

### Notch (Notch.one)
- **Born:** ~2015 (public release; developed by Notch.one, formerly 10bit FX, in London)
- **Identity:** GPU-first, real-time 3D creation engine for live events, broadcast, and XR. Purpose-built for the live entertainment industry
- **Philosophy:** Everything on the GPU, every frame. The entire scene is a single GPU render pipeline — not a data-flow graph. Nodes are render passes/modifiers, not independent data transforms. Timeline-centric workflow designed for cue-based shows
- **User base:** Live event production companies, broadcast graphics, XR studios. Tight ecosystem with disguise (d3) media servers. Smaller than TD overall but dominant in high-end live events
- **Key strength:** Unmatched GPU throughput for dense 3D scenes. GPU particles (millions), fluid sim, cloth, hair — all GPU-native at 60fps. Deep media server integration (disguise, Barco, Green Hippo). Multi-GPU support. Adaptive quality scaling for guaranteed frame delivery


---

## 21. Licensing, Cost & Business Model

| Aspect | TouchDesigner | vvvv | Jitter (Max/MSP) | Notch | GONODES |
|--------|--------------|------|-------------------|-------|---------|
| **License type** | Commercial (subscription or perpetual) | Free (gamma); beta: legacy free non-comm | Perpetual ($399) or subscription ($99/yr) | Subscription (£5,995+/yr Builder) | MIT open source |
| **Non-commercial** | Free (1280×1280 cap, watermark) | Free (no restrictions in gamma) | Education discount; no free tier | No free tier | Free (no restrictions) |
| **Commercial** | $2,200 (perpetual) or $600/yr | Free (gamma); $2,400/yr (beta enterprise) | $399 perpetual | £5,995/yr (Builder), £11,995/yr (Pro) | Free |
| **Resolution limits** | Free: 1280×1280. Commercial: unlimited | None | None | None | **None** |
| **Source available** | No (proprietary) | No (gamma: closed .NET) | No (proprietary) | No (proprietary) | **Yes — full source** |
| **Deployment license** | Included in commercial license; free version adds watermark | Free | Included | Playback bundled with media servers | **Free — no licensing for deployment** |
| **Revenue model** | Software license sales | Community + consulting | Software license + Ableton partnership | Software license + media server partnerships | None (community-driven) |

**GONODES advantage:** Zero cost at any scale. No resolution limits, no watermarks, no deployment fees, no dongles. Full source code access. This is a profound differentiator for students, artists, small studios, and anyone building custom installations. The only cost is development time and hardware. Notch is the most expensive tool in this comparison (£5,995+/yr for the Builder edition) and has no free tier — making GONODES the polar opposite in terms of accessibility.

**Risk for GONODES:** No revenue model means development depends on contributor goodwill and (potentially) grants/sponsorship. Competitors have dedicated engineering teams funded by license revenue.

---


---

## 22. Data Types & Families

| Data concept | TouchDesigner | vvvv | Jitter | Notch | GONODES |
|-------------|--------------|------|--------|-------|---------|
| **GPU texture** | TOP (2D texture) | Texture (Stride) | `jit.gl.texture` (2D) | Implicit (render pipeline textures) | TOP (SubViewport texture) |
| **CPU image** | TOP (CPU mode) | Image | `jit.matrix` (char/float planes) | N/A (everything GPU) | IMG (Image-based) |
| **Multi-channel float** | CHOP (channels) | Spread (beta) / Sequence (gamma) | `jit.matrix` (1D float array) | N/A (params/timeline only) | CHOP (Dictionary of PackedFloat32Array) |
| **Table/text** | DAT (rows×cols) | Spreadsheet (gamma) | `jit.cellblock` / Dictionary | N/A | DAT (GNTableData) |
| **Geometry/mesh** | SOP (point/poly) | Mesh (Stride) | `jit.gl.mesh` + `jit.matrix` (vertex data) | Built-in (GPU-resident meshes) | SOP (ArrayMesh via GNGeoData) |
| **Material** | MAT | Material (Stride) | Shader/texture bindings | Built-in materials | MAT (ShaderMaterial/Standard) |
| **3D scene graph** | COMP hierarchy | SceneGraph (Stride) | `jit.gl.render` context | Scene graph (modifier stacks) | COMP (Godot Node3D tree) |
| **GPU particles** | Not typed | Not typed | Not typed | Built-in (GPU-native, millions) | **POP (SSBO particle buffers)** |
| **3D volumes** | Not typed | Not typed | Not typed | Not typed | **VOL (Texture3D voxel grids)** |
| **SDF** | Not typed | Not typed | Not typed | Not typed | **SDF (ray-marched fields)** |

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


---

## 23. Host Embedding — The libgonodes Advantage

This is GONODES's most unique capability and the area where it has clear superiority over all competitors.

### Comparison Matrix

| Capability | TouchEngine SDK | vvvv | Jitter / Max | Notch Playback | libgonodes |
|-----------|----------------|------|-------------|----------------|------------|
| **Embed in host apps** | Yes (TouchEngine) | No | Max for Live only (Ableton) | **Yes** (disguise, Unreal, Unity) | **Yes — any C-calling app** |
| **GPU context sharing** | Yes (shared device) | N/A | No | Yes (DX11/12 shared device) | **Yes (Vulkan, Metal, OpenGL)** |
| **Bidirectional textures** | Yes (zero-copy) | N/A | No | Yes (texture output) | **Yes (zero-copy)** |
| **Bidirectional channels** | Yes (float arrays) | N/A | Limited (Live API) | Limited (parameter values) | **Yes (multi-channel CHOP)** |
| **Bidirectional tables** | Yes (string tables) | N/A | No | No | **Yes (row×col tables)** |
| **Bidirectional geometry** | **Read-only** | N/A | No | No | **Yes (full bidirectional)** |
| **Bidirectional volumes** | **Not supported** | N/A | No | No | **Yes** |
| **Bidirectional particles** | **Not supported** | N/A | No | No | **Yes** |
| **MIDI injection** | Parameter mapping only | N/A | Native (Ableton→Max) | MIDI input in scene | **Direct MIDI events** |
| **OSC injection** | Parameter mapping only | N/A | Native `udpreceive` | OSC input in scene | **Direct OSC messages** |
| **Bidirectional events** | Pulse params (host→only) | N/A | No | No | **Yes (fire_event / on_event)** |
| **Graph editing from host** | **Not supported** | N/A | No | **Not supported** | **Full CRUD (create/delete/connect)** |
| **Parameter control** | Yes (all types) | N/A | Limited (Live API params) | Yes (exposed parameters) | **Yes (all types)** |
| **Hot reload** | Yes | N/A | No | Yes | **Yes (with state preservation)** |
| **Data contexts** | 4 (texture, channels, table, limited geo) | 0 | 1 (Ableton params) | 2 (texture, parameters) | **9 (texture, channels, table, geo, volume, particles, MIDI, OSC, events)** |

### What This Means

**libgonodes is the only embeddable node-graph engine that supports bidirectional exchange of 9 data contexts through a single C API.** No other tool comes close:

- **TouchEngine** is the nearest competitor but lacks bidirectional geometry, volume, and particle exchange. It also can't edit the graph at runtime from the host.
- **Notch Playback** embeds in disguise/Unreal/Unity with GPU texture output and parameter control, but offers only 2 data contexts (texture + parameters). No bidirectional data exchange, no graph editing, no geometry/volume/particle contexts.
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


---

## 24. 3D Engine Integration

| Feature | TouchDesigner | vvvv beta | vvvv gamma | Jitter | Notch | GONODES |
|---------|-------------|-----------|------------|--------|-------|---------|
| **Underlying engine** | Custom (Derivative) | Custom (DX11) | Stride (Vulkan-based) | None (raw GL/Metal) | Custom (DX11/12, GPU-first) | **Godot 4.6** |
| **Physics** | Bullet (legacy) | Box2D/Bullet plugins | Bepu Physics (Stride) | None built-in | **GPU cloth, hair, fluids** | **Jolt Physics (modern)** |
| **Scene graph** | COMP hierarchy | SceneGraph | Stride SceneGraph | `jit.gl.render` context | Modifier stack (3ds Max-style) | **Godot Node3D tree** |
| **Lighting** | Basic (legacy pipeline) | DX11 deferred | Stride PBR | OpenGL fixed-function + GLSL | **PBR, area lights, volumetric** | **Godot Forward+ PBR** |
| **Shadows** | Basic shadowmaps | VSM, CSM plugins | Stride shadowmaps | Manual (fragment shader) | **Direct shadows, contact shadows** | **Godot CSM + PCF** |
| **Post-processing** | GLSL TOPs (manual) | Plugins | Stride post-process | Manual slab chains | **Built-in (bloom, DOF, motion blur, color grading)** | **Built-in (glow, DOF, SSAO, SSIL, SSR, fog)** |
| **VR/AR** | OpenVR/OpenXR plugin | Plugin | Partial | None | No | **Godot OpenXR** |
| **PBR materials** | Phong + custom shaders | PBR (DX11 plugins) | Stride PBR | Manual shaders | **PBR (metallic/roughness)** | **StandardMaterial3D (full PBR)** |
| **Animation** | Basic + CHOP-driven | Timeline | Stride animation | None | **Timeline + keyframe (deep)** | **AnimationCOMP + KeyframeCHOP** |
| **Instancing** | Instance COMP | Instancing (DX11) | Stride instancing | `jit.gl.mesh @draw_mode instanced` | **GPU instancing (millions)** | **InstanceCOMP (MultiMesh)** |
| **Terrain** | Not built-in | Not built-in | Not built-in | Not built-in | Heightmap terrain | **HeightfieldSOP** |

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


---

## 25. Shader Authoring

| Feature | TouchDesigner | vvvv | Jitter | Notch | GONODES |
|---------|-------------|------|--------|-------|---------|
| **Fragment shaders** | GLSL TOP | HLSL (beta), SDSL (gamma) | Gen→GLSL, raw GLSL | Limited (material overrides, no custom shaders) | CustomShaderTOP (GLSL) |
| **Compute shaders** | GLSL Compute TOP | Stride compute (gamma) | **Not available** | Built-in (particles, fluids — no user access) | ComputeShaderTOP |
| **ISF format** | No | No | No | No | **Yes (gn_ext_isf)** |
| **Shadertoy format** | No | No | No | No | **Yes (gn_ext_shadertoy)** |
| **Visual shader editor** | No | **VL→shader** (partial) | **Gen** (visual codegen) | No | No |
| **Shader presets** | No | No | No | No | **Yes (factory + user)** |
| **GLSL hot-reload** | Manual | Manual | Via Gen patching | N/A | **Automatic (file watcher)** |
| **Multi-pass** | Manual chain | Manual | Manual slab chain | Built-in (render pipeline manages passes) | FeedbackTOP + shader chain |

### Jitter Gen — A Unique Approach

Gen is Jitter's standout shader feature: a visual patching environment that compiles to GLSL (for GPU) or optimized C (for CPU audio). Users patch with math operators, and Gen generates the shader code. This lowers the barrier to GPU programming significantly — no GLSL syntax knowledge needed.

GONODES has no visual shader editor, but compensates with:
- **ISF support** — Interactive Shader Format, a cross-platform shader standard with a large community library
- **Shadertoy support** — one-click import of thousands of shaders from shadertoy.com
- **Shader presets** — save/load custom shader configurations with factory examples

The visual shader editing gap is real but less critical given ISF/Shadertoy compatibility and the wealth of existing shaders available in those formats.

---


---

## 26. Asset & Project Management

| Feature | TouchDesigner | vvvv | Jitter / Max | Notch | GONODES |
|---------|-------------|------|-------------|-------|---------|
| **Project format** | `.toe` (binary) | `.vl` (XML in gamma) | `.maxpat` (JSON) | `.dfx` (proprietary binary) | `.gnpatch` (JSON) |
| **Version control friendly** | No (binary) | Partial (XML) | **Yes (JSON)** | No (binary) | **Yes (JSON)** |
| **Reusable assets** | `.tox` (COMP export) | NuGet packages | Max patchers + packages | Notch Blocks (presets) | `.gnasset` (JSON, self-contained) |
| **Asset promotion** | Manual | N/A | Subpatch encapsulation | N/A | **Wizard-based (spare params → interface)** |
| **Instance sync** | Inline (auto-update) | NuGet versioning | Package versioning | N/A | Global `.gnasset` sync on save |
| **Read-only assets** | No | N/A | No | N/A | **Yes (lock + "Make Editable" escape hatch)** |
| **Help patches per node** | Yes (~1 per node) | Yes | Yes (~2–3 per node) | Tutorials (not per-node) | **Yes (3+ per node, 1,413 total)** |
| **Package manager** | No (community sharing) | NuGet | **Max Package Manager** | No | No (file-based) |
| **OS drag-and-drop** | Limited | No | No | No | **Yes (.gnpatch + .gnasset files)** |
| **Undo/redo** | Yes | Yes | Yes | Yes | **Yes (compound actions)** |
| **Copy/paste** | Yes | Yes | Yes | Yes | **Yes (JSON clipboard)** |

### Jitter/Max's Package Ecosystem

Max has a mature package manager that's a genuine strength — thousands of community packages covering MIDI controllers, audio effects, video processing, ML, and more. `jit.mo` (motion), `jit.bfg` (noise), the VIZZIE library (beginner-friendly video effects) — all installable from within Max.

GONODES has no package manager yet. The extension architecture (`gn_ext_*`) provides the foundation, but there's no discovery/install mechanism beyond manually placing addons.

---


---

## 27. UI & Editor Experience

| Feature | TouchDesigner | vvvv | Jitter / Max | Notch | GONODES |
|---------|-------------|------|-------------|-------|---------|
| **Node graph style** | Wired, left→right flow | Wired, spread-based (beta); VL (gamma) | Wired, top→down patcher | Wired, modifier stack (3ds Max-style) | Wired, left→right (Godot GraphEdit) |
| **Live node previews** | Yes (TOP thumbnails) | Yes (pins show data) | No (patchers are static) | **Yes** (viewport preview) | **Yes (per-node toggle)** |
| **Parameter inspector** | Right-click dialog | Inspector (gamma) | Object inspector | Properties panel | **Docked inspector panel** |
| **Performance profiling** | Yes (per-node cook time) | Yes (frame profiler) | No (manual timing) | Yes (GPU profiler) | **Yes (per-node + per-expression µs)** |
| **Debug tools** | Probe, Info CHOP | Tooltip pins, Renderer | `print`, `jit.print` | Limited | **Debug panel (F2, 3 tabs, 5 overlay layers)** |
| **Code editor** | External (Atom, etc.) | Integrated (VL) | Integrated (Gen) | N/A (no scripting) | **Integrated (GNCodeEditor, syntax HL)** |
| **Context menus** | Yes | Yes | Yes | Yes | **Yes (right-click, copy as JSON)** |
| **Network boxes** | Not built-in | No | None | N/A | **Yes (annotations + sticky notes)** |
| **Timeline** | Basic | Basic | Transport bar | **Full timeline** (cue-based, keyframe-rich) | **TimelineCHOP + CueDAT + Editor UI** |
| **Keyboard shortcuts** | Extensive | Extensive | Extensive | Moderate | Growing |
| **Multi-monitor** | Yes (separate windows) | Yes | Yes | Yes (multi-viewport) | WindowOUT (separate windows) |
| **Float field control** | Slider + text field | Slider | Number box + slider | Slider | **Houdini-style (drag, ladder tiers, Shift/Ctrl modifiers)** |

### Jitter/Max Editor Experience

Max's patcher window is fundamentally different from node-graph tools:
- **Top-down flow** (messages flow down, not left-to-right)
- **No live previews** — you can't see texture thumbnails on nodes (must open a `jit.pwindow` or `jit.gl.render` window)
- **Locked/unlocked modes** — edit mode (unlock) vs performance mode (lock). In performance mode, UI objects become interactive. This is unique and powerful for building custom interfaces.
- **Presentation mode** — a second visual layer where you arrange UI elements for end-user interaction, hiding the patcher underneath

Max's UI building story (presentation mode, bpatcher embedding, Max for Live device creation) is more mature than GONODES's UI operators, though GONODES's UI family provides a node-graph-integrated approach that's arguably more flexible for generative/reactive UIs.

---


---

## 28. Cross-Platform & Deployment

| Platform | TouchDesigner | vvvv beta | vvvv gamma | Jitter / Max | Notch | GONODES |
|----------|-------------|-----------|------------|-------------|-------|---------|
| **Windows** | Primary | Yes | Yes | Yes | **Primary (only)** | **Yes** |
| **macOS** | Experimental | No | Yes | Yes | No | **Yes** |
| **Linux** | No | No | Yes | No | No | **Yes** |
| **Web (HTML5)** | No | No | No (planned) | No | No | **Yes (Godot export)** |
| **iOS** | No | No | No | No (MIRA remote only) | No | **Yes (Godot export)** |
| **Android** | No | No | No | No | No | **Yes (Godot export)** |
| **Standalone export** | Yes (Player, TouchEngine) | Yes (exe) | Yes (.exe, runtime) | No (requires Max) | Yes (Notch Playback) | **Yes (Godot export templates)** |
| **Headless/server** | Limited (TouchEngine) | Yes (beta server) | Yes (.NET console) | No | No | **Yes (exported player)** |
| **ARM64** | No | No | Planned | Apple Silicon (Rosetta) | No | **Yes (native ARM64)** |

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
- **Notch** is **Windows-only** — the most platform-restricted tool in this comparison

For artists creating installations on Raspberry Pi, web-based generative art, or mobile interactive experiences, GONODES is the only option among these tools.

---


---

## 29. Audio Pipeline

| Feature | TouchDesigner | vvvv | Jitter / Max | Notch | GONODES |
|---------|-------------|------|-------------|-------|---------|
| **Audio synthesis** | Limited (via CHOP) | Limited | **400+ MSP objects — complete audio language** | None | Limited (21 audio CHOPs) |
| **Sample-accurate timing** | No (frame-based) | No | **Yes (MSP signal vector)** | No | No (frame-based) |
| **Audio effects** | Basic (via CHOP math) | Basic | **Complete (EQ, reverb, delay, compression, etc.)** | None | AudioDynamicsCHOP (compressor/limiter/gate) |
| **FFT analysis** | AudioSpectrum CHOP | Plugins | `pfft~` (phase vocoder) | **Yes** (audio-reactive input) | AudioSpectrumCHOP + AudioBandCHOP |
| **Audio I/O** | 1 device | Basic | **ASIO, CoreAudio, multi-device** | Audio input only | 1 device (Godot AudioServer) |
| **MIDI→audio** | Via CHOP→audio | Via nodes | **Native (noteout~, etc.)** | N/A | Via CHOP→AudioDeviceOUT |
| **DAW integration** | No | No | **Max for Live (full Ableton integration)** | No | No |
| **Spatial audio** | No | No | `mc.` (multichannel) | No | **Godot AudioStreamPlayer3D** |
| **Audio recording** | Via FFmpeg | No | `sfrecord~` (WAV/AIFF) | No | RecordOUT (via FFmpeg) |

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


---

## 30. Physics & Simulation

| Feature | TouchDesigner | vvvv | Jitter / Max | Notch | GONODES |
|---------|-------------|------|-------------|-------|---------|
| **Physics engine** | Bullet (legacy) | Box2D, Bullet plugins | None built-in (deprecated `jit.phys.*`) | **GPU sim (proprietary)** | **Jolt Physics (modern)** |
| **Rigid body** | Bullet | Plugins | Deprecated | Basic | **RigidBodyCOMP** |
| **Soft body** | No | No | No | No | **SoftBodyCOMP** |
| **Cloth** | Not built-in | No | No | **Yes (GPU cloth)** | **ClothSOP (Verlet PBD)** |
| **Vehicle physics** | No | No | No | No | **VehicleCOMP (Jolt)** |
| **Constraints/joints** | Basic | Basic | No | Basic | **JointCOMP (6 joint types)** |
| **Fluid sim** | Plugin/GLSL workaround | No | No | **Yes (GPU fluids)** | **FluidVOL (3D Navier-Stokes) + Fluid2DTOP** |
| **Particle sim** | Legacy Particle SOP | No | Deprecated `jit.phys.*` | **Yes (GPU particles — millions)** | **14 POP operators (GPU compute)** |
| **Pyro (fire/smoke)** | Not built-in | No | No | **Yes (GPU volumetric)** | **PyroVOL** |
| **Navigation/pathfinding** | No | No | No | No | **NavigationCOMP** |
| **Hair** | No | No | No | **Yes (GPU hair sim)** | No |

GONODES and Notch both have strong physics/simulation offerings, but with different architectures: Notch runs everything on the GPU within its unified pipeline (higher throughput for GPU-resident sim), while GONODES uses a mix of CPU (Jolt physics) and GPU compute (POP, VOL) with typed data flow between stages.

---


---

## 31. Machine Learning & Computer Vision

| Feature | TouchDesigner | vvvv | Jitter / Max | Notch | GONODES |
|---------|-------------|------|-------------|-------|---------|
| **ML framework** | TensorFlow, PyTorch plugins | ML.NET, ONNX (gamma) | None built-in | No | **gn_ext_ml (ONNX Runtime)** |
| **Object detection** | MediaPipe plugin | YOLO plugin | None | No | **ObjectDetectDAT** |
| **Pose estimation** | MediaPipe plugin | None | None | No | **PoseDetectCHOP** |
| **Face detection** | MediaPipe plugin | None | None | No | **FaceDetectCHOP** |
| **Hand tracking** | MediaPipe plugin | None | None | No | **HandDetectCHOP** |
| **Style transfer** | Plugin | None | None | No | **StyleTransferTOP** |
| **Depth estimation** | Plugin | None | None | No | **DepthEstimateTOP** |
| **Segmentation** | Plugin | None | None | No | **SegmentationTOP** |
| **Custom models** | Yes (Python) | Yes (.NET) | No | No | **OnnxInferenceTOP (any ONNX model)** |
| **Depth sensors** | Kinect, RealSense, ZED, Leap, Orbbec | Kinect, RealSense, Nuitrack | None | No | **gn_ext_depth_sensor (3 backends)** |

All five tools except Notch have ML capabilities through extensions or plugins. Notch focuses purely on GPU rendering and has no ML inference pipeline. GONODES's gn_ext_ml with 7 dedicated operators provides a well-integrated experience, but TD's MediaPipe integration is more mature and covers more models.

---


---

## 32. Community, Ecosystem & Learning Resources

| Aspect | TouchDesigner | vvvv | Jitter / Max | Notch | GONODES |
|--------|-------------|------|-------------|-------|---------|
| **Community size** | Large (tens of thousands) | Medium (thousands, EU-focused) | Large (Max community; Jitter subset) | Medium (live events niche) | **Small (early alpha)** |
| **Forum** | forum.derivative.ca (very active) | discourse.vvvv.org | cycling74.com/forums | notch.one/forum | N/A |
| **Tutorials** | Hundreds (YouTube, courses) | Good documentation + tutorials | Extensive (30+ years of books, courses) | Limited (official tutorials) | Minimal (help patches only) |
| **Books** | Several third-party | "vvvv — a Multipurpose Toolkit" | Dozens (Max/MSP, Jitter, Gen) | None | None |
| **Courses** | Interactive & Immersive HQ, YouTube channels | NODE festival workshops | Kadenze, Berklee, many universities | None | None |
| **Package ecosystem** | Palette (community .tox) | NuGet (gamma), Contribution (beta) | **Max Package Manager (thousands)** | None | gn_ext_* addons (manual) |
| **Industrial adoption** | High (studios, agencies, events) | Medium (installations, architecture) | Medium (academic, music) | **High** (live events, broadcast) | None yet |
| **Job market** | Growing (TD-specific job postings) | Niche | Academic + music industry | Niche (live events specialists) | None |
| **Documentation** | Good (wiki + Forum) | Good (gamma), aging (beta) | Extensive (Max docs + Jitter tutorials) | Adequate (official docs) | 1,413 help patches + dev docs |
| **Example database** | Palette examples | Girlpower demo folder | Jitter-examples, Recipe series | Official examples | 1,413 help patches |

### This Is GONODES's Biggest Gap

Community and ecosystem are arguably more important than technical features for adoption. All four competitors have:
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


---

## 33. Unique Strengths Per Tool

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

### Notch — Only In Notch

1. **Unified GPU pipeline** — the entire scene (geometry, particles, simulation, compositing, post-processing) is a single GPU submission. Zero per-node overhead. No other tool achieves this level of GPU pipeline unification
2. **Media server ecosystem** — the deepest integration with disguise (d3), Barco, and Green Hippo media servers. Notch is the de facto standard for high-end live event visuals
3. **GPU hair simulation** — real-time GPU-native hair/strand simulation. No competitor in this comparison has built-in hair sim
4. **Adaptive quality with guaranteed frame delivery** — dynamic resolution scaling and LOD to guarantee frame targets during live shows. Critical for broadcast where dropped frames are unacceptable
5. **Multi-GPU workload distribution** — automatic distribution of render work across multiple GPUs for maximum throughput on media server hardware

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


---

## 34. Conclusion

### Where GONODES Stands Today

GONODES is a technically impressive alpha-stage tool that has achieved remarkable breadth in one year of development:

- **574 operators** across 14 families — more than TD's ~300 or Notch's ~200, comparable to vvvv's ~700
- **Architecture** — push-based cook engine with 3-tier guard system achieves equivalent work-skipping to TD's mature pull engine. Notch's full-scene-every-frame approach trades this efficiency for unified GPU pipeline throughput
- **GPU compute** — POP, VOL, and SDF pipelines exceed all four competitors in built-in compute capability. Notch has strong GPU sim (particles, fluids, cloth, hair) but within a closed, non-extensible pipeline
- **Host embedding** — libgonodes offers the most comprehensive embeddable node-graph engine ever built (9 data contexts, bidirectional, graph editing). Notch Playback is limited to texture output + parameters
- **Platform reach** — 6 deployment platforms vs TD's 1.5, Max's 2, vvvv's 3, Notch's 1
- **Open source** — no competitor offers this. Zero cost, full source, no restrictions

### Where GONODES Falls Short

- **Maturity** — alpha status means unknown edge cases, untested production scenarios, and potential architectural issues not yet discovered
- **Community** — zero community content, tutorials, or production track record. This is the #1 adoption barrier
- **GPU parallelism** — Godot's single render thread limits multi-chain GPU utilization vs TD and Notch
- **GPU pipeline unity** — Notch's unified GPU pipeline achieves higher throughput for dense 3D scenes than GONODES's per-SubViewport model
- **Media server integration** — Notch dominates the live event pipeline via disguise/d3 partnerships. GONODES has no media server ecosystem
- **Audio** — orders of magnitude behind Max/MSP for audio synthesis (but this isn't the target domain)
- **Adaptive quality** — can't gracefully degrade under load like TD and Notch can

### Strategic Position

GONODES occupies a unique position that no competitor addresses:

1. **Free + open source** — the only node-based real-time visual tool that's genuinely open
2. **Embeddable** — the only tool with a comprehensive C embedding API (9 data contexts)
3. **Full game engine** — the only tool built on a modern game engine with PBR, physics, VR, and 6-platform export
4. **Compute pipelines** — the only tool with built-in GPU volume, particle, and SDF compute (Notch has particles and fluids but no volumes or SDFs, and they're not user-extensible)
5. **Extensibility** — 3-tier scripting (GDScript/Python/C++) vs Notch's zero scripting, TD's Python-only, vvvv's .NET VL

The competitive strategy should not be "beat TD at being TD" or "beat Notch at live events" — those fights require decades and media server partnerships. Instead, GONODES should lean into its unique strengths: **open source access**, **embeddability**, **compute pipelines**, **cross-platform reach**, **extensibility**, and **Godot engine integration**. These create use cases that TD, vvvv, Jitter, and Notch simply cannot address.

The primary risk isn't technical — it's adoption. A technically superior tool with no community will lose to a technically adequate tool with thousands of users and tutorials. Priority #1 should be building the community and content ecosystem that makes GONODES approachable and trustworthy for real projects.


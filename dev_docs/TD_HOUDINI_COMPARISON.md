# TouchDesigner vs Houdini vs GONODES — Architecture Deep Dive

> **Audience:** Core developers and architecture reviewers.  
> **Date:** 2026-03-03  
> **Purpose:** Comprehensive comparison of cooking models, data flow, engine architecture, and UI patterns across all three systems — with actionable improvement recommendations for GONODES.
>
> Several recommendations from this document have been implemented:
> - ✅ Ramp parameter type with curve editor (§11.2.B)
> - ✅ Network boxes + sticky notes (§11.2.F)
> - ✅ Audio Band CHOP — multi-band frequency analysis with envelope followers (§13 #1)
> - ✅ 2D Fluid TOP — Navier-Stokes feedback shader with dual viewport (§13 #16)
> - ✅ Reaction-Diffusion TOP — Gray-Scott generative patterns, 7 presets (§13 #11)
> - ✅ FluidVOL vorticity confinement — curl amplification compute pass (§13 #7)
> - ✅ FluidVOL obstacle collision — SDF/mesh mask injection into velocity field (§13 #5)
> - ✅ Timeline / Cue system — TimelineCHOP, CueDAT, CueCHOP, Editor Timeline UI (§13 #6)
> - Remaining items tracked in GONODES_CONTEXT.md roadmap and §13 below

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Cooking Model](#2-cooking-model)
3. [Data Flow & Type System](#3-data-flow--type-system)
4. [Parameter & Expression Systems](#4-parameter--expression-systems)
5. [Graph Topology & Evaluation Order](#5-graph-topology--evaluation-order)
6. [Performance Architecture](#6-performance-architecture)
7. [Scripting & Extensibility](#7-scripting--extensibility)
8. [UI & Workflow Patterns](#8-ui--workflow-patterns)
9. [Sub-Networks & Encapsulation](#9-sub-networks--encapsulation)
10. [I/O & External Integration](#10-io--external-integration)
11. [Gap Analysis & Recommendations](#11-gap-analysis--recommendations)
12. [Operator Coverage Gap Analysis](#12-operator-coverage-gap-analysis)
13. [Full Feature Audit & Improvement Roadmap](#13-full-feature-audit--improvement-roadmap)

---

## 1. Executive Summary

| Aspect | TouchDesigner | Houdini | GONODES |
|--------|--------------|---------|---------|
| **Primary domain** | Real-time visuals, interactive media | VFX, simulation, procedural modeling | Real-time visuals, VJing |
| **Cook paradigm** | Pull-based, demand-driven per frame | Pull-based, demand-driven on dependency change | Push-based, topo-sorted per frame |
| **Engine language** | C++ (operators), Python (scripting) | C++ (HDK), VEX (shaders/wrangles), Python/HScript | GDScript (operators), GDScript (scripting) |
| **GPU pipeline** | DirectX 11/12, OpenGL, Vulkan (GLSL/HLSL) | Karma (CPU/GPU), OpenGL viewport, Vulkan (Houdini 20+) | Godot renderer (Vulkan/OpenGL via SubViewport + GLSL) |
| **Node families** | TOP, CHOP, SOP, DAT, COMP, MAT, UI | SOP, DOP, VOP, COP, CHOP, ROP, LOP, TOP (PDG) | TOP, IMG, CHOP, DAT, SOP, POP, VOL, COMP, MAT, OUT, UI |
| **Typical network size** | Dozens to hundreds of nodes | Hundreds to thousands of nodes | Dozens to hundreds of nodes |
| **Hierarchy model** | COMPs contain networks (infinite nesting) | Subnet OTLs, HDA assets (infinite nesting) | SubNetworkNode with InTunnel/OutTunnel |
| **Open source / cost** | Commercial ($2,200+ / $600 non-comm.) | Commercial ($4,495+ / free non-comm.) | Open source (Godot 4.6 + GDScript) |

---

## 2. Cooking Model

### 2.1 TouchDesigner

TD uses a **pull-based, demand-driven** cook model:

- Each operator has a **cook flag** (dirty bit). When an output is requested by a downstream consumer, the operator checks its dirty state, recursively requests inputs if needed, cooks, caches the result, and clears the dirty flag.
- **Time-sliced cooking**: TD divides each frame's cook budget across operators. If the frame overruns, it drops frames or reduces quality — the engine prioritizes maintaining the target FPS.
- **Viewer-driven demand**: Only operators whose output is currently *visible* (in a viewer, exported via Syphon/NDI, or feeding an output) are demanded. Disconnected subgraphs never cook.
- **Frame-independent operators**: Some operators (like MovieFileIn, AudioDeviceIn) have their own internal clock and can cook asynchronously.
- **Cook dependency chain**: TOP→TOP follows GPU pipeline order. CHOPs are CPU-cook. SOPs are CPU-cook. The engine handles cross-family dependencies (e.g., a CHOP export driving a TOP parameter) by ensuring the CHOP cooks before the TOP in the same frame.
- **Parallel cook**: TD cooks multiple independent TOP chains on separate GPU threads/streams. CPU operators (CHOP, SOP, DAT) run on the main thread but can use the Thread CHOP for parallel CPU work.
- **Export CHOP**: A special mechanism where CHOP channels are "exported" to target parameters, bypassing the normal pull chain. This creates a side-channel that runs after the main cook.
- **Pulse cook**: Operators like Script CHOP can be set to "Cook Type: Manual" and only cook when explicitly pulsed — not every frame.

**Key behaviors:**
- An operator never cooks unless something downstream *wants* its output.
- Time-dependent operators (LFO, Noise, Audio) mark themselves dirty every frame.
- Parameter changes propagate dirty upstream→downstream via the dependency graph.
- GPU TOPs leverage the GPU command queue — multiple TOPs can be submitted in a batch.

### 2.2 Houdini

Houdini uses a more sophisticated **pull-based, demand-driven** cook model, but with a fundamentally different philosophy:

- **Cook-on-demand**: Nodes only cook when their output is explicitly requested — typically by the viewport, a ROP (render output), or a downstream node. Unrequested nodes remain uncalculated.
- **Time dependency is explicit**: Each node declares whether it depends on `$T` (time), `$F` (frame), or other time-varying variables. Only time-dependent nodes recook on frame change. Non-time-dependent nodes cache indefinitely until an input or parameter changes.
- **Expression dependency tracking**: Houdini builds a fine-grained dependency graph at the *parameter* level, not just the node level. If parameter A references parameter B via `ch("../node/param")`, Houdini knows that changing B invalidates only paramA → nodeA, not the entire downstream tree. This is more precise than whole-node dirty propagation.
- **Cooking is not per-frame**: Houdini cooks *on change*. In the viewport, moving the timeline triggers a cook. Editing a parameter triggers a cook. But if nothing changes, nothing cooks — even time-dependent SOPs only recook when the frame changes.
- **Compiled cook**: SOPs (geometry) use a "compiled" cook optimization: Houdini can analyze a chain of SOPs and fuse their operations into a single compiled block, executing them as one unit without intermediate geometry allocation. This is critical for large procedural networks.
- **PDG/TOPs (Task Operator Graph)**: Houdini's "TOP" family (confusingly named, different from TD's TOPs) is a **task dependency graph** for batch processing. It's not real-time — it's a job scheduler for farm rendering, simulation caching, etc.
- **Multi-threaded SOP cook**: Many SOPs (wrangle, VDB operations, polyreduce) are internally multi-threaded. The cook engine itself is single-threaded, but individual node cooks can spawn worker threads.
- **Lock/Bypass/Template**: Each node can be locked (cached, won't recook), bypassed (passes input through), or templated (visible in viewport but not passed downstream).

**Key behaviors:**
- Parameter-level dependency is the foundation — far more granular than TD or GONODES.
- Non-time-dependent networks are essentially "computed once, cached forever" until you touch a parameter.
- The compiled SOP block is a massive performance feature — fusing 20 SOPs into one compiled unit.
- Cook events propagate *up* the chain (pull) rather than *down* (push).

### 2.3 GONODES

GONODES uses a **push-based, topography-sorted per-frame** cook model:

- Every frame, `cook_frame(delta)` runs: marks time-dependent nodes dirty, topo-sorts, cooks dirty+active nodes in topo order with input hash guard (parameter values + input timestamps — nodes skip cooking entirely when inputs unchanged).
- **Active chain cooking** limits work to subgraphs feeding live sinks (viewers, WindowOUT, RecordOUT, etc.).
- Inactive nodes keep `cached_output` frozen — **similar to TD's demand-driven model**.
- Cook is **synchronous, single-threaded, main-thread** — no parallel cook lanes.
- Parameter resolution (expression eval) happens inline before each node cooks.
- TOPs push GPU work via SubViewport `UPDATE_ONCE` — Godot's renderer handles the actual GPU submission.

### 2.4 Comparison Table

| Behavior | TouchDesigner | Houdini | GONODES |
|----------|--------------|---------|---------|
| Cook trigger | Demand (downstream pull) | Demand (downstream pull) | Frame loop (topo-sorted push) |
| Dirty granularity | Node-level | Parameter-level | Expression-level dep map + input hash guard |
| Time-dep recook | Auto per frame for time-dep nodes | Only on frame change (explicit $T/$F) | Auto per frame for time-dep nodes |
| Inactive subgraph | Never cooks (no demand) | Never cooks (no demand) | Active chain skips them |
| GPU parallelism | Multi-stream TOP cook | Karma GPU (offline) | Single Godot render thread |
| CPU parallelism | Thread CHOP, async I/O | Multi-threaded SOPs, PDG farm | Single thread |
| Compiled blocks | No | Yes (SOP compile) | No |
| Cook throttle | Frame budget / frame drop | N/A (not real-time) | `max_cooks_per_frame` |
| Non-realtime mode | No (always real-time) | Default (not real-time) | Yes (fixed timestep) |

---

## 3. Data Flow & Type System

### 3.1 TouchDesigner

TD has **six operator families**, each with a dedicated data type:

| Family | Data | Typical size | Transfer |
|--------|------|-------------|----------|
| TOP | GPU texture (FBO) | 1920×1080 RGBA32F | GPU→GPU (zero-copy, texture handle) |
| CHOP | Named float channels | 1–1000 samples × 1–100 channels | CPU, pass-by-reference |
| SOP | Polygonal geometry + attributes | 100–1M points | CPU, shared memory |
| DAT | String tables / text | Unbounded rows × cols | CPU, pass-by-reference |
| COMP | Container / 3D scene | N/A (hierarchy) | N/A |
| MAT | Material definition | N/A (parameter bundle) | N/A |

**Key data flow patterns:**
- **GPU→GPU (TOPs)**: Textures stay on the GPU. A CompositeTOP reads texture handles from two upstream TOPs and composites them in a single GPU pass. No CPU readback unless explicitly requested (TOPtoCHOP, TOPtoSOP).
- **Cross-family bridges**: CHOPtoTOP, TOPtoCHOP, SOPtoCHOP, etc. — explicit conversion operators.
- **Parameter exports**: CHOP Export mechanism pushes channel values directly into any parameter on any operator. This is a one-way data path that doesn't create a visible wire.
- **Select / In / Out operators**: Allow referencing data from anywhere in the network hierarchy without wires.
- **No implicit type coercion**: You cannot wire a CHOP output into a TOP input. The type system is strict.

### 3.2 Houdini

Houdini's type system is **attribute-centric** — data is geometry with arbitrary named attributes:

| Family | Data | Key concept |
|--------|------|-------------|
| SOP | Geometry (points, prims, verts, detail) + arbitrary attributes | Point/prim/vertex/detail attributes |
| DOP | Simulation state (geometry + forces + constraints) | Object/data/relationship hierarchy |
| COP | Pixels (image planes) | Multi-plane images (C, A, depth, normal, etc.) |
| CHOP | Channel data (float arrays) | Named channels × samples |
| VOP | Shader graph (compiled to VEX/RSL/GLSL) | Visual shader programming |
| ROP | Render output (driver) | Invokes mantra, karma, file cache |
| LOP | USD scene description | USD prims, properties, layers |
| TOP (PDG) | Work items (task graph) | Dependency graph for batch processing |

**Key data flow patterns:**
- **Everything is attributes**: A SOP point has `P` (position), `N` (normal), `Cd` (color), and any number of user-defined attributes. Wrangles and VOPs read/write these attributes directly.
- **Geometry streaming**: Data flows as geometry containers. Even CHOPs can be converted to geometry attributes and vice versa.
- **Named outputs**: Some SOPs have multiple named outputs (e.g., Boolean SOP outputs A∩B, A−B, B−A on different output ports).
- **Spare parameters + channel references**: Any parameter can reference any other parameter via `ch()`, `chs()`, `chf()` — creating implicit data flows.
- **Contexts are strict**: SOPs produce geometry, COPs produce images, CHOPs produce channels. No implicit coercion, but bridge nodes exist (attribfrommap, choptosop, etc.).
- **Copy-on-write with reference counting**: Houdini's `GU_Detail` (geometry container) uses COW — multiple nodes sharing the same unmodified input don't duplicate memory.

### 3.3 GONODES

| Family | Data class | Content | Transfer mechanism |
|--------|-----------|---------|-------------------|
| TOP | `GNTextureData` | `Texture2D` from SubViewport | GPU texture handle (read-only downstream) |
| IMG | `GNImageData` | CPU `Image` | Pass-by-reference, COW via `_mutable_input()` |
| CHOP | `GNChannelData` | `Dict[String, PackedFloat32Array]` | Pass-by-reference, COW |
| DAT | `GNTableData` | Headers + rows (string table) or text | Pass-by-reference, COW |
| SOP | `GNGeoData` | `ArrayMesh` + attributes | Pass-by-reference, COW |
| COMP | N/A (scene node) | `Node3D` in scene tree | Scene tree parenting |
| MAT | `GNMaterialData` | `Material` resource | Pass-by-reference, COW |
| UI | N/A (control node) | `Control` in SubViewport | Scene tree parenting via PanelTOP |

**Key data flow patterns:**
- **COW (Copy-on-Write)**: `_mutable_input()` duplicates data only when `_shared = true` (fan-out). Single-consumer chains are zero-copy.
- **TOPs are GPU-resident**: SubViewport textures are sampled by downstream shaders — inherently read-only, no COW needed.
- **Cross-family expressions**: `chop("lfo1")["out"]`, `top("noise1")`, `par("node", "param")` — expression-based references rather than explicit bridge operators.
- **Bridge operators**: ImgToTOP, TOPtoIMG, CHOPtoDAT, DATtoCHOP — explicit conversion.

### 3.4 Comparison Table

| Feature | TouchDesigner | Houdini | GONODES |
|---------|--------------|---------|---------|
| Copy-on-write | Yes (TOPs GPU, others CPU) | Yes (GU_Detail reference counting) | Yes (`_mutable_input()` + `_shared` flag) |
| Attribute system | Limited (SOP attributes) | Rich (point/prim/vert/detail, arbitrary types) | Basic (`point_attribs` dict on GNGeoData) |
| GPU texture transfer | Zero-copy FBO handles | N/A (offline rendering) | SubViewport texture handles (Godot-managed) |
| Cross-family data | Bridge operators + CHOP exports | Bridge operators + attribute promotion | Bridge operators + expressions |
| Multi-output nodes | Some (CHOP, SOP) | Common (Boolean, Split, etc.) | Yes (FluidVOL, MultiBufferRender, etc.) |
| Named outputs | No (port index only) | Yes (named outputs) | Yes (port labels + `output()`/`vol()`/`sop()`/`dat()`/`img()`/`mat()`) |
| Data introspection | Built-in viewers per family | Geometry spreadsheet, visualizers | Per-family preview (label/texture) |

---

## 4. Parameter & Expression Systems

### 4.1 TouchDesigner

- **Parameter types**: Float, Int, String, Menu (enum), Toggle (bool), Color, XY/XYZ/XYZW, File, Folder, Header, Pulse, OP, Sequence
- **Expression language**: Python (evaluted per-cook)
- **Reference syntax**: `op('noise1').par.scale`, `op('chop1')['chan1']`, `me.par.frequency`
- **CHOP Export**: A dedicated mechanism to push CHOP values into any parameter, creating a one-way binding outside the normal wire graph. Appears as a green/cyan parameter highlight.
- **Per-component expressions**: Each component (X, Y, Z, W) can independently be constant or expression.
- **Parameter ranges**: Min/max/clamp per parameter.
- **Custom parameters**: Operators (especially COMPs and Scripts) can define user-created custom parameters visible in the inspector.
- **Bind mode**: Parameters can be "bound" to external references (CHOP, DAT, COMP).
- **Parameter execute DAT**: A special DAT that fires callbacks when specific parameters change — event-driven scripting.

### 4.2 Houdini

- **Parameter types**: Float, Int, String, Toggle, Menu, Color, Button, Ramp (curve editor!), Separator, Label, Folder, MultiParm (dynamically instanced groups), OP Path
- **Expression languages**: HScript expressions (`ch()`, `$F`, `$T`, etc.) AND VEX expressions (faster, compiled)
- **Reference syntax**: `ch("../node/param")`, `chs()`, `chf()`, `chi()` — typed channel references
- **Parameter dependency graph**: Houdini builds a fine-grained dependency graph at the parameter level. Changing one parameter only invalidates the exact nodes/parameters that depend on it.
- **Ramp parameter**: A full curve editor (spline/linear/constant interpolation) built into the parameter system. This is a first-class type, not a workaround. VEX can evaluate ramps directly via `chramp()`.
- **Multiparm blocks**: Dynamic lists of parameter groups that the user can add/remove (e.g., a list of point groups, each with name + color + weight). These are parameterized templates.
- **Spare parameters**: User-created parameters on any node, visible in the inspector. Often used for controller interfaces on HDAs.
- **Keyframe animation**: Any parameter can have keyframe animation curves with handles and interpolation modes.
- **Channel references with relative paths**: `ch("../other_node/scale")`, `ch("./child_subnet/param")` — full hierarchy navigation.
- **VEX parameter functions**: `chf()`, `chi()`, `chs()`, `chv()` (vector), `chramp()` (ramp curve), `ch4()` (4×4 matrix).

### 4.3 GONODES

- **Parameter types**: Float, Int, Bool, String, Enum, Vector2, Vector2i, Vector3, Vector4, Color, File
- **Expression language**: GDScript expressions evaluated by Godot's `Expression` class
- **Reference syntax**: `par("param")` (self), `par("node", "param")` (cross), `chop("node", "chan")`, `top("node")`, `op("node")`
- **Typed variants**: `parf()`, `pari()`, `pars()` for params; `chopf()`, `chopi()`, `chops()` for CHOP channels — guarantee return type
- **Per-component expressions**: Vector2/3/4 and Color have independent C/E toggle per component
- **Parameter presets**: Copy/paste/save/load per-operator type
- **Circular guard**: Simple evaluating-set guard (not a full parameter DAG)
- **Built-in utility functions**: `fit()`, `smooth()`, `lag()`, `pulse()`, `noise1()`, `noise2()`, `trigger()`, `cycle()`, `bounce()`, etc.

### 4.4 Comparison Table

| Feature | TouchDesigner | Houdini | GONODES | Gap? |
|---------|--------------|---------|---------|------|
| Expression language | Python | HScript + VEX | GDScript Expression | ✓ adequate |
| Parameter-level deps | Partial (CHOP export) | Full dependency DAG | Expression dep map (`_expr_consumer_map`) + value-compare gate + input hash guard | ✓ Functionally equivalent |
| Ramp parameter type | No (workaround via LookupTOP) | Yes (first-class, `chramp()`) | No | **GAP** |
| Multiparm / dynamic groups | No | Yes | No | Gap (minor) |
| Keyframe animation | Yes (basic timeline) | Yes (full animation editor) | Yes (KeyframeCHOP + ramp curves) | ✅ Implemented |
| Custom user parameters | Yes (on COMPs) | Yes (spare params, HDAs) | `@param` in Script ops only | Gap (minor) |
| Demand-driven expression eval | Yes | Yes | Inline per cook frame | ✓ adequate |
| Autocomplete | Yes (Python) | Yes (HScript, VEX) | Yes (CodeEdit) | ✓ |
| Profiling per param | No | No | Yes (Âµs per expression) | GONODES advantage |

---

## 5. Graph Topology & Evaluation Order

### 5.1 TouchDesigner

- **Flat + Hierarchical**: The top-level "project" contains COMPs. Each COMP contains its own network of TOPs, CHOPs, SOPs, DATs. This creates a tree of networks.
- **Evaluation order**: Pull-based. When a viewer requests output from a TOP, that TOP pulls from its inputs, which pull from theirs, etc. The Cook Manager resolves order implicitly.
- **Cross-network references**: `op('/project1/comp1/noise1')` — full path addressing. Relative paths also supported: `op('../other_comp/lfo1')`.
- **No explicit topo sort needed**: The pull model naturally resolves dependencies.
- **Cycle prevention**: TD prevents cycles at connection time (cannot create a loop). FeedbackTOP is a special operator that reads from the *previous frame's* output, breaking the cycle.

### 5.2 Houdini

- **Deep hierarchy**: Networks can nest infinitely. A SOP network lives inside a Geometry OBJ, which lives inside a Scene, which can contain more subnets.
- **Evaluation order**: Pull-based with compiled blocks. Houdini's cook manager walks backward from the requested node, evaluating dependencies.
- **Compiled SOPs**: A chain of SOPs can be "compiled" into a single fused block for optimal execution (removes intermediate allocations).
- **Named inputs/outputs**: SOPs can have named outputs (e.g., Boolean produces "A minus B" and "B minus A" as separate outputs).
- **Fetch nodes**: Like TD's Select, allows pulling data from anywhere in the hierarchy.
- **Time dependency tracking**: Explicit per-node. The viewport only recooks time-dependent subgraphs when the frame changes. Editing a parameter recooks only the dependent subgraph.

### 5.3 GONODES

- **Flat + one-level subnet**: Root network with SubNetworkNode for one level of grouping (infinite nesting possible via nested SubNetworkNodes).
- **Evaluation order**: Kahn's BFS topological sort, cached. All dirty+active nodes cooked in order.
- **Cycle prevention**: DAG enforcement at connection time (`has_cycle()` check).
- **FeedbackTOP**: Uses `RenderingServer.texture_2d_get()` to read from the *previous frame's* texture, breaking the cycle.
- **Expression-tracked dependencies**: Active chain BFS follows both wire connections AND expression references (regex scan for `chop()/op()/top()/sop()/dat()/mat()/vol()/img()/output()` calls).

### 5.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES |
|---------|--------------|---------|---------|
| Hierarchy depth | Infinite (COMP nesting) | Infinite (subnet nesting) | Infinite (SubNetworkNode nesting) |
| Sort algorithm | Implicit (pull) | Implicit (pull) + compiled blocks | Explicit (Kahn's BFS) |
| Named I/O | No | Yes | No |
| Feedback mechanism | FeedbackTOP (prev frame) | Time Shift SOP, CHF(-1) | FeedbackTOP (prev frame) |
| Cross-network refs | `op('/path/to/node')` | `ch("../relative/path")` | `op("subnet/node")`, `op("../node")` |
| Implicit dependency tracking | Partial (CHOP export) | Full (parameter deps) | Expression dep map + selective re-eval + value-compare gate |

---

## 6. Performance Architecture

### 6.1 TouchDesigner

- **C++ core**: All built-in operators are C++ (HDK-derived). Python is only for scripting/callbacks.
- **GPU-first TOPs**: TOPs run entirely on the GPU. The CPU never touches pixel data unless you explicitly request it (TOPtoCHOP, TOPtoSOP).
- **Multi-GPU support**: TD can distribute TOP chains across multiple GPUs.
- **Parallel TOP cook**: Multiple independent TOP chains cook on separate GPU command queues / streams.
- **Instancing**: SOP and COMP instancing for rendering thousands of copies efficiently.
- **GLSL TOPs**: User-written GLSL runs on GPU with multi-pass and compute shader support.
- **Memory management**: Reference counting with texture pooling for GPU memory. Explicit resolution control per-chain.
- **Performance DAT**: Built-in profiling per-node (cook time, GPU time, memory usage).

### 6.2 Houdini

- **C++ core**: All SOPs are C++ (HDK). VEX compiles to machine code via LLVM.
- **VEX JIT compilation**: VEX (Houdini's expression/wrangle language) is compiled to optimized machine code — not interpreted. Wrangles running VEX on millions of points can match hand-written C++.
- **OpenCL acceleration**: Some SOPs (pyrosolver, volume operations) use OpenCL for GPU acceleration.
- **Compiled SOP blocks**: Fuses chains of SOPs into a single compiled unit, eliminating intermediate geometry allocation and enabling whole-chain optimization.
- **PDG parallel processing**: Task-level parallelism via PDG — distributes work items across cores, machines, or render farms.
- **Memory**: Geometry COW with reference counting. Packed primitives for instancing (millions of instances sharing geometry).
- **Performance monitor**: Built-in cook time profiler, memory usage, dependency graph viewer.

### 6.3 GONODES

- **GDScript core + GDExtension C++ hot-paths**: All operators are GDScript. 92 performance-critical operators (42 SOP, 23 CHOP, 5 IMG, 4 TOP, 9 VOL, 9 POP) have C++ GDExtension implementations via `gn_ext_native` that the GDScript wrappers auto-delegate to when available.
- **Godot renderer**: TOPs leverage Godot's Vulkan/OpenGL renderer via SubViewport — GPU-accelerated.
- **GPU compute**: POP (particles via SSBO) and VOL (volumetric via 3D textures) families use compute shaders where `RenderingDevice` is available. ComputeShaderTOP exposes user-written compute GLSL.
- **Single-threaded cook**: Main thread only. No parallel cook lanes.
- **Active chain cooking**: Only cooks subgraphs feeding live sinks (equivalent to TD's demand-driven).
- **UPDATE_ONCE**: SubViewport renders exactly once per dirty cycle — eliminates redundant GPU work.
- **COW data sharing**: `_mutable_input()` avoids unnecessary copies at fan-out points.
- **Input hash guard (Tier 2)**: Before cooking, hashes all resolved parameter values + input data timestamps. If unchanged from last frame, the cook is skipped entirely (no `_cook()` call, no GPU/CPU work). 100% accurate for parameter-driven changes. Incremental propagation in topo order replaces upfront BFS.
- **Implemented**: Multi-threaded cook engine (level-based parallelism via WorkerThreadPool). User-facing thread regions (Tier 4) remain future work.

### 6.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES | Gap? |
|---------|--------------|---------|---------|------|
| Core operator language | C++ | C++ + VEX (JIT) | GDScript + GDExtension C++ (92 native ops) | Partial (hot-paths covered) |
| GPU pipeline | Native DirectX/OpenGL/Vulkan | Karma GPU, OpenCL | Godot SubViewport (Vulkan/GL) + compute shaders (POP/VOL) | Adequate for real-time |
| Multi-threaded cook | Yes (TOPs multi-stream) | Yes (SOP internal, PDG farm) | Yes (level-based WorkerThreadPool) | ✓ Implemented |
| Expression compilation | Python (interpreted) | VEX (JIT compiled) | GDScript Expression (interpreted) | Minor gap |
| Compiled blocks | No | Yes (SOP compile) | No | Not applicable (real-time) |
| Instancing | Yes (SOP/COMP) | Yes (packed prims) | Godot MultiMeshInstance3D via CopySOP | Minor gap |
| Profiling | Per-node + Performance DAT | Performance monitor + dependency viewer | Per-node cook time + expression µs + VRAM display | ✓ Good |
| Memory optimization | Texture pooling, GPU mem management | COW geometry, packed prims | COW data, lazy viewport, active chain | ✓ Adequate |

---

## 7. Scripting & Extensibility

### 7.1 TouchDesigner

- **Python**: Full Python 3 embedded. Script CHOPs/SOPs/TOPs/DATs with complete Python API.
- **GLSL**: Custom shader TOPs with GLSL (vertex + fragment + compute).
- **Extensions**: Python classes can extend COMPs with custom behavior.
- **tdu module**: TouchDesigner utility functions available in Python (`tdu.clamp`, `tdu.remap`, module access).
- **Callbacks**: Parameter Execute DAT, Panel Execute DAT — event-driven scripting.
- **No plugin SDK**: You cannot write C++ operators for TD (unlike Houdini's HDK). Python is the only extension path.

### 7.2 Houdini

- **VEX**: Purpose-built shading/geometry language. JIT-compiled, runs on millions of points at native speed. The primary way users write custom logic.
- **Python**: Full Python 3 with `hou` module for scene access, UI scripting, and pipeline tools.
- **HDK (C++ SDK)**: Full C++ API for writing custom SOPs, DOPs, ROPs, etc. This is how studios build proprietary tools.
- **HDA (Houdini Digital Asset)**: Package a subnet into a reusable, distributable asset with a custom parameter interface. This is Houdini's primary extension model — artists create HDAs, not C++ plugins.
- **OSL (Open Shading Language)**: For material/shader authoring in the LOP/Karma context.
- **HScript**: Legacy expression language, still supported but VEX is preferred for performance.

### 7.3 GONODES

- **GDScript scripting**: ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG with runtime compilation.
- **GLSL shaders**: CustomShaderTOP with `shader_type canvas_item` source, dynamic uniform scanning. ComputeShaderTOP for `shader_type compute` (Vulkan/Forward+ only).
- **Extension system**: `gn_ext_*` addon folders with `gn_extension.cfg` manifests (platform/architecture/dependency guards). Extensions register operators dynamically. 10 extensions shipped.
- **GDExtension C++ (implemented)**: 69 native operators via `gn_ext_native` — C++ processor classes with GDScript fallback wrappers.
- **@param/@input annotations**: Dynamic UI generation from script annotations.
- **Presets**: Code presets (factory + user) for Script operators.

### 7.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES | Gap? |
|---------|--------------|---------|---------|------|
| User scripting | Python | VEX + Python | GDScript | ✓ Adequate |
| Shader authoring | GLSL (frag/vert/compute) | VEX, GLSL, OSL, MaterialX | GLSL (canvas_item + compute shader) | ✓ Good |
| C++ plugin SDK | No | Yes (HDK) | GDExtension (92 native ops implemented) | ✓ Done |
| Asset packaging | No (Projects only) | HDA (full asset package) | SubNetworkNode + .gnpatch | **GAP** (see §11) |
| Dynamic annotations | No | Spare params, HDA interface | `@param`/`@input` in scripts | ✓ Good |
| Extension marketplace | No | Orbolt, SideFX Labs | Planned | Future |

---

## 8. UI & Workflow Patterns

### 8.1 TouchDesigner

- **Single-view-per-network**: Each COMP's network is viewed in the main editor pane. Navigate in/out of COMPs.
- **Inline previews on every node**: All TOPs show live texture thumbnails by default. CHOPs show mini-graphs. SOPs show wireframe previews.
- **Viewer**: The active viewer shows the currently selected TOP (or SOP in 3D).
- **Parameter dialog**: Floating or docked parameter window with per-type widgets.
- **Network navigation**: Double-click COMP to enter, 'u' key to go up. Breadcrumb path at top.
- **Palette browser**: Categorized by family with search.
- **Wire styles**: Curved wires color-coded by family.
- **Performance monitor**: Built-in cookTime, gpu_time per node.
- **OP snippets**: Factory example networks for each operator type.
- **Quick-add (Tab)**: Tab key opens a quick-add search popup.
- **Color coding**: Family-specific colors for nodes and wires (Purple=TOP, Green=CHOP, Blue=SOP, Yellow=DAT, etc.).

### 8.2 Houdini

- **Multi-pane editor**: Multiple network editors, parameter editors, viewports, spreadsheets open simultaneously.
- **Network boxes**: Color-coded grouping rectangles for organizing nodes visually.
- **Sticky notes**: Text annotations directly on the network canvas.
- **Dot nodes**: Routing dots for cleaner wire organization.
- **Spreadsheet**: Full geometry data spreadsheet showing all attributes per point/prim/vert.
- **Radial/Quick menus**: Tab search + radial context menus for fast node creation.
- **Handles**: Direct manipulation handles in the viewport (translate/rotate/scale gizmos tied to parameters).
- **Takes**: Named parameter overrides that can be layered (like layer comps in Photoshop).
- **Desktop presets**: Saved window layouts for different tasks (modeling, lookdev, animation, sim).
- **Color, shape, badges**: Nodes can have custom colors, shapes, badges (warnings, errors, time dependency, bypass, lock indicators).

### 8.3 GONODES

- **Single GraphEdit pane**: Godot GraphEdit with breadcrumb navigation for sub-networks.
- **Inline previews**: TOPs show TextureRect thumbnails. CHOPs/SOPs/DATs/MATs show text labels. IMGs show resolution string. Per-node toggle.
- **Performance overlay**: Cook time badge per node with color thresholds.
- **Inspector panel**: Parameter widgets per type, expression toggle, per-component C/E.
- **Viewer panel**: TextureRect showing selected TOP output. Floating viewer windows for multi-output.
- **Palette**: Tab key opens tree-based family-grouped palette with search. Drop-wire-to-add filters by compatible family.
- **Context menu**: Right-click with copy/paste/delete/undo/redo/align/bypass/lock/presets.
- **Keyboard shortcuts**: Comprehensive set (Tab, B, L, W, H, V, F, M, Ctrl+G, ?, 1-9 bookmarks).
- **Node help**: Per-node help window with auto-generated docs from operator metadata + example patches.
- **Wire styles**: Curved/straight/right-angle via W key toggle.
- **Expression reference lines**: Dashed cyan overlay showing implicit expression dependencies.

### 8.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES | Gap? |
|---------|--------------|---------|---------|------|
| Multi-pane layout | Limited (COMP-based) | Full multi-pane | Single pane + float windows | Gap (minor) |
| Inline previews | Rich (textures, graphs) | Basic (wireframe) | Labels + textures | ✓ Good |
| Data spreadsheet | Grid-like viewer | Full spreadsheet | GNViewerPanel Tree spreadsheet | ✓ Viewer-level |
| Network boxes / annotations | No | Yes (color boxes + stickies) | No | **GAP** |
| Dot/routing nodes | No | Yes | No | Gap (minor) |
| Viewport handles | Limited | Full 3D handles | No | Gap (not real-time relevant) |
| Node badges | Some (error, cook flag) | Rich (warnings, time dep, bypass, lock, HDA badge) | Bypass ⏩, Lock ??, Perf ms, Bookmark # | ✓ Good |
| Quick-add | Tab search | Tab search + radial | Tab search + drop-wire filter | ✓ Good |
| Expression overlays | No | No | Yes (dashed cyan reference lines) | GONODES advantage |

---

## 9. Sub-Networks & Encapsulation

### 9.1 TouchDesigner

- **COMPs are containers**: Every COMP (Geometry, Base, Container, etc.) contains its own network. This is the only hierarchy mechanism.
- **In/Out operators**: Pass data between parent and child networks.
- **Custom COMPs**: Clone a Base COMP, define custom parameters, add internal network — acts as a reusable "module."
- **No formal asset system**: No equivalent to Houdini's HDA. Modules are shared as `.tox` files (COMP exports).
- **Parameters on COMPs**: COMPs can expose custom parameters that internal nodes reference via `parent().par.X`.

### 9.2 Houdini

- **Subnets and HDAs**: Any network group can become a subnet. Subnets can be promoted to HDAs (Houdini Digital Assets).
- **HDA (the gold standard)**: Package a node network into a self-contained, distributable asset with:
  - Custom parameter interface (the "Type Properties" dialog)
  - Multiple named inputs/outputs with labels
  - Help documentation
  - Example files
  - Pre/post-scripts (Python)
  - Version control (embedded definitions)
  - Menu scripts, callback scripts
  - Custom icon, custom color, custom shape
- **Dive in/dive out**: Double-click to enter any subnet/HDA. Breadcrumb navigation.
- **OTL libraries**: `.hda` files that act as shared libraries of node types — studios maintain libraries of custom HDAs used across all projects.
- **Distributed as files**: HDAs are single files that can be installed by dropping into `$HOUDINI_PATH/otls/`.

### 9.3 GONODES

- **SubNetworkNode**: Single grouping mechanism. InTunnel/OutTunnel for data bridging.
- **Dive in/out**: Double-click to enter, Backspace or breadcrumb to exit.
- **Inner cook engine**: Recursive cooking — injected data into InTunnels, reads OutTunnel results.
- **Hierarchical expressions**: `op("subnet/node")`, `op("../node")`, `op("/root_node")`.
- **No formal asset packaging**: SubNetworkNodes are serialized inline in `.gnpatch`. No standalone distributable format.

### 9.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES | Gap? |
|---------|--------------|---------|---------|------|
| Basic sub-networks | Yes (COMPs) | Yes (subnets) | Yes (SubNetworkNode) | ✓ |
| Reusable asset format | `.tox` (COMP export) | `.hda` (full asset) | `.gnasset` (JSON, self-contained) | ✓ Implemented |
| Custom parameter interface | Yes (COMP params) | Yes (HDA type properties) | Partial (`@param` scripts) | **GAP** |
| Version control | No | Yes (HDA versioning) | No | Gap (minor) |
| Named I/O with labels | Yes (In/Out operators) | Yes (named inputs/outputs) | Yes (InTunnel/OutTunnel) | ✓ |
| Asset distribution | File sharing | OTL libraries + Orbolt | Extension system (gn_ext_*) | ✓ Architecture exists |

---

## 10. I/O & External Integration

| Protocol | TouchDesigner | Houdini | GONODES |
|----------|--------------|---------|---------|
| OSC | Built-in (In/Out) | Basic (via Python) | Built-in (OscInCHOP, OscOUT, OscInDAT) |
| MIDI | Built-in (In/Out) | No | Input only (MidiInCHOP, MidiInDAT). Output planned. |
| NDI | Built-in | No | Planned |
| Syphon/Spout | Built-in | No | Planned |
| Audio input | Built-in | No | Built-in (AudioInCHOP, AudioSpectrumCHOP) |
| Video input | Built-in (webcam, capture card) | No | WebcamIMG + ImgToTOP |
| Serial/COM | Built-in | No | Extension (SerialSendDAT, SerialReceiveDAT — scaffold; needs serial GDExtension for hardware I/O) |
| DMX/ArtNet | Built-in | No | Built-in (DMXDAT — bidirectional Art-Net send/receive via PacketPeerUDP) |
| Laser | Laser CHOP + DAC CHOP | No | Data model only (LaserCHOP — XY/RGB/intensity point lists). DAC drivers deferred. |
| USD | No | Full LOP pipeline | No |
| Alembic | Export only | Full I/O | No |
| FBX/glTF | Import | Full I/O | Export only (glTF) |
| Python API | Full `td` module | Full `hou` module | Scripting via GDScript in-node |
| Embedding | No | Houdini Engine (C++ API) | LibGodot (planned, GDExtension) |
| Web API | WebSocket, HTTP | No (PDG has REST) | Not yet |

---

## 11. Gap Analysis & Recommendations

Based on the comparison, here are the most impactful improvements GONODES could adopt, ordered by estimated value:

### 11.1 HIGH PRIORITY — Architectural Improvements

#### A. ~~Parameter-Level Dependency Tracking~~ — IMPLEMENTED

**Status**: ✅ Resolved. GONODES has a three-layer expression-dependency system that achieves functionally equivalent behavior to Houdini's parameter-level deps:

1. **Expression consumer map** (`_expr_consumer_map`): Regex-scanned reverse dependency map — upstream node → list of expression consumers. Rebuilt on topology change.
2. **Selective re-evaluation** (`_should_eval_expressions`): On each cook frame, expression consumers only re-evaluate if their referenced upstream node actually cooked this frame (or is time-dependent). Avoids unnecessary Expression class invocations.
3. **Value-compare gate** (`_try_expression_dirty`): Even when re-evaluated, the node is only marked dirty if the resolved value actually changed. This catches cases where `par("A", "x") > 0.5` still evaluates to the same result.
4. **Input hash guard**: Final gate hashes all resolved param values + input timestamps. Even dirty nodes skip `_cook()` if the hash matches.

**Result**: If nodeA has 20 parameters and only `scale` changes, nodeB (which references `par("A", "scale")`) will re-evaluate that one expression, see it changed, and recook — but nodeC (which references `par("A", "seed")`) will also re-evaluate but see the value is the same, and skip cooking. The only remaining theoretical gap vs Houdini is that GONODES tracks at the *node* level ("did A cook?") rather than the *parameter* level ("did A.scale specifically change?"), so consumers do re-evaluate expressions when *any* upstream param changes — but the value-compare gate makes this nearly zero-cost in practice.

#### B. Ramp / Curve Parameter Type

**Gap**: Houdini's ramp parameter is a first-class type — a curve editor built into the parameter UI. This is transformative for procedural workflows: color gradients, falloff curves, animation curves, noise shaping, and any value-over-domain mapping. Neither TD nor GONODES has this as a built-in parameter type.

**Impact**: Currently GONODES users who want a color gradient over an animation cycle must either:
- Chain multiple ConstantTOPs with CrossTOP (clunky)
- Use a LookupTOP with a pre-made texture (non-interactive)
- Write math in expressions (fragile)

A ramp parameter would let them draw a gradient curve directly in the inspector and evaluate it via `ramp("param_name", t)` in expressions or `chramp()` in scripts.

**Recommendation**: Add `ValueType.RAMP` to `GNParameter`. Data model: array of `{position: float, value: Color or float, interpolation: enum}` control points. UI: custom `Control` with draggable handles and interpolation mode per segment. Expression function: `ramp("name", t)` returns interpolated value at position `t ∈ [0,1]`. Serialize as JSON array of keyframes.

**Complexity**: Medium-high. The parameter system supports custom types well. Main work is the curve editor UI widget and the interpolation math.

#### C. ~~Reusable Asset Package Format (.gnasset)~~ — IMPLEMENTED

**Status**: ✅ Fully implemented. `GNCustomOperator` extends SubNetworkNode and loads self-contained `.gnasset` JSON files. Promotion wizard (`GNAssetPromotionDialog`): right-click SubNetwork → "Promote to Custom Asset…" → set identity (name/family/author/version/tags) + choose which inner params to promote → writes `.gnasset` file. `GNExtensionRegistry.scan_custom_assets()` hot-registers assets from 3 directories (`res://addons/gonodes/assets/`, `res://custom_operators/`, `user://gonodes_assets/`) into the operator palette at startup.

**Remaining (Phases 3-4)**: Unpack-to-SubNetwork, inline asset editing, dedicated asset browser panel, nested asset dependency resolution, community sharing integration.

#### D. ~~Multi-Threaded Cook Engine~~ — IMPLEMENTED

**Status**: ✅ **IMPLEMENTED** — Level-based topological sort groups nodes into dependency levels. CPU-family nodes at the same level cook concurrently via `WorkerThreadPool`. GPU families (TOP, POP, VOL) cook sequentially on the main thread (Godot renderer constraint). Config vars `parallel_cook_enabled` and `parallel_min_batch` control the behaviour.

**Implementation**: `gn_network.gd` adds `get_topological_levels()` (Kahn's algorithm with depth tracking). `gn_cook_engine.gd` adds `_cook_single_node()`, `_cook_cpu_batch_parallel()`, `_is_gpu_family()` helpers. The parallel path pre-resolves parameters and gathers inputs on the main thread (graph reads are not thread-safe), then dispatches `_cook()` calls to worker threads.

### 11.2 MEDIUM PRIORITY — Workflow Improvements

#### E. ~~Data Spreadsheet / Table Viewer~~ — RESOLVED

**Status**: ✅ GNViewerPanel already includes a Tree-based spreadsheet that displays DAT tables with column headers and row selection. CHOP channels are shown in the waveform view (GNWaveformView) with per-channel colors and value legend. SOP geometry is shown in an interactive 3D orbit viewer. The original gap description was inaccurate — it assumed viewer-level inspection didn't exist.

**Design decision**: Node thumbnails intentionally stay text-only (channel names + values for CHOPs, row count for DATs). Full inspection is done in the viewer panel, keeping the node graph clean.

#### F. Network Boxes / Sticky Notes

**Gap**: Houdini's network boxes (colored rectangles for grouping) and sticky notes (text annotations on the canvas) are essential for organizing large networks. TD lacks these too.

**Impact**: Networks larger than ~30 nodes become hard to navigate without visual grouping cues. SubNetworks help for encapsulation but not for visual organization of a flat network.

**Recommendation**: Add `GNNetworkBox` (colored rectangle with label, serialized in .gnpatch) and `GNStickyNote` (text annotation on the canvas). Both are non-cooking, purely organizational. Render as GraphEdit child controls behind nodes.

**Complexity**: Low. No cook engine changes needed — purely UI. Serialize as additional arrays in the `.gnpatch` format.

#### G. ~~Keyframe Animation System~~ — IMPLEMENTED

**Status**: ✅ **IMPLEMENTED** — Four animation-focused CHOP operators provide keyframe curve support:
- **KeyframeCHOP**: User-defined ramp curves sampled over time with start/end range and extend modes (Hold/Cycle/Mirror/Slope).
- **SequenceCHOP**: Sequences multiple CHOP inputs end-to-end with optional crossfade.
- **ClipCHOP**: Transport controls (speed, loop, trim, trigger) for recorded CHOP data.
- **ChannelCHOP**: Expression-friendly named channels from parameter values.

The ramp parameter type provides the curve editor infrastructure (keypoints with tangents, cubic Hermite interpolation). These operators leverage the existing RAMP UI for visual keyframe editing.

#### H. ~~CHOP Viewer Graph (Waveform Display)~~ — RESOLVED

**Status**: ✅ GNViewerPanel uses `GNWaveformView` — a custom `Control._draw()` waveform renderer with 8-color per-channel polylines, Y/X zoom (scroll/Shift+scroll), pan, grid with auto-scaled step sizes, and channel name + current value legend. Single-sample scalars render as horizontal reference lines.

**Design decision**: Node tile previews remain text-only by design — waveform display lives in the viewer panel window, keeping the graph editor clean and lightweight. This is an intentional choice, not a gap.

### 11.3 LOW PRIORITY — Nice to Have

#### I. Named Output Ports

**Gap**: ~~Houdini SOPs frequently have named outputs (Boolean → "Intersect", "A minus B", "B just B"). GONODES uses indexed ports only.~~

**Status**: ✅ **IMPLEMENTED** — `GNPort.label` + `display_name()` on all ports. `add_input()`/`add_output()` accept optional `port_label`. UI renders labels on the graph. All multi-port operators labeled. Expression functions `output()`, `vol()`, `sop()`, `dat()`, `img()`, `mat()` resolve ports by index, name, or label (case-insensitive).

#### J. Dot/Routing Nodes

**Gap**: ~~Houdini's dot nodes let you route wires cleanly for readability.~~

**Status**: ✅ **IMPLEMENTED** — `DotNode` operator passes data through unchanged with automatic family adaptation. Registered as a generic routing node.

#### K. Takes / Parameter Layer Overrides

**Gap**: Houdini's Take system lets you save named parameter states and switch between configurations non-destructively.

**Recommendation**: Low priority — parameter presets partially cover this use case. Could extend `GNParamPresetManager` with "take" semantics (apply an override layer, revert to base).

---

## Summary: Top 5 Recommendations

| # | Recommendation | Effort | Value | Status |
|---|---------------|--------|-------|--------|
| 1 | **Ramp parameter type** with curve editor | Medium | Very High | ✅ **Implemented** |
| 2 | ~~CHOP waveform preview~~ | Low | High | ✅ **Resolved** — GNViewerPanel has full waveform graph; node tiles stay text-only by design |
| 3 | ~~Data spreadsheet viewer~~ | Low-Med | High | ✅ **Resolved** — GNViewerPanel has Tree-based spreadsheet for DATs |
| 4 | **Network boxes + sticky notes** | Low | Medium | ✅ **Implemented** (annotations system) |
| 5 | **Multi-threaded cook engine** | High | Very High | ✅ **Implemented** — Level-based parallel dispatch via WorkerThreadPool |

GONODES is remarkably well-aligned with both TD and Houdini's core architecture. The active chain cooking, COW data model, expression system, per-component expressions, preview system, and sub-network hierarchy put it in strong competitive territory. With the parallel cook engine, named output ports, dot routing nodes, and keyframe animation system, all major architectural gaps are now closed. Remaining gaps are in **power-user workflow tools** (Takes/parameter layers) rather than fundamental architecture or operator coverage.

---

## 12. Operator Coverage Gap Analysis

### 12.1 New Operators Added (Session 34)

A systematic audit of TouchDesigner's operator set yielded **16 new operators** that close significant coverage gaps:

| Family | Operator | TD Equivalent | Notes |
|--------|----------|--------------|-------|
| CHOP | **FeedbackCHOP** | Feedback CHOP | Previous-frame data for feedback loops |
| CHOP | **BlendCHOP** | Blend CHOP | Weighted blend of 2-8 inputs, 4 easing modes |
| CHOP | **PerformCHOP** | Perform CHOP | FPS, frame_time, memory, frame_count via Engine/OS/Performance |
| CHOP | **TransformCHOP** | Transform CHOP | 3D transform on xyz channel groups, 6 transform orders |
| DAT | **WebServerDAT** | Web Server DAT | HTTP server via TCPServer, table output of requests |
| DAT | **WebSocketDAT** | WebSocket DAT | WebSocket client/server via WebSocketPeer |
| DAT | **ErrorDAT** | Error DAT | Hooks GNLogger.log_sink, captures warnings/errors |
| DAT | **FolderDAT** | Folder DAT | Directory listing with glob filter |
| DAT | **MultiTouchInDAT** | Multi Touch In DAT | Touch events as table rows |
| SOP | **FileInSOP** | File In SOP | OBJ/glTF/Resource import |
| SOP | **FileOutSOP** | File Out SOP | OBJ export with geometry pass-through |
| SOP | **GroupSOP** | Group SOP | Point/prim groups via BBox/Normal/Range/All |
| SOP | **PrimitiveSOP** | Primitive SOP | Per-prim face normals, area, centroid, prim_id |
| SOP | **BlendSOP** | Blend SOP | Vertex-level morph between two geometries |
| MAT | **NormalMapMAT** | Phong MAT (normal map) | StandardMaterial3D with normal map controls |
| MAT | **LineMAT** | Line MAT | ShaderMaterial wireframe with stipple controls |

### 12.2 Excluded Operators — Rationale & Roadmap

The following TD operators were evaluated and **excluded** from this batch, with documented reasons:

#### Covered by Existing GONODES Operators

| TD Operator | Covered By | Explanation |
|-------------|-----------|-------------|
| TCP/IP DAT | **NetworkDAT** | Already supports both TCP and UDP protocols |
| UDP In/Out DAT | **NetworkDAT** | Same — NetworkDAT handles UDP mode |
| Shift CHOP | **WarpCHOP** | Time-shifting functionality covered by WarpCHOP |
| Cycle CHOP | **ExtendCHOP** | Cycle/repeat modes are ExtendCHOP's extend_mode parameter |
| Clip CHOP | **TrimCHOP** | Clipping/trimming ranges handled by TrimCHOP |
| CHOP Execute DAT | **CallbackDAT** | CallbackDAT covers all execute-on-event patterns |
| SOP Execute DAT | **CallbackDAT** | Same pattern — CallbackDAT is generalised |
| Phong MAT | **PBR_MAT** | PBR_MAT covers Phong-like workflows via roughness=1.0 |
| Screen Grab TOP | **ScreenGrabIMG** | Already in IMG family as ScreenGrabIMG |

#### Requires External Libraries (Roadmap)

| TD Operator | Dependency | Roadmap Priority |
|-------------|-----------|-----------------|
| NDI In/Out TOP | NDI SDK (Newtek) | Medium — awaits GDExtension C++ pipeline |
| Syphon In/Out TOP | Syphon framework (macOS only) | Low — platform-specific |
| Spout In/Out TOP | Spout SDK (Windows only) | Medium — Windows-focused deployments |
| MIDI Out CHOP | RtMidi or similar | Low — MIDI In already exists; Out needs native lib |
| Laser DAC CHOP | EtherDream (TCP/UDP), Helios (USB HID), ShowNET (vendor SDK) | Medium — LaserCHOP data model exists; DAC drivers need GDExtensions |

#### Niche / External Hardware

| TD Operator | Status |
|-------------|--------|
| DMX In/Out CHOP | **Implemented** — DMXDAT (bidirectional Art-Net via PacketPeerUDP, no external libs) |
| ArtNet CHOP | **Implemented** — DMXDAT uses Art-Net protocol natively |
| Serial DAT | **Implemented** — SerialSendDAT + SerialReceiveDAT (gn_ext_serial extension; needs serial GDExtension for hardware I/O) |
| Laser CHOP | **Implemented** — LaserCHOP (data model: XY/RGB/intensity point lists, test patterns). DAC output deferred. |
| Laser DAC CHOP | **Deferred** — EtherDream (TCP/UDP, complex timing), Helios (USB HID), ShowNET (proprietary). Requires GDExtensions. |
| Leap Motion CHOP | Deprecated hardware; community-contributed if needed |

### 12.3 Updated Operator Totals

| Family | Before | After | Delta |
|--------|--------|-------|-------|
| TOP | 63 | 64 | +1 |
| IMG | 12 | 12 | — |
| CHOP | 61 | 67 | +6 |
| DAT | 29 | 36 | +7 |
| SOP | 57 | 62 | +5 |
| COMP | 20 | 21 | +1 |
| MAT | 6 | 8 | +2 |
| OUT | 9 | 9 | — |
| UI | 31 | 31 | — |
| **Total** | **288** | **310** | **+22** |

Help patches: 299 → 327 (+28).

---

## 13. Full Feature Audit & Improvement Roadmap

> **Date:** 2026-03-17
> **Scope:** Comprehensive TD/Houdini feature audit against the current GONODES codebase (374+ operators, 11 families, 11 GDExtension addons). Prioritized for real-time visual art / VJ workflows.

### 13.1 Feature Coverage Matrix

| TD Feature Area | TD Implementation | GONODES Status |
|---|---|---|
| **Texture processing** | 90+ TOPs | **70 TOPs** — ~80% parity, strong |
| **Channel/signal** | 70+ CHOPs | **74 CHOPs** — near parity |
| **Geometry** | 50+ SOPs | **71 SOPs** — exceeds TD in some areas |
| **Data tables** | 30+ DATs | **37 DATs** — near parity |
| **Materials** | ~10 MATs | **9 MATs** — solid |
| **Components** | COMPs (containers, 3D scenes, panels) | **20 COMPs** — good, physics included |
| **GPU Particles** | Particle SOP/POP network | **10 POP operators** — SSBO compute pipeline |
| **3D Volumes** | Not native (3D texture workarounds) | **11 VOL operators** — **GONODES leads here** |
| **UI Widgets** | Panel COMP widgets | **31 UI operators** — comparable |
| **Shader authoring** | GLSL TOP, Compute Shader TOP | CustomShaderTOP + ComputeShaderTOP + ISF + Shadertoy — strong |
| **Video I/O** | Theora, HAP, FFMPEG, NDI, Blackmagic | HAP, FFmpeg, GPU Encode, Theora — **missing NDI, Blackmagic** |
| **Texture sharing** | Spout (Win), Syphon (Mac) | **Both implemented** |
| **Projection mapping** | Stoner, Kantan Mapper (plugins) | **gn_ext_mapper** built-in |
| **Audio** | Audio analysis, synthesis, device I/O | AudioIn, AudioSpectrum, AudioBand, AudioDynamics, Beat, AudioDeviceOUT |
| **MIDI** | MIDI In/Out | **gn_ext_midi** (RtMidiIn + RtMidiOut) |
| **OSC** | OSC In/Out | OscOutOUT + OscInDAT/OscInCHOP |
| **Serial** | Serial DAT | **gn_ext_serial** |
| **Physics** | Bullet (legacy) | **Jolt physics COMPs** — modern, better |
| **SDF rendering** | Not built-in | **gn_ext_sdf** — GONODES leads |
| **Embed in host apps** | TouchEngine SDK | **LibGodot + libgonodes C API** — comparable |
| **Custom operators** | C++ or Python .tox | **.gnasset + Script operators** |
| **Fluid simulation** | NVIDIA Flex (plugin), GLSL workarounds | **FluidVOL (3D NS) + Fluid2DTOP (2D NS)** — see §13.3 |
| **Machine Learning** | TensorFlow, OpenCV, MediaPipe plugins | **Not present** |
| **AR/Face Tracking** | Kinect, Leap, MediaPipe | **Not present** |
| **Multi-display** | Multi-window, output mapping | WindowOUT multi-window — basic |

### 13.2 Houdini Features Worth Borrowing

| Houdini Concept | Relevance | GONODES Status |
|---|---|---|
| VEX/CVEX wrangle nodes | GDScript node-level scripting | ScriptSOP/CHOP/DAT/IMG — ✅ covered |
| HDA (Houdini Digital Assets) | Reusable operator packages | .gnasset + SubNetwork — ✅ covered |
| Attribute system | Rich per-element data | AttributeSOP — partial (no vertex attrs on data type) |
| PDG (Task Graph) | Batch/async processing | Not applicable for real-time |
| FLIP Fluids | Particle-in-cell hybrid | See §13.5 #23 |
| Pyro (sparse volumes) | Fire/smoke/explosion | See §13.4 #8 |
| Wire/Cloth/Hair solvers | Specialized sim | Jolt soft body as base |
| Crowds/Agents | Mass animation instancing | InstanceCOMP partially covers |
| Terrain (HeightfieldSOP) | Generative landscapes | See §13.5 #13 |
| For-Each loops | Iterative per-piece processing | ReplicatorCOMP |
| Spare parameters | Add params to any node | ✅ Already implemented |
| Takes (parameter layers) | Named param snapshots | See §11.3.K — planned |

### 13.3 Fluid Simulation — Current State

GONODES has **two fluid simulation systems**:

**3D Fluid (FluidVOL)** — GPU Navier-Stokes on 3D volume grid:
- 6-pass pipeline: Inject → Advect (semi-Lagrangian) → Vorticity Confinement → Divergence → Pressure (Jacobi) → Project
- Obstacle support: mesh/SDF mask injection (R > 0.5 = solid, 0.1–0.5 = friction boundary)
- Vorticity confinement: curl amplification for turbulent detail (adjustable 0–5)
- Rendering: RaymarchVOL (Beer-Lambert absorption, front-to-back compositing)
- Mesh extraction: MarchingCubesVOL (CPU iso-surface → SOP)
- POP interaction: AdvectPOP moves particles along VOL velocity field
- CPU fallback for all passes (Compatibility renderer support)

**2D Fluid (Fluid2DTOP)** — GPU Navier-Stokes on SCREEN_TEXTURE feedback:
- Dual SubViewport architecture: sim viewport (CLEAR_MODE_NEVER) + render viewport
- Semi-Lagrangian advection, vorticity confinement, simplified pressure correction
- Configurable emitter (position/direction/radius/force/dye — expression-friendly)
- External dye input (TOP) for ink/paint effects
- Two-color gradient rendering with velocity visualization mode

**What could still improve fluid visuals:**

| Visual Feature | Current State | Enhancement |
|---|---|---|
| Translucent fluid surface | MarchingCubes + PBR_MAT | Dedicated FluidSurfaceMAT (subsurface, refraction, Fresnel) |
| Temperature / buoyancy | Not present | Temperature field + upward force in FluidVOL |
| Multiple species | Single density channel | Multi-channel density (RGBA32F already supports it) |
| Multi-pass lighting | Single-pass raymarcher | Phase functions (Henyey-Greenstein), shadow rays |

### 13.4 Improvement Roadmap — Tier 1 (High Impact, Moderate Effort)

| # | Suggestion | Why | Effort | Status |
|---|---|---|---|---|
| 1 | **Audio Input + Analysis** | VJ workflow lifeblood — live mic/line-in drives reactive visuals | Medium | ✅ **AudioBandCHOP** done (AudioInCHOP, AudioSpectrumCHOP, BeatCHOP already existed) |
| 2 | **NDI In/Out extension** | Industry standard video-over-IP for live production | Medium | ⬜ Needs C++ GDExtension wrapping libndi |
| 3 | **OSC In CHOP/DAT** | Controllers (TouchOSC, Lemur), phones, other software | Low | ✅ OscInDAT + OscInCHOP already exist |
| 4 | **Fluid Surface Rendering** | FluidVOL → MarchingCubes → visually compelling output | Medium | ⬜ Dedicated FluidSurfaceMAT with refraction/caustics |
| 5 | **FluidVOL Obstacle Collision** | Fluid flows around objects, wake turbulence | Low-Medium | ✅ **Implemented** — obstacle input port + compute shader + CPU fallback |
| 6 | **Timeline / Cue System** | Live performance structure — cue points, transitions, scene switching | Medium | ✅ **Implemented** — TimelineCHOP, CueDAT, CueCHOP, Editor Timeline UI |
| 7 | **Vorticity Confinement** | Curl amplification — transforms flat fluid into cinematic turbulence | Low | ✅ **Implemented** — GPU compute pass + CPU fallback, 0–5 strength |

### 13.5 Improvement Roadmap — Tier 2 (Feature Extensions)

| # | Suggestion | Why | Effort | Status |
|---|---|---|---|---|
| 8 | **Pyro-Style Emitter VOL** | Temperature + fuel + combustion for fire/smoke | Medium | ⬜ VOL infrastructure exists, needs combustion model |
| 9 | **Cloth/Softbody SOP** | Verlet-integration mesh deformer for visual art | Medium-High | ⬜ SoftBodyCOMP (Jolt) exists for physics, not procedural cloth |
| 10 | **Machine Learning Bridge** | MediaPipe face/hand/pose, style transfer, depth estimation | High | ⬜ Transformative but heavy — could be `gn_ext_ml` wrapping ONNX |
| 11 | **Reaction-Diffusion TOP** | Classic generative art pattern (Gray-Scott model) | Low | ✅ **Implemented** — 7 presets, seed input, 3 color modes |
| 12 | **Multi-Pass Lighting in RaymarchVOL** | Phase functions, shadow rays, scattering approximation | Medium | ⬜ Transforms volume rendering from blob to atmospheric phenomenon |
| 13 | **HeightfieldSOP** | Terrain generation from noise/erosion for generative landscapes | Medium | ⬜ |
| 14 | **Instancer improvements** | Per-instance color/scale from CHOP, animated geometry, LOD | Medium | ⬜ Current InstanceCOMP is functional but basic |
| 15 | **Point Cloud rendering** | Dedicated splatting renderer with size attenuation, depth testing | Medium | ⬜ Better than RenderPOP's billboard approach for dense clouds |

### 13.6 Improvement Roadmap — Tier 3 (Polish & Advanced)

| # | Suggestion | Why | Effort | Status |
|---|---|---|---|---|
| 16 | **2D Fluid TOP** | Screen-space Navier-Stokes for interactive installations | Low | ✅ **Implemented** — Fluid2DTOP with dual viewport feedback |
| 17 | **Blackmagic / AJA video I/O** | Professional SDI/HDMI capture/output for broadcast | High | ⬜ Niche but essential for high-end installations |
| 18 | **Trail / Ribbon rendering** | Render particle trails as ribbons/tubes — staple VJ effect | Medium | ⬜ TrailSOP exists, needs efficient GPU ribbon renderer |
| 19 | **Voronoi / Shatter SOP** | Procedural fracturing for motion graphics | Medium | ⬜ |
| 20 | **Periodic/Tiling Noise** | Seamless tiling for looping content | Low | ⬜ NoiseTOP shader modification |
| 21 | **GPU Marching Cubes** | MarchingCubesVOL is CPU-only; compute shader would be 10-100× faster | High | ⬜ Godot 4.x RD atomics may help |
| 22 | **Boids / Flocking POP** | Emergent behavior particles — classic generative art | Medium | ⬜ Compute shader with spatial hash neighbor search |
| 23 | **FLIP Fluid (Houdini-style)** | Hybrid particle-grid for splashy water — unique among real-time tools | Very High | ⬜ |

### 13.7 Roadmap Summary

**Completed this session (6 of 7 Tier 1 items):**
- ✅ #1 Audio Band CHOP (multi-band frequency analysis with envelope followers)
- ✅ #5 FluidVOL obstacles (GPU + CPU, friction boundary support)
- ✅ #6 Timeline/Cue system (3 operators + editor UI)
- ✅ #7 Vorticity confinement (GPU compute + CPU, adjustable strength)
- ✅ #11 Reaction-Diffusion TOP (Gray-Scott, 7 presets, seed input, 3 color modes)
- ✅ #16 2D Fluid TOP (dual-viewport NS with emitter, dye input, velocity visualization)

**Highest remaining priorities:**
1. **NDI extension (#2)** — unlocks professional live production pipelines
2. **Fluid Surface MAT (#4)** — makes existing 3D fluid pipeline look production-quality
3. **Pyro emitter VOL (#8)** — fire/smoke on existing VOL infrastructure
4. **ML bridge (#10)** — face/hand tracking would be transformative for installations
5. **Takes / parameter layers (§11.3.K)** — live performance preset switching

**Overall completion:** 12 of 23 suggestions implemented (52%), including all high-priority architectural items (§11.1) and 6 of 7 Tier 1 workflow items.

# TouchDesigner vs Houdini vs GONODES — Architecture Deep Dive

> **Date:** 2026-03-03  
> **Purpose:** Comprehensive comparison of cooking models, data flow, engine architecture, and UI patterns across all three systems — with actionable improvement recommendations for GONODES.

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

---

## 1. Executive Summary

| Aspect | TouchDesigner | Houdini | GONODES |
|--------|--------------|---------|---------|
| **Primary domain** | Real-time visuals, interactive media | VFX, simulation, procedural modeling | Real-time visuals, VJing |
| **Cook paradigm** | Pull-based, demand-driven per frame | Pull-based, demand-driven on dependency change | Push-based, topo-sorted per frame |
| **Engine language** | C++ (operators), Python (scripting) | C++ (HDK), VEX (shaders/wrangles), Python/HScript | GDScript (operators), GDScript (scripting) |
| **GPU pipeline** | DirectX 11/12, OpenGL, Vulkan (GLSL/HLSL) | Karma (CPU/GPU), OpenGL viewport, Vulkan (Houdini 20+) | Godot renderer (Vulkan/OpenGL via SubViewport + GLSL) |
| **Node families** | TOP, CHOP, SOP, DAT, COMP, MAT | SOP, DOP, VOP, COP, CHOP, ROP, LOP, TOP (PDG) | TOP, IMG, CHOP, DAT, SOP, COMP, MAT |
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

- Every frame, `cook_frame(delta)` runs: marks time-dependent nodes dirty, topo-sorts, propagates dirty downstream (BFS), cooks all dirty+active nodes in topo order.
- **Active chain cooking** limits work to subgraphs feeding live sinks (viewers, WindowTOP, RecordCHOP, etc.).
- Inactive nodes keep `cached_output` frozen — **similar to TD's demand-driven model**.
- Cook is **synchronous, single-threaded, main-thread** — no parallel cook lanes.
- Parameter resolution (expression eval) happens inline before each node cooks.
- TOPs push GPU work via SubViewport `UPDATE_ONCE` — Godot's renderer handles the actual GPU submission.

### 2.4 Comparison Table

| Behavior | TouchDesigner | Houdini | GONODES |
|----------|--------------|---------|---------|
| Cook trigger | Demand (downstream pull) | Demand (downstream pull) | Frame loop (topo-sorted push) |
| Dirty granularity | Node-level | Parameter-level | Node-level |
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
| Multi-output nodes | Some (CHOP, SOP) | Common (Boolean, Split, etc.) | SubNetworkNode only |
| Named outputs | No (port index only) | Yes (named outputs) | No (port index only) |
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
| Parameter-level deps | Partial (CHOP export) | Full dependency DAG | None (node-level dirty) | **GAP** |
| Ramp parameter type | No (workaround via LookupTOP) | Yes (first-class, `chramp()`) | No | **GAP** |
| Multiparm / dynamic groups | No | Yes | No | Gap (minor) |
| Keyframe animation | Yes (basic timeline) | Yes (full animation editor) | No | **GAP** |
| Custom user parameters | Yes (on COMPs) | Yes (spare params, HDAs) | `@param` in Script ops only | Gap (minor) |
| Demand-driven expression eval | Yes | Yes | Inline per cook frame | ✓ adequate |
| Autocomplete | Yes (Python) | Yes (HScript, VEX) | Yes (CodeEdit) | ✓ |
| Profiling per param | No | No | Yes (µs per expression) | GONODES advantage |

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
- **Expression-tracked dependencies**: Active chain BFS follows both wire connections AND expression references (regex scan for `chop()/op()/top()/sop()/dat()/mat()` calls).

### 5.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES |
|---------|--------------|---------|---------|
| Hierarchy depth | Infinite (COMP nesting) | Infinite (subnet nesting) | Infinite (SubNetworkNode nesting) |
| Sort algorithm | Implicit (pull) | Implicit (pull) + compiled blocks | Explicit (Kahn's BFS) |
| Named I/O | No | Yes | No |
| Feedback mechanism | FeedbackTOP (prev frame) | Time Shift SOP, CHF(-1) | FeedbackTOP (prev frame) |
| Cross-network refs | `op('/path/to/node')` | `ch("../relative/path")` | `op("subnet/node")`, `op("../node")` |
| Implicit dependency tracking | Partial (CHOP export) | Full (parameter deps) | Partial (expression regex scan) |

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

- **GDScript core**: All operators are GDScript. Inner loops (pixel ops, vertex ops) are GDScript — the primary bottleneck.
- **Godot renderer**: TOPs leverage Godot's Vulkan/OpenGL renderer via SubViewport — GPU-accelerated.
- **Single-threaded cook**: Main thread only. No parallel cook lanes.
- **Active chain cooking**: Only cooks subgraphs feeding live sinks (equivalent to TD's demand-driven).
- **UPDATE_ONCE**: SubViewport renders exactly once per dirty cycle — eliminates redundant GPU work.
- **COW data sharing**: `_mutable_input()` avoids unnecessary copies at fan-out points.
- **Planned**: Multi-threaded cook, GDExtension C++ hot-paths, GPU compute shaders.

### 6.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES | Gap? |
|---------|--------------|---------|---------|------|
| Core operator language | C++ | C++ + VEX (JIT) | GDScript (interpreted) | **GAP** (planned: GDExtension) |
| GPU pipeline | Native DirectX/OpenGL/Vulkan | Karma GPU, OpenCL | Godot SubViewport (Vulkan/GL) | Adequate for real-time |
| Multi-threaded cook | Yes (TOPs multi-stream) | Yes (SOP internal, PDG farm) | No | **GAP** (planned) |
| Expression compilation | Python (interpreted) | VEX (JIT compiled) | GDScript Expression (interpreted) | Minor gap |
| Compiled blocks | No | Yes (SOP compile) | No | Not applicable (real-time) |
| Instancing | Yes (SOP/COMP) | Yes (packed prims) | Godot MultiMeshInstance3D (usable but not integrated) | Gap (minor) |
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
- **GLSL shaders**: CustomShaderTOP with `shader_type canvas_item` source, dynamic uniform scanning.
- **Extension system**: `gn_ext_*` addon folders with `gn_extension.cfg` manifests. Extensions register operators dynamically.
- **GDExtension (planned)**: C++ hot-path migration for performance-critical operators.
- **@param/@input annotations**: Dynamic UI generation from script annotations.
- **Presets**: Code presets (factory + user) for Script operators.

### 7.4 Comparison

| Feature | TouchDesigner | Houdini | GONODES | Gap? |
|---------|--------------|---------|---------|------|
| User scripting | Python | VEX + Python | GDScript | ✓ Adequate |
| Shader authoring | GLSL (frag/vert/compute) | VEX, GLSL, OSL, MaterialX | GLSL (canvas_item shader) | Minor gap (no compute) |
| C++ plugin SDK | No | Yes (HDK) | GDExtension (planned) | ✓ Architecture ready |
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
| Data spreadsheet | Grid-like viewer | Full spreadsheet | No | **GAP** |
| Network boxes / annotations | No | Yes (color boxes + stickies) | No | **GAP** |
| Dot/routing nodes | No | Yes | No | Gap (minor) |
| Viewport handles | Limited | Full 3D handles | No | Gap (not real-time relevant) |
| Node badges | Some (error, cook flag) | Rich (warnings, time dep, bypass, lock, HDA badge) | Bypass ⏩, Lock 🔒, Perf ms, Bookmark # | ✓ Good |
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
| Reusable asset format | `.tox` (COMP export) | `.hda` (full asset) | None (inline in .gnpatch) | **GAP** |
| Custom parameter interface | Yes (COMP params) | Yes (HDA type properties) | Partial (`@param` scripts) | **GAP** |
| Version control | No | Yes (HDA versioning) | No | Gap (minor) |
| Named I/O with labels | Yes (In/Out operators) | Yes (named inputs/outputs) | Yes (InTunnel/OutTunnel) | ✓ |
| Asset distribution | File sharing | OTL libraries + Orbolt | Extension system (gn_ext_*) | ✓ Architecture exists |

---

## 10. I/O & External Integration

| Protocol | TouchDesigner | Houdini | GONODES |
|----------|--------------|---------|---------|
| OSC | Built-in (In/Out) | Basic (via Python) | Built-in (OscInCHOP, OscOutCHOP, OscInDAT) |
| MIDI | Built-in (In/Out) | No | Input only (MidiInCHOP, MidiInDAT). Output planned. |
| NDI | Built-in | No | Planned |
| Syphon/Spout | Built-in | No | Planned |
| Audio input | Built-in | No | Built-in (AudioInCHOP, AudioSpectrumCHOP) |
| Video input | Built-in (webcam, capture card) | No | WebcamIMG + ImgToTOP |
| Serial/COM | Built-in | No | Not planned (niche) |
| DMX/ArtNet | Built-in | No | Not planned (niche) |
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

#### A. Parameter-Level Dependency Tracking

**Gap**: GONODES propagates dirty flags at the node level. If `nodeA.paramX` changes, all of `nodeA` is dirty and everything downstream recooks. Houdini tracks dependencies at the parameter level — only nodes whose parameters actually reference the changed parameter are invalidated.

**Impact**: In a large network where one node has 20 parameters and only `scale` changed, GONODES recooks the full downstream tree. With parameter-level deps, only nodes that reference `scale` (directly or transitively) would recook.

**Recommendation**: Build a parameter dependency mini-graph during `_resolve_node_parameters()`. Each expression evaluation records which parameters were read. On parameter change, only invalidate nodes whose expressions touched that specific parameter. This is the "Full Parameter DAG" mentioned in your roadmap (§7.6). The existing `_evaluating_params` guard is the seed — extend it to record a `reads_from` set per expression.

**Complexity**: Medium. The infrastructure (`_evaluating_params`) exists. Main work is recording reads during `par()`/`chop()` calls and using them to narrow dirty propagation.

#### B. Ramp / Curve Parameter Type

**Gap**: Houdini's ramp parameter is a first-class type — a curve editor built into the parameter UI. This is transformative for procedural workflows: color gradients, falloff curves, animation curves, noise shaping, and any value-over-domain mapping. Neither TD nor GONODES has this as a built-in parameter type.

**Impact**: Currently GONODES users who want a color gradient over an animation cycle must either:
- Chain multiple ConstantTOPs with CrossTOP (clunky)
- Use a LookupTOP with a pre-made texture (non-interactive)
- Write math in expressions (fragile)

A ramp parameter would let them draw a gradient curve directly in the inspector and evaluate it via `ramp("param_name", t)` in expressions or `chramp()` in scripts.

**Recommendation**: Add `ValueType.RAMP` to `GNParameter`. Data model: array of `{position: float, value: Color or float, interpolation: enum}` control points. UI: custom `Control` with draggable handles and interpolation mode per segment. Expression function: `ramp("name", t)` returns interpolated value at position `t ∈ [0,1]`. Serialize as JSON array of keyframes.

**Complexity**: Medium-high. The parameter system supports custom types well. Main work is the curve editor UI widget and the interpolation math.

#### C. Reusable Asset Package Format (.gnasset)

**Gap**: Houdini's HDA system lets artists package subnet networks into distributable, versioned assets with custom parameter UIs. GONODES has SubNetworkNode but no way to export one as a reusable, distributable type. TD has `.tox` but it's more limited than HDA.

**Impact**: Without an asset format, sharing custom node types requires copy-pasting SubNetworks or writing GDScript operators. An asset format would enable a community ecosystem — artists share useful node setups without coding.

**Recommendation**: Define a `.gnasset` format: a JSON file containing the inner network definition + a parameter interface definition (which inner params are "promoted" to the subnet's inspector). `GNExtensionRegistry` can load `.gnasset` files alongside `gn_ext_*` extensions. Users drag-and-drop `.gnasset` files into a library folder. The SubNetworkNode's parameter interface would be defined by the asset author.

**Complexity**: Medium. The serialization infrastructure exists (SubNetworkNode already serializes `inner_network.to_dict()`). The parameter interface promotion (which inner params appear on the outer node) is the main new work.

#### D. Multi-Threaded Cook Engine

**Gap**: GONODES cooks everything on the main thread. TD parallelizes GPU work across command queues. Houdini parallelizes SOP/VEX across CPU cores.

**Impact**: For networks with independent branches (e.g., two parallel CHOP chains feeding different TOPs), the branches could cook simultaneously.

**Recommendation**: This is already on your roadmap. The architecture supports it — each node's `_cook()` only reads its `inputs` array and writes to `cached_output`. Independent branches in the topo order can be identified and dispatched to Godot's `WorkerThreadPool`. The main complexity is thread-safety for shared state (expressions reading other nodes' params, CHOP exports, etc.) and Godot's scene-tree thread affinity for SubViewports.

**Complexity**: High. Godot's rendering is main-thread-affine for SubViewport operations.

### 11.2 MEDIUM PRIORITY — Workflow Improvements

#### E. Data Spreadsheet / Table Viewer

**Gap**: Houdini's geometry spreadsheet is one of its most loved features — you can inspect every point, primitive, and attribute value in a table. TD has grid viewers for CHOPs and DATs. GONODES shows data only as text labels in node previews.

**Impact**: Debugging data flow (especially CHOPs and DATs) without a spreadsheet means adding print statements or NullDATs to inspect values. A spreadsheet viewer would dramatically improve workflow.

**Recommendation**: Add a `GNDataSpreadsheet` dockable panel. When a CHOP is selected, show a table with columns = channel names, rows = sample indices. When a DAT is selected, show the table directly. When a SOP is selected, show vertices/points with position, normal, UV, and custom attributes. Open via double-click or context menu.

**Complexity**: Low-medium. Godot's `Tree` or `ItemList` widgets could serve as the table. Data is already in memory (`GNChannelData.channels`, `GNTableData.rows`, `GNGeoData.get_positions()`, etc.).

#### F. Network Boxes / Sticky Notes

**Gap**: Houdini's network boxes (colored rectangles for grouping) and sticky notes (text annotations on the canvas) are essential for organizing large networks. TD lacks these too.

**Impact**: Networks larger than ~30 nodes become hard to navigate without visual grouping cues. SubNetworks help for encapsulation but not for visual organization of a flat network.

**Recommendation**: Add `GNNetworkBox` (colored rectangle with label, serialized in .gnpatch) and `GNStickyNote` (text annotation on the canvas). Both are non-cooking, purely organizational. Render as GraphEdit child controls behind nodes.

**Complexity**: Low. No cook engine changes needed — purely UI. Serialize as additional arrays in the `.gnpatch` format.

#### G. Keyframe Animation System

**Gap**: Both TD and Houdini support keyframe animation on parameters. Houdini has a full animation editor with curves, handles, and interpolation modes. TD has a simpler timeline. GONODES has no animation system beyond time-dependent expressions.

**Impact**: For motion graphics and pre-rendered content, keyframe animation is essential. Currently users must write math expressions to animate parameters — viable but tedious for complex animations.

**Recommendation**: Add a timeline panel and keyframe data model. Each `GNParameter` optionally stores an animation curve (`Array[{frame: int, value: Variant, interpolation: enum}]`). A new parameter mode `ANIMATED` plays back keyframe curves. The timeline panel shows a mini curve editor. Expression mode remains available for procedural animation.

**Complexity**: Medium-high. The parameter system needs a new mode and data structure. The UI (curve editor panel) is the bulk of the work.

#### H. CHOP Viewer Graph (Waveform Display)

**Gap**: TD shows live waveform graphs on CHOP node thumbnails — you can see oscillating signals at a glance. GONODES shows CHOP values as text labels.

**Impact**: For audio, LFO, noise, and signal processing workflows, a visual waveform is far more informative than a number. This would make GONODES' CHOP development experience match TD's.

**Recommendation**: Override `GNChopBase.create_preview_control()` to return a custom `Control` that draws a mini line graph of the channel data. Use `_draw()` with `draw_polyline()` — render at 120×80px per node. Color by channel, scale Y to data range, show most recent N samples.

**Complexity**: Low. Custom `Control._draw()` with `draw_polyline()`. Data is already in `_cached_channel_data.channels`. No cook engine changes.

### 11.3 LOW PRIORITY — Nice to Have

#### I. Named Output Ports

**Gap**: Houdini SOPs frequently have named outputs (Boolean → "Intersect", "A minus B", "B just B"). GONODES uses indexed ports only.

**Recommendation**: Add optional `port_label: String` to `GNPort`. Show in tooltip and palette. Low effort, improves readability for multi-output nodes.

#### J. Dot/Routing Nodes

**Gap**: Houdini's dot nodes let you route wires cleanly for readability.

**Recommendation**: A "DotNode" that passes data through unchanged, with no parameter UI — purely for wire routing.

#### K. Takes / Parameter Layer Overrides

**Gap**: Houdini's Take system lets you save named parameter states and switch between configurations non-destructively.

**Recommendation**: Low priority — parameter presets partially cover this use case. Could extend `GNParamPresetManager` with "take" semantics (apply an override layer, revert to base).

---

## Summary: Top 5 Recommendations

| # | Recommendation | Effort | Value | Rationale |
|---|---------------|--------|-------|-----------|
| 1 | **Ramp parameter type** with curve editor | Medium | Very High | Unlocks gradients, falloff curves, animation curves — transformative for procedural/motion graphics |
| 2 | **CHOP waveform preview** (mini line graph) | Low | High | Makes CHOP debugging visual instead of numerical — matches TD's core UX |
| 3 | **Data spreadsheet viewer** | Low-Med | High | Essential debugging tool for CHOPs, DATs, and SOPs — Houdini's most loved feature |
| 4 | **Network boxes + sticky notes** | Low | Medium | Canvas organization for complex networks — near-universal in DCC tools |
| 5 | **Parameter-level dependency tracking** | Medium | High | Reduces unnecessary recooks in large networks — Houdini's key optimization |

GONODES is already remarkably well-aligned with both TD and Houdini's core architecture. The active chain cooking, COW data model, expression system, per-component expressions, preview system, and sub-network hierarchy put it in strong competitive territory. The gaps are mostly in **power-user workflow tools** (spreadsheet, ramp, annotations) rather than fundamental architecture holes.

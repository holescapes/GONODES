# GONODES — LLM Context File

> **Last updated:** 2026-02-25
> **Status:** Phase 4 Complete — Node Graph UI, Parameter Inspector, and live expression editing all functional. Ready for Phase 5 (Polish & More Operators).

---

## 1. Project Overview

**GONODES** is a real-time node-based visual programming framework built on Godot 4.6, inspired by Derivative TouchDesigner. It targets **visual/generative art and VJing** workflows.

### Key Differentiator

GONODES uses **LibGodot** (Godot 4.6's embeddable engine library) as its portability layer. This means:
- The GONODES editor is a full Godot application
- For embedding in host apps (VDMX, Resolume, etc.), LibGodot is embedded in the host process
- The same GONODES framework code (GDExtension) runs in both contexts
- Godot's renderer, audio, compute, and physics systems are available everywhere
- This follows the same model as VUO patches embedded in VDMX via FxPlug

---

## 2. Architecture Decisions (Locked In)

| Decision               | Choice                                              |
|------------------------|-----------------------------------------------------|
| Engine                 | Godot 4.6 (with LibGodot)                           |
| Primary Language       | GDScript (GDExtension/C++ for hot paths later)      |
| Patch Format (MVP)     | Godot Resource (.tres)                              |
| Patch Format (Future)  | JSON (.GNNode) for cross-app portability             |
| Project Name           | GONODES                                             |
| Target Use Case        | Visual/generative art, VJing                        |
| Priority OP Families   | TOPs (textures) and CHOPs (channels/signals) first  |
| MVP Scope              | Node graph UI + LFO CHOP driving a Noise TOP        |
| MVP Timeline           | 4–6 weeks                                           |
| I/O Protocols (Future) | Syphon/Spout, OSC, NDI — not in MVP                 |
| Runtime Model          | Standalone app + LibGodot embedding in host apps     |
| Dev Strategy           | GDScript-first, GDExtension for perf optimization   |
| Editor Platforms       | Windows, macOS, Linux (no ARM devices for editor)    |
| Export Targets         | All Godot-supported platforms (incl. mobile/web)     |
| Renderer Selection     | User-selectable in editor (Forward+, Mobile, Compat) |
| Param References       | Cross-node parameter/data referencing (like TD)      |

---

## 3. High-Level Architecture

```
┌──────────────────────────────────────────────────┐
│  GONODES Editor (Godot 4.6 Application)          │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │  UI Layer                                   │ │
│  │  GraphEdit canvas, Inspector panel,         │ │
│  │  Viewer windows, Node palette, Timeline     │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Operator Library                           │ │
│  │  Built-in TOPs, CHOPs, SOPs, DATs, MATs     │ │
│  │  Each is a GNNode subclass with cook()      │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Cook Engine                                │ │
│  │  DAG traversal, dirty propagation,          │ │
│  │  lazy evaluation, caching                   │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Node Graph Model                           │ │
│  │  GNNetwork, GNNode, GNConnection, GNPort    │ │
│  │  Type system, serialization                 │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Data Types                                 │ │
│  │  GNTextureData, GNChannelData, GNGeoData,   │ │
│  │  GNTableData, GNMaterialData                │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Godot Engine (renderer, audio, compute)    │ │
│  └─────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘

Embedding Model (Future):
┌──────────────────────────┐
│  Host App (VDMX, etc.)   │
│  ┌────────────────────┐  │
│  │ LibGodot (embedded) │  │
│  │  + GONODES Framework│  │
│  │  (GDExtension)     │  │
│  └────────────────────┘  │
│  Host feeds data in →    │
│  ← reads textures out    │
│  Loads .GNNode patches   │
└──────────────────────────┘
```

---

## 4. TouchDesigner → GONODES Concept Mapping

| TouchDesigner         | GONODES Implementation                                   |
|-----------------------|----------------------------------------------------------|
| Operator (OP)         | `GNNode` (Node subclass) with `cook()` method             |
| TOP (Texture OP)      | `GNTopNode` — uses SubViewport + ShaderMaterial           |
| CHOP (Channel OP)     | `GNChopNode` — processes named float arrays              |
| SOP (Surface OP)      | `GNSopNode` — produces ArrayMesh (future)                |
| POP (Point OP)        | `GNPopNode` — GPU particle/point cloud system (future)   |
| DAT (Data OP)         | `GNDatNode` — tables/text (future)                       |
| MAT (Material OP)     | `GNMatNode` — Godot ShaderMaterial (future)              |
| COMP (Component OP)   | `GNCompNode` — nested networks (future)                  |
| Network / Canvas      | `GNNetwork` (Resource) displayed in `GraphEdit`          |
| Wire / Connection     | `GNConnection` — typed, family-checked                   |
| Cook / Evaluate       | `GNCookEngine` — topological DAG walk + dirty flags      |
| Parameter Reference   | GDScript expression evaluated at cook time               |
| Timeline              | Godot `_process()` driving cook engine each frame        |
| Parameter             | `GNParameter` — typed value with optional expression     |
| Param References      | `op("name").par.X` / `chop("name").value("ch")` syntax   |
| Patch Export           | Godot export system → standalone runnable per platform   |

---

## 5. Core Data Types

### GNData (Base)
```
GNData (RefCounted)
├── valid: bool
├── timestamp: int (cook frame)
└── type() -> GNFamily
```

### GNTextureData (TOP output)
```
GNTextureData extends GNData (RefCounted)
├── texture: Texture2D (result of SubViewport rendering)
├── viewport: SubViewport (owned by the TOP node)
├── resolution: Vector2i
└── format: Image.Format
```

### GNChannelData (CHOP output)
```
GNChannelData extends GNData (RefCounted)
├── channels: Dictionary[String, PackedFloat32Array]
│   e.g., {"tx": [0.0, 0.1, ...], "ty": [...], "tz": [...]}
├── sample_rate: float
├── length: int (number of samples)
└── get_channel(name: String) -> PackedFloat32Array
└── get_value(channel: String, index: int = -1) -> float
    (index=-1 returns last sample, useful for single-value CHOPs)
```

---

## 6. Operator Base Class

```gdscript
class_name GNNode extends Node

enum GNFamily { TOP, CHOP, SOP, POP, DAT, MAT, COMP }

# Identity
var id: String                     # Unique ID within network
var node_type: String              # e.g., "noise", "lfo", "composite"
var family: GNFamily               # Which OP family

# Ports
var input_ports: Array[GNPort]     # Defined by subclass
var output_ports: Array[GNPort]    # Defined by subclass

# Parameters
var parameters: Dictionary         # name -> GNParameter

# Cook state
var dirty: bool = true
var cached_output: GNData = null
var cook_time_ms: float = 0.0      # Profiling
var cook_valid: bool = false

# Timing (injected by GNCookEngine before each cook)
var current_delta: float = 0.0     # Frame delta in seconds
var elapsed_time: float = 0.0      # Total time since engine start
var current_frame: int = 0         # Frame counter

# UI metadata (stored but not used by cook engine)
var graph_position: Vector2 = Vector2.ZERO

# Interface
func _init_ports() -> void: pass          # Override: define ports
func _init_parameters() -> void: pass     # Override: define params
func _cook(inputs: Array[GNData]) -> GNData: return null  # Override: produce output
func get_input(index: int) -> GNData: ...  # Resolved by cook engine
func mark_dirty() -> void: ...             # Propagates downstream
```

### Node Lifecycle
- `_init()` — set `node_type`, `family`, `time_dependent` (runs before entering tree)
- `initialize(id)` — sets `name = id`, `process_mode = DISABLED`, calls `_init_ports()` / `_init_parameters()`
- Processing is disabled on GNNodes — only the cook engine drives cooking
- TOPs add SubViewport as `add_child()` during first `_cook()` — auto-freed on removal
- CookEngine adopts all network nodes as children via `add_child()` in `_ready()`
- `queue_free()` cascades to SubViewport/Window children (no manual cleanup needed)

---

## 7. Port System

```gdscript
class_name GNPort extends RefCounted

var port_name: String
var family: GNNode.GNFamily    # Type of data this port accepts/produces
var index: int                 # Port index on the node
var is_input: bool
var multi_input: bool = false  # Some ops accept multiple inputs (e.g., Composite)
```

### Connection Rules
- Ports can only connect within the same family (TOP→TOP, CHOP→CHOP)
- Exception: Bridge operators (CHOPtoTOP, TOPtoCHOP) have mixed port types
- One output can connect to many inputs (fan-out)
- An input can receive one connection (unless multi_input=true)
- No cycles allowed (DAG enforcement)

### Family Colors (UI)
| Family | Color        |
|--------|-------------|
| TOP    | Purple      |
| CHOP   | Green       |
| SOP    | Blue        |
| DAT    | Yellow      |
| POP    | Cyan        |
| MAT    | Red/Orange  |
| COMP   | Gray        |

---

## 8. Network & Cook Engine

### GNNetwork
```gdscript
class_name GNNetwork extends Resource

var nodes: Dictionary = {}            # id -> GNNode
var connections: Array[GNConnection] = []

func add_node(node: GNNode) -> void
func remove_node(id: String) -> void
func connect_nodes(from_id: String, from_port: int,
                   to_id: String, to_port: int) -> bool
func disconnect_nodes(from_id: String, from_port: int,
                      to_id: String, to_port: int) -> void
func get_topological_order() -> Array[GNNode]
func get_upstream_nodes(id: String) -> Array[GNNode]
func get_downstream_nodes(id: String) -> Array[GNNode]
func has_cycle() -> bool
```

### GNConnection
```gdscript
class_name GNConnection extends RefCounted

var from_node: String    # GNNode id
var from_port: int       # Output port index
var to_node: String      # GNNode id
var to_port: int         # Input port index
```

### GNCookEngine
```gdscript
class_name GNCookEngine extends Node

var network: GNNetwork
var frame_count: int = 0

func _process(delta: float) -> void:
    cook_frame(delta)

func cook_frame(delta: float) -> void:
    # 1. Mark time-dependent nodes dirty (LFO, Noise with time input, etc.)
    # 2. Collect dirty nodes
    # 3. Get topological order (only dirty + downstream)
    # 4. Cook each in order, passing resolved inputs
    # 5. Cache results
    # 6. Clear dirty flags
    # 7. Increment frame_count

func cook_node(node: GNNode) -> GNData:
    # Resolve inputs from upstream cached outputs
    # Call node._cook(inputs)
    # Cache result
    # Record cook time for profiling

func propagate_dirty(node: GNNode) -> void:
    # Walk downstream connections, mark all as dirty
```

### Cook Semantics
- **Time-dependent nodes** (LFO, Noise with `time` param) are always dirty.
- **Parameter-changed nodes** are marked dirty when a parameter changes.
- **Input-changed nodes** are marked dirty via `propagate_dirty()`.
- **Nodes only cook when dirty** — lazy evaluation.
- **Each node cooks at most once per frame** — results are cached.
- **Cook order** = topological sort of the dirty subgraph.

---

## 9. MVP Operators

### TOP Family

#### NoiseTOP
- **Outputs:** 1 texture (SubViewport render)
- **Inputs:** 0
- **Parameters:**
  - `resolution`: Vector2i (default 512×512)
  - `noise_type`: enum (Simplex, Perlin, Voronoi, White)
  - `scale`: float (default 4.0)
  - `offset`: Vector2 (default 0,0)
  - `time_offset`: float (driven by time or manual)
  - `seed`: int
  - `monochrome`: bool (default true)
- **Implementation:** SubViewport + ColorRect + ShaderMaterial running a noise GLSL shader
- **Time-dependent:** Yes (if time_offset is linked to global time)

#### CompositeTOP
- **Outputs:** 1 texture
- **Inputs:** 2 textures (A and B)
- **Parameters:**
  - `operation`: enum (Add, Multiply, Over, Screen, Subtract, Difference)
  - `opacity`: float (0–1, default 1.0)
- **Implementation:** SubViewport + shader that samples both inputs

#### LevelTOP
- **Outputs:** 1 texture
- **Inputs:** 1 texture
- **Parameters:**
  - `brightness`: float (default 1.0)
  - `contrast`: float (default 1.0)
  - `gamma`: float (default 1.0)
  - `invert`: bool (default false)
  - `opacity`: float (default 1.0)

### CHOP Family

#### LFO_CHOP
- **Outputs:** 1 channel set (single channel "out")
- **Inputs:** 0
- **Parameters:**
  - `waveform`: enum (Sine, Triangle, Square, Sawtooth, Pulse)
  - `frequency`: float (default 1.0 Hz)
  - `amplitude`: float (default 1.0)
  - `offset`: float (default 0.0)
  - `phase`: float (default 0.0)
  - `duty_cycle`: float (for Pulse, default 0.5)
- **Time-dependent:** Yes (always cooks)

#### MathCHOP
- **Outputs:** 1 channel set
- **Inputs:** 1–2 channel sets
- **Parameters:**
  - `operation`: enum (Add, Subtract, Multiply, Divide, Abs, Sin, Cos, Pow)
  - `operand`: float (for single-input operations)

#### NoiseCHOP
- **Outputs:** 1 channel set (configurable number of channels)
- **Inputs:** 0
- **Parameters:**
  - `num_channels`: int (default 1)
  - `channel_names`: String (comma-separated, default "chan1")
  - `roughness`: float
  - `period`: float
  - `seed`: int
- **Time-dependent:** Yes

### Bridge Operators

#### CHOPtoTOP (Parameter Reference Bridge)
This is not a traditional operator — it's a mechanism for CHOP channels to drive TOP parameters.

**Implementation approach for MVP:**
Parameter expressions on any GNNode can reference CHOP outputs:
```
# On NoiseTOP.scale parameter expression:
chop("lfo1").value("out")   # Gets last sample of channel "out" from node "lfo1"
```

This is resolved during cook: the cook engine evaluates parameter expressions before calling `_cook()`, injecting resolved values.

---

## 10. UI Architecture

### Main Editor Layout
```
┌──────────────────────────────────────────────────┐
│  Menu Bar                                        │
├──────────┬───────────────────────┬───────────────┤
│          │                       │               │
│  Node    │   Graph Editor        │   Inspector   │
│  Palette │   (GraphEdit)         │   (Params)    │
│          │                       │               │
│          │   ┌───┐    ┌───┐      │               │
│  TOPs    │   │LFO│───▶│NOI│      │  [NoiseTOP]   │
│  CHOPs   │   │   │    │SE │      │  scale: 4.0   │
│  SOPs    │   └───┘    └───┘      │  seed: 42     │
│  ...     │                       │  type: Simplex│
│          │                       │               │
├──────────┴───────────────────────┴───────────────┤
│  Viewer (SubViewportContainer — shows TOP output)│
│                                                  │
└──────────────────────────────────────────────────┘
```

### GNGraphEditor (extends GraphEdit)
- Renders GNNetwork as GraphNode instances
- Handles drag-and-drop from palette, wiring, deletion
- Color-codes connections by family
- Right-click context menu to add nodes
- Emits signals when user modifies graph → updates GNNetwork model

### GNNodeView (extends GraphNode)
- Visual representation of a GNNode
- Shows typed input/output ports with family colors
- Shows node name and type icon
- Shows mini preview (thumbnail) for TOP outputs
- Highlights when cooking, shows cook time

### GNInspector (extends VBoxContainer)
- Shows parameters for the currently selected node
- Renders appropriate controls per parameter type:
  - float → HSlider + SpinBox
  - int → SpinBox
  - Vector2 → 2x SpinBox
  - Color → ColorPickerButton
  - enum → OptionButton
  - bool → CheckBox
  - String → LineEdit
- Expression toggle: switch from value to expression mode

### GNViewer (extends SubViewportContainer)
- Full-size preview of a selected TOP's output
- Can be popped out into a separate window
- Shows resolution, cook time, FPS overlay

---

## 11. Folder Structure

```
GONODES/
├── project.godot
├── GONODES_CONTEXT.md              ← This file
├── addons/
│   └── gonodes/
│       ├── plugin.cfg
│       ├── gonodes_plugin.gd       # EditorPlugin entry (for editor mode)
│       ├── core/
│       │   ├── gn_data.gd          # GNData base class (RefCounted)
│       │   ├── gn_texture_data.gd  # GNTextureData (RefCounted)
│       │   ├── gn_channel_data.gd  # GNChannelData (RefCounted)
│       │   ├── gn_node.gd          # GNNode base operator class (Node)
│       │   ├── gn_port.gd          # GNPort definition (RefCounted)
│       │   ├── gn_connection.gd    # GNConnection (RefCounted)
│       │   ├── gn_network.gd       # GNNetwork (Resource — serialization boundary)
│       │   ├── gn_cook_engine.gd   # GNCookEngine (Node)
│       │   ├── gn_parameter.gd     # GNParameter (Resource — typed param with expressions)
│       │   ├── gn_family.gd        # GNFamily enum constants
│       │   └── gn_logger.gd        # GNLogger — centralized logging with level filtering
│       ├── operators/
│       │   ├── top/
│       │   │   ├── noise_top.gd
│       │   │   ├── composite_top.gd
│       │   │   └── level_top.gd
│       │   ├── chop/
│       │   │   ├── lfo_chop.gd
│       │   │   ├── math_chop.gd
│       │   │   └── noise_chop.gd
│       │   ├── bridge/
│       │   │   └── chop_to_top.gd  # (or parameter expression system)
│       │   └── output/
│       │       └── window_top.gd   # WindowTOP — multi-window display output
│       ├── ui/
│       │   ├── gn_graph_editor.gd
│       │   ├── gn_graph_editor.tscn
│       │   ├── gn_node_view.gd
│       │   ├── gn_node_view.tscn
│       │   ├── gn_inspector.gd
│       │   ├── gn_inspector.tscn
│       │   ├── gn_viewer.gd
│       │   ├── gn_viewer.tscn
│       │   ├── gn_node_palette.gd
│       │   ├── gn_node_palette.tscn
│       │   └── gn_main_editor.tscn # Main layout scene
│       ├── shaders/
│       │   ├── noise_simplex.gdshader
│       │   ├── noise_perlin.gdshader
│       │   ├── noise_voronoi.gdshader
│       │   ├── composite.gdshader
│       │   └── levels.gdshader
│       └── icons/
│           ├── top_icon.svg
│           ├── chop_icon.svg
│           └── ... (per-operator icons)
├── scenes/
│   └── main.tscn                   # Application entry scene
├── tests/
│   ├── test_cook_engine.gd
│   ├── test_network.gd
│   └── test_operators.gd
└── assets/
```

---

## 12. Development Phases

### Phase 1: Core Framework (Week 1) ✅
- [x] Set up Godot 4.6 project structure
- [x] Implement GNData, GNTextureData, GNChannelData
- [x] Implement GNPort, GNConnection
- [x] Implement GNParameter (value + expression support)
- [x] Implement GNNode base class with cook lifecycle
- [x] Implement GNNetwork (graph model, topological sort, cycle detection)
- [x] Implement GNCookEngine (dirty propagation, frame cook loop)
- [ ] Write unit tests for graph operations and cook order

### Phase 2: First Operators (Week 2) ✅
- [x] Implement NoiseTOP (SubViewport + noise shader)
- [x] Implement LFO_CHOP (waveform generator)
- [x] Wire up cook engine to process a test network from code
- [x] Test scene: LFO_CHOP expression driving NoiseTOP.time_offset
- [x] Implement CompositeTOP
- [x] Implement LevelTOP
- [x] Implement NoiseCHOP, MathCHOP
- [x] Implement WindowTOP (multi-window/multi-display output)
- [x] Implement GNLogger (centralized logging with toggle)
- [x] Resource → Node/RefCounted migration
- [x] Expression system debugging & rearchitecture (base_instance model)
- [x] WindowTOP rendering fix (anchors + zero-copy texture routing)
- [x] Cook engine performance optimization (cached adjacency, zero-alloc inputs)
- [x] Verified: animated noise, movable output window, stable cook times

### Phase 3: Node Graph UI (Week 3) ✅
- [x] Implement GNGraphEditor (GraphEdit wrapper with bidirectional network sync)
- [x] Implement GNNodeView (GraphNode per operator with family-colored title bar)
- [x] Port rendering with family colors via `set_slot()` typed port slots
- [x] Wire connection UI with type checking
- [x] Add/remove nodes via UI (Tab / right-click palette)
- [x] Connect/disconnect wires via UI
- [x] Sync UI ↔ GNNetwork model bidirectionally (signal-driven)
- [x] Implement GNNodePalette (popup with search + family grouping)
- [x] Editor scene (gn_editor.tscn) with HSplit layout: graph + viewer/inspector

### Phase 4: Parameters & Inspector (Week 4) ✅
- [x] Implement GNParamInspector panel (family color bar, header, scrollable params)
- [x] Implement GNParamRow (per-parameter widget with type-specific controls)
- [x] Render parameter controls by type (FLOAT: slider+spinbox, INT: spinbox, BOOL: checkbox, ENUM: dropdown, COLOR: picker, VECTOR2/2I: dual spinbox, STRING: line edit)
- [x] Parameter mode toggle (C=constant green / E=expression orange)
- [x] Expression inline editor with focus guard (no 60fps text clobbering)
- [x] Parameter change → mark node dirty → recook
- [x] GNViewer panel showing TOP output in real-time (VSplit: viewer top, inspector bottom)
- [x] Expression mode: CHOP channel references in parameter fields
- [x] Live cook time display per node in inspector header
- [x] NoiseTOP noise_type enum wired to shader (4 algorithms: Simplex/Perlin/Voronoi/White)
- [x] WindowTOP `_window_params_dirty` flag — only reconfigures on own param changes, not upstream cook-dirty

### Phase 5: Polish & More Operators (Week 5)
- [ ] MathCHOP, NoiseCHOP
- [ ] Node palette (categorized operator list, drag-to-add)
- [ ] Right-click context menu on graph canvas
- [ ] Copy/paste nodes
- [ ] Undo/redo (Godot's UndoRedo system)
- [ ] Mini preview thumbnails on TOP nodes

### Phase 6: Integration & Stabilization (Week 6)
- [ ] Save/load patches (.tres resources)
- [ ] Multiple viewer windows
- [ ] Performance profiling overlay (cook time per node)
- [ ] Stress test: 50+ node network
- [ ] Bug fixes
- [ ] README and basic documentation

---

## 13. Future Roadmap (Post-MVP)

### Near-term
- [ ] JSON patch export/import (.GNNode format)
- [ ] Patch export to standalone runnables (Godot export templates)
- [ ] Renderer selection UI in editor (Forward+, Mobile, Compatibility)
- [ ] SOP family (procedural geometry: Grid, Circle, Merge, Transform)
- [ ] DAT family (Table, Text, Script)
- [ ] MAT family (PBR Material, Shader Material)
- [ ] COMP family (nested sub-networks, UI containers)
- [ ] Keyboard shortcuts and workflow polish

### Medium-term
- [ ] POP family (GPU point/particle operators — see Section 18)
- [ ] LibGodot embedding proof-of-concept
  - Build a minimal host app that embeds LibGodot
  - Load a .GNNode patch via API
  - Feed data in, read textures out
- [ ] Syphon (macOS) / Spout (Windows) texture sharing
- [ ] OSC input/output operators
- [ ] MIDI input operators
- [ ] Audio input CHOP (microphone / audio file)
- [ ] Webcam / video input TOP
- [ ] Custom GLSL shader TOP (user-editable shader code)

### Long-term
- [ ] NDI video streaming
- [ ] FxPlug / FFGL plugin export (for VDMX, Resolume)
- [ ] GPU compute shaders for CHOPs (massive parallel channel processing)
- [ ] Multi-threaded cook engine
- [ ] Python scripting DAT (embedded Python via GDExtension)
- [ ] Network collaboration (shared editing)
- [ ] Asset/patch marketplace
- [ ] Mobile/web export for patches (leveraging Godot's Mobile + Compatibility renderers)

---

## 14. Technical Notes

### SubViewport Strategy for TOPs
Each TOP node owns a `SubViewport` for rendering its output texture:
- The viewport has a `ColorRect` (or `MeshInstance2D`) with a `ShaderMaterial`
- Input textures are passed as shader uniforms
- The viewport renders each frame (or only when dirty)
- The output `ViewportTexture` becomes the node's `GNTextureData.texture`
- Resolution is configurable per node
- Viewports are managed by the cook engine (created/destroyed with nodes)

**Performance consideration:** Each SubViewport is a render pass. For large networks, we may need viewport pooling or deferred rendering optimizations. For MVP, one viewport per TOP is acceptable.

### Cook Engine Optimizations (Implemented)

The cook engine has been optimized with these patterns:

1. **Cached adjacency maps** — `GNNetwork._downstream_map` and `_input_conn_map` are rebuilt only when the graph structure changes (node/connection add/remove). All per-frame lookups (dirty propagation, input gathering) use O(1) dictionary lookups instead of scanning all connections.

2. **Upfront dirty propagation** — Dirty flags are propagated in a single BFS pass BEFORE the cook loop starts, not interleaved with cooking. This eliminates redundant BFS calls (previously one per producing node).

3. **Cached input arrays** — `_input_cache` stores a reusable `Array[GNData]` per node. Arrays are cleared and refilled each frame instead of being reallocated. Zero per-frame allocations in steady state.

4. **Skip-already-dirty BFS** — `propagate_dirty()` stops traversal at nodes already marked dirty, avoiding redundant downstream walks.

### CHOP Channel Model
CHOPs produce `GNChannelData` which contains:
- Named channels (e.g., "tx", "ty", "tz" or "out", "chan1")
- Each channel is a `PackedFloat32Array`
- Single-value CHOPs (like LFO) have arrays of length 1
- Multi-sample CHOPs (like audio) have arrays of length N
- `sample_rate` field enables time-domain operations

### Parameter Expression System
Parameters support two modes:
1. **Value mode:** Direct value (float, int, vec2, etc.)
2. **Expression mode:** GDScript expression string evaluated at cook time

**CRITICAL — Expression Architecture (Godot's Expression class):**

Godot's `Expression` class resolves function calls as **method lookups on `base_instance`**, NOT as calls to input variables. You cannot pass Callables as input variables and expect to call them — they will be treated as data, not functions.

Therefore:
- `chop()`, `op()`, `top()` are **real public methods on GNCookEngine**
- `Expression.execute()` uses `self` (the cook engine) as `base_instance`
- Input variables are limited to data: `["me", "time", "frame", "dt"]`
- The expression `chop("lfo1", "out") * 5.0` calls `GNCookEngine.chop("lfo1", "out")` directly

This was a hard-won architectural insight — the original design passed Callable lambdas as input vars, which silently failed (Expression returned 0.0 fallback → static noise).

Expression context provides:
- `me` — reference to the owning node (GNNode)
- `chop(name, channel)` — method on base_instance, returns float
- `op(name, param)` — method on base_instance, returns Variant
- `top(name, property)` — method on base_instance, returns Variant
- `time` — current time in seconds (input variable)
- `frame` — current frame number (input variable)
- `dt` — delta time (input variable)

Example: `chop("lfo1", "out") * 5.0`

### Godot Version Requirements
- **Godot 4.6** (for LibGodot support)
- Uses: GraphEdit, GraphNode, SubViewport, ShaderMaterial, Resource serialization
- GDScript typed syntax throughout
- Static typing enforced where possible

### Renderer Compatibility & Selection
Godot 4.x offers three rendering backends. GONODES must support all three so exported patches run on any target device:

| Renderer       | GPU Target              | Use Case              | Notes for GONODES                      |
|----------------|-------------------------|-----------------------|----------------------------------------|
| **Forward+**   | Desktop Vulkan/D3D12    | Full quality, desktop | Default for editor. All features.      |
| **Mobile**     | Mobile Vulkan/Metal     | Mobile devices        | Fewer shader features. TOPs must use compatible shaders. |
| **Compatibility** | OpenGL 3.3 / WebGL2  | Web, old hardware     | No compute shaders. CHOP/POP fallbacks needed. |

**Editor behavior:**
- A dropdown in the editor toolbar lets the user switch renderers live while editing.
- This allows previewing how a patch will look on each target platform.
- Operators should report if they are incompatible with the current renderer (e.g., compute-based POP on Compatibility).

**Implementation:**
- `ProjectSettings.set_setting("rendering/renderer/rendering_method", ...)` at runtime.
- Each operator can declare `supported_renderers: Array[String]` (default: all three).
- The cook engine skips or substitutes incompatible operators and shows a warning badge in the UI.

### Patch Export System
Patches should be exportable as standalone applications on all Godot-supported platforms:

**How it works:**
1. The GONODES editor saves the network as a `.tres` resource (MVP) or `.GNNode` JSON (future).
2. A "Export Patch" command generates a minimal Godot project:
   - `project.godot` configured for the selected renderer
   - The patch resource
   - A thin `main.tscn` that loads the patch into a `GNCookEngine` + output `SubViewport`
   - Only the needed operator scripts/shaders (tree-shaken)
3. Godot's standard export system packages it for the target platform.

**Supported export targets:**
- Windows, macOS, Linux (desktop)
- Android, iOS (mobile — requires Mobile or Compatibility renderer)
- Web/HTML5 (requires Compatibility renderer)
- Headless/server (for installations, compute-only patches)

**Patch runtime:**
- The exported app is a self-contained Godot application.
- It runs the cook engine at target FPS, rendering to the screen or a texture.
- Input can come from: command-line args, config file, OSC, MIDI (if those operators are included).
- Output can go to: screen, Syphon/Spout, NDI, file recording.

---

## 15. Design Principles

1. **Data flows left to right** — Inputs on left, outputs on right, consistent with TD.
2. **Type safety at wire level** — Only compatible ports connect. Errors are prevented, not reported.
3. **Lazy evaluation** — Nothing cooks unless it needs to. Dirty flags propagate downstream.
4. **Separation of model and view** — GNNetwork is the pure data model (Resource). GNNode is a Node in the scene tree but doesn't do UI — the cook engine drives it. UI reads/writes the model but doesn't own it.
5. **Operators are self-describing** — Each operator declares its ports, parameters, and family. The UI renders them generically. Adding a new operator = one new script file.
6. **Robust error handling** — Cook errors don't crash the app. Failed nodes output null/default data and show error state in UI.
7. **Performance visibility** — Cook times are always measurable. Users can see which nodes are expensive.
8. **Godot-native, not Godot-shy** — This framework is permanently married to Godot. We do NOT abstract away from Godot or build engine-agnostic layers. Use Godot's built-in systems aggressively:
   - `SubViewport` for TOP rendering (not a custom framebuffer abstraction)
   - `GraphEdit` / `GraphNode` for the node editor UI
   - `Resource` serialization for patch save/load
   - `ShaderMaterial` / `.gdshader` for GPU processing
   - `RenderingDevice` + compute shaders for POP/CHOP GPU work
   - `AudioServer` / `AudioStreamPlayer` for audio CHOPs
   - `UndoRedo` for undo/redo
   - `EditorPlugin` APIs when running as a plugin
   - `Expression` class for parameter expressions
   - `Tween` / `AnimationPlayer` where useful for timeline
   - `MultiMeshInstance3D` for point cloud / particle rendering
   - `GPUParticles3D` as a possible backend for simple particle POPs
   - `ProjectSettings` for renderer switching
   - Godot's export pipeline for patch export
   - `HTTPRequest`, `TCPServer`, `UDPServer` for networking operators
   - `MIDIMessage` / `InputEventMIDI` for MIDI input
   - Signals for event-driven communication between components
   - `ConfigFile` / `JSON` for settings and future .GNNode format
   - `ResourceLoader` / `ResourceSaver` for async resource management
   - `Thread` / `Mutex` / `Semaphore` for future multi-threaded cook engine
   
   If Godot has a built-in for something, use it. Don't reinvent. This maximizes compatibility with Godot updates, reduces code surface, and ensures patches export cleanly to all Godot platforms.

---

## 16. Naming Conventions

| Element                | Convention                    | Example               |
|------------------------|-------------------------------|-----------------------|
| GDScript files         | `snake_case.gd`              | `gn_node.gd`          |
| Class names            | `PascalCase`                 | `GNNode`, `GNNetwork` |
| Variables              | `snake_case`                 | `cook_time_ms`         |
| Constants/Enums        | `UPPER_SNAKE_CASE`           | `GNFamily.TOP`        |
| Signals                | `snake_case` (past tense)    | `node_cooked`         |
| Shader files           | `snake_case.gdshader`        | `noise_simplex.gdshader` |
| Scene files            | `snake_case.tscn`            | `gn_graph_editor.tscn` |
| Operator scripts       | `type_family.gd`             | `noise_top.gd`        |
| Resource prefix        | `GN` (all core classes)      | `GNData`, `GNPort`    |

---

## 17. Parameter Referencing System (Cross-Node References)

One of TouchDesigner's most powerful features is referencing parameters and data from any node inside the parameters of another node. GONODES replicates this with a multi-mode system.

### 17.1 Parameter Modes

TouchDesigner has 4 parameter modes. GONODES implements all 4, but only **Constant** and **Expression** are in the MVP. **Bind** and **Export** are designed now for architecture compatibility and implemented post-MVP.

```
GNParameter.Mode:
├── CONSTANT     ← MVP   — Direct literal value. No evaluation overhead.
├── EXPRESSION   ← MVP   — String evaluated each cook frame. Flexible, some overhead.
├── BIND         ← Later — Direct link to another parameter. Zero-overhead relay, no string parsing.
└── EXPORT       ← Later — Driven externally by a CHOP Export operator. Parameter is passive (push model).
```

#### Mode 1: CONSTANT (MVP)
A typed literal value set by the user.
```
scale = 4.0       # Just a float
offset = (0.5, 0.3)  # Just a Vector2
```
No per-frame evaluation. Cheapest mode. Node is only dirty when user changes the value via the inspector.

#### Mode 2: EXPRESSION (MVP)
A string evaluated every cook frame (or when dependencies change). This is where cross-node referencing lives.
```
scale = chop("lfo1").value("out") * 10.0
offset.x = sin(time * 2.0)
```
Has per-frame evaluation cost (string parsing + execution). See Section 17.2 for full expression syntax.

#### Mode 3: BIND (Post-MVP)
A direct pointer/link from one parameter to another parameter on a different node. No string evaluation — the cook engine just copies the value.
```
[NoiseTOP.scale] --BIND--> [ControlPanel.master_scale]
```
**Implementation:**
```gdscript
# GNParameter in BIND mode:
var bind_source_node: String    # e.g., "ctrl_panel"
var bind_source_param: String   # e.g., "master_scale"
var bind_transform: Callable    # Optional: transform function (e.g., * 2.0, clamp)
```
**Why it matters:**
- 10x faster than expression — no string evaluation, just a direct value copy
- Clearer in the UI — shows as a visible line/link between parameters
- Useful for control panels: one slider drives many parameters
- TD's equivalent: the small arrows drawn between parameter fields

**Dependency tracking:**
- Bind creates an implicit edge in the dependency DAG (same as expression deps)
- Source param changes → mark bound param's node dirty

#### Mode 4: EXPORT (Post-MVP)
A CHOP node **pushes** its channel values into parameters of target nodes. The receiving parameter is passive. This is the inverse of Expression mode (pull → push).

**In TouchDesigner, this works via the Export CHOP or by enabling "export" on any CHOP.** The CHOP's channels are mapped to target parameters by name or explicit assignment.

```
LFO_CHOP "lfo1"
  channels: ["out"]
  export targets:
    "out" → noise1.par.scale
    "out" → noise2.par.scale
    "out" → level1.par.brightness
```

**Why it matters vs. expressions:**
- One CHOP drives 20 parameters with one export declaration, vs. writing 20 separate expressions
- More performant: the CHOP cooks once, values are pushed in bulk
- Cleaner patch: no expressions cluttering every parameter field
- Natural for VJing: "this LFO controls all the brightness sliders"

**Implementation:**
```gdscript
class_name GNExportMapping extends Resource

var source_node: String          # CHOP node ID
var source_channel: String       # Channel name (e.g., "out")
var target_node: String          # Target node ID
var target_param: String         # Target parameter name
var scale: float = 1.0           # Multiply before applying
var offset: float = 0.0          # Add after scaling
var clamp_min: float = -INF      # Optional clamp range
var clamp_max: float = INF

# Stored in GNNetwork.export_mappings: Array[GNExportMapping]
```

**Cook engine behavior:**
```
After cooking a CHOP node with exports:
  1. Read the CHOP's output channels
  2. For each export mapping targeting this CHOP:
     a. Get channel value
     b. Apply scale/offset/clamp
     c. Set target parameter value directly (bypassing mode check)
     d. Mark target node dirty
```

**UI:**
- In the inspector, a parameter in Export mode shows: `← lfo1:out` with a small CHOP icon
- The source CHOP shows export lines/indicators pointing to its targets
- Users can set up exports via: right-click CHOP → "Export to..." → pick target param

### 17.2 Expression Syntax (Detail)

Inside any parameter's expression field, users can write references:

```gdscript
# Reference another node's parameter value
op("noise1").par.scale          # Get the 'scale' parameter value of node 'noise1'
op("lfo1").par.frequency         # Get LFO's frequency param

# Reference CHOP channel values
chop("lfo1").value("out")        # Last sample of channel 'out' from CHOP 'lfo1'
chop("noise_chop1").value("tx")  # Last sample of channel 'tx'
chop("math1").value("out", 5)    # Sample at index 5

# Reference TOP properties
top("noise1").resolution.x       # Width of TOP output
top("noise1").resolution.y       # Height of TOP output

# Math with references
chop("lfo1").value("out") * 10.0 + op("ctrl").par.offset
sin(time * op("speed").par.rate)

# Ternary / conditional
1.0 if chop("toggle").value("out") > 0.5 else 0.0
```

### 17.3 Reference Proxies by Family

Each family has its own reference proxy with family-specific accessors. **MVP implements CHOP and TOP proxies. Others are designed here for future implementation.**

#### `op(name)` — Generic (all families)
```gdscript
op("any_node").par.<param_name>   # Resolved parameter value (any family)
op("any_node").family             # GNFamily enum
op("any_node").cook_time          # Last cook duration in ms
op("any_node").valid              # Whether node cooked successfully
```

#### `chop(name)` — CHOP Proxy (MVP)
```gdscript
chop("lfo1").value("out")         # Last sample of channel (float)
chop("lfo1").value("out", 5)      # Sample at index 5
chop("lfo1").channels             # Array of channel names: ["out"]
chop("lfo1").length               # Sample count per channel
chop("lfo1").sample_rate          # Sample rate (float)
chop("lfo1")["out"]               # Shorthand for .value("out") — TD syntax compatibility
```

#### `top(name)` — TOP Proxy (MVP)
```gdscript
top("noise1").resolution          # Vector2i (width, height)
top("noise1").resolution.x        # Width
top("noise1").resolution.y        # Height
top("noise1").aspect              # float (width / height)
```

#### `sop(name)` — SOP Proxy (Future)
```gdscript
sop("grid1").num_points           # Total point count
sop("grid1").num_prims            # Primitive count
sop("grid1").point(0).P           # Position of point 0 (Vector3) — CPU readback!
sop("grid1").point(0).N           # Normal of point 0
sop("grid1").bounds               # AABB bounding box
```
**Warning:** Accessing individual SOP point data in an expression requires GPU→CPU readback, which is expensive. Limit to occasional use (not per-frame for many points). Use CHOP bridges for bulk data instead.

#### `pop(name)` — POP Proxy (Future)
```gdscript
pop("particles1").num_points      # Point count
pop("particles1").num_prims       # Primitive count
pop("particles1").point(0).P      # Position (GPU readback — expensive)
pop("particles1").point(0).PartVel    # Velocity
pop("particles1").point(0).PartAge    # Age
pop("particles1").attr("custom_attr") # Custom attribute value at point 0
```

#### `dat(name)` — DAT Proxy (Future)
```gdscript
dat("table1").cell(1, "name")     # Cell value at row 1, column "name"
dat("table1").cell(2, 3)          # Cell value at row 2, column 3
dat("table1").num_rows            # Row count
dat("table1").num_cols            # Column count
dat("table1").row(0)              # Entire row as Array
dat("table1").col("name")         # Entire column as Array
dat("text1").text                 # Full text content of a Text DAT
```

#### `mat(name)` — MAT Proxy (Future)
```gdscript
mat("pbr1").par.base_color        # Material parameter (same as op().par.*)
mat("pbr1").par.roughness
```

### 17.4 Node Path Resolution (Hierarchical — Designed, Flat for MVP)

**MVP:** `op("name")` resolves by flat string lookup within the current network (`GNNetwork.nodes[name]`). Node names must be unique within a network.

**Future (when COMPs are added):**
Paths follow a filesystem-like hierarchy:

```gdscript
# Flat (current network) — always works
op("noise1")

# Relative paths (from the current node's network context)
op("../sibling")           # Node in the parent network
op("./child_comp/noise1")  # Node inside a child COMP
op("../../uncle/node1")    # Two levels up, into a sibling COMP

# Absolute paths (from the root network)
op("/root/comp1/noise1")   # Fully qualified path

# Self and parent references
me                         # The current node
me.parent()                # The COMP containing the current node
me.parent().par.scale      # Parameter of the parent COMP
```

**Implementation design (future):**
```gdscript
func resolve_node_path(from_node: GNNode, path: String) -> GNNode:
    if path.begins_with("/"):
        # Absolute path: walk from root network
        return _resolve_absolute(path)
    elif path.begins_with("..") or path.begins_with("./"):
        # Relative path: walk from current node's network
        return _resolve_relative(from_node, path)
    else:
        # Simple name: lookup in current network (MVP behavior)
        return from_node.network.nodes.get(path, null)
```

**For MVP**, path is always a simple string name. The resolver function is written to make the upgrade to hierarchical paths a non-breaking change — expressions using `op("name")` will continue to work identically.

### 17.5 Expression Evaluation Engine

```gdscript
class_name GNExpressionEngine

var network: GNNetwork
var expression_cache: Dictionary = {}  # "node_id:param_name" -> Expression
var dependency_map: Dictionary = {}    # "node_id:param_name" -> Array[String] (referenced node IDs)

func resolve_parameter(node: GNNode, param_name: String) -> Variant:
    var param: GNParameter = node.parameters[param_name]
    match param.mode:
        GNParameter.Mode.CONSTANT:
            return param.value
        GNParameter.Mode.EXPRESSION:
            return _evaluate_expression(node, param_name, param)
        GNParameter.Mode.BIND:
            return _resolve_bind(node, param)
        GNParameter.Mode.EXPORT:
            return param.value  # Export sets value directly, just read it
    return param.value

func _evaluate_expression(node: GNNode, param_name: String, param: GNParameter) -> Variant:
    var expr: Expression = _get_or_compile(node.id, param_name, param.expression)
    var result = expr.execute(_build_context(node), node)
    if expr.has_execute_failed():
        push_warning("Expression error on %s.%s: %s" % [node.id, param_name, expr.get_error_text()])
        return param.fallback_value  # Return last good value or default
    param.resolved_value = result    # Cache for UI tooltip display
    return result

func _resolve_bind(node: GNNode, param: GNParameter) -> Variant:
    var source_node: GNNode = network.nodes.get(param.bind_source_node, null)
    if not source_node:
        return param.fallback_value
    var source_param: GNParameter = source_node.parameters.get(param.bind_source_param, null)
    if not source_param:
        return param.fallback_value
    var value: Variant = resolve_parameter(source_node, param.bind_source_param)
    if param.bind_transform:
        value = param.bind_transform.call(value)
    return value

func _build_context(node: GNNode) -> Array:
    # Build the bindings array for Expression.execute()
    # Returns: [op_func, chop_func, top_func, me_ref, time, frame, dt, ...]
    pass

func get_expression_dependencies(node: GNNode, param_name: String) -> Array[String]:
    # Parse expression string to find op("..."), chop("..."), top("...") references
    # Returns list of node IDs this expression depends on
    # Used by cook engine for implicit dirty propagation
    pass

func invalidate_cache(node_id: String, param_name: String) -> void:
    # Called when expression text changes — removes compiled Expression from cache
    expression_cache.erase("%s:%s" % [node_id, param_name])
    dependency_map.erase("%s:%s" % [node_id, param_name])
```

### 17.6 Dependency Tracking & Dirty Propagation

Parameter references create **implicit dependency edges** in addition to wire-based connections:

```
Wire dependencies (explicit, via connections):
    LFO_CHOP ──wire──► NoiseTOP        (data flows through port)

Expression dependencies (implicit, via param references):
    LFO_CHOP ··expr··► CompositeTOP    (CompositeTOP.opacity expression reads chop("lfo1"))

Bind dependencies (implicit, direct):
    ControlPanel ··bind··► NoiseTOP    (NoiseTOP.scale BIND to ctrl.master_scale)

Export dependencies (implicit, push):
    LFO_CHOP ··export··► NoiseTOP     (LFO exports "out" → noise1.par.scale)
             ··export··► LevelTOP     (LFO exports "out" → level1.par.brightness)
```

**All dependency types** feed into the same DAG for topological sort and cycle detection. The cook engine treats them uniformly:
1. Collect all edges: wire connections + expression deps + bind deps + export deps
2. Topological sort the full graph
3. Detect cycles (reject if found)
4. Cook in order

**Dirty propagation:**
- Wire: upstream cooks → downstream marked dirty (standard)
- Expression: referenced node parameter changes → mark this node dirty
- Bind: source parameter changes → mark bound node dirty
- Export: CHOP cooks → push values to all export targets → mark them dirty

### 17.7 Circular Reference Protection
- All reference types (expression, bind, export) add edges to the dependency DAG
- If adding a reference would create a cycle, it is rejected immediately
- Expression mode: error shown inline in the expression text field
- Bind mode: bind cannot be created (UI shows "would create circular dependency")
- Export mode: export mapping rejected (CHOP shows warning)
- Self-references via `me.par.X` within the same parameter are always rejected

### 17.8 UI Integration

**Parameter field behavior by mode:**

| Mode       | Inspector Display                                    | Node Badge | Graph Visual               |
|------------|------------------------------------------------------|------------|-----------------------------|
| CONSTANT   | Standard input control (slider, spinner, color, etc.) | None       | None                        |
| EXPRESSION | Text field with syntax highlighting. Resolved value shown on hover. | `fx`       | None (expression is invisible in graph) |
| BIND       | Read-only display: `← ctrl.master_scale`. Click to select source. | `→`        | Dashed line from source param to target param |
| EXPORT     | Read-only display: `← lfo1:out`. Dimmed, locked.    | `◄`        | Dotted line from CHOP to target param |

**Mode switching:** Right-click any parameter → Set Mode → Constant / Expression / Bind / Export

**Autocomplete (planned for MVP):**
- When typing `op("` in an expression field, show dropdown of available node names
- After `op("noise1").par.`, show dropdown of parameter names for that node
- After `chop("lfo1").value("`, show dropdown of channel names
- Provides discoverability without memorizing node/param names

**Drag-and-drop parameter linking:**
- Drag a parameter label from one node's inspector to another node's parameter field
- Automatically creates a BIND connection
- Hold Ctrl while dragging to create an EXPRESSION with `op("source").par.param` pre-filled

---

## 18. POP (Point Operators) Family — Future Planning

TouchDesigner's POPs are a relatively new operator family (GPU-accelerated point/particle system). GONODES should plan for this from the architecture level, even though implementation is post-MVP.

### What TD's POPs Are

POPs (Point Operators) are a **GPU-native geometry processing system**. Key characteristics:
- All computation runs on the GPU (unlike legacy Particle SOP which was CPU-bound)
- Operates on **point clouds** — arrays of points with arbitrary attributes
- Supports particles (with physics sim), but also static/procedural geometry
- Uses a feedback loop architecture: Particle POP → downstream processing → Null POP → feedback back into Particle POP
- Can handle millions of points at real-time framerates
- Points carry typed attributes (position, velocity, age, lifespan, mass, drag, custom)
- Rendered via Render TOP (instancing, point sprites, or geometry)

### TD POP Operator Categories

| Category           | Examples                                   | Purpose                              |
|--------------------|--------------------------------------------|--------------------------------------|
| **Generators**     | Particle POP, Grid POP, Box POP, Sphere POP, Circle POP | Create point clouds/particles |
| **Modifiers**      | Noise POP, Transform POP, Point POP, Math POP, Force Radial POP | Modify attributes |
| **Attributes**     | Attribute POP, Attribute Combine POP, Attribute Convert POP | Create/edit/convert attributes |
| **Structure**      | Copy POP, Merge POP, Delete POP, Sort POP, Group POP | Structural operations |
| **Simulation**     | Particle POP (with feedback), Field POP, Limit POP | Physics simulation |
| **IO/Bridge**      | SOP to POP, CHOP to POP, DAT to POP, TOP to POP, File In/Out POP | Cross-family conversion |
| **GPU Code**       | GLSL POP, GLSL Advanced POP, GLSL Create POP | Custom GPU compute |
| **Rendering**      | Texture Map POP, Projection POP            | Apply textures to points |
| **Analysis**       | Analyze POP, Neighbor POP, Histogram POP   | Analyze point clouds |

### POP Data Model: GNPointData

```gdscript
class_name GNPointData extends GNData

# Core: all attribute data lives on GPU buffers
var point_count: int
var attributes: Dictionary = {}
# Each attribute: name -> { type: "float"|"vec2"|"vec3"|"vec4"|"int"|"uint",
#                           buffer: RID (GPU buffer) }

# Reserved particle attributes (created by ParticlePOP):
# "P"            : vec3  — position
# "PartVel"      : vec3  — velocity
# "PartAge"      : float — age in seconds
# "PartLifeSpan" : float — expected lifespan
# "PartForce"    : vec3  — accumulated forces
# "PartMass"     : float — mass
# "PartDrag"     : float — drag coefficient
# "PartId"       : uint  — unique particle ID
# "PartDeath"    : uint  — death flag (1 = remove next frame)

# Primitive types
enum PrimitiveType { POINTS, LINES, LINESTRIPS, TRIANGLES, QUADS }
var primitive_type: PrimitiveType = PrimitiveType.POINTS
var primitives: PackedInt32Array = []  # Vertex indices

func get_attribute(name: String) -> RID: ...
func set_attribute(name: String, type: String, data: PackedFloat32Array) -> void: ...
func read_back_positions() -> PackedVector3Array: ...  # GPU → CPU readback (expensive)
```

### Godot Implementation Strategy

Godot 4.x provides several GPU-side systems we can leverage:

1. **GPUParticles3D / GPUParticles2D** — Built-in particle system with process materials (ParticleProcessMaterial)
   - Good for basic particle effects
   - Limited: can't easily chain operations or do attribute manipulation

2. **Compute Shaders** (Forward+ and Mobile renderers only) — Full GPGPU via `RenderingDevice`
   - Create SSBO (Shader Storage Buffer Objects) for point attributes
   - Each POP operator = a compute shader dispatch
   - Chain operators by passing SSBOs between dispatches
   - **This is the right approach for GONODES POPs**

3. **MultiMeshInstance3D** — For rendering point clouds as instanced geometry
   - Each point → one instance with transform from position attribute
   - Efficient for up to millions of instances

**Architecture:**
```
ParticlePOP (generator)
  ↓ SSBO (positions, velocities, attributes)
NoisePOP (modifier) — compute shader reads/writes SSBO
  ↓ same SSBO, modified
ForcePOP (forces) — compute shader adds to PartForce attribute
  ↓
NullPOP (feedback endpoint)
  ↓ feeds back to ParticlePOP next frame
  ↓ also feeds to...
Render TOP — reads SSBO, renders via MultiMesh or custom shader
```

**Renderer constraints:**
- Compute shaders require Forward+ or Mobile renderer
- Compatibility renderer (OpenGL 3.3) has NO compute shaders
- For Compatibility: fall back to CPU-side particle sim using `PackedVector3Array` + `MultiMesh.set_instance_transform()` (much slower, limited particle count)
- Operator should declare: `supported_renderers = ["forward_plus", "mobile"]` and the cook engine handles the fallback

### Feedback Loop Architecture

TD's particle system uses a feedback loop for simulation. In GONODES:

```
frame N:  ParticlePOP reads previous frame's output from NullPOP
          → births new particles, removes dead ones
          → applies Time Integration (F → V → P)
          → outputs current frame's SSBO
          ↓
          downstream POPs modify attributes
          ↓
          NullPOP caches the final state
          ↓
frame N+1: ParticlePOP reads NullPOP again (feedback)
```

This is a **controlled cycle** in the DAG — the only allowed exception to the no-cycles rule. Implementation:
- `GNNetwork` allows one feedback edge per ParticlePOP, flagged as `is_feedback = true`
- The cook engine handles feedback connections specially: reads from previous frame's cache, not current frame
- This gives one frame of latency, which is standard for particle systems

### POP ↔ Other Family Bridges

| Bridge             | Direction     | What it does                                    |
|--------------------|---------------|-------------------------------------------------|
| SOP to POP         | SOP → POP     | Convert mesh points to POP points               |
| CHOP to POP        | CHOP → POP    | Map channel values to point attributes           |
| TOP to POP         | TOP → POP     | Sample texture to set point colors/positions     |
| DAT to POP         | DAT → POP     | Read point data from table                       |
| POP to SOP         | POP → SOP     | Convert POP points back to mesh (future)         |
| POP to TOP         | POP → TOP     | Render POP via Render TOP (output = texture)     |

### Phase Planning for POPs

**Phase A (foundation):** After SOP family is working
- Implement `GNPointData` with GPU buffer management
- Implement basic generators: Grid POP, Sphere POP
- Implement Transform POP (compute shader: modify P attribute)
- Implement Render TOP integration (MultiMesh from POP points)

**Phase B (particles):** 
- Implement Particle POP with feedback loop
- Time Integration (force → velocity → position)
- Birth/death system
- Force Radial POP, Noise POP
- Limit POP (bounding box, kill/bounce)

**Phase C (advanced):**
- GLSL POP (custom compute shader operator)
- Attribute system (create/combine/convert)
- Neighbor POP (spatial queries using GPU sort)
- Copy POP (point instancing)

---

## 19. Portability & Export Architecture

### Editor Platform Targets
The GONODES editor runs on **desktop only**:
- Windows (x86_64)
- macOS (x86_64 + Apple Silicon)
- Linux (x86_64)

No ARM/mobile editor — too complex a UI for small screens.

### Patch Export Targets
Exported patches (standalone runnables) can target **all Godot-supported platforms**:

| Platform       | Renderer Options               | Notes                                |
|----------------|--------------------------------|--------------------------------------|
| Windows        | Forward+, Mobile, Compat       | Primary desktop target               |
| macOS          | Forward+, Mobile, Compat       | Metal via MoltenVK                   |
| Linux          | Forward+, Mobile, Compat       | Vulkan or OpenGL                     |
| Android        | Mobile, Compat                 | No Forward+ (too heavy)              |
| iOS            | Mobile, Compat                 | Metal via MoltenVK                   |
| Web (HTML5)    | Compat only                    | WebGL2. No compute shaders.          |
| Headless       | N/A (no rendering)             | For data-processing-only patches     |

### Renderer-Aware Operators

Every operator declares which renderers it supports:

```gdscript
# In GNNode base class:
func get_supported_renderers() -> Array[String]:
    return ["forward_plus", "mobile", "gl_compatibility"]  # Default: all

# Override in specific operators:
# e.g., compute-shader-based POP:
func get_supported_renderers() -> Array[String]:
    return ["forward_plus", "mobile"]  # No compute on Compatibility
```

The cook engine checks compatibility at cook time:
- If an operator is incompatible with current renderer → skip cook, output null data, show warning badge
- The export system validates that all operators in a patch support the chosen export renderer
- A "Renderer Compatibility" panel shows which operators work on which targets

### Export Workflow

```
1. User clicks "Export Patch..." in editor
2. Export dialog:
   - Select target platform (Windows/macOS/Linux/Android/iOS/Web)
   - Select renderer (auto-selected based on platform, overridable)
   - Configure: resolution, FPS target, input sources, output mode
   - Compatibility check: warns about unsupported operators
3. GONODES generates a minimal Godot project:
   - project.godot (configured for target renderer)
   - The patch resource (.tres or .GNNode)
   - A runtime main.tscn:
     - GNCookEngine (loads patch, runs cook loop)
     - Output viewport (fullscreen or configurable)
     - Optional: OSC/MIDI input listeners
     - Optional: Syphon/Spout/NDI output
   - Only the needed operator scripts and shaders (tree-shaking)
4. Godot's export pipeline packages it for the target platform
5. Result: a standalone executable / .apk / .ipa / HTML page
```

### Renderer Live-Switching in Editor

The editor allows switching renderers at runtime for preview purposes:
- Toolbar dropdown: `[Forward+ ▼]` → `Mobile` → `Compatibility`
- Triggers `ProjectSettings` change + viewport recreation
- All SubViewports (TOP outputs) are recreated with new renderer
- Operators re-cook
- Incompatible operators show error state immediately
- This lets artists preview exactly how their patch will look on mobile/web before exporting

**Technical note:** Godot 4.x requires a restart for full renderer change. For live preview, we may use a secondary viewport with the alternate renderer, or simply restart the embedded preview. Investigate during implementation.

---

## 21. Data Ownership & Passing Model

### How TouchDesigner Does It
- **TOPs:** Textures live on the GPU. Downstream nodes receive a **handle/reference** to the GPU texture, not a pixel copy. The producer node owns its framebuffer; consumers sample it read-only via shader uniforms. Zero-copy.
- **CHOPs:** Channel arrays are passed by reference. The cook engine manages lifecycle. Consumers read the producing node's output; only the producing node writes.
- **SOPs/POPs:** Geometry/point data is passed by reference. Copy-on-write only when a node modifies geometry (e.g., Transform SOP creates its own output, doesn't mutate input).
- **Core rule: producer owns the data, consumers borrow it read-only.**

### GONODES Data Passing Rules

```
Ownership Rule:
  1. Each node OWNS its cached_output (the GNData it produced last cook).
  2. The cook engine passes cached_output REFERENCES to downstream _cook(inputs) calls.
  3. Downstream nodes MUST NEVER mutate input data — always create new output data.
  4. GNTextureData: the ViewportTexture is a live GPU reference (zero-copy on GPU).
  5. GNChannelData: PackedFloat32Array is copy-on-write in GDScript — safe as long as
     downstream doesn't mutate it. The contract forbids mutation.
```

### Per-Family Behavior

| Family | Data Type         | GPU/CPU | Passing Strategy                                     |
|--------|-------------------|---------|------------------------------------------------------|
| TOP    | GNTextureData     | GPU     | ViewportTexture reference. Zero-copy. Texture stays on GPU. Downstream samples via shader uniform. |
| CHOP   | GNChannelData     | CPU     | Reference to channels Dictionary. Read-only. PackedFloat32Array is CoW-safe. |
| SOP    | (future)          | CPU/GPU | Reference to mesh/point data. Transform ops create new output. |
| POP    | (future)          | GPU     | GPU buffer handle. Zero-copy. Downstream compute shaders bind the buffer. |
| DAT    | (future)          | CPU     | Reference to table/text data. Read-only. |

### GNTextureData Reuse

Previously, each TOP cook created a new `GNTextureData` every frame. This caused unnecessary GC pressure.

**New rule:** Each TOP creates its `GNTextureData` once (during `_ensure_viewport()`) and reuses it across cooks. Only metadata (resolution, timestamp) is updated. The `ViewportTexture` reference is stable — it auto-updates when the SubViewport re-renders.

```gdscript
# In each TOP's _cook():
# BAD (old):
var data := GNTextureData.new()  # Allocates every frame
data.texture = _viewport.get_texture()
return data

# GOOD (new):
_cached_tex_data.resolution = res
return _cached_tex_data  # Same object, reused
```

### Thread Safety (Future)

When the cook engine moves to threaded cooking:
- GNData becomes **immutable after cook** — the producing node creates a new GNData for each cook, and the old one can be read by consumers on other threads.
- Or: **double-buffering** — each node has two GNData slots (front/back), consumers read front while producer writes back.
- For MVP (single-threaded `_process`), reference passing with read-only contract is sufficient.

---

## 22. Node-Based Architecture (GNNode extends Node)

GNNode extends Godot's `Node` class instead of `Resource`. This gives operators direct scene tree participation, allowing TOPs to own SubViewports as children and WindowTOPs to create OS windows naturally.

### Why Not Resource?
- **No scene tree lifecycle** — Resources have no `_ready()`, `_process()`, `_exit_tree()`. This forced workarounds: a centralized ViewportManager for TOPs, `Engine.get_frames_per_second()` hacks for delta time, manual `cleanup()` methods for SubViewport teardown.
- **Accidental copy risk** — `Resource.duplicate()` creates broken shallow copies of viewport/material references. Resource's serialization machinery was never used (patches serialize via GNNetwork, not individual nodes).
- **Per-frame allocation overhead** — GNData as Resource had unnecessary serialization infrastructure for transient compute results.

### The Tiered Design

| Class | Extends | Why |
|---|---|---|
| **GNNode** | **Node** | Scene tree access, TOPs own SubViewports, auto-cleanup via queue_free() |
| **GNData/GNTextureData/GNChannelData** | **RefCounted** | Transient compute results — lightest possible allocation |
| **GNPort** | **RefCounted** | Lightweight struct, no serialization needed |
| **GNConnection** | **RefCounted** | Lightweight struct, network serializes connection info |
| **GNParameter** | **Resource** | Benefits from @export for inspector + value persistence |
| **GNNetwork** | **Resource** | The serialization boundary — saves/loads patch files as .tres |

### Scene Tree Structure

```
MainScene (Node)
  ├── Viewer (TextureRect)
  ├── InfoLabel (Label)
  └── CookEngine (GNCookEngine extends Node)
        ├── lfo1 (LFO_CHOP extends GNNode extends Node)
        ├── noise1 (NoiseTOP extends GNNode extends Node)
        │   └── VP_noise1 (SubViewport)       ← owned by TOP, auto-freed
        │       └── Canvas (ColorRect + ShaderMaterial)
        ├── level1 (LevelTOP extends GNNode extends Node)
        │   └── VP_level1 (SubViewport)       ← owned by TOP, auto-freed
        │       └── Canvas (TextureRect + ShaderMaterial)
        └── win1 (WindowTOP extends GNNode extends Node)
            └── GNOutput_win1 (Window)        ← separate OS window, auto-freed
                └── Display (TextureRect)
```

### Timing Injection

Since `process_mode = DISABLED` on GNNodes, they can't self-tick. The cook engine injects timing each frame:

```gdscript
# In GNCookEngine.cook_frame():
for node in topo_order:
    node.current_delta = current_delta    # Frame delta (seconds)
    node.elapsed_time = elapsed_time      # Total time since start
    node.current_frame = frame_count      # Frame counter
```

Operators use `self.current_delta` instead of the old `Engine.get_frames_per_second()` hack.

### Node Adoption

The cook engine parents all network nodes as children in `_ready()`:

```gdscript
func _adopt_network_nodes() -> void:
    for node_id in network.nodes:
        var node: GNNode = network.nodes[node_id]
        if node.get_parent() == null:
            add_child(node)
```

When `network.remove_node()` is called, it removes the node from the tree and calls `queue_free()`, cascading cleanup to all child SubViewports and Windows.

---

## 23. Multi-Window & Multi-Display Output

GONODES supports multiple output windows, each displayable on any connected monitor. This is essential for VJing (editor on laptop screen, output on projector).

### Godot's Multi-Window Support

Godot 4.x provides:
- `Window` node — creates an OS-level window, can be moved/resized/fullscreened
- `DisplayServer.get_screen_count()` — enumerate connected monitors
- `DisplayServer.get_screen_position(idx)` / `get_screen_size(idx)` — monitor geometry
- `DisplayServer.window_set_mode()` — fullscreen, borderless, windowed
- Each `Window` can host its own `SubViewportContainer` to display content

### WindowTOP Operator

A new TOP operator that takes a texture input and displays it in a standalone OS window.

```
WindowTOP
├── Inputs: 1 (TOP texture)
├── Outputs: 0 (display-only, terminal node)
├── Parameters:
│   ├── title: String ("GONODES Output")
│   ├── monitor: int (0 = primary, 1 = secondary, ...)
│   ├── window_mode: enum (Windowed, Fullscreen, Borderless)
│   ├── resolution: Vector2i (1920×1080)
│   ├── position: Vector2i (auto = centered on target monitor)
│   ├── always_on_top: bool (false)
│   └── vsync: bool (true)
└── Implementation:
    ├── Creates a Godot Window node
    ├── Inside: SubViewportContainer + SubViewport + TextureRect
    ├── TextureRect.texture = input TOP's ViewportTexture
    ├── Window positioned on target monitor
    └── Updates every frame (the TextureRect auto-updates from ViewportTexture)
```

### Multi-Window Architecture

```
Scene Tree:
  Root (Window — main editor)
  ├── MainEditor (editor UI, graph, inspector)
  └── CookEngine (GNCookEngine)
        ├── noise1 (NoiseTOP)
        │   └── VP_noise1 (SubViewport)
        │       └── Canvas (ColorRect)
        ├── level1 (LevelTOP)
        │   └── VP_level1 (SubViewport)
        │       └── Canvas (TextureRect)
        ├── win1 (WindowTOP — second monitor, fullscreen)
        │   └── GNOutput_win1 (Window — OS window)
        │       └── Display (TextureRect → level1's ViewportTexture)
        └── win2 (WindowTOP — projector, borderless)
            └── GNOutput_win2 (Window — OS window)
                └── Display (TextureRect → noise1's ViewportTexture)
```

### Monitor Enumeration at Runtime

```gdscript
# Available to WindowTOP and the editor's display picker:
# Note: Godot 4.x uses screen_get_position/screen_get_size (not get_screen_*).
for i in range(DisplayServer.get_screen_count()):
    var pos := DisplayServer.screen_get_position(i)
    var size := DisplayServer.screen_get_size(i)
    print("Display %d: %s at %s" % [i, size, pos])
```

### Texture Routing

WindowTOP does NOT copy the texture. It assigns the upstream TOP's `ViewportTexture` directly to its internal TextureRect — a live GPU reference. The Window's render tree samples the same GPU texture as the graph viewer. **Zero-copy output.**

**Important — TextureRect layout in programmatic Windows:**
When creating a TextureRect inside a Window node via code, do NOT use the `anchors_preset` property setter — it only sets anchors but leaves offsets at 0, resulting in a 0×0 rect. Always call `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` AFTER adding the control to the tree.

**Important — ViewportTexture cross-viewport usage:**
When assigning a ViewportTexture programmatically (not via the editor), it works across Viewport boundaries because it references the source SubViewport by RID, not by scene-relative path. Direct assignment (`texture_rect.texture = viewport.get_texture()`) works correctly even when the TextureRect lives inside a secondary Window.

### VJ Workflow

1. Build patch in the editor (monitor 1)
2. Add a WindowTOP node, set `monitor = 1` (projector), `window_mode = Borderless`
3. Wire the final TOP chain into the WindowTOP
4. The projector shows the live output, borderless, fullscreen
5. Multiple WindowTOPs can show different parts of the patch on different displays
6. Parameters (monitor, fullscreen, resolution) can be driven by CHOPs for live switching

---

## 24. Logging System (GNLogger)

GNLogger is a static utility class (`extends RefCounted`, `class_name GNLogger`) providing centralized, toggleable logging across the framework.

### Design

- **Static API** — call from anywhere without instantiation: `GNLogger.info("Category", "message")`
- **Master toggle** — `GNLogger.enabled` (off by default, no output when disabled)
- **Level filtering** — `GNLogger.level` with `DEBUG`, `INFO`, `WARN`, `ERROR`, `NONE`
- **Category muting** — `GNLogger.muted_categories["CookEngine"] = true` to silence a subsystem
- **Routing** — `WARN` → `push_warning()`, `ERROR` → `push_error()`, others → `print()`
- **Per-line metadata** — frame number, optional timestamps

### Usage

```gdscript
GNLogger.enabled = true
GNLogger.level = GNLogger.Level.DEBUG  # See everything

GNLogger.info("CookEngine", "Frame cooked in %.2fms" % t)
GNLogger.debug("NoiseTOP", "Viewport created: %s" % vp.name)
GNLogger.warn("Network", "Cycle detected")
GNLogger.error("Parameter", "Expression compile failed")
```

### Coverage

| Subsystem | Logged Events |
|---|---|
| GNCookEngine | Engine ready, node adoption, per-frame summary (DEBUG), per-node cook timing (DEBUG), expression/bind errors, proxy lookup failures, invalidate/reset |
| GNNetwork | Node add/remove, connect/disconnect, cycle detection, topo sort recomputation |
| GNNode | Initialize (ports/params), null cook output |
| TOP operators | Viewport creation, missing input warnings |
| WindowTOP | Window creation, window hidden by user |
| CHOP operators | Missing input warnings |
| GNParameter | Expression compile success/failure |

### UI Toggle

The test scene includes a `CheckButton` (top-right corner, "Debug Log") that toggles `GNLogger.enabled` at runtime.

---

## 20. Open Questions (To Resolve During Implementation)

1. **GraphEdit vs custom canvas:** Godot's `GraphEdit` has limitations (styling, custom port shapes, minimap). May need custom drawing. Evaluate during Phase 3.
2. **Expression sandboxing:** GDScript `Expression` class is limited. May need a custom expression parser for the `op()/chop()` syntax. Evaluate during Phase 4.
3. **Viewport performance ceiling:** How many SubViewports can run simultaneously before frame drops? Profile during Phase 6.
4. **Thread safety:** When moving cook engine to threads (future), GNData needs immutable snapshots or double-buffering. Design for this but don't implement in MVP.
5. **LibGodot API surface:** What exactly does the LibGodot C API expose? Need to research when targeting host embedding post-MVP.
6. **Renderer live-switching:** Does Godot 4.6 support hot-swapping renderers without restart? If not, what's the best workaround for editor preview?
7. **Compute shader availability:** Verify that `RenderingDevice` compute dispatches work in Mobile renderer on all targets (some mobile GPUs have limitations).
8. **POP feedback loops:** Validate that the one-frame-latency feedback model works smoothly with Godot's `SubViewport` / buffer management.
9. **Export tree-shaking:** Can we reliably detect which operator scripts/shaders a patch uses and exclude unused ones from the export?

---

*This file should be read by the LLM at the start of each session to maintain continuity.*

---

## 21. Phase 3 Architecture: Node Graph UI

### Overview

The editor UI is built on Godot's `GraphEdit` and `GraphNode` controls with bidirectional sync to the `GNNetwork` model. Flow is left-to-right (Godot `GraphEdit` is hardcoded horizontal — vertical layout would require replacing the entire widget).

### Files

| File | Class | Purpose |
|------|-------|---------|
| `addons/gonodes/ui/gn_node_view.gd` | `GNNodeView` | GraphNode wrapper per operator. Family-colored title bar (StyleBoxFlat), typed port slots via `set_slot()`, position sync via `position_offset_changed` |
| `addons/gonodes/ui/gn_graph_editor.gd` | `GNGraphEditor` | GraphEdit canvas. Handles connection/disconnection/deletion, bidirectional sync with GNNetwork via signals, hosts palette. Signals: `operator_selected(node_id)`, `operator_deselected()` |
| `addons/gonodes/ui/gn_node_palette.gd` | `GNNodePalette` | PopupPanel with search LineEdit + Tree grouped by family. Tab/right-click to open. Spawns operators via `_create_operator_instance()` |
| `scenes/gn_editor.tscn` | — | HSplitContainer layout: GraphPanel (left) + RightPanel (VSplit: Viewer + Inspector) + InfoBar (bottom) |
| `scenes/gn_editor.gd` | — | Wires graph_editor + inspector + cook_engine. Demo network: lfo1→noise1→level1→win1 |

### Operator Registry

Currently hardcoded in `GNGraphEditor.get_operator_registry()` as a static Dictionary:

```gdscript
{ "noise_top": NoiseTOP, "composite_top": CompositeTOP, ... }
```

New operators must be manually added to this dictionary.

### Signal Flow

```
User drags wire → GraphEdit.connection_request
  → GNGraphEditor._on_connection_request()
    → GNNetwork.connect_nodes()
      → GNNetwork.connection_added signal
        → GNGraphEditor._on_network_connection_added()
          → GraphEdit.connect_node() (visually)
```

Same pattern for disconnection, node add/remove.

---

## 22. Phase 4 Architecture: Parameters & Inspector

### Overview

The parameter inspector is a right-side panel that shows all parameters for the selected node, with type-specific UI controls, live expression editing, and mode toggling.

### Files

| File | Class | Purpose |
|------|-------|---------|
| `addons/gonodes/ui/gn_param_row.gd` | `GNParamRow` | Per-parameter widget. Type-specific controls (FLOAT: HSlider+SpinBox, INT: SpinBox, BOOL: CheckBox, ENUM: OptionButton, COLOR: ColorPickerButton, VECTOR2/2I: dual SpinBox, STRING: LineEdit). Mode toggle button (C=green, E=orange). Expression LineEdit with focus guard |
| `addons/gonodes/ui/gn_param_inspector.gd` | `GNParamInspector` | PanelContainer with family color bar, header (node ID, type, cook time), scrollable GNParamRow list, placeholder label when nothing selected |

### Key Design Decisions

1. **Per-cook updates are lightweight:** Inspector connects to `node_cooked` signal. Per-cook path only calls `update_expression_status()` (error label colors), NEVER `_update_mode_display()` (which sets text).
2. **Focus guard:** `_expr_edit.has_focus()` is checked before setting text in any update path to prevent clobbering user edits.
3. **Expression commit on focus-out:** `focus_exited` signal on expression LineEdit triggers `_apply_expression_text()`.
4. **Mode toggle:** Single button cycles C→E (E→C). Button text and color update immediately.

### Editor Layout

```
HSplitContainer
├── GraphPanel (split_offset ratio ~2:1)
│   └── GNGraphEditor (GraphEdit)
└── RightPanel (VSplitContainer)
    ├── ViewerPanel (TextureRect, split ~1.5)
    │   └── _viewer_rect (shows selected TOP output)
    └── InspectorPanel (split ~1.0)
        └── GNParamInspector
InfoBar (bottom)
└── FPS label (yellow)
```

---

## 25. Hard Rules & Lessons Learned

These are non-negotiable constraints discovered during development. **Never violate these.**

### 25.1 No CPU Roundtrips for Real-Time Texture Data

**NEVER** call `Texture2D.get_image()` or `Image.get_data()` in a per-frame path. This triggers a GPU→CPU readback that stalls the rendering pipeline and can cost 5-15ms per call.

- Use `ViewportTexture` (live GPU reference) for texture routing between nodes
- Use `ImageTexture` snapshots ONLY for one-time captures (thumbnails, file export)
- All real-time texture passing stays on the GPU via SubViewport → ViewportTexture → TextureRect chain
- If you need CPU-side pixel data (e.g., for a DAT or CHOP reading color values), do it async via `RenderingServer` and accept one-frame latency

### 25.2 Godot Expression base_instance Architecture

- Functions called inside an `Expression` are **method lookups on `base_instance`**, not calls to input variables
- Passing Callables as input variables and calling them will **silently fail** (returns null, no error)
- Always make expression-callable functions **real methods** on the base_instance object

### 25.3 GNFamily.get_name → get_family_name

- Static methods on classes extending `Object` must not shadow built-in methods
- `Object.get_name()` takes 0 args; a custom `get_name(family)` with 1 arg causes a signature collision at runtime
- Use unique names: `get_family_name()`, not `get_name()`

### 25.4 WindowTOP Cook-Dirty vs Param-Dirty

- `dirty` on a sink node (WindowTOP) is `true` every frame when upstream contains time_dependent nodes
- Using `if dirty:` to apply window config causes per-frame reconfiguration → 15fps
- Use a dedicated `_window_params_dirty` flag, set only by overriding `_on_parameter_changed()`
- Cook-dirty (upstream data changed) ≠ parameter-dirty (this node's params changed)
- Any future config-heavy sink nodes should use the same pattern

### 25.5 Anchors Preset vs set_anchors_and_offsets_preset

- `Control.anchors_preset = PRESET_FULL_RECT` only sets anchors, NOT offsets → 0×0 size
- Always use `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` for full-rect layout
- Must be called AFTER the control is added to the tree

### 25.6 embed_subwindows

- `project.godot` must have `window/subwindows/embed_subwindows=false` for WindowTOP to create real OS-level windows
- Without this, Window nodes render as embedded panels inside the main window

### 25.7 DisplayServer API (Godot 4.x)

- Use `DisplayServer.screen_get_size()` / `screen_get_position()` (not `get_screen_size/position`)
- Use `DisplayServer.window_set_vsync_mode(mode, window_id)` for per-window vsync

### 25.8 GraphEdit / GraphNode Signal Naming

- `GraphEdit` has built-in signals named `node_selected` and `selection_cleared`
- Custom signals on subclasses must use different names to avoid shadowing
- Use `operator_selected` / `operator_deselected` instead

### 25.9 Inspector Per-Cook Updates

- Inspector is called every cook frame via `node_cooked` signal
- NEVER call `_update_mode_display()` (which sets `_expr_edit.text`) per-cook — clobbers edits 60x/sec
- Use lightweight `update_expression_status()` per-cook (only updates error label colors)
- Check `_expr_edit.has_focus()` before setting text in any update path

---

## 26. Known Bugs

### 26.1 WindowTOP: ESC to Exit Fullscreen Not Working

- **Issue:** When the output window is in Fullscreen or Borderless mode with Always On Top enabled, the user cannot escape back to windowed mode
- **Root cause:** Input events in a child `Window` node stay in that window's viewport tree. `Input.is_action_just_pressed()` polled from the parent node's `_process()` never sees them. Attempts with `gui_input` on a focusable `TextureRect` inside the window also failed to trigger
- **Workaround:** Change Window Mode back to Windowed from the inspector (requires access to the main editor window)
- **Planned fix:** Investigate `Window._unhandled_input()` override, or a dedicated `SubViewport` overlay with `_input()` handler inside the output window
- **Priority:** Low — does not affect core functionality, only UX convenience

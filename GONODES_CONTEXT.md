# GONODES — LLM Context File

> **Last updated:** 2026-02-26
> **Status:** Phase 6 Complete — Phase 7 planned. Save/load, copy/paste, undo/redo, live node previews with per-node toggle, family base classes, right-click context menu, performance profiling overlay, stress test (59 nodes). GNExtensionRegistry dynamic operator architecture. 3D scene pipeline (SOP→MAT→COMP→RenderTOP) live with per-object materials, shadow system, and MergeCOMP scene composition. WindowTOP open/close toggle. Phases 1–6 complete. 82 operators across 6 families (28 TOP, 21 CHOP, 12 DAT, 14 SOP, 4 COMP, 2 MAT, 1 output).

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
│  │  GNExtensionRegistry                        │ │
│  │  Core operators + gn_ext_* addon operators  │ │
│  │  Dynamic factory, descriptions, manifests   │ │
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
| TOP (Texture OP)      | `GNTopBase` — SubViewport + ShaderMaterial (infra in base class) |
| CHOP (Channel OP)     | `GNChopNode` — processes named float arrays              |
| SOP (Surface OP)      | `GNSopNode` — produces ArrayMesh via GNGeoData           |
| POP (Point OP)        | `GNPopNode` — GPU particle/point cloud system (future)   |
| DAT (Data OP)         | `GNDatNode` — tables/text via GNTableData                |
| MAT (Material OP)     | `GNMatNode` — PBR or custom ShaderMaterial               |
| COMP (Component OP)   | `GNCompNode` — 3D scene components (Camera, Light, Geo)  |
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

### GNTableData (DAT output)
```
GNTableData extends GNData (RefCounted)
├── is_table: bool           # true = 2D table mode, false = plain text mode
├── headers: PackedStringArray
├── rows: Array[PackedStringArray]
├── text: String             # Plain text content (text mode only)
├── cell(row, col) -> String
├── cell_by_name(row, col_name) -> String
├── cell_as_float(row, col) -> float
├── set_headers(headers: PackedStringArray)
├── append_row(row: PackedStringArray)
├── set_text(text: String)
├── to_tsv() -> String       # Export as tab-separated values
└── from_tsv(tsv: String)    # Import from tab-separated values
```

### GNGeoData (SOP output)
```
GNGeoData extends GNData (RefCounted)
├── mesh: ArrayMesh          # Godot native mesh — the actual geometry
├── transform: Transform3D   # Object-space transform
├── bounds: AABB             # Bounding box
├── vertex_count: int
├── point_attribs: Dictionary # Custom per-point attributes
├── set_surface_arrays(arrays: Array, primitive: Mesh.PrimitiveType)
├── set_from_surface_tool(st: SurfaceTool)
├── set_mesh(primitive_mesh: PrimitiveMesh)  # Copy from Godot PrimitiveMesh
├── get_positions() -> PackedVector3Array
├── get_normals() -> PackedVector3Array
├── get_uvs() -> PackedVector2Array
└── has_geometry() -> bool
```

GNGeoData wraps Godot's native `ArrayMesh`, leveraging Godot's built-in mesh types (`BoxMesh`, `SphereMesh`, `CylinderMesh`, `TorusMesh`) via `set_mesh()` and Godot's `SurfaceTool` for procedural generation.

### GNMaterialData (MAT output)
```
GNMaterialData extends GNData (RefCounted)
├── material: Material       # Godot Material base class (StandardMaterial3D, ShaderMaterial, etc.)
├── material_label: String   # Human-readable label for UI preview (e.g., "PBR", "Shader: custom_toon")
├── get_family() -> MAT
├── invalidate()             # Clears material and label
└── duplicate_data() -> GNData  # Deep-copies Material resource
```

GNMaterialData wraps Godot's `Material` base class, allowing any material type (StandardMaterial3D, ShaderMaterial, ORMMaterial3D) to flow through the graph. MAT operators produce GNMaterialData, which GeometryCOMP consumes as an optional material override.

---

## 6. Operator Base Class

### GNNode (Root Base)

GNNode is **fully type-agnostic** — it contains no references to any family-specific data types. Preview methods are virtual no-ops that return null; family base classes (see below) override them.

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

# Preview (virtual — overridden by family base classes)
func create_preview_control() -> Control:  return null   # No-op
func update_preview_control(ctrl: Control) -> void: pass  # No-op
```

# Preview (virtual — overridden by family base classes)
func create_preview_control() -> Control:  return null   # No-op
func update_preview_control(ctrl: Control) -> void: pass  # No-op
```

### Family Base Classes

Five intermediate base classes sit between GNNode and the individual operators. Each sets the `family`, provides family-specific helpers, and overrides the preview virtual methods.

| Base Class | Family | Cached Data | Preview | Helpers |
|------------|--------|-------------|---------|--------|
| `GNTopBase` | TOP | `_viewport`, `_material`, `_canvas`, `_cached_tex_data` | TextureRect from `cached_output.texture` | `_get_input_top()`, `_create_viewport()`, `_ensure_viewport()`, `_init_shader_viewport()`, `execute_cook()` |
| `GNChopBase` | CHOP | `_cached_channel_data: GNChannelData` | Label: channel name:value pairs | `_prepare_output(sr)`, `_get_input_chop()` |
| `GNDatBase` | DAT | `_cached_table: GNTableData` | Label: headers + first 3 rows | `_prepare_table(clear)`, `_get_input_dat()` |
| `GNSopBase` | SOP | `_cached_geo: GNGeoData` | Label: vertex/surface counts | `_prepare_geo()`, `_get_input_sop()`, `_require_input_geo()` |
| `GNCompBase` | COMP | `_scene_node: Node3D` | Label: node class + visibility | auto `_notification(PREDELETE)` cleanup, `get_scene_node()` |
| `GNMatBase` | MAT | `_cached_mat_data: GNMaterialData` | Label: material type/label | `_prepare_output()` |

**Class Hierarchy:**
```
GNNode (type-agnostic base)
├── GNTopBase (28 TOP operators)
├── GNChopBase (21 CHOP operators, incl. DATtoCHOP bridge)
├── GNDatBase (12 DAT operators)
├── GNSopBase (14 SOP operators)
├── GNCompBase (4 COMP operators)
└── GNMatBase (2 MAT operators)
```

**GNTopBase** provides the shared viewport/texture infrastructure used by all TOP operators:
- **`_viewport: SubViewport`** — primary render viewport (null until first cook).
- **`_material: ShaderMaterial`** — shader material applied to the canvas (null for non-shader TOPs like Text, Movie).
- **`_canvas: Control`** — a `ColorRect` (generators) or `TextureRect` (filters) that fills the viewport.
- **`_cached_tex_data: GNTextureData`** — reusable output data wrapping the viewport texture.
- **`_create_viewport()`** — factory that creates a SubViewport with `UPDATE_DISABLED` and sensible defaults.
- **`_ensure_viewport(size)`** — lazily creates `_viewport` + `_cached_tex_data`. Used by custom TOPs (Constant, Text, Blur, etc.).
- **`_init_shader_viewport(shader_path, transparent_bg, use_texture_rect, size)`** — full pipeline setup: SubViewport → ShaderMaterial → canvas → GNTextureData. Used by the 17 standard shader TOPs.
- **`execute_cook()`** — overrides GNNode to trigger `UPDATE_ONCE` on all child SubViewports after `_cook()` completes, eliminating wasted GPU work on non-dirty frames.

Generator TOPs pass `get_param_value("resolution")` as the viewport size. Filter TOPs pass `tex_in.resolution` (matching their input). No hardcoded sizes.

**DATtoCHOP** extends `GNChopBase` (not GNDatBase) because its output is CHOP channel data.

### Node Lifecycle
- `_init()` — set `node_type`, `family`, `time_dependent` (runs before entering tree)
- `initialize(id)` — sets `name = id`, `process_mode = DISABLED`, calls `_init_ports()` / `_init_parameters()`
- Processing is disabled on GNNodes — only the cook engine drives cooking
- TOPs add SubViewport as `add_child()` during first `_cook()` — auto-freed on removal
- `execute_cook()` (GNTopBase override) — after `_cook()` completes, sets `UPDATE_ONCE` on all child SubViewports so they render exactly once per cook cycle
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

signal node_added(node_id: String)
signal node_removed(node_id: String)
signal connection_added(connection: GNConnection)
signal connection_removed(connection: GNConnection)
signal node_renamed(old_id: String, new_id: String)
signal graph_changed()

func add_node(node: GNNode) -> bool
func remove_node(id: String) -> bool
func rename_node(old_id: String, new_id: String) -> bool
func connect_nodes(from_id: String, from_port: int,
                   to_id: String, to_port: int) -> bool
func disconnect_nodes(from_id: String, from_port: int,
                      to_id: String, to_port: int) -> void
func get_topological_order() -> Array[GNNode]
func get_upstream_nodes(id: String) -> Array[GNNode]
func get_downstream_nodes(id: String) -> Array[GNNode]
func has_cycle() -> bool
func generate_unique_id(base_type: String) -> String
func prune_stale_connections(node_id: String) -> void
```

**`rename_node()` updates:** nodes dictionary key, `GNNode.id`, `GNNode.name`, all `GNConnection.from_node`/`to_node` references, expression strings across all parameters in the network (simple `"old_id"` -> `"new_id"` replacement). Validates: alphanumeric/underscore only, no duplicates, no empty. Emits `node_renamed` then `graph_changed`.

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
│  HSplitContainer                                │
├─────────────────────────────┬────────────────────┤
│                             │  VSplitContainer   │
│  GraphPanel (stretch 2x)    ├────────────────────┤
│  └─ GraphEdit               │  ViewerPanel       │
│     + Node Palette popup    │  (stretch 1.5)     │
│                             │  └─ TextureRect    │
│     ┌───┐    ┌───┐          │    KEEP_ASPECT_CTR │
│     │LFO│───▶│NOI│          │    IGNORE_SIZE    │
│     │   │    │SE │          ├────────────────────┤
│     └───┘    └───┘          │  InspectorPanel   │
│                             │  (stretch 1.0)     │
│                             │  └─ GNParamInsp.  │
│                             │    260px min width │
├─────────────────────────────┴────────────────────┤
│  InfoBar: FPS | Frame | Cook | Viewing: nodeID  │
└──────────────────────────────────────────────────┘
```

**Scene file:** `scenes/gn_editor.tscn`
- Viewer TextureRect: `stretch_mode = KEEP_ASPECT_CENTERED`, `expand_mode = IGNORE_SIZE` (texture aspect doesn't force panel width)
- Both panels: `clip_contents = true`, `custom_minimum_size.y = 40` (freely resizable via VSplit splitter)
- Window stretch: `canvas_items` mode, `expand` aspect (set in `project.godot`)

### GNGraphEditor (extends GraphEdit)
- Renders GNNetwork as GraphNode instances
- Handles drag-and-drop from palette, wiring, deletion
- Color-codes connections by family
- Tab key opens node palette popup
- **Right-click context menu** (`PopupMenu`) with contextual options:
  - Add Node… (opens palette), Copy, Cut, Paste, Duplicate, Delete, Select All, Undo, Redo
  - Items grayed out when not applicable (e.g., no selection → copy/cut/delete disabled)
  - Shortcut hints displayed in menu items
- Emits `operator_selected` / `operator_deselected` signals
- Handles node rename: disconnects visual wires under old name, updates view identity, reconnects under new name
- Connects to `network.node_renamed` signal for model-driven rename updates
- `previews_visible` flag — controls whether inline previews are shown; respects toggle on newly created views
- `perf_overlay_visible` flag — controls per-node cook time badge; respects toggle on newly created views
- `set_previews_visible(enabled)` — shows/hides all existing node preview controls; newly created views auto-hide if `previews_visible` is false
- `set_perf_overlay_visible(enabled)` — shows/hides all existing perf overlay labels; newly created views auto-show if `perf_overlay_visible` is true
- `update_previews()` — skips updates when `previews_visible` is false (zero cost when hidden)
- `update_perf_overlays()` — skips updates when `perf_overlay_visible` is false

### GNNodeView (extends GraphNode)
- Visual representation of a GNNode
- Shows typed input/output ports with family colors
- Family-colored title bar via StyleBoxFlat theme overrides
- Title format: `"nodeId  [FAMILY]"` (e.g., `"noise1  [TOP]"`)
- **Double-click title bar to rename** — inline LineEdit overlay, commits on Enter or focus-lost
- `rename_requested(old_id, new_id)` signal emitted on commit
- Dynamic port rebuilding via `rebuild_slots()` + `reset_size()`
- Port/node tooltips from descriptions
- **Live preview** via `_setup_preview()` → family base class `create_preview_control()`
- `show_preview()` / `hide_preview()` — toggle preview control visibility with `reset_size()` to resize the node
- **Performance overlay** via `_perf_label` (Label): color-coded cook time badge (✓/✗ + ms)
- `show_perf_overlay()` / `hide_perf_overlay()` / `update_perf_overlay()` — lazy label creation, color-coded by threshold

### GNInspector (GNParamInspector, extends PanelContainer)
- Shows parameters for the currently selected node
- Header shows node ID (updates on rename) + status line (family, type, port count, resolution for TOPs)
- Resolution display for TOPs: `In [in0:512x512, in1:256x256] | Out 512x512`
- Renders appropriate controls per parameter type:
  - float → HSlider + SpinBox
  - int → SpinBox
  - Vector2 → 2x SpinBox
  - Color → ColorPickerButton
  - enum → OptionButton
  - bool → CheckBox
  - String → LineEdit
- Expression toggle: switch from value to expression mode

### GNViewer (TextureRect in ViewerPanel)
- Aspect-correct preview of a selected TOP's output
- `stretch_mode = KEEP_ASPECT_CENTERED`, `expand_mode = IGNORE_SIZE`
- Panel freely resizable via VSplitContainer splitter
- `clip_contents = true` on ViewerPanel prevents texture aspect from forcing panel size

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
│       │   ├── gn_table_data.gd    # GNTableData — DAT output (RefCounted)
│       │   ├── gn_geo_data.gd      # GNGeoData — SOP output, wraps ArrayMesh (RefCounted)
│       │   ├── gn_node.gd          # GNNode base operator class (Node) — type-agnostic
│       │   ├── gn_top_base.gd      # GNTopBase — TOP family base (viewport infra, shader pipeline, render-once-per-cook)
│       │   ├── gn_chop_base.gd     # GNChopBase — CHOP family base (channel data cache, label preview)
│       │   ├── gn_dat_base.gd      # GNDatBase — DAT family base (table cache, label preview)
│       │   ├── gn_sop_base.gd      # GNSopBase — SOP family base (geo cache, label preview)
│       │   ├── gn_comp_base.gd     # GNCompBase — COMP family base (scene node, auto-cleanup)
│       │   ├── gn_port.gd          # GNPort definition (RefCounted)
│       │   ├── gn_connection.gd    # GNConnection (RefCounted)
│       │   ├── gn_network.gd       # GNNetwork (Resource — serialization boundary)
│       │   ├── gn_cook_engine.gd   # GNCookEngine (Node)
│       │   ├── gn_parameter.gd     # GNParameter (Resource — typed param with expressions)
│       │   ├── gn_extension_registry.gd # GNExtensionRegistry — dynamic operator registry + extension loader
│       │   ├── gn_family.gd        # GNFamily enum constants
│       │   └── gn_logger.gd        # GNLogger — centralized logging with level filtering
│       ├── operators/
│       │   ├── top/
│       │   │   ├── noise_top.gd         # + 19 more TOPs (blur, ramp, circle, etc.)
│       │   │   ├── composite_top.gd
│       │   │   ├── level_top.gd
│       │   │   └── render_top.gd        # RenderTOP — 3D SubViewport bridge (COMP→TOP)
│       │   ├── chop/
│       │   │   ├── lfo_chop.gd          # + 19 more CHOPs (wave, pattern, filter, etc.)
│       │   │   ├── math_chop.gd
│       │   │   └── noise_chop.gd
│       │   ├── dat/
│       │   │   ├── constant_dat.gd      # 4×4 editable table
│       │   │   ├── text_dat.gd          # Plain text
│       │   │   ├── null_dat.gd          # Passthrough
│       │   │   ├── select_dat.gd        # Row/col range selection
│       │   │   ├── merge_dat.gd         # Row or column merge
│       │   │   ├── transpose_dat.gd     # Transpose rows/cols
│       │   │   ├── sort_dat.gd          # Sort by column (alpha/numeric)
│       │   │   ├── evaluate_dat.gd      # Expression cells (=expr)
│       │   │   ├── switch_dat.gd        # Index-based input select
│       │   │   ├── chop_to_dat.gd       # CHOP→DAT bridge
│       │   │   ├── dat_to_chop.gd       # DAT→CHOP bridge (family=CHOP)
│       │   │   ├── info_dat.gd          # System info table (time-dependent)
│       │   │   └── osc_in_dat.gd        # OSC input (stub for future UDP)
│       │   ├── sop/
│       │   │   ├── grid_sop.gd          # Subdivided plane (SurfaceTool)
│       │   │   ├── box_sop.gd           # Godot BoxMesh
│       │   │   ├── sphere_sop.gd        # Godot SphereMesh
│       │   │   ├── torus_sop.gd         # Godot TorusMesh
│       │   │   ├── cylinder_sop.gd      # Godot CylinderMesh
│       │   │   ├── line_sop.gd          # Line strip
│       │   │   ├── circle_sop.gd        # Filled disc or wire circle
│       │   │   ├── transform_sop.gd     # TRS with 6 transform orders
│       │   │   ├── noise_sop.gd         # FastNoiseLite vertex displacement
│       │   │   ├── subdivide_sop.gd     # Triangle→4 split (up to 4 iterations)
│       │   │   ├── wireframe_sop.gd     # Triangles→lines (edge dedup)
│       │   │   ├── merge_sop.gd         # Multi-input surface append
│       │   │   ├── null_sop.gd          # Passthrough
│       │   │   └── switch_sop.gd        # Index-based input select
│       │   ├── comp/
│       │   │   ├── geometry_comp.gd     # MeshInstance3D wrapper (SOP→3D scene)
│       │   │   ├── camera_comp.gd       # Camera3D wrapper (perspective/ortho)
│       │   │   └── light_comp.gd        # Light3D wrapper (dir/omni/spot)
│       │   ├── bridge/
│       │   │   └── chop_to_top.gd       # (or parameter expression system)
│       │   └── output/
│       │       └── window_top.gd        # WindowTOP — multi-window display output
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
│   └── gn_ext_ffmpeg/                  # ← First GNExtension addon (reference impl)
│       ├── gn_extension.cfg            # Manifest: name, deps, operator list
│       ├── README.md
│       └── operators/top/
│           └── ffmpeg_in_top.gd        # FFmpegInTOP — dynamic ClassDB.instantiate("FFmpegVideoStream")
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
- [x] Render parameter controls by type (FLOAT: slider+spinbox, INT: spinbox, BOOL: checkbox, ENUM: dropdown, COLOR: picker, VECTOR2/2I: dual spinbox, STRING: line edit, FILE: project file picker button with FileDialog)
- [x] Parameter mode toggle (C=constant green / E=expression orange)
- [x] Expression inline editor with focus guard (no 60fps text clobbering)
- [x] Parameter change → mark node dirty → recook
- [x] GNViewer panel showing TOP output in real-time (VSplit: viewer top, inspector bottom)
- [x] Expression mode: CHOP channel references in parameter fields
- [x] Live cook time display per node in inspector header
- [x] NoiseTOP noise_type enum wired to shader (4 algorithms: Simplex/Perlin/Voronoi/White)
- [x] WindowTOP `_window_params_dirty` flag — only reconfigures on own param changes, not upstream cook-dirty

### Phase 5: Polish & More Operators (Week 5) ✅
- [x] MathCHOP, NoiseCHOP (completed in Phase 2)
- [x] Massive operator expansion — 20 new TOPs + 17 new CHOPs
  - **New TOP generators:** RampTOP, CircleTOP, RectangleTOP, ConstantTOP, TextTOP
  - **New TOP filters:** BlurTOP (2-pass Gaussian), TransformTOP, HSVAdjustTOP, EdgeTOP, ThresholdTOP, FlipTOP, TileTOP, CropTOP, FeedbackTOP, ResolutionTOP
  - **New TOP combiners:** CrossTOP, DisplaceTOP, LookupTOP
  - **New TOP utility:** NullTOP, SwitchTOP
  - **New CHOP generators:** ConstantCHOP, WaveCHOP, PatternCHOP, TimerCHOP
  - **New CHOP filters:** FilterCHOP, LagCHOP, LimitCHOP, TriggerCHOP, SpeedCHOP, CountCHOP, HoldCHOP, SelectCHOP
  - **New CHOP combiners:** LogicCHOP, MergeCHOP, CrossCHOP
  - **New CHOP utility:** NullCHOP, SwitchCHOP
- [x] 14 new GPU shaders (blur, ramp, circle, rectangle, transform2d, hsv_adjust, edge, threshold, displace, flip, tile, cross, crop, lookup, feedback)
- [x] All operators registered in palette registry
- [x] CustomShaderTOP — user-editable GLSL shaders with live recompilation
- [x] Right-click context menu on graph canvas (moved to Phase 6)
- [x] Copy/paste nodes (moved to Phase 6)
- [x] Undo/redo (Godot's UndoRedo system) (moved to Phase 6)
- [x] Mini preview thumbnails on all nodes (moved to Phase 6)
- [ ] Expression reference lines (dashed/stippled overlay between nodes when a parameter references another node via `chop()`/`op()`/`top()` expressions)

### Phase 5.5: DAT, SOP, COMP & 3D Pipeline ✅
- [x] **GNTableData** — DAT output data type (2D string table + text mode, headers, TSV import/export)
- [x] **GNGeoData** — SOP output data type wrapping Godot's native `ArrayMesh`
- [x] **12 DAT operators:** ConstantDAT, TextDAT, NullDAT, SelectDAT, MergeDAT, TransposeDAT, SortDAT, EvaluateDAT, SwitchDAT, CHOPDAT (CHOP→DAT bridge), DATtoCHOP (DAT→CHOP bridge), InfoDAT
  - OscInDAT stub for future UDP/OSC input
- [x] **14 SOP operators:** GridSOP, BoxSOP, SphereSOP, TorusSOP, CylinderSOP, LineSOP, CircleSOP, TransformSOP, NoiseSOP, SubdivideSOP, WireframeSOP, MergeSOP, NullSOP, SwitchSOP
  - SOP generators use Godot native meshes: BoxMesh, SphereMesh, CylinderMesh, TorusMesh
  - Procedural generators use Godot SurfaceTool (GridSOP, LineSOP, CircleSOP)
  - NoiseSOP uses Godot FastNoiseLite for vertex displacement
- [x] **3 COMP operators:** GeometryCOMP, CameraCOMP, LightCOMP
  - GeometryCOMP: wraps MeshInstance3D, applies SOP geometry + StandardMaterial3D + TOP texture
  - CameraCOMP: wraps Camera3D, perspective/ortho, look-at mode
  - LightCOMP: wraps DirectionalLight3D / OmniLight3D / SpotLight3D with shadow control
- [x] **RenderTOP** — 3D SubViewport bridge (COMP → TOP texture pipeline)
  - Own `World3D` per viewport (isolated 3D scene)
  - Walks network connections to adopt GeometryCOMP/CameraCOMP/LightCOMP nodes
  - Default camera fallback if no CameraCOMP connected
  - WorldEnvironment with configurable ambient/background
  - MSAA control (Off/2x/4x/8x), transparent background option
- [x] **All operators registered** in graph editor registry + palette
- [x] **Codebase review & bug fixes:**
  - Fixed multi-input port data loss in `_gather_inputs()` (MergeSOP, CompositeTOP now work)
  - Fixed stale `cached_output` when cook returns null
  - Fixed COMP null-return warning suppression
  - Fixed PatternCHOP per-frame RNG allocation (moved to member variable)
  - Fixed `_select_first_leaf` recursive tree traversal in palette

### Phase 5.6: UI Polish & Node Renaming ✅
- [x] **Canvas anchoring fix** — all 21 TOP operators now use `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` for SubViewport canvas sizing (replaces manual `_canvas.size = Vector2(res)`)
- [x] **Viewer panel sizing fix** — TextureRect `expand_mode = 1` (IGNORE_SIZE), `clip_contents = true` on both ViewerPanel and InspectorPanel, prevents texture aspect ratio from forcing panel width
- [x] **Node renaming** — double-click title bar to rename nodes inline; full ID update chain: nodes dict, GNNode.id/name, all GNConnection references, expression strings, visual wires
- [x] **Inspector refresh on rename** — header label updates when re-inspecting a renamed node
- [x] **Documentation update** — GONODES_CONTEXT.md updated with Hard Rules 25.16–25.18

### Phase 5.7: File Parameters & Media Input ✅
- [x] **FILE parameter type** — new `ValueType.FILE` in GNParameter with `file_filters` (PackedStringArray of wildcard patterns). `create_file()` factory method. Stores `res://` paths.
- [x] **File picker UI** — GNParamRow renders FILE params as a Button (showing filename) + "X" clear button. Opens Godot's native FileDialog scoped to `ACCESS_RESOURCES` (project directory only). Filter extensions from parameter's `file_filters`.
- [x] **TextTOP font selection** — new `font_file` FILE parameter accepting TTF, OTF, WOFF, WOFF2. Loads via `ResourceLoader`, applies with `add_theme_font_override("font", ...)`. Empty = default theme font.
- [x] **ImageFileInTOP** — new TOP generator loading image/texture resources (PNG, JPG, WebP, BMP, TGA, SVG, HDR, EXR, .tres/.res). TextureRect in SubViewport with configurable fit mode (Stretch, Keep Aspect, Keep Aspect Centered, Keep Aspect Covered, Tile). Bilinear/nearest filtering toggle.
- [x] **MovieFileInTOP** — new TOP generator using Godot's native `VideoStreamPlayer` for .ogv Theora video playback. Play/pause, loop, seek, speed controls. Video renders inside SubViewport for standard TOP pipeline integration.
  - **Codec limitations:** Godot's built-in Theora decoder outputs RGB only (no alpha). HAP codec (VJ-standard S3TC/DXT GPU-direct upload) requires a custom GDExtension — see roadmap. For alpha video, use image sequences (PNG/WebP).

### Phase 5.8: Extension Registry Architecture ✅
- [x] **GNExtensionRegistry** — centralized operator registry (`addons/gonodes/core/gn_extension_registry.gd`). Lazy singleton with `instance()`. Replaces the static match-factory in GNGraphEditor and the static description dictionary in GNNodePalette.
  - `OperatorEntry` inner class: family, GDScript, description, source ("core" or extension name)
  - `register_operator()` / `unregister_operator()` — dynamic operator registration API
  - `create_instance(class_name)` → GNNode — data-driven factory (no more match block)
  - `get_operator_registry()` → Dictionary grouped by family — same shape as before
  - `get_description(class_name)` → String — tooltip text for palette
  - `has_operator()`, `get_operator_count()`, `get_all_operator_names()`, `get_loaded_extensions()` — query API
- [x] **Extension scanning** — `scan_extensions()` discovers `res://addons/gn_ext_*/gn_extension.cfg` manifest files (ConfigFile format). Each manifest declares:
  - `[extension]` section: name, version, author, description, dependencies (ClassDB class names)
  - `[operator.<ClassName>]` sections: family, script path, description
  - Dependency guard via `ClassDB.class_exists()` — skips extensions whose GDExtension deps are missing
- [x] **Refactored GNGraphEditor** — `_create_operator_instance()` and `get_operator_registry()` now delegate to GNExtensionRegistry (replaced ~230-line match block + ~40-line static dictionary)
- [x] **Refactored GNNodePalette** — `_get_operator_description()` now delegates to GNExtensionRegistry (replaced ~80-line static dictionary)
- [x] **Editor startup** — `gn_editor.gd._ready()` calls `GNExtensionRegistry.instance().scan_extensions()` before network setup

### Phase 6: Integration & Stabilization (Week 6) ✅
- [x] **Save/load patches** (`.gnpatch` JSON files) — full serialization pipeline:
  - `GNParameter.to_dict()` / `from_dict()` — serializes value, mode, expression, bind info. Custom `_variant_to_json()` / `_json_to_variant()` handles Vector2, Vector2i, Vector3, Vector4, Color → typed JSON dicts.
  - `GNNode.to_dict()` / `from_dict()` — serializes operator type, graph position, all parameters.
  - `GNNetwork.to_dict()` / `from_dict()` — serializes all nodes + connections. Uses `GNExtensionRegistry.create_instance()` for reconstruction.
  - `GNNetwork.save_to_file(path)` / `load_from_file(path)` — JSON read/write with pretty-printing.
  - Editor UI: New / Open / Save / Save As buttons in bottom bar + Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S keyboard shortcuts. FileDialog for file picker. Window title shows current file name.
- [x] **Node copy/paste** — clipboard-based with ID remapping:
  - `GNGraphEditor._clipboard` stores serialized nodes + internal connections.
  - Copy (Ctrl+C): serializes selected nodes via `to_dict()`, gathers connections where both endpoints are selected.
  - Paste (Ctrl+V): reconstructs with fresh IDs via `generate_unique_id()`, offsets positions +50/+50, remaps internal connections, auto-selects pasted nodes.
  - Cut (Ctrl+X): copy then delete. Duplicate (Ctrl+D): copy then paste in one step.
- [x] **Undo/redo** — Godot `UndoRedo` command pattern:
  - Tracks: add node, delete node(s), connect, disconnect, move node(s), rename.
  - Keyboard shortcuts: Ctrl+Z (undo), Ctrl+Y / Ctrl+Shift+Z (redo).
  - `_ur_*` helper methods on GNGraphEditor operate on the network model; network signals update views automatically.
  - Delete snapshots node dict + connections for full reconstruction on undo.
  - Move tracked via GraphEdit `begin_node_move`/`end_node_move` signals with position diffing.
  - Paste/duplicate record compound actions (all pasted nodes removed on undo).
  - History cleared on New/Load to avoid cross-patch undo.
- [x] **Mini preview thumbnails** on all nodes (generic preview system):
  - `GNNode.create_preview_control()` — virtual, returns a custom `Control` for family-specific previews. Returns null by default (type-agnostic GNNode).
  - `GNNode.update_preview_control(control)` — virtual, called each cook frame to update previews. No-op by default.
  - Family base classes override these: GNTopBase (TextureRect), GNChopBase (Label: channel values), GNDatBase (Label: table rows), GNSopBase (Label: mesh stats), GNCompBase (Label: node class).
  - `GNNodeView._setup_preview()` — creates preview control via `gn_node.create_preview_control()` (120×80px min size).
  - `GNGraphEditor.update_previews()` iterates ALL node views each cook frame (skipped when hidden).
  - Extensible: any operator can override `create_preview_control()` for operator-specific rendering.
- [x] **Family base classes** — 6 intermediate bases between GNNode and operators:
  - `GNTopBase` (28 TOPs), `GNChopBase` (21 CHOPs), `GNDatBase` (12 DATs), `GNSopBase` (14 SOPs), `GNCompBase` (4 COMPs), `GNMatBase` (2 MATs).
  - Each sets family, provides cached data helpers, and overrides preview methods.
  - All 82 operators migrated. GNNode is now fully type-agnostic.
- [x] **Preview toggle** — global toolbar `CheckButton` ("Previews") to show/hide inline node previews:
  - `GNGraphEditor.previews_visible` flag controls whether `update_previews()` processes updates.
  - `GNGraphEditor.set_previews_visible(enabled)` shows/hides all preview controls on existing views.
  - Newly created views auto-hide their preview if `previews_visible` is false.
  - `GNNodeView.show_preview()` / `hide_preview()` toggle visibility with `reset_size()` to reflow node layout.
- [x] **Right-click context menu** — contextual `PopupMenu` on graph canvas:
  - Items: Add Node…, Copy, Cut, Paste, Duplicate, Delete, Select All, Undo, Redo.
  - Selection-aware: copy/cut/delete/duplicate grayed out when nothing is selected.
  - Clipboard-aware: paste grayed out when clipboard is empty.
  - Undo/redo state-aware: grayed out when no history available.
  - Shortcut hints displayed beside each item.
- [x] **Performance profiling overlay** — per-node cook time badge with toolbar toggle:
  - `GNNodeView._perf_label` (Label) shows `✓ 0.12ms` or `✗ 0.00ms` with color coding.
  - Color thresholds: green (<1ms), yellow (<5ms), red (≥5ms).
  - Created lazily on first `show_perf_overlay()` call (zero cost when never enabled).
  - `GNGraphEditor.perf_overlay_visible` flag; `set_perf_overlay_visible(enabled)` toggles all views.
  - `GNGraphEditor.update_perf_overlays()` called each cook frame (skipped when hidden).
  - Newly created views auto-show overlay if `perf_overlay_visible` is true.
  - Editor toolbar "Perf" `CheckButton` (off by default) wired to `_on_perf_toggled()`.
- [x] **MAT family** — material operators with per-object material binding:
  - `GNMaterialData` data type wrapping Godot's `Material` base class.
  - `GNMatBase` family base class with `_prepare_output()` helper and material label preview.
  - `PBR_MAT` — StandardMaterial3D wrapper: albedo color, metallic, roughness, specular, emission (toggle/color/energy), normal scale, transparency mode (Disabled/Alpha/Alpha Scissor/Depth Pre-Pass), alpha scissor threshold, cull mode (Back/Front/Disabled), triplanar UV. 3 optional TOP inputs (albedo texture, normal map, ORM texture).
  - `Shader_MAT` — ShaderMaterial wrapper: inline shader code (string param) or external `.gdshader` file. 8 float uniforms (u0–u7), 2 color uniforms (color0, color1), 2 optional TOP inputs (tex0, tex1). Lazy shader recompilation (only when source changes).
  - GeometryCOMP updated: 3 inputs (SOP, MAT, TOP). MAT input overrides fallback PBR; when disconnected, built-in PBR params still work.
- [x] **MergeCOMP** — groups multiple COMP scene nodes under a single Node3D parent:
  - Multi-input COMP port. Full transform params (t/r/s xyz) + visible toggle.
  - `_populate_from_network()` walks upstream connections, reparents COMP scene nodes.
  - RenderTOP updated to recognize MergeCOMP and adopt entire group node.
- [x] **Shadow system** — per-light and global shadow controls:
  - LightCOMP: shadow_bias, shadow_normal_bias, shadow_blur, shadow_opacity, directional shadow mode (Orthogonal/PSSM2/PSSM4).
  - RenderTOP: shadow atlas size, directional shadow size, shadow filter quality.
  - GeometryCOMP: cast_shadow mode (Off/On/Double-Sided/Shadows Only).
- [x] **Bug fixes** — family assignment (`_init()` override without `super()`), expression re-cook (`_pre_cook` detection + `mode_changed` signal), torus Y-axis rotation visibility.
- [x] **Multiple viewer windows** — floating viewer windows pinned to any TOP node:
  - `GNViewerWindow` extends Window — dark background, TextureRect with aspect-preserving display.
  - Each window is pinned to a specific node via `node_id` and updates every cook frame.
  - Spawned via toolbar "+ Viewer" button (uses current viewer target) or right-click "Open Viewer" on a selected TOP node.
  - Windows track node renames automatically and clean up on new/load.
  - Multiple windows can be open simultaneously, each showing a different node's output.
  - Close button frees the window and removes it from the tracked array.
- [x] Stress test: 50+ node network (59 nodes across all 6 families, toolbar button + auto-report)
- [x] **Per-node preview toggle** — right-click context menu "Preview: ON/OFF":
  - `GNNode.preview_enabled` flag (default true, persists with save/load).
  - Global "Previews" toolbar toggle acts as master switch (sets all per-node flags).
  - Per-node toggle works independently — turn global off, then selectively re-enable specific nodes.
  - `update_previews()` skips nodes with `preview_enabled = false` (zero cost).
  - TOGGLE_PREVIEW added to `_CtxID` enum. Shows current state in menu label.
- [x] **WindowTOP open/close toggle** — `open` boolean parameter:
  - Default `false` (window doesn't pop up on creation). Resolution default changed to 512×512.
  - Close button sets `open = false` in inspector. Toggle back to `true` to reopen.
  - `_cook()` syncs `_window.visible` with param each frame.
- [x] README and basic documentation

### Phase 7: Creative Tools, Performance & Workflow
- [ ] **ScriptCHOP** — user-editable GDScript for custom channel processing:
  - Inline code editor (string param) or external `.gd` file.
  - `cook(inputs, frame, time, delta)` entry point returning channel dict.
  - Access to all expression context variables.
- [ ] **ScriptDAT** — user-editable GDScript for table/text processing:
  - Same inline/file model as ScriptCHOP.
  - `cook(inputs, frame, time, delta)` entry point returning table/text data.
- [ ] **ScriptTOP** — CPU-side pixel generation via GDScript:
  - Write to Image pixel-by-pixel or via bulk operations.
  - Input textures readable as Image data.
- [ ] **ScriptSOP** — procedural geometry via GDScript:
  - SurfaceTool-based mesh generation.
  - Access to input geometry vertices/normals/UVs.
- [ ] **OSC input/output operators**:
  - OscInCHOP — receives OSC messages on configurable UDP port, maps to channels.
  - OscOutCHOP — sends channel data as OSC messages to target host:port.
  - Complete the OscInDAT stub with actual UDP listener.
- [ ] **MIDI input operators**:
  - MidiInCHOP — receives MIDI note/CC/pitch bend, maps to channels.
  - MidiInDAT — raw MIDI message log as table rows.
  - Device selection parameter (enumerate OS MIDI inputs).
- [ ] **Audio input CHOP**:
  - AudioInCHOP — microphone or audio file input as waveform channels.
  - AudioSpectrumCHOP — FFT analysis, outputs frequency bands as channels.
  - AudioFileInCHOP — playback of WAV/OGG with transport controls (play, pause, seek, loop).
- [ ] **Webcam / video input TOP**:
  - WebcamTOP — live camera feed via CameraServer.
  - Device selection, resolution, and format parameters.
- [ ] **ImageSequenceTOP** — numbered frame playback:
  - PNG/WebP/JPG sequences with alpha support.
  - Configurable frame range, speed, loop mode, hold first/last.
  - Expression-driven frame index for precise sequencing.
- [x] **Performance: SubViewport UPDATE_ONCE** for non-time-dependent TOPs:
  - All SubViewports now created with `UPDATE_DISABLED`. `GNTopBase.execute_cook()` triggers `UPDATE_ONCE` after each cook — TOPs render exactly once per dirty cycle.
  - Time-dependent TOPs (e.g., CustomShaderTOP with `time_dependent` toggle) are re-cooked each frame by the cook engine, so they naturally re-render via the same mechanism.
  - Reduces GPU load significantly for static texture chains.
- [ ] **Performance: Viewport pooling**:
  - Reuse freed SubViewports instead of creating/destroying.
  - Pool tracks available viewports by resolution. Reduces allocation churn at scale.
- [ ] **Performance: Active chain cooking**:
  - Only cook subgraphs that feed into a WindowTOP, visible preview, or viewer window.
  - Disconnected/orphan subgraphs skip cooking entirely.
  - `GNCookEngine.active_outputs` tracks which sink nodes are live.
- [x] **Performance: Lazy viewport creation**:
  - Viewport creation is deferred to first `_cook()` call — `_init_shader_viewport()` and `_ensure_viewport()` guard with `if _viewport != null: return`.
  - Disconnected TOPs have zero GPU footprint until first cook.
- [ ] **Performance: GPU memory budget monitoring**:
  - Track total estimated VRAM across all SubViewports.
  - Warn when approaching configurable budget limit.
  - Display in info bar alongside FPS/cook time.
- [ ] **Performance: Resolution downscaling for previews**:
  - Render inline preview thumbnails at ¼ or ½ res.
  - Full resolution only for the active viewer output and WindowTOPs.
- [ ] **Keyboard shortcuts & workflow polish**:
  - Consistent shortcut reference card (help overlay, '?' key).
  - Node alignment tools (align horizontal/vertical, distribute evenly).
  - Fit-to-view (F key zooms to selected nodes or entire graph).
  - Node bypass/disable toggle (B key — node passes input through unchanged).
  - Node lock toggle (L key — prevents accidental parameter changes).
  - Wire style options (curved/straight/right-angle).
- [ ] **Renderer selection UI**:
  - Dropdown in toolbar: Forward+, Mobile, Compatibility.
  - Applies to RenderTOP SubViewport and WindowTOP output.
  - Enables previewing how patches will look on different target platforms.
- [ ] **Patch export to standalone apps**:
  - **Pre-built Player approach**: Ship a `GONODESPlayer.exe` alongside the editor —
    a minimal runtime that loads a `.gnpatch`, runs the cook engine + WindowTOP
    output only (no editor UI). "Build" button copies Player + patch + assets → output folder.
  - Player entry scene (`player_main.tscn`): loads patch, starts cook, opens WindowTOPs.
  - Later: Godot export templates for desktop (Windows/macOS/Linux), web export (Compatibility renderer).
  - **Extension distribution for exported apps**: When GONODES ships as a
    standalone application (not running inside the Godot editor), users will need
    a way to install extensions without touching `res://addons/`. Design a
    user-facing `Extensions/` folder (e.g. next to the executable or in
    `user://extensions/`) that `scan_extensions()` also searches. This keeps the
    same `gn_ext_<name>/gn_extension.cfg` manifest convention but lets
    end-users drag-and-drop extension folders without rebuilding the project.
    Consider:
    - Scanning both `res://addons/gn_ext_*` (dev) and `user://extensions/gn_ext_*` (end-user).
    - An in-app "Extensions" settings panel listing installed / available extensions with enable/disable toggles.
    - Version compatibility checks (engine version, GONODES version) in the manifest.
    - Hot-reload of extensions without restarting the editor.
- [ ] **Node help system**:
  - `?` button in node context menu (or node header) opens a help Window.
  - Help window: `Window` + `RichTextLabel` rendering per-node documentation.
  - Documentation stored as `.md` files in `res://addons/gonodes/help/<family>/`.
  - File naming convention: `<node_type>.md` (e.g. `noise_top.md`, `lfo_chop.md`).
  - Auto-generation: bootstrap help files from existing `node_description`, port
    descriptions, and parameter descriptions already defined in each operator.
  - Template: heading, description, inputs table, outputs table, parameters table,
    usage notes, example patch links.
  - Example patches stored as `.gnpatch` files alongside help (e.g. `noise_top_example.gnpatch`).
  - "Open Example" button at bottom of help page loads the example patch into the
    editor (with confirmation if current patch has unsaved changes).
  - Folder structure:
    ```
    addons/gonodes/help/
    ├── top/
    │   ├── noise_top.md
    │   ├── noise_top_example.gnpatch
    │   ├── blur_top.md
    │   └── ...
    ├── chop/
    ├── dat/
    ├── sop/
    ├── comp/
    └── mat/
    ```
- [ ] **Node grouping / sub-networks**:
  - Select multiple nodes → group into a collapsed sub-network node.
  - Double-click to dive into sub-network. Breadcrumb navigation.
  - Input/output tunnel nodes for wiring between levels.
- [ ] **Minimap**:
  - Small overview panel showing entire graph layout.
  - Click to navigate. Viewport rectangle shows current zoom region.
- [ ] **Node bookmarks**:
  - Tag important nodes with named bookmarks.
  - Quick-jump dropdown or number keys (1-9) to teleport to bookmarked nodes.
- [ ] **Auto-layout**:
  - One-click graph cleanup using topological order + layer assignment.
  - Minimizes wire crossings. Configurable spacing.
- [ ] **Parameter presets**:
  - Save/load named parameter snapshots per operator instance.
  - Copy parameters between nodes of the same type.
  - Global preset library for reusable configurations.

### Near-term
- [x] SOP family (procedural geometry: Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Transform, Noise, Subdivide, Wireframe, Merge, Null, Switch)
- [x] DAT family (Constant, Text, Select, Merge, Transpose, Sort, Evaluate, Switch, bridges)
- [x] MAT family (PBR_MAT, Shader_MAT)
- [x] COMP family (GeometryCOMP, CameraCOMP, LightCOMP, MergeCOMP + RenderTOP bridge)
- [x] Keyboard shortcuts and workflow polish (Alt+A palette, context menu shortcuts, per-node preview toggle)

### Medium-term
- [ ] POP family (GPU point/particle operators — see Section 18)
- [ ] LibGodot embedding proof-of-concept
  - Build a minimal host app that embeds LibGodot
  - Load a .GNNode patch via API
  - Feed data in, read textures out
- [ ] Syphon (macOS) / Spout (Windows) texture sharing
- [x] FFmpeg GDExtension addon (`gn_ext_ffmpeg`) — **Done: first reference extension for GNExtensionRegistry**
  - Wraps [EIRTeam/EIRTeam.FFmpeg](https://github.com/EIRTeam/EIRTeam.FFmpeg) GDExtension
  - FFmpegInTOP: H.264, H.265, VP9, AV1, ProRes playback via dynamic `ClassDB.instantiate("FFmpegVideoStream")`
  - Demonstrates `gn_extension.cfg` manifest, `ClassDB.class_exists()` dependency guards
  - Core MovieFileInTOP always available (Theora .ogv); FFmpegInTOP appears only when GDExtension installed
- [ ] HAP codec GDExtension — GPU-direct S3TC/DXT video playback for VJ workflows
  - HAP, HAP Alpha, HAP Q variants
  - Custom `VideoStreamHAP` resource extending Godot's `VideoStream`
  - Wraps [Vidvox/hap](https://github.com/Vidvox/hap) (Snappy + DXT decompression, direct GPU upload)
  - Enables alpha-channel video without image sequences
- [x] Custom GLSL shader TOP (user-editable shader code) — **Done: CustomShaderTOP**
- [ ] ComputeShaderTOP (user-editable GPU compute shader — see Section 27)

### Performance & GPU Optimizations (Post-Phase 7)
- [ ] Multi-threaded cook engine
- [ ] GPU compute shaders for CHOPs (massive parallel channel processing)

### Long-term
- [ ] NDI video streaming
- [ ] FxPlug / FFGL plugin export (for VDMX, Resolume)
- [ ] ScriptTOP (CPU-side pixel generation via GDScript — see Section 27)
- [ ] ScriptSOP (procedural geometry via GDScript — see Section 27)
- [ ] Python scripting DAT (embedded Python via GDExtension)
- [ ] Network collaboration (shared editing)
- [ ] Asset/patch marketplace
- [ ] Mobile/web export for patches (leveraging Godot's Mobile + Compatibility renderers)

---

## 13.5. Coding Guidelines

These principles guide all GONODES development. Follow them when adding new operators, refactoring existing code, or reviewing contributions.

### 1. Consolidate Common Members in Family Base Classes

Shared properties, cached data, and helper methods that appear in more than one operator within a family **must** live in the family base class (`GNTopBase`, `GNChopBase`, `GNDatBase`, `GNSopBase`, `GNCompBase`, `GNMatBase`), not duplicated across subclasses.

**Why:** Reduces boilerplate, prevents drift between implementations, and makes family-wide behavioral changes (like the UPDATE_ONCE render lifecycle) possible in one place.

**Examples:**
- `GNTopBase._viewport`, `_material`, `_canvas`, `_cached_tex_data` — every TOP needs viewport infrastructure.
- `GNChopBase._cached_channel_data` — every CHOP caches channel output.
- `GNDatBase._cached_table` — every DAT caches table output.

**Rule of thumb:** If you're about to declare the same `var` in a third subclass, move it to the base.

### 2. Prefer Godot Built-in Classes

Use Godot's native types and engine classes wherever possible instead of building custom abstractions.

**Why:** Godot's built-in classes are optimized, well-documented, and battle-tested. Wrapping them adds indirection with no benefit. Leveraging the engine's type system (Node, Resource, RefCounted) also enables automatic memory management, serialization, and editor integration for free.

**Concrete preferences:**
| Instead of … | Use … |
|---|---|
| Custom render pipeline | `SubViewport` + `ShaderMaterial` + `ColorRect`/`TextureRect` |
| Manual memory management | `RefCounted` subclasses (freed automatically) |
| Custom mesh format | `ArrayMesh` / `SurfaceTool` / `PrimitiveMesh` |
| Custom material wrapper | `StandardMaterial3D` / `ShaderMaterial` |
| Custom signal bus | Godot signals, `Node.notification()` |
| Manual tree cleanup | `queue_free()` cascade, `_notification(PREDELETE)` |
| Custom serialization | `Resource` with `@export` properties |
| Custom logging | `GNLogger` wrapping Godot's `push_warning()` / `push_error()` |

### 3. Resolution Follows Context

- **Generator TOPs** (no input): viewport size = `get_param_value("resolution")`.
- **Filter TOPs** (has input): viewport size = `tex_in.resolution` (matches input).
- Never hardcode viewport sizes (e.g., `Vector2i(512, 512)`) in operator `_cook()` methods. The factory defaults in `_create_viewport()` are only fallbacks for when no resolution is available yet.

### 4. Render Only When Needed

SubViewports must be created with `UPDATE_DISABLED`. The base class (`GNTopBase.execute_cook()`) triggers `UPDATE_ONCE` after each successful cook. Operators must **not** set `UPDATE_ALWAYS` or manually trigger renders — the base class owns the render lifecycle.

Exception: `process_mode = PROCESS_MODE_ALWAYS` is acceptable for media-playback TOPs (Movie, FFmpeg) that need Godot's built-in `_process()` for decoder advancement.

---

## 14. Technical Notes

### SubViewport Strategy for TOPs
Each TOP node owns a `SubViewport` for rendering its output texture. The infrastructure lives in **GNTopBase**:

- **Creation:** `_create_viewport()` factory produces a SubViewport with `UPDATE_DISABLED`, `gui_disable_input = true`, and optional transparency / 3D. Higher-level helpers `_ensure_viewport()` and `_init_shader_viewport()` build upon it.
- **Canvas:** A `ColorRect` (generators) or `TextureRect` (filters) with `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` auto-fills the viewport — no manual `_canvas.size` management (see Hard Rule 25.16).
- **Resolution:** Generator TOPs pass `get_param_value("resolution")` as the viewport size. Filter TOPs pass `tex_in.resolution` (matching their input). No hardcoded sizes.
- **Render lifecycle:** Viewports are created with `UPDATE_DISABLED`. `GNTopBase.execute_cook()` triggers `UPDATE_ONCE` on every child SubViewport after `_cook()` sets uniforms/textures, so each TOP renders **exactly once per cook cycle** — no wasted GPU passes on non-dirty frames.
- **Input textures** are passed as shader uniforms (zero-copy GPU references).
- **Output:** The `ViewportTexture` is wrapped in `GNTextureData` and becomes the node's `cached_output`.
- **Cleanup:** Viewports are children of the GNNode; `queue_free()` cascades automatically.

**Performance consideration:** Each SubViewport is a render pass. For large networks, viewport pooling or deferred rendering may be needed. For MVP, one viewport per TOP is acceptable.

### Cook Engine Optimizations (Implemented)

The cook engine has been optimized with these patterns:

1. **Cached adjacency maps** — `GNNetwork._downstream_map` and `_input_conn_map` are rebuilt only when the graph structure changes (node/connection add/remove). All per-frame lookups (dirty propagation, input gathering) use O(1) dictionary lookups instead of scanning all connections.

2. **Upfront dirty propagation** — Dirty flags are propagated in a single BFS pass BEFORE the cook loop starts, not interleaved with cooking. This eliminates redundant BFS calls (previously one per producing node).

3. **Cached input arrays** — `_input_cache` stores a reusable `Array[GNData]` per node. Arrays are cleared and refilled each frame instead of being reallocated. Zero per-frame allocations in steady state.

4. **Skip-already-dirty BFS** — `propagate_dirty()` stops traversal at nodes already marked dirty, avoiding redundant downstream walks.

5. **SubViewport render-once-per-cook** — All TOP SubViewports are created with `UPDATE_DISABLED` instead of `UPDATE_ALWAYS`. Previously every SubViewport rendered every frame regardless of whether the TOP was dirty, wasting GPU passes on static texture chains. Now `GNTopBase.execute_cook()` sets `UPDATE_ONCE` on each child SubViewport only after `_cook()` finishes setting uniforms/textures. This means a TOP renders **exactly once per dirty cycle** — if it isn't cooked, its viewport never re-renders. For a network with N TOPs where only K are dirty, this reduces per-frame GPU render passes from N to K.

6. **Lazy viewport creation** — `_init_shader_viewport()` and `_ensure_viewport()` are guarded with `if _viewport != null: return`, deferring SubViewport allocation to the first `_cook()` call. TOPs that are never cooked (disconnected, orphaned) have zero GPU footprint — no SubViewport, no texture memory, no render passes.

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

#### `sop(name)` — SOP Proxy (Planned)
```gdscript
sop("grid1").num_points           # Total point count
sop("grid1").num_prims            # Primitive count
sop("grid1").point(0).P           # Position of point 0 (Vector3)
sop("grid1").point(0).N           # Normal of point 0
sop("grid1").bounds               # AABB bounding box
```
**Note:** SOP family is implemented (14 operators, GNGeoData type), but the expression proxy for `sop()` is not yet wired up. Access SOP data through GeometryCOMP or DATtoCHOP bridges for now.

#### `pop(name)` — POP Proxy (Future)
```gdscript
pop("particles1").num_points      # Point count
pop("particles1").num_prims       # Primitive count
pop("particles1").point(0).P      # Position (GPU readback — expensive)
pop("particles1").point(0).PartVel    # Velocity
pop("particles1").point(0).PartAge    # Age
pop("particles1").attr("custom_attr") # Custom attribute value at point 0
```

#### `dat(name)` — DAT Proxy (Planned)
```gdscript
dat("table1").cell(1, "name")     # Cell value at row 1, column "name"
dat("table1").cell(2, 3)          # Cell value at row 2, column 3
dat("table1").num_rows            # Row count
dat("table1").num_cols            # Column count
dat("table1").row(0)              # Entire row as Array
dat("table1").col("name")         # Entire column as Array
dat("text1").text                 # Full text content of a Text DAT
```
**Note:** DAT family is implemented (12 operators, GNTableData type), but the expression proxy for `dat()` is not yet wired up. Access DAT data through DATtoCHOP bridge for now.

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

## 20.5. 3D Scene Pipeline (SOP → COMP → RenderTOP)

GONODES uses Godot's native scene graph for 3D rendering instead of building a custom 3D engine. SOPs produce geometry data, COMPs wrap Godot Node3D types, and RenderTOP renders everything through a SubViewport back into the TOP texture pipeline.

### Architecture

```
SOP Chain (geometry)    MAT Layer        COMP Layer (3D scene)              TOP Pipeline
┌──────────┐  ┌────────────┐             ┌──────────────┐                     ┌───────────┐
│ GridSOP  │→→│TransformSOP│──→──┐       │              │                     │           │
└──────────┘  └────────────┘     ├──→─── │GeometryCOMP  │ (MeshInstance3D)─┐  │           │
                   ┌─────────┐  │       │              │                  │  │           │
                   │ PBR_MAT │──→──┘     └──────────────┘                  ├──│ RenderTOP │→→ texture
                   └─────────┘           ┌──────────────┐                  │  │           │   output
                                         │ CameraCOMP   │ (Camera3D) ─────┤  │           │
                                         └──────────────┘                  │  │           │
                                         ┌──────────────┐                  │  │           │
                                         │ LightCOMP    │ (Light3D) ──────┤  │           │
                                         └──────────────┘                  │  └───────────┘
                                         ┌──────────────┐                  │
                                         │ MergeCOMP    │ (Node3D group)──┘
                                         └──────────────┘
```

### Key Design Decisions

1. **Godot-native 3D nodes** — GeometryCOMP creates a real `MeshInstance3D`, CameraCOMP creates a real `Camera3D`, LightCOMP creates a real `DirectionalLight3D`/`OmniLight3D`/`SpotLight3D`. No custom rendering abstraction.

2. **Isolated World3D** — Each RenderTOP creates a `SubViewport` with `own_world_3d = true`, giving it a separate 3D scene. This prevents 3D content from appearing in the main editor viewport and allows multiple independent 3D scenes in one network.

3. **Scene population via network walk** — RenderTOP's `_populate_scene_from_network()` walks upstream connections to discover COMP nodes, then reparents their Node3D children into the RenderTOP's viewport. This means the 3D scene is defined by network wiring, not by Godot scene tree structure.

4. **MAT input on GeometryCOMP** — GeometryCOMP accepts 3 inputs: SOP (geometry), MAT (material override), TOP (albedo texture for fallback PBR). When a MAT is connected, its Material is used directly via `material_override`; when disconnected, built-in PBR params + TOP texture build a fallback `StandardMaterial3D`.

5. **Default camera fallback** — If no CameraCOMP is connected to a RenderTOP, it creates a default perspective camera at (0, 2, 5) looking at origin, ensuring there's always a valid render.

6. **MergeCOMP for scene composition** — MergeCOMP groups multiple COMP scene nodes under a single `Node3D` parent. RenderTOP recognizes MergeCOMP and adopts the entire group node, enabling multi-object scenes wired through a single connection.

7. **Shadow system** — Shadows are controlled at three levels: per-light (LightCOMP: bias, normal_bias, blur, opacity, directional shadow mode), per-object (GeometryCOMP: cast_shadow mode), and global quality (RenderTOP: shadow atlas size, directional shadow size, shadow filter).

### COMP Family Details

COMPs are unique in that they don't produce data output (no `GNData` return from cook). Instead, they create and maintain Godot Node3D instances that other nodes access via API methods:

- `GeometryCOMP.get_mesh_instance() → MeshInstance3D`
- `CameraCOMP.get_camera() → Camera3D`
- `LightCOMP.get_light() → Light3D`
- `MergeCOMP.get_group_node() → Node3D`

The cook engine suppresses null-output warnings for COMP family nodes since this is intentional design.

### SOP Data Flow

SOPs output `GNGeoData` which wraps an `ArrayMesh`:

```
SOP generators (BoxSOP, SphereSOP, etc.)
  → create GNGeoData with ArrayMesh
  → pass downstream via SOP ports

SOP filters (TransformSOP, NoiseSOP, etc.)
  → read input GNGeoData
  → extract vertex arrays
  → modify and produce new GNGeoData

GeometryCOMP (terminal SOP consumer)
  → reads GNGeoData from SOP input
  → applies mesh to its MeshInstance3D
  → if MAT input connected: uses Material directly (material_override)
  → else: builds fallback StandardMaterial3D from params + optional TOP albedo texture
```

### Godot Types Used

| GONODES Operator | Godot Type Used |
|---|---|
| BoxSOP | `BoxMesh` |
| SphereSOP | `SphereMesh` |
| CylinderSOP | `CylinderMesh` |
| TorusSOP | `TorusMesh` |
| GridSOP, LineSOP, CircleSOP | `SurfaceTool` → `ArrayMesh` |
| NoiseSOP | `FastNoiseLite` + `SurfaceTool` |
| TransformSOP | Manual vertex transform via `Basis` |
| GeometryCOMP | `MeshInstance3D` + `StandardMaterial3D` |
| CameraCOMP | `Camera3D` |
| LightCOMP | `DirectionalLight3D` / `OmniLight3D` / `SpotLight3D` |
| RenderTOP | `SubViewport` + `WorldEnvironment` + `Environment` |

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
| SOP    | GNGeoData         | CPU/GPU | Reference to ArrayMesh. Transform ops create new output. Mesh data on GPU after upload. |
| POP    | (future)          | GPU     | GPU buffer handle. Zero-copy. Downstream compute shaders bind the buffer. |
| DAT    | GNTableData       | CPU     | Reference to table/text data. Read-only. Lightweight string arrays. |
| COMP   | null (scene nodes) | N/A    | COMPs return null from cook. Access via API: get_mesh_instance(), get_camera(), get_light(). |

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
| `addons/gonodes/ui/gn_param_row.gd` | `GNParamRow` | Per-parameter widget. Type-specific controls (FLOAT: HSlider+SpinBox, INT: SpinBox, BOOL: CheckBox, ENUM: OptionButton, COLOR: ColorPickerButton, VECTOR2/2I: dual SpinBox, STRING: LineEdit, FILE: Button+FileDialog picker). Mode toggle button (C=green, E=orange). Expression LineEdit with focus guard |
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

### 25.10 Multi-Input Port Data Gathering

- `_gather_inputs()` in the cook engine has TWO code paths:
  - **Single-input ports** (fast path): cached array aligned by port index, one connection per slot
  - **Multi-input ports** (`port.multi_input = true`): collects ALL upstream connections into a flat array
- If only the fast path exists, multi-input operators (MergeSOP, CompositeTOP, RenderTOP) silently lose all but the last connection
- Always check for the `multi_input` flag when modifying input gathering logic

### 25.11 COMP Nodes Return Null Output

- COMPs (GeometryCOMP, CameraCOMP, LightCOMP) intentionally return `null` from `_cook()`
- Their "output" is a Godot Node3D (MeshInstance3D, Camera3D, Light3D), not a GNData subclass
- Downstream access is via API methods: `get_mesh_instance()`, `get_camera()`, `get_light()`
- The cook engine must suppress null-output warnings for `GNFamily.COMP` nodes
- RenderTOP accesses COMP nodes by walking the network graph, not by reading cook output

### 25.12 SubViewport own_world_3d for Isolated 3D Scenes

- RenderTOP uses `SubViewport.own_world_3d = true` to create an isolated 3D world
- Without this, 3D content from RenderTOP would appear in the main editor viewport
- Each RenderTOP has its own Environment/WorldEnvironment for independent lighting/sky

### 25.13 Lazy Cook / No Unnecessary Work

- **A node must NOT cook (or render) if nothing changed.** A cook fires only when:
  1. `time_dependent = true` → always dirty each frame
  2. A parameter value changed (expression eval, UI edit, script)
  3. An upstream input produced new output (dirty propagation)
- **Applies to ALL families equally** — TOPs, CHOPs, DATs, SOPs, COMPs
- **TOP-specific rule — SubViewport update mode:**
  - `time_dependent = true` → `UPDATE_ALWAYS` (renders every frame)
  - `time_dependent = false` → `UPDATE_ONCE` on cook (Godot renders one frame, then auto-flips to `UPDATE_DISABLED`)
  - `_ensure_viewport()` should default to `UPDATE_DISABLED` (not `UPDATE_ALWAYS`) so the viewport never renders before first cook
- **No per-frame overhead when static:** A non-time-dependent NoiseTOP with unchanged params produces zero GPU render passes after its initial cook
- **Expression-driven params are safe:** Expression evaluation that changes a param marks the node dirty → re-cook → `UPDATE_ONCE` fires → exactly one render pass. No difference from `UPDATE_ALWAYS` in that scenario, but saves the render pass when the expression result is unchanged
- **SOP/DAT/CHOP equivalent:** The cook engine already skips `_cook()` on clean nodes. No additional mechanism needed — just never set `time_dependent = true` unless the operator genuinely changes every frame

### 25.14 Tooltip Descriptions — Mandatory for Every Operator

- **Every operator MUST provide three levels of description:**
  1. `node_description` — set in `_init()` alongside `node_type` and `family`. Short sentence describing the node's purpose (shown in palette tooltip and node header).
  2. **Port descriptions** — last argument (`desc`) on every `add_input()` / `add_output()` call in `_init_ports()`. Describes what the port expects or produces.
  3. **Parameter descriptions** — last argument (`p_description`) on every `GNParameter.create_*()` call in `_init_parameters()`. Describes what the parameter controls.
- **Factory method pattern:** `p_description` is always the LAST positional argument, after `p_label`. If a parameter has no custom label, pass `""` for `p_label` before the description: `create_float("size", 1.0, 0.0, 10.0, 0.1, "", "Widget size in pixels")`.
- **Port method pattern:** `desc` is the last arg: `add_input("in", GNFamily.Type.TOP, false, "Input texture")`.
- **UI wiring (already implemented):**
  - Inspector: `GNParamRow` sets `tooltip_text` on the parameter name label from `param.description`.
  - Graph ports: `GNNodeView._build_slots()` sets `tooltip_text` on the row container from port descriptions.
  - Palette: `GNNodePalette` shows `_get_operator_description()` as tree-item tooltip.
- **When adding a new operator:** follow this rule or the node will have empty tooltips.

### 25.15 Dynamic Port Counts — Runtime-Adjustable I/O Ports

- **Goal:** Nodes whose input (or output) count is logically variable should expose a parameter or auto-detection mechanism that adds/removes ports at runtime instead of wasting fixed slots.
- **Base-class API (GNNode):**
  - `set_input_count(count, port_family, name_prefix, desc_prefix)` — clears all input ports, rebuilds `count` sequentially-named ports, emits `ports_changed(node_id)`.
  - `set_output_count(…)` — same for outputs.
  - `signal ports_changed(node_id: String)` — fired after any port-count change.
- **Graph wiring (GNGraphEditor + GNNetwork):**
  - `GNGraphEditor` connects to `ports_changed` **before** `GNNodeView.setup()` so stale wires are pruned first.
  - `GNNetwork.prune_stale_connections(node_id)` removes any connection whose port index exceeds the node's current port count, emitting `connection_removed` for each.
  - `GNNodeView` listens for `ports_changed` and calls `rebuild_slots()` to update the visual GraphNode.
- **Parameter-driven pattern (Switch / Merge nodes):**
  - Add a `num_inputs` INT parameter (min 2, max 8, default 2).
  - Override `_on_parameter_changed` — when `num_inputs` changes, call `set_input_count()` and clamp the `index` parameter's `max_value` to `num_inputs - 1`.
  - Applies to: SwitchTOP, SwitchCHOP, SwitchDAT, SwitchSOP, MergeCHOP.
- **Shader-driven pattern (CustomShaderTOP):**
  - On shader recompile, scan for `uniform sampler2D gn_tex<N>` declarations.
  - Rebuild input ports to match the highest `gn_tex` index found + 1 (clamped 0-8).
  - No explicit `num_inputs` parameter — the shader source is the single source of truth.
- **Resource motivation:** Every unused TOP input port can imply an idle SubViewport. Fewer ports = fewer GPU resources wasted.
- **When adding a new operator with variable port count:** follow either the parameter-driven or auto-detection pattern above. Always emit `ports_changed` after modifying port arrays.

### 25.16 Canvas Anchoring in TOP SubViewports

- **Problem:** Setting `_canvas.size = Vector2(res)` manually causes rendering glitches when switching between inputs with different resolutions. The canvas can end up smaller than the viewport or positioned incorrectly, producing clipped or offset output.
- **Root cause:** Manual size management has timing issues with Godot's layout system. When the viewport resizes, the canvas may not update in the same frame.
- **Solution:** Use `_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` AFTER `add_child(_canvas)` (anchors require a parent). The canvas auto-fills its parent viewport at any resolution. In `_cook()`, only set `_viewport.size = res` — the canvas follows automatically via anchors.
- **Critical:** Use `set_anchors_and_offsets_preset()`, NOT `set_anchors_preset()`. The latter only sets anchor values but adjusts offsets to maintain the current rect (which is zero-sized), resulting in an invisible canvas. `set_anchors_and_offsets_preset()` properly zeroes offsets so the Control fills the parent.
- **Applies to:** All 21 TOP operators with SubViewports (every file in `operators/top/` except null_top, switch_top, render_top, window_top).
- **Special cases:** `blur_top.gd` has 2 canvases (`_canvas_h`, `_canvas_v`), `text_top.gd` has `_bg` + `_label` — all get anchors.

### 25.17 Viewer Panel Sizing — TextureRect expand_mode

- **Problem:** The ViewerPanel (TOP preview) forces the entire right panel to grow when displaying a wide texture (e.g., 512x256 = 2:1 ratio doubles the panel width).
- **Root cause:** `TextureRect.expand_mode = EXPAND_FIT_HEIGHT` (value 3) scales the texture to fit the panel's height, then demands width matching the texture's aspect ratio. This feeds back into the SplitContainer's minimum size calculation.
- **Solution:** Use `expand_mode = EXPAND_IGNORE_SIZE` (value 1). The TextureRect reports zero minimum size, so the panel is freely resizable. Combined with `stretch_mode = KEEP_ASPECT_CENTERED` (value 5), the texture renders with correct proportions inside whatever space is available.
- **Also:** Set `clip_contents = true` and a small `custom_minimum_size.y = 40` on both ViewerPanel and InspectorPanel so the VSplitContainer allows them to shrink freely.

### 25.18 Node Renaming — Full ID Update Chain

- **Feature:** Double-click a node's title bar to rename it inline. Press Enter or click away to commit.
- **Implementation chain:**
  1. `GNNodeView._gui_input()` detects double-click in the title bar area (y <= 30px)
  2. A `LineEdit` is added as an overlay (NOT as a GraphNode child row — but since GraphNode auto-slots children, we must call `reset_size()` after removal to prevent height growth)
  3. On commit, `rename_requested(old_id, new_id)` signal fires
  4. `GNGraphEditor._on_node_rename_requested()` calls `network.rename_node()`
  5. `GNNetwork.rename_node()` updates: nodes dict key, `GNNode.id`, `GNNode.name`, all `GNConnection` references, expression strings across all params, then emits `node_renamed`
  6. `GNGraphEditor._on_network_node_renamed()` disconnects visual wires under old name, updates `_node_views` dict key, calls `view.apply_rename()`, reconnects wires, re-emits `operator_selected`
  7. `gn_editor.gd._on_node_renamed()` updates `_viewer_node_id` if renamed node was being viewed
  8. Inspector refreshes header label on re-inspect of same node object
- **Validation:** IDs must match `^[a-zA-Z_][a-zA-Z0-9_]*$` (alphanumeric + underscore, starts with letter or underscore). Empty and duplicate IDs are rejected.
- **GraphNode.name matters:** GraphEdit uses `GraphNode.name` for wire routing. The `name` property MUST be updated atomically with the visual wire disconnect/reconnect to avoid orphaned connections.

---

## 26. Known Bugs

### 26.1 WindowTOP: ESC to Exit Fullscreen Not Working

- **Issue:** When the output window is in Fullscreen or Borderless mode with Always On Top enabled, the user cannot escape back to windowed mode
- **Root cause:** Input events in a child `Window` node stay in that window's viewport tree. `Input.is_action_just_pressed()` polled from the parent node's `_process()` never sees them. Attempts with `gui_input` on a focusable `TextureRect` inside the window also failed to trigger
- **Workaround:** Change Window Mode back to Windowed from the inspector (requires access to the main editor window)
- **Planned fix:** Investigate `Window._unhandled_input()` override, or a dedicated `SubViewport` overlay with `_input()` handler inside the output window
- **Priority:** Low — does not affect core functionality, only UX convenience

---

## 27. Code-Based / Scriptable Operators — Architecture & Roadmap

This section defines the strategy for operators where the user writes executable code (shaders, GDScript, or future languages). These are the GONODES equivalents of TouchDesigner's GLSL TOP, Script CHOP, Script SOP, and Python-based DATs.

### 27.1 Design Philosophy

1. **Sandboxed execution** — User code runs inside controlled contexts (shader uniforms, `Expression.execute()`, or dedicated `RefCounted` subclasses). Never `eval()` arbitrary strings on the main thread without containment.
2. **Stable uniform/API contract** — Each scriptable operator defines a fixed set of inputs, outputs, and auto-bound variables. User code plugs into a well-defined slot; the framework handles plumbing.
3. **Graceful failure** — Shader compilation errors, GDScript parse errors, and runtime exceptions are caught, logged, and the operator falls back to its last-good output. The network never crashes from user code.
4. **Hot-reload** — Code changes recompile/re-evaluate without restarting the cook engine. Shader recompilation is synchronous; GDScript re-parse should be deferred to avoid frame spikes.

### 27.2 Implemented: CustomShaderTOP (GLSL TOP)

**Status: ✅ Done**

The user provides a complete `shader_type canvas_item;` shader. The operator:
- Accepts up to **4 texture inputs** (`gn_tex0` … `gn_tex3`)
- Exposes **4 float uniforms** (`gn_float0` … `gn_float3`) bound to inspector params
- Exposes **2 color uniforms** (`gn_color0`, `gn_color1`)
- Exposes **resolution** (`gn_resolution`) and Godot's built-in `TIME`
- Recompiles when `shader_code` string changes; keeps last-good shader on failure
- Default template is a simple pass-through for rapid prototyping

**Limitations:**
- Godot does not surface shader compilation errors programmatically — they go to the editor output console. Future: parse console output or use RenderingServer API if exposed.
- Single-pass only. Multi-pass requires chaining multiple CustomShaderTOP nodes.

### 27.3 Planned: ScriptCHOP (GDScript CHOP)

**Status: 🔲 Planned — Near-term priority**

The GDScript equivalent of TouchDesigner's Script CHOP. The user writes a GDScript snippet that runs every cook and returns channel data.

**Design:**
```
class_name ScriptCHOP extends GNNode

# User-facing API (injected into Expression.execute or custom RefCounted):
#   in0: GNChannelData — channels from input 0
#   in1: GNChannelData — channels from input 1
#   me:  GNNode        — self-reference (access own params)
#   time, frame, dt    — engine time variables
#
# Return: Dictionary { "chan_name": float_or_array, ... }
```

**Implementation approach:**
- Option A (MVP): Use Godot's `Expression` system — same as parameter expressions but returning a Dictionary. Simple, but limited to single-line expressions or small lambdas.
- Option B (Full): Use a dynamically-loaded GDScript `Resource`. The user writes a script extending a `GNScriptContext` base class with an overridable `_evaluate()` method. The ScriptCHOP loads/caches this script and calls `_evaluate()` each cook. This gives full GDScript power (loops, variables, classes).
- **Recommendation:** Start with Option A for quick scripting, add Option B for complex logic.

**Uniform contract:**
```gdscript
# User writes:
func _evaluate(in0: GNChannelData, in1: GNChannelData,
               time: float, frame: int, dt: float) -> Dictionary:
    var lfo_val = in0.get_value("out") if in0 else 0.0
    return { "processed": lfo_val * 2.0 + sin(time) }
```

### 27.4 Planned: ScriptDAT (GDScript DAT)

**Status: 🔲 Planned**

Processes table/text data via user GDScript. DAT family and GNTableData are now implemented.

**Design:**
```gdscript
# User writes:
func _evaluate(in_table: GNTableData, me: GNNode,
               time: float) -> GNTableData:
    var out = GNTableData.new()
    for row in in_table.rows:
        if float(row["value"]) > 0.5:
            out.append_row(row)
    return out
```

**Key decisions:**
- GNTableData: Dictionary-of-arrays (column-major) or Array-of-Dictionaries (row-major)? TD uses row-major. Recommend row-major for user-friendliness.
- String manipulation: full GDScript string API available (regex, split, JSON parse)
- File I/O: sandboxed to project directory only (user:// paths)

### 27.5 Planned: ScriptTOP (GDScript TOP)

**Status: 🔲 Planned — Medium-term**

The user writes GDScript that generates/manipulates pixel data on the CPU. Useful for procedural generation that's easier to express in code than shaders.

**Design:**
```gdscript
# User writes:
func _evaluate(in_img: Image, me: GNNode,
               time: float) -> Image:
    var out = Image.create(512, 512, false, Image.FORMAT_RGBA8)
    for y in range(512):
        for x in range(512):
            var u = float(x) / 512.0
            var v = float(y) / 512.0
            out.set_pixel(x, y, Color(u, v, sin(time) * 0.5 + 0.5, 1.0))
    return out
```

**Performance considerations:**
- CPU pixel loops are slow for large resolutions. This is intentional — ScriptTOP is for prototyping or small textures.
- For production GPU work, users should use CustomShaderTOP.
- We could offer a compute shader variant later (ComputeShaderTOP).

### 27.6 Planned: ComputeShaderTOP (GPU Compute)

**Status: 🔲 Planned — Long-term**

Uses Godot's `RenderingDevice` compute shader API for massively parallel GPU operations.

**Design:**
- User writes a GLSL compute shader
- Framework handles buffer creation, dispatch, and readback
- Useful for: particle simulation, fluid dynamics, image processing at scale
- Depends on Godot's compute shader stability and RenderingDevice API maturity

### 27.7 Planned: ScriptSOP (GDScript SOP)

**Status: 🔲 Planned**

Procedural geometry generation/manipulation via GDScript. SOP family and GNGeoData are now implemented. User receives mesh data arrays and returns modified arrays.

### 27.8 Implementation Priorities

| Priority | Operator | Depends On | Complexity |
|----------|----------|------------|------------|
| ✅ Done | CustomShaderTOP | — | Medium |
| 🥇 Next | ScriptCHOP | GNScriptContext base class | Medium |
| 🥈 | ScriptDAT | — (DAT family done) | Medium-High |
| 🥉 | ScriptTOP | — | Low (but slow) |
| Later | ComputeShaderTOP | RenderingDevice API | High |
| Later | ScriptSOP | — (SOP family done) | High |

### 27.9 Shared Infrastructure: GNScriptContext

All GDScript-based scriptable operators will share a common base class:

```gdscript
class_name GNScriptContext extends RefCounted
## Base class for user-written script contexts.
## Subclassed dynamically or used via Expression.

var _script_text: String = ""
var _compiled: bool = false
var _error: String = ""
var _last_good_result: Variant = null

func compile(code: String) -> bool:
    # Parse and validate the GDScript code
    # Return true on success, false on error
    pass

func execute(inputs: Array, variables: Dictionary) -> Variant:
    # Run the compiled code with the given inputs/variables
    # On error, return _last_good_result (graceful fallback)
    pass
```

This gives us:
- **Consistent error handling** across all script operators
- **Hot-reload** without restarting
- **Sandboxing** via controlled variable injection
- **Caching** of last-good results for smooth failure recovery

### 27.10 UI Considerations for Code Editing

Current string parameters use single-line `LineEdit`. Code-based operators need:

1. **Phase 1 (MVP):** Multi-line `TextEdit` in the inspector for shader/script code. Monospace font, basic syntax highlighting via Godot's `CodeEdit` control.
2. **Phase 2:** Popup code editor window (resizable, with line numbers, error gutter).
3. **Phase 3:** Integration with external editor (VS Code) via file-on-disk + file watcher.

**Implementation plan:**
- Add `ValueType.CODE` to `GNParameter` (or detect `shader_code` / `script_code` param names)

---

## 28. Extension Architecture (GNExtensionRegistry)

### 28.1 Overview

GONODES uses a dynamic operator registry (`GNExtensionRegistry`) to manage all operators — both built-in core operators and third-party extension-provided operators. This replaces the previous approach of hardcoded match-block factories and static description dictionaries, enabling a plugin-friendly architecture where GDExtension addons can register new operators without modifying core code.

### 28.2 Registry Singleton

`GNExtensionRegistry` is a `RefCounted`-based lazy singleton accessed via `GNExtensionRegistry.instance()`. It is initialized on first access, at which point all 78 core operators are registered via `_register_core_operators()`. Extension scanning happens explicitly via `scan_extensions()`, called during editor startup (`gn_editor.gd._ready()`).

### 28.3 OperatorEntry

Each registered operator is stored as an `OperatorEntry` with:
- `family: String` — TOP, CHOP, SOP, DAT, MAT, COMP, POP
- `script: GDScript` — the preloaded GDScript class (supports `.new()`)
- `description: String` — one-line tooltip for the palette
- `source: String` — "core" or the extension name that provided it

### 28.4 API Surface

| Method | Returns | Purpose |
|--------|---------|---------|
| `register_operator(name, family, script, desc, source)` | void | Register an operator |
| `unregister_operator(name)` | void | Remove an operator |
| `create_instance(name)` | GNNode | Data-driven factory (replaces match block) |
| `get_operator_registry()` | Dictionary | `{ "TOP": [...], "CHOP": [...] }` — palette data |
| `get_description(name)` | String | Tooltip text |
| `has_operator(name)` | bool | Existence check |
| `get_operator_count()` | int | Total registered operators |
| `get_all_operator_names()` | PackedStringArray | All registered names |
| `get_loaded_extensions()` | PackedStringArray | Loaded extension folder names |
| `scan_extensions()` | void | Discover and load `gn_ext_*` addons |

### 28.5 Extension Convention

Extensions live under `res://addons/gn_ext_<name>/` and contain a `gn_extension.cfg` manifest (ConfigFile format):

```ini
[extension]
name="FFmpeg Video Support"
version="1.0.0"
author="GONODES"
description="FFmpeg-powered video decoding. Adds FFmpegInTOP with H.264, H.265, VP9, AV1 and broad format support."
dependencies=["FFmpegVideoStream"]

[operator.FFmpegInTOP]
family="TOP"
script="res://addons/gn_ext_ffmpeg/operators/top/ffmpeg_in_top.gd"
description="FFmpeg video decoder. H.264, H.265, VP9, AV1 and more."
```

### 28.6 Dependency Guards

Before loading an extension's operators, the registry checks `ClassDB.class_exists()` for each class listed in `dependencies`. If any dependency is missing (e.g., the GDExtension `.dll`/`.so` is not installed), the entire extension is skipped with a warning — no crash, no error.

### 28.7 Loading Flow

1. **Editor startup** → `gn_editor.gd._ready()` calls `GNExtensionRegistry.instance().scan_extensions()`
2. **First access** → `instance()` creates the singleton and runs `_register_core_operators()` (82 core operators)
3. **scan_extensions()** → iterates `res://addons/gn_ext_*/gn_extension.cfg`, checks dependencies, loads operator scripts
4. **Palette/Factory** → `GNGraphEditor.get_operator_registry()` and `_create_operator_instance()` delegate to the registry
5. **Palette tooltips** → `GNNodePalette._get_operator_description()` delegates to registry

### 28.8 Future Extensions (Roadmap)

| Extension | Folder | Dependencies | Operators | Status |
|-----------|--------|-------------|-----------|--------|
| FFmpeg | `gn_ext_ffmpeg` | `FFmpegVideoStream` | FFmpegInTOP | ✅ Done |
| Kinect | `gn_ext_kinect` | `KinectTracker` | KinectCHOP, KinectPointCloudSOP | Planned |
| NDI | `gn_ext_ndi` | `NDIFinder` | NDIInTOP, NDIOutTOP | Planned |
| Spout | `gn_ext_spout` | `SpoutSender` | SpoutInTOP, SpoutOutTOP | Planned |
| MIDI | `gn_ext_midi` | — | MidiInCHOP, MidiOutCHOP | Planned |
- `GNParamRow` creates a `CodeEdit` instead of `LineEdit` for CODE-type params
- `CodeEdit` supports syntax highlighting for `.gdshader` and `.gd` automatically
- Apply-on-blur or explicit "Compile" button to avoid recompiling on every keystroke

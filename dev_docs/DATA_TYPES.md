# GONODES Data Types — Internals

> **Audience:** Contributors, extension authors.
> **User-facing reference:** GONODES_CONTEXT.md §5

This document covers the data type hierarchy, the copy-on-write (COW)
sharing model, consumer count tracking, and the `_mutable_input()` pattern
that prevents data corruption at fan-out points.

---

## Table of Contents

1. [Data Type Hierarchy](#1-data-type-hierarchy)
2. [GNData Base Class](#2-gndata-base-class)
3. [Family Data Types](#3-family-data-types)
4. [Copy-on-Write (COW) Model](#4-copy-on-write-cow-model)
5. [Consumer Count Tracking](#5-consumer-count-tracking)
6. [The \_mutable\_input() Pattern](#6-the-_mutable_input-pattern)
7. [When COW Doesn't Apply](#7-when-cow-doesnt-apply)
8. [Extension Data Types](#8-extension-data-types)

---

## 1. Data Type Hierarchy

```
GNData (RefCounted)
├── GNTextureData     (TOP)  — GPU texture + SubViewport metadata
├── GNChannelData     (CHOP) — named float channel arrays
├── GNGeoData         (SOP)  — ArrayMesh + point attributes
├── GNTableData       (DAT)  — 2D string table + text buffer
├── GNMaterialData    (MAT)  — Godot Material wrapper
├── GNPopData         (POP)  — GPU particle state (SSBO RIDs)
├── GNVolumeData      (VOL)  — Texture3D compute volumes
├── GNCompData        (COMP) — 3D scene node reference
├── GNUiData          (UI)   — Control node reference
└── [Extension types]        — e.g. GNSDFData (SDF family)
```

All data types are `RefCounted` — they are transient compute results, never
serialized to disk. The cook engine passes them between nodes by reference.

---

## 2. GNData Base Class

```gdscript
class_name GNData
extends RefCounted

var valid: bool = false         # True after a successful cook
var timestamp: int = -1         # Frame number when last produced

## Set by the cook engine -- true when this output feeds 2+ downstream
## consumers. Operators must never set this directly.
var _shared: bool = false

## Generic sideband metadata dictionary for passing operator-specific info
## alongside the main data payload.  Producers set keys; consumers read them.
## Example: FixtureSamplerTOP sets metadata["fixture_manifest"] so downstream
## nodes can read the manifest without walking the graph.
var metadata: Dictionary = {}
```

Every data subclass must implement:

| Method | Purpose |
|--------|---------||
| `duplicate_data() -> GNData` | Deep copy for COW -- copies all payload fields, including `metadata.duplicate(true)` |
| `get_preview_text() -> String` | Compact text for viewer info bar |

### Sideband Metadata

The `metadata` dictionary carries operator-specific information alongside the
main payload without requiring graph-walking or upstream type checks. The
producer sets keys during `_cook()`; downstream consumers read them from the
input data. `duplicate_data()` always deep-copies the dictionary.

Use metadata when an operator produces information that downstream nodes need
but that does not belong in the primary data payload (texture, channels, etc.).
Never use metadata as a substitute for wired connections or proper data fields.

```gdscript
# Producer (in _cook):
_cached_tex_data.metadata["fixture_manifest"] = _fixture_manifest
return _cached_tex_data

# Consumer (in _cook):
var manifest: Array = tex_data.metadata.get("fixture_manifest", [])
if manifest.is_empty():
    node_warning = "Input has no fixture_manifest metadata."
    return null
```

---

## 3. Family Data Types

### GNTextureData (TOP)

```gdscript
var texture: Texture2D = null
var viewport: SubViewport = null
var resolution: Vector2i = Vector2i(512, 512)
var format: Image.Format = Image.FORMAT_RGBA8
```

TOPs produce GPU textures via SubViewport rendering. Downstream TOPs sample
textures via shader `uniform sampler2D` — inherently read-only. **COW is
unnecessary for the TOP pipeline** (see §7).

### GNChannelData (CHOP)

```gdscript
var channels: Dictionary = {}    # { "chan_name": PackedFloat32Array }
var sample_rate: float = 60.0
var length: int = 1
```

Key methods:
- `get_value(channel_name, index=-1)` — returns float (-1 = latest sample)
- `set_channel(name, samples)` — set a channel's data
- `get_channel_names()` — list all channel names

CHOPs pass `PackedFloat32Array` data by reference. In-place operators
(e.g. MathCHOP adding a scalar) must use `_mutable_input()`.

### GNGeoData (SOP)

```gdscript
var mesh: ArrayMesh = null
var transform: Transform3D = Transform3D.IDENTITY
var bounds: AABB = AABB()
var vertex_count: int = 0
var point_attribs: Dictionary = {}
```

Key methods:
- `set_from_surface_tool(st)` — commit a SurfaceTool to the mesh
- `has_geometry()` — true if mesh has surfaces
- `get_point_attrib_color()` — reads Cd point attribute as PackedColorArray

### GNTableData (DAT)

```gdscript
var table: Array[PackedStringArray] = []
var has_header: bool = true
var text: String = ""
var is_table: bool = true
```

Dual-mode: table mode (`is_table = true`) stores rows × columns; text mode
stores a plain string in `text`.

### GNMaterialData (MAT)

```gdscript
var material: Material = null
var material_label: String = ""
```

Wraps any Godot `Material` subclass (StandardMaterial3D, ShaderMaterial,
ORMMaterial3D, etc.).

---

## 4. Copy-on-Write (COW) Model

Node outputs are shared by reference. When a node's output feeds multiple
downstream consumers (fan-out), the cook engine sets `_shared = true` on
the output data. This is the signal that in-place mutation is unsafe.

### The Problem

```
NoiseIMG ──┬──→ BlurIMG
           └──→ PixelSortIMG
```

If BlurIMG modifies the pixel array in-place, PixelSortIMG receives the
already-blurred image instead of the original noise. Both operators would
corrupt each other's inputs.

### The Solution

The cook engine tracks consumer counts per node output. When count > 1,
`_shared = true`. Operators that need to mutate input data call
`_mutable_input(data)` which checks the flag and duplicates only when needed.

```
Fan-out (2 consumers):  _shared = true  → _mutable_input() duplicates
Single consumer:        _shared = false → _mutable_input() returns original (zero copy)
```

---

## 5. Consumer Count Tracking

The cook engine maintains `_consumer_counts: Dictionary` mapping
`node_id → int` — the number of downstream connections from that node.

### Rebuild Trigger

Consumer counts are rebuilt when:
- Topology changes (wire added/removed)
- Active set changes (viewer target switched)
- `_consumer_counts_dirty` flag is set

### Viewer-Aware Counting

The viewer panel reads `cached_output` outside the normal data-flow graph —
it's an invisible consumer. The rebuild counts the viewed node itself, and
also that node's immediate upstream (a passthrough viewer is showing the
upstream buffer):

```gdscript
for sink_id in active_sinks:
    _consumer_counts[sink_id] = _consumer_counts.get(sink_id, 0) + 1
    for conn in network.get_input_connections(sink_id):
        _consumer_counts[conn.from_node] = _consumer_counts.get(conn.from_node, 0) + 1
```

Without the self-count, a viewer on NoiseIMG plus one wire into PixelSortIMG
is only one consumer. PixelSort then mutates the image the viewer is showing.

`_shared` is stamped only on an object the cooking node created. A node that
returns an input (`NullCHOP`, bypass) must not write `_shared` onto that
object — doing so clears the producer's flag from the passthrough's own
consumer count.

### Shared Flag Propagation

After a node cooks, the engine sets `_shared` on the object that cook
created, from that node's consumer count. It does not write the flag onto
an input object the cook returned unchanged.

---

## 6. The \_mutable\_input() Pattern

Defined on `GNNode`, this is the correct way for operators to get a
modifiable copy of input data:

```gdscript
func _mutable_input(data: GNData) -> GNData:
    if data == null:
        return null
    if data._shared:
        return data.duplicate_data()
    return data
```

### Usage in Operators

```gdscript
# BlurIMG — needs to modify pixel data in-place
func cook(ctx: Dictionary) -> void:
    var src: GNData = get_input_value(0)
    if src == null:
        return
    var img_data := _mutable_input(src) as GNImgData  # ← safe copy if shared
    _apply_blur(img_data.image)
    set_output_value(0, img_data)
```

### Rules

1. **Built-in operators** that modify input data **must** use `_mutable_input()`.
2. **Script operators** do NOT auto-copy. If user code mutates `inputs[0]`
   directly at a fan-out point, it will corrupt upstream data. Users must
   call `inputs[0].duplicate_data()` manually.
3. **Generator operators** (no input, produce fresh data) don't need COW.
4. **Filter operators** that only read inputs (e.g. AnalyzeCHOP) don't need COW.

---

## 7. When COW Doesn't Apply

### TOPs (GPU Pipeline)

Each TOP renders into its own SubViewport, producing a fresh GPU texture
every cook. Downstream TOPs sample that texture via shader
`uniform sampler2D` — inherently read-only. No downstream TOP can mutate
an upstream TOP's framebuffer. COW is unnecessary for the GPU pipeline.

### Read-Only Operators

Operators that only read input data to produce new output (e.g.
AnalyzeCHOP reads channels to compute statistics, produces a new
GNChannelData with the results) don't need `_mutable_input()`.

### Families Summary

| Family | COW Needed? | Reason |
|--------|-------------|--------|
| TOP | No | GPU textures are read-only via samplers |
| IMG | **Yes** | CPU Image pixels passed by reference |
| CHOP | **Yes** | PackedFloat32Array channels by reference |
| SOP | **Yes** | ArrayMesh arrays by reference |
| DAT | **Yes** | Table rows by reference |
| MAT | **Yes** | Material properties by reference |
| POP | No | GPU SSBO handles, each node owns its buffer |
| VOL | No | Each node owns its Texture3D compute output |
| COMP | No | Scene node references, not mutable data |
| UI | No | Control node references, not mutable data |
| OUT | N/A | Sinks — consume but don't produce data |

### The GPU/CPU Family Rule

**Any operator that performs a GPU→CPU readback (texture download) must be in the IMG family, not TOP.**

This is a deliberate design rule. TOP operators are GPU-resident: they produce `GNTextureData` via SubViewport shaders and never stall the GPU pipeline. When an operator needs to read pixels back to the CPU (histogram analysis, blob detection, pixel sorting, etc.), the GPU→CPU transfer is expensive (1–5ms+). By placing these in the IMG family, users see the orange IMG color in their graph and immediately know "this node has a CPU cost". If an IMG result needs to go back to GPU, wire it through `ImgToTOP`.

Examples:
- `HistogramIMG` — reads TOP texture, computes histogram bins on CPU, outputs chart Image
- `TOPtoIMG` — explicit bridge operator (GPU readback)
- `PixelSortIMG` — CPU-bound pixel manipulation
- `ScreenGrabIMG` — viewport capture to CPU

The bridge pair `TOPtoIMG` / `ImgToTOP` makes the cost boundary visible in the graph.

---

## 8. Extension Data Types

Extensions that define new families must create a `GNData` subclass:

```gdscript
class_name GNSDFData
extends GNData

var sdf_tree: Array = []
var tree_hash: int = 0

func duplicate_data() -> GNData:
    var copy := GNSDFData.new()
    copy.valid = valid
    copy.timestamp = timestamp
    copy.sdf_tree = sdf_tree.duplicate(true)
    copy.tree_hash = tree_hash
    return copy

func get_preview_text() -> String:
    if sdf_tree.is_empty():
        return "Empty SDF tree"
    return "%d nodes, hash: %d" % [sdf_tree.size(), tree_hash]
```

Register the data factory in the manifest:

```ini
[family.SDF]
color = "0.95,0.65,0.15"
data_script = "res://addons/gn_ext_sdf/core/gn_sdf_data.gd"
```

The extension registry calls `GNFamily.register_data_factory()` so that
`GNFamily.create_data_for_family(family_id)` returns fresh instances of
the custom data class — used by the script annotation system when a script
declares `# @output sdf`.

### Marshalling Extension Data for Script Nodes

Script nodes (NativeSCRIPT, PythonSCRIPT) can produce and consume
extension data types via generic marshalling — no per-extension code
changes are needed in the wrappers.

**Input marshalling (`_marshal_extension`):** Converts a `GNData` subclass
to a plain Dictionary by checking for known properties. For example,
`GNSDFData` is serialized as `{"sdf_tree": [...], "tree_hash": N}`.

**Output building (`_build_extension`):** Creates a fresh `GNData`
instance via `GNFamily.create_data_for_family(family_id)` and sets
properties from the cook result dict.

This pattern means extension SDK authors only need to produce/consume
plain Dictionaries from C++ and Python code — the generic marshalling
bridge handles the GDScript data class conversion automatically.

### SDK Helpers for Extension Data

Extensions can ship SDK files that simplify creating/consuming their data
from script nodes:

| Language | SDK Location | Example (SDF) |
|----------|-------------|---------------|
| C++ | `addons/gn_ext_user_native/sdk/gn_user_sdf.h` | `gn::sdf_sphere()`, `gn::make_sdf_result()` |
| Python | `addons/gn_ext_user_python/sdk/gonodes/sdf.py` | `sdf_sphere()`, `make_sdf_result()` |
| GDScript | Direct `GNData` subclass API | `GNSDFData.sdf_tree = [...]` |

See `dev_docs/EXTENSIONS.md` §13 for the full extension SDK pattern.

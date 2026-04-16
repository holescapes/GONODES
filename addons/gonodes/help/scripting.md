# Scripting Guide

GONODES provides three scripting operators in the SCRIPT family for writing
custom logic directly in the node graph. Each supports multiple output
families via a template system.

---

## Script Operators

| Operator | Language | Use Case |
|----------|----------|----------|
| **GDScriptSCRIPT** | GDScript | General-purpose scripting, tightest Godot integration |
| **PythonSCRIPT** | Python | NumPy-based data processing, familiar syntax for TD users |
| **NativeSCRIPT** | C++ | Performance-critical custom operators with hot-reload |

All three share the same interface: a template dropdown, annotation-based
ports/params, and a built-in code editor (click "Edit ↗" in the inspector).

---

## Templates

The template dropdown selects what kind of data the script produces:

| Template | Output Family | Pre-populated Code |
|----------|---------------|-------------------|
| **CHOP** | Channel data | Writes named float channels |
| **SOP** | Geometry | Produces ArrayMesh via SurfaceTool |
| **DAT** | Table/text | Writes rows × columns or plain text |
| **IMG** | CPU image | Writes pixel data to an Image |
| **TOP** | GPU texture | Renders to a SubViewport (Python/Native only) |
| **Generic** | Any (via annotations) | Multi-output with `# @output` |

Changing the template replaces the code with a starter example for that
family. Your custom code is preserved if you switch back.

---

## Annotations

Annotations are special comments that declare dynamic ports and parameters.
The script engine parses them before compilation.

### Parameters — `# @param`

```gdscript
# @param float speed 1.0 Animation speed multiplier
# @param int count 10 Number of points
# @param bool active true Enable processing
# @param color tint 1.0,0.5,0.0,1.0 Tint color
# @param string label Hello Display text
# @param vec2 offset 0.0,0.0 Position offset
```

Format: `# @param <type> <name> <default> <description>`

Supported types: `float`, `int`, `bool`, `color`, `vec2`, `vec2i`, `string`, `file`

Access in code with `par("name")`:
```gdscript
var s = par("speed")
var n = par("count")
```

### Inputs — `# @input`

```gdscript
# @input chop Upstream signal data
# @input sop Geometry to deform
```

Format: `# @input <family> <description>`

Adds a typed input port. Access via `inputs[0]`, `inputs[1]`, etc.

### Outputs — `# @output` (Generic template only)

```gdscript
# @output chop Processed channels
# @output sop Generated geometry
# @output dat Status table
```

Format: `# @output <family> <description>`

Adds typed output ports. Write to `outputs[0]`, `outputs[1]`, etc.
This is how GDScriptSCRIPT's Generic template produces multiple data types
simultaneously.

---

## Context Variables

These variables are available in every script, injected automatically:

| Variable | Type | Description |
|----------|------|-------------|
| `me` | GNNode | The script node itself |
| `inputs` | Array | Input data from upstream connections |
| `outputs` | Array | Pre-populated output data objects |
| `op` | GNData | Alias for `outputs[0]` (convenience) |
| `time` | float | Seconds elapsed since engine start |
| `frame` | int | Current frame number |
| `dt` | float | Delta time this frame |

---

## Helper Functions

### Parameter Access

| Function | Returns | Description |
|----------|---------|-------------|
| `par(name)` | Variant | Read this node's parameter value |

### Cross-Node Data References

| Function | Returns | Description |
|----------|---------|-------------|
| `chop(id, chan, index)` | float | Read a CHOP channel value (also accepts port arg) |
| `top(id, property)` | Variant | Read a TOP property (also accepts port arg) |
| `sop(id)` | GNGeoData | Get a SOP node's geometry data |
| `dat(id, row, col)` | Variant | Read a DAT cell or full table |
| `op_ref(id, param)` | Variant | Read any node's parameter |

### Parameter Writing

| Function | Returns | Description |
|----------|---------|-------------|
| `set_par(name, value)` | bool | Set a parameter on this node |
| `set_par(node_id, name, value)` | bool | Set a parameter on another node |

`set_par()` triggers dirty propagation automatically — the target node
and its downstream chain will re-cook.

### Network API

Build and modify the node graph from scripts:

| Function | Returns | Description |
|----------|---------|-------------|
| `network_add_node(type, id)` | String | Create a node (returns assigned ID) |
| `network_remove_node(id)` | bool | Delete a node |
| `network_connect(from, port, to, port)` | bool | Wire two nodes |
| `network_disconnect(from, port, to, port)` | bool | Remove a wire |
| `network_node_ids()` | PackedStringArray | List all node IDs |
| `network_node_info(id)` | Dictionary | Get node type, family, params |

### Example — Procedural Graph Construction

```gdscript
# @output dat Status log

func cook():
    op.set_headers(PackedStringArray(["action", "detail"]))

    # Create an LFO driving a Math node
    var lfo = network_add_node("LfoCHOP", "auto_lfo")
    var math = network_add_node("MathCHOP", "auto_math")

    # Wire LFO → Math
    network_connect(lfo, 0, math, 0)

    # Set parameters on the new nodes
    set_par(lfo, "frequency", 2.0)
    set_par(math, "multiply", 10.0)

    op.append_row(PackedStringArray(["created", lfo + " → " + math]))
```

---

## CHOP Template Example

```gdscript
# @param float frequency 1.0 Oscillation frequency
# @param float amplitude 1.0 Output amplitude

func cook():
    var freq = par("frequency")
    var amp = par("amplitude")

    var samples = PackedFloat32Array()
    samples.append(sin(time * freq * TAU) * amp)

    op.set_channel("wave", samples)
    op.valid = true
```

## SOP Template Example

```gdscript
# @param int num_points 100 Number of points in the spiral
# @param float radius 2.0 Spiral radius
# @param float height 3.0 Spiral height

func cook():
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_POINTS)

    var n = par("num_points")
    for i in range(n):
        var t = float(i) / float(n)
        var angle = t * TAU * 4.0
        var r = par("radius") * t
        var pos = Vector3(cos(angle) * r, t * par("height"), sin(angle) * r)
        st.add_vertex(pos)

    st.generate_normals()
    op.set_from_surface_tool(st)
    op.valid = true
```

## DAT Template Example

```gdscript
# @param string greeting Hello Custom greeting text

func cook():
    op.set_headers(PackedStringArray(["key", "value"]))
    op.append_row(PackedStringArray(["time", str(time)]))
    op.append_row(PackedStringArray(["frame", str(frame)]))
    op.append_row(PackedStringArray(["message", par("greeting")]))
    op.valid = true
```

## IMG Template Example

```gdscript
# @param int width 256 Image width
# @param int height 256 Image height
# @param color fill_color 1.0,0.0,0.0,1.0 Fill color

func cook():
    var w = par("width")
    var h = par("height")
    var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(par("fill_color"))
    op.image = img
    op.valid = true
```

---

## Tips

- Press **Ctrl+Enter** in the code editor to apply changes immediately.
- Use the **Presets** dropdown in the code editor toolbar to save/load code snippets.
- Use `print()` in scripts — output appears in the Godot console and the Textport log panel.
- Scripts have a **cook-once pulse** mode: right-click the node → "Cook Once" to run the
  script a single time instead of every frame.
- When using `set_par()` to write to other nodes, be careful not to create
  circular dependencies (A sets B's param, B sets A's param). The engine
  detects and breaks circular expression references, but `set_par()` writes
  bypass this protection.
- Script operators in the **Generic** template can output multiple families
  simultaneously — useful for analysis nodes that produce both a data table
  and a visualization texture.

---

## Help Patches

Open the Help window (F1) and navigate to the Script section for interactive
examples. Available patches include:

- Basic scripting for each template (CHOP, SOP, DAT, IMG)
- Time-dependent animation
- Cross-node parameter reading with `chop()` and `op_ref()`
- Parameter writing with `set_par()`
- Multi-output Generic template
- Network API procedural graph construction

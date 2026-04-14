# Expressions Guide

Expressions let you drive parameter values with code instead of static constants.
Any parameter can be switched to expression mode by clicking the **C** button
(which changes to **E**). The expression is evaluated every cook frame.

---

## Input Variables

These variables are available in every expression:

| Variable | Type    | Description                                     |
|----------|---------|-------------------------------------------------|
| `me`     | GNNode  | The node this parameter belongs to               |
| `time`   | float   | Seconds elapsed since the cook engine started    |
| `frame`  | int     | Current frame number (increments each cook)      |
| `dt`     | float   | Delta time for this frame (seconds)              |

### Examples

```gdscript
# Oscillate a float parameter over time
sin(time * 2.0) * 0.5 + 0.5

# Frame-based stepping
frame % 60

# Smooth delta-time accumulation
time * 10.0
```

---

## Cross-Node References

Four functions let you read values from other nodes in the network.
They are called as methods, not variables — just type them directly.

### `chop(node_id, channel, index)`

Reads a CHOP channel value (returns `float`).

| Argument   | Type   | Required | Description                                    |
|------------|--------|----------|------------------------------------------------|
| `node_id`  | String | yes      | The ID of the CHOP node (e.g. `"lfo1"`)        |
| `channel`  | String | yes      | Channel name (e.g. `"out"`, `"chan1"`)          |
| `index`    | int    | no       | Sample index. `-1` or omitted = latest sample  |

```gdscript
# Read the LFO output
chop("lfo1", "out")

# Read sample 0 explicitly
chop("lfo1", "out", 0)

# Scale and offset an LFO (-1..1) to (0..512)
chop("lfo1", "out") * 256.0 + 256.0

# Read a specific channel from a MathCHOP
chop("math1", "result", 0)

# Get channel info dictionary (advanced)
chop("lfo1")
# → { "channels": ["out"], "length": 1, "sample_rate": 60 }

# --- UI Widget State ---
# Every UI widget has a "state" CHOP output with plain channel names.
# Read them exactly like any other CHOP:
chop("slider1", "value")
chop("knob1", "value")
chop("xy_pad1", "x")
chop("toggle1", "value")
chop("colorpicker1", "r")

# ContainerUI aggregates children — channels are prefixed with child ID:
chop("container1", "slider1:value")
chop("container1", "colorpicker1:r")
```

### `op(node_id, param_name)`

Reads another node's parameter value.

| Argument     | Type   | Required | Description                                  |
|--------------|--------|----------|----------------------------------------------|
| `node_id`    | String | yes      | The ID of any node (e.g. `"noise1"`)         |
| `param_name` | String | yes      | Parameter name (e.g. `"scale"`, `"speed"`)   |

```gdscript
# Read noise1's scale parameter
op("noise1", "scale")

# Use another node's speed to drive your own
op("lfo1", "speed") * 2.0

# Get full node info dictionary (advanced)
op("noise1")
# → { "par": { "scale": 1.0, ... }, "family": 1, "cook_time": 0.5, "valid": true }
```

### `top(node_id, property)`

Reads TOP (texture) metadata.

| Argument   | Type   | Required | Description                                  |
|------------|--------|----------|----------------------------------------------|
| `node_id`  | String | yes      | The ID of a TOP node (e.g. `"noise1"`)       |
| `property` | String | yes      | `"resolution"` (Vector2i) or `"aspect"` (float) |

```gdscript
# Get output resolution of a TOP
top("noise1", "resolution")
# → Vector2i(512, 512)

# Get aspect ratio
top("noise1", "aspect")
# → 1.0

# Match another TOP's resolution on one axis
top("render1", "resolution").x
```

### `chopp(node_id, port, channel, index)` — Port-Aware CHOP Read

Like `chop()` but targets a **specific output port** by name or index.
Essential for multi-output nodes (e.g., GDScriptSCRIPT with two CHOP outputs)
where `chop()` always picks the first CHOP port it finds.

| Argument   | Type          | Required | Description                                    |
|------------|---------------|----------|------------------------------------------------|
| `node_id`  | String        | yes      | The ID of the CHOP node                         |
| `port`     | String or int | yes      | Port name (e.g. `"out2"`) or port index (e.g. `1`) |
| `channel`  | String        | no       | Channel name (e.g. `"tx"`). Omit for info dict. |
| `index`    | int           | no       | Sample index. `-1` or omitted = latest sample   |

```gdscript
# Read "tx" from the second output port (by name)
chopp("script1", "out2", "tx")

# Read "tx" from port index 1
chopp("script1", 1, "tx")

# Read sample 5 of "tx" from port "out2"
chopp("script1", "out2", "tx", 5)
```

**Typed variant:** `choppf()` — guaranteed `float` return (same arguments).

### `topp(node_id, port, property)` — Port-Aware TOP Read

Like `top()` but targets a **specific output port** by name or index.
For multi-output TOPs (e.g., GLSLMultiTOP, MultiBufferRenderTOP) where
`top()` picks the first TOP port.

| Argument   | Type          | Required | Description                                    |
|------------|---------------|----------|------------------------------------------------|
| `node_id`  | String        | yes      | The ID of the TOP node                          |
| `port`     | String or int | yes      | Port name (e.g. `"out1"`) or port index (e.g. `1`) |
| `property` | String        | no       | `"resolution"` or `"aspect"`. Omit for info dict. |

```gdscript
# Get resolution of GLSLMultiTOP's second output
topp("glsl_multi1", "out1", "resolution")

# Get resolution of port index 1
topp("glsl_multi1", 1, "resolution")
```

### `par(param_name)` or `par(node_id, param_name)`

Reads a parameter value from own node (self-reference) or another node.
This is the Houdini `ch()` equivalent.

| Argument     | Type   | Required | Description                                   |
|--------------|--------|----------|-----------------------------------------------|
| `param_name` | String | yes      | Parameter name (e.g. `"scale"`, `"speed"`)    |
| `node_id`    | String | no       | Node ID for cross-node reference. Omit for self. |

**Typed variants** for guaranteed return types:
- `parf(...)` → guaranteed `float`
- `pari(...)` → guaranteed `int`
- `pars(...)` → guaranteed `String`

```gdscript
# Self-reference: read own node's parameter
par("scale")
par("offset_x") + par("offset_y")

# Cross-node: read another node's parameter
par("noise1", "scale")
par("noise1", "speed") * 2.0

# Hierarchical path
par("../lfo1", "frequency")

# Typed: guaranteed float return even if param is int
parf("noise1", "scale")

# Typed: guaranteed int
pari("noise1", "seed")

# Typed: guaranteed string
pars("noise1", "file")

# Math with self-references
par("base_freq") * 2.0  # e.g., in 'overtone_freq' param
```

> **Circular dependency protection:** If param A references param B which
> references param A, the engine detects the cycle and returns B's fallback
> value with a warning. No infinite loops.

### `ramp(param_name, t)` or `ramp(node_id, param_name, t)`

Samples a RAMP parameter's curve at position `t` (0.0–1.0).

| Argument     | Type   | Required | Description                                    |
|--------------|--------|----------|------------------------------------------------|
| `param_name` | String | yes      | Name of a RAMP-type parameter                  |
| `node_id`    | String | no       | Node ID for cross-node. Omit for self-reference.|
| `t`          | float  | yes      | Evaluation position along the curve (0.0–1.0)  |

```gdscript
# Sample own node's ramp at t=0.5
ramp("falloff", 0.5)

# Sample another node's ramp
ramp("noise1", "gradient", time % 1.0)

# Use ramp as a remapping curve
ramp("ease", chop("lfo1", "out") * 0.5 + 0.5)
```

> **Tip:** For multiple user-editable ramps, use a **RampCHOP** instead of
> adding ramp params to operators. The RampCHOP supports 1–16 dynamic ramp
> slots and outputs them as CHOP channels, readable via `chop()`:
> ```gdscript
> chop("ramp1", "falloff")      # scalar read (samples=1)
> chop("ramp1", "falloff", 42)  # specific sample index (samples>1)
> ```

### Named Output Access

Multi-output nodes (e.g., FluidVOL with Density and Velocity outputs,
MultiBufferRenderTOP with Color/Depth/Normal) expose their outputs by
**port name or label**. Six functions let you fetch typed output data from
any node — by index, by name, or by label.

#### `output(node_id, port)`

Generic output accessor — works with any data family.

| Argument  | Type          | Required | Description                                        |
|-----------|---------------|----------|----------------------------------------------------|
| `node_id` | String        | yes      | The ID of the source node                           |
| `port`    | int or String | no       | Port index, port name, or port label. Omit for port 0. |

```gdscript
# By port index
output("fluid1", 0)          # → GNVolumeData (density)
output("fluid1", 1)          # → GNVolumeData (velocity)

# By port name
output("fluid1", "density_out")

# By port label (case-insensitive)
output("fluid1", "Density")
output("fluid1", "velocity")

# Default (port 0)
output("fluid1")
```

#### Family-Typed Variants

These functions work like `output()` but filter by data type. When called
without a port argument, they return the **first output matching the type**
rather than always port 0.

| Function | Returns          | Type Filter     |
|----------|------------------|-----------------|
| `vol()`  | `GNVolumeData`   | VOL family      |
| `sop()`  | `GNGeoData`      | SOP family      |
| `dat()`  | `GNTableData`    | DAT family      |
| `img()`  | `GNImageData`    | IMG family      |
| `mat()`  | `GNMaterialData` | MAT family      |

All accept the same `(node_id, port)` signature as `output()`.

```gdscript
# FluidVOL has two VOL outputs — get each by label
vol("fluid1", "Density")     # → GNVolumeData
vol("fluid1", "Velocity")    # → GNVolumeData

# Default: first VOL output (port 0 = density)
vol("fluid1")

# MultiBufferRenderTOP — get specific buffer by index or label
output("mbr1", "Color")      # → GNImageData (port 0)
output("mbr1", "Depth")      # → GNImageData (port 1)
output("mbr1", "Normal")     # → GNImageData (port 2)

# SOP/DAT/MAT examples
sop("grid1")                 # → GNGeoData from first SOP port
dat("table1", "out")         # → GNTableData by port name
mat("pbr1")                  # → GNMaterialData
```

> **Port Labels vs Port Names:** Every port has a `port_name` (internal ID like
> `"density_out"`) and an optional `label` (display name like `"Density"`).
> Both `output()` and the typed variants match either one, case-insensitively.
> Labels are visible on the node in the graph editor.

### Copy Reference Workflow

Instead of typing references manually, you can copy them from the UI:

- **Right-click a node** in the graph → **"Copy Node Path"** copies `op("node_id")`
- **Right-click a node** → **"Copy Output Ref"** copies a family-appropriate reference:
  - CHOP: `chop("name", "out")`
  - TOP: `top("name")`
  - Other: `op("name")`
- **Right-click a parameter name** in the inspector →
  - "Copy Self Ref" → `par("param_name")`
  - "Copy Cross Ref" → `par("node_id", "param_name")`
  - "Copy op() Ref" → `op("node_id", "param_name")`

Paste the copied reference directly into any expression field.

---

## Writable References — `set_par()`

All SCRIPT family operators (GDScriptSCRIPT, PythonSCRIPT, NativeSCRIPT,
CallbackDAT) can **write** parameter values on other nodes, not just read them.

### `set_par(node_id, param_name, value)` or `set_par(param_name, value)`

Sets a parameter's constant value on another node (or self). The target node is
automatically marked dirty so it re-cooks next frame. Returns `true` on success.

| Argument     | Type    | Required | Description                                   |
|--------------|---------|----------|-----------------------------------------------|
| `node_id`    | String  | no       | Target node ID. Omit for self-reference.       |
| `param_name` | String  | yes      | Parameter name on the target node               |
| `value`      | Variant | yes      | New value (must be compatible with param type)  |

```gdscript
# Cross-node: set another node's parameter
set_par("noise1", "scale", 2.5)

# Self-reference: set own parameter
set_par("speed", par("speed") * 2.0)

# Drive a parameter from a CHOP value
set_par("render1", "bg_color", Color(chop("lfo1", "out"), 0.5, 0.5))

# Conditional parameter override
if chop("audio1", "level") > 0.8:
    set_par("glow_comp", "glow_intensity", 2.0)
else:
    set_par("glow_comp", "glow_intensity", 0.5)
```

> **Safety:** `set_par()` sets the value immediately and marks the target dirty.
> If you set a parameter on a node that hasn't cooked yet this frame, it will
> pick up the new value when it cooks. Be mindful of circular dependencies.

---

## Network API — Procedural Graph Construction

Script operators can manipulate the node graph programmatically — adding nodes,
creating connections, and removing elements. This is the GONODES equivalent of
TouchDesigner's "modify the editor" Python API.

### `network_add_node(operator_type, node_id)`

Creates a new node and adds it to the network.

| Argument        | Type   | Required | Description                                    |
|-----------------|--------|----------|------------------------------------------------|
| `operator_type` | String | yes      | Registry class name (e.g. `"NoiseTOP"`, `"LFOCHOP"`) |
| `node_id`       | String | no       | Custom ID. Auto-generated if omitted.           |

Returns the new node's ID string, or `""` on failure.

```gdscript
# Create nodes
var noise_id = network_add_node("NoiseTOP")
var lfo_id = network_add_node("LFOCHOP", "my_lfo")
```

### `network_remove_node(node_id)`

Removes a node and all its connections. Returns `true` on success.

```gdscript
network_remove_node("old_noise1")
```

### `network_connect(from_id, from_port, to_id, to_port)`

Creates a wire between two nodes. Port indices are 0-based. Returns `true` on success.

```gdscript
# Connect noise1's output 0 to composite1's input 1
network_connect("noise1", 0, "composite1", 1)
```

### `network_disconnect(from_id, from_port, to_id, to_port)`

Removes a specific wire. Returns `true` on success.

```gdscript
network_disconnect("noise1", 0, "composite1", 1)
```

### `network_node_ids()`

Returns a `PackedStringArray` of all node IDs in the current network.

```gdscript
for nid in network_node_ids():
    print(nid, " — ", network_node_info(nid).get("type", ""))
```

### `network_node_info(node_id)`

Returns a dictionary: `{ "type": "NoiseTOP", "family": "TOP", "valid": true, "position": Vector2(100, 200) }`.

```gdscript
var info = network_node_info("noise1")
if info.get("valid", false):
    print("noise1 is cooking correctly")
```

### Complete Example — Procedural Graph Building

```gdscript
# In a GDScriptSCRIPT with cook_once = true:
func cook():
    # Build a noise → level → composite chain
    var n1 = network_add_node("NoiseTOP")
    var n2 = network_add_node("LevelTOP")
    var n3 = network_add_node("CompositeTOP")

    set_par(n1, "resolution", Vector2i(512, 512))
    set_par(n2, "brightness", 1.5)
    set_par(n3, "operation", 0)  # Add mode

    network_connect(n1, 0, n2, 0)
    network_connect(n2, 0, n3, 0)
```

> **Tip:** Use `cook_once = true` for one-shot graph construction scripts.
> The script runs once and then stops, leaving the constructed graph in place.

---

## Per-Component Expressions

Multi-dimensional parameters (**Vector2**, **Vector2i**, **Vector3**, **Vector4**,
**Color**) support independent expressions on each component.

Each component has its own **C/E** toggle button. You can mix constant and
expression components freely — for example, drive X with an LFO while keeping
Y at a fixed value.

### Component Labels

| Type     | Components          |
|----------|---------------------|
| Vector2  | X, Y                |
| Vector2i | X, Y                |
| Vector3  | X, Y, Z             |
| Vector4  | X, Y, Z, W          |
| Color    | R, G, B, A          |

### Example: Animate only the X component of a Vector2

```
X → [E] chop("lfo1", "out") * 100.0
Y → [C] 50.0
```

### Example: Color with animated red channel

```
R → [E] abs(sin(time))
G → [C] 0.5
B → [C] 0.8
A → [C] 1.0
```

> **Note:** Per-component expressions must return a single `float` (or `int`).
> The cook engine assembles the final Vector/Color from all components after
> evaluating each one independently.

---

## Built-in GDScript Functions

Expressions use Godot's `Expression` class, so all
[GDScript built-in functions](https://docs.godotengine.org/en/stable/classes/class_%40gdscript.html)
are available:

### Math

| Function                      | Description                              |
|-------------------------------|------------------------------------------|
| `sin(x)`, `cos(x)`, `tan(x)` | Trigonometric functions (radians)         |
| `abs(x)`                      | Absolute value                           |
| `floor(x)`, `ceil(x)`         | Round down / up                          |
| `round(x)`                    | Round to nearest                         |
| `clamp(x, min, max)`          | Clamp value to range                     |
| `lerp(a, b, t)`               | Linear interpolation                     |
| `fmod(x, y)`                  | Floating-point modulo                    |
| `sqrt(x)`, `pow(x, y)`        | Square root, power                       |
| `min(a, b)`, `max(a, b)`      | Minimum / maximum                        |
| `sign(x)`                     | Returns -1, 0, or 1                      |
| `fposmod(x, y)`               | Positive float modulo (wraps to 0..y)    |
| `PI`, `TAU`                   | Constants (3.14159…, 6.28318…)           |

### Random

| Function               | Description                               |
|------------------------|-------------------------------------------|
| `randf()`              | Random float 0.0 – 1.0                    |
| `randi()`              | Random integer                             |
| `randf_range(lo, hi)`  | Random float in range                      |
| `randi_range(lo, hi)`  | Random integer in range                    |

### Conversion

| Function              | Description                                |
|-----------------------|--------------------------------------------|
| `int(x)`              | Convert to integer                          |
| `float(x)`            | Convert to float                            |
| `str(x)`              | Convert to string                           |

---

## Common Patterns

### Oscillation

```gdscript
# Sine wave (0 to 1 range)
sin(time * speed) * 0.5 + 0.5

# Triangle wave (0 to 1 range)
abs(fmod(time * speed, 2.0) - 1.0)

# Sawtooth (0 to 1 range)
fmod(time * speed, 1.0)

# Square wave (0 or 1)
1.0 if fmod(time * speed, 1.0) < 0.5 else 0.0
```

### Remapping

```gdscript
# Remap LFO output (-1..1) to custom range (lo..hi)
chop("lfo1", "out") * (hi - lo) / 2.0 + (hi + lo) / 2.0

# Remap 0..1 to 100..500
chop("lfo1", "out") * 0.5 + 0.5) * 400.0 + 100.0
```

### Conditional

```gdscript
# Ternary — switch between two values
10.0 if chop("lfo1", "out") > 0.0 else 20.0

# Clamp to a safe range
clamp(chop("noise1", "out"), 0.0, 1.0)
```

### Using `me` (self-reference)

```gdscript
# Read the current node's own ID
me.id

# Check if this node has valid output
me.cook_valid
```

---

## Error Handling

- If an expression fails to **parse**, the field turns red and a tooltip shows
  the error. The parameter keeps its last valid value (fallback).
- If an expression fails to **execute** at runtime, the cook engine logs the
  error, emits `cook_error`, and uses the fallback value.
- Per-component errors are independent — a broken expression on X does not
  affect Y, Z, or W.

---

## Tips

1. **Expressions compile once** when you submit them (press Enter or leave the
   field). They don't recompile every frame — only `execute()` runs per cook.
2. **Use `chop()` for animation**, not raw `time`. LFO, Noise, and Math CHOPs
   give you shaped, controllable signals you can reference from any parameter.
3. **Use `par()` for self-references.** `par("scale")` reads your own node's
   scale param — much cleaner than `op("my_node_name", "scale")`.
4. **Per-component expressions return floats.** Don't return a Vector2 from a
   single component's expression — the engine expects a scalar per component.
5. **Node IDs are case-sensitive.** `chop("LFO1", "out")` won't find `lfo1`.
   Port names/labels in `output()`, `vol()`, etc. are case-**in**sensitive.
6. **Renaming a node** automatically updates all expression strings across the
   network that reference the old name.
7. **Right-click to copy references.** Right-click a node → Copy Node Path, or
   right-click a param name → Copy Self/Cross Ref. Much faster than typing.

---

## Inline Autocomplete

Autocomplete works directly in the **inline expression field** (the
LineEdit in the parameter row) — no need to open the popup editor for
quick references.

**How it triggers:**

- **Typing** — type `chop("`, `top("`, `sop("`, etc. and a dropdown
  appears with matching node IDs, filtered to the relevant family.
- **Caret movement** — use arrow keys, Home/End, or click inside the
  quotes to re-trigger the dropdown at the new caret position.
- **Channel names** — inside the second argument (e.g., `chop("lfo1", "`)
  the dropdown switches to channel name suggestions from the referenced
  node's outputs.

Select an item with mouse click or Enter. The text is inserted at the
caret position. Press Escape to dismiss.

> The inline dropdown uses the same family filtering and color-coding as
> the popup editor's autocomplete.

---

## Multi-line Expression Editor

For complex expressions, click the **↗** button next to any expression field to
open the **Expression Editor** popup. It provides:

- **CodeEdit** with syntax highlighting for GONODES keywords, GDScript functions,
  and context variables
- **Live validation** — errors shown immediately as you type
- **Autocomplete** — press Ctrl+Space for suggestions:
  - Inside `chop("` — suggests only CHOP-family nodes (green)
  - Inside `top("` — suggests only TOP-family nodes (purple)
  - Inside `sop("`, `dat("`, `mat("`, `vol("`, `img("` — filters by family
  - Inside `output("` — suggests all nodes (any family)
  - Inside `op("`, `par("`, `set_par("` — suggests all nodes (any family)
  - Inside `chop("lfo1", "` — suggests channel names from that node
  - Inside `op("node1", "` or `par("node1", "` — suggests parameter names
  - Inside `fn("` — suggests registered custom functions
  - Hierarchical paths: type `subnet1/` to browse subnetwork nodes, `../` for parent
  - General context — variables, functions, constants
  - Node IDs are color-coded by family (CHOP green, TOP purple, SOP blue, etc.)
- **Snippets** dropdown — pre-built expression templates (see below)
- **Profiling info** — shows last/average evaluation time
- **Ctrl+Enter** to confirm, **Escape** to cancel

---

## Built-in Utility Functions

These functions are available in all expressions, called directly (no imports needed):

### Remapping

| Function | Signature | Description |
|----------|-----------|-------------|
| `fit` | `fit(value, in_min, in_max, out_min, out_max)` | Linear remap between ranges (TD-style) |
| `fit01` | `fit01(value, in_min, in_max)` | Shorthand for `fit(value, in_min, in_max, 0.0, 1.0)` |
| `step` | `step(edge, value)` | Returns 1.0 if value >= edge, else 0.0 |
| `smoothstep` | `smoothstep(edge0, edge1, x)` | Hermite smoothstep between two edges |

### Smoothing & Filtering

| Function | Signature | Description |
|----------|-----------|-------------|
| `smooth` | `smooth(key, target, speed)` | Exponential smoothing with per-key state |
| `lag` | `lag(key, target, up_speed, down_speed)` | Asymmetric lag (different speeds up/down) |
| `trigger` | `trigger(key, value, threshold)` | Returns 1.0 on the frame value crosses above threshold |

> **Note:** `smooth()`, `lag()`, and `trigger()` use a string `key` to maintain
> state between frames. Use unique keys per usage (e.g., `smooth("vol", value, 5.0)`).

### Waveforms & Time

| Function | Signature | Description |
|----------|-----------|-------------|
| `pulse` | `pulse(phase, duty)` | Pulse wave: 1.0 when fmod(phase, 1.0) < duty |
| `cycle` | `cycle(period)` | Cyclic 0→1 ramp with given period in seconds |
| `bounce` | `bounce(t)` | Bounce easing: `abs(sin(t * PI))` |

### Noise

| Function | Signature | Description |
|----------|-----------|-------------|
| `noise1` | `noise1(x)` | 1D value noise, returns ~[-1, 1] |
| `noise2` | `noise2(x, y)` | 2D value noise, returns ~[-1, 1] |

### Examples

```gdscript
# Smoothly remap an LFO to a custom range
fit(chop("lfo1", "out"), -1.0, 1.0, 100.0, 500.0)

# Smooth follow a noisy value
smooth("my_smooth", chop("noise1", "out"), 3.0)

# Asymmetric lag: fast attack, slow release
lag("volume", chop("audio1", "level"), 10.0, 2.0)

# Cyclic animation with 4-second period
cycle(4.0) * 360.0

# Trigger detection
trigger("beat", chop("audio1", "level"), 0.8)
```

---

## Custom User-Defined Functions

You can register custom functions via `GNExpressionFunctions.register()` and call
them from expressions using the `fn()` dispatch method:

```gdscript
# In expressions:
fn("my_func", arg1, arg2)

# Registration (in your script):
GNExpressionFunctions.register("my_func", my_callable, "Description", ["arg1", "arg2"])
```

Custom functions appear in the expression editor's autocomplete when typing
inside `fn("`.

---

## Expression Snippets

The expression editor's **Snippets ▾** dropdown provides ready-to-use templates:

| Category | Snippets |
|----------|----------|
| **Time & Animation** | Sine wave, Cosine wave, Sawtooth, Cyclic ramp, Ping-pong, Bounce, Pulse wave |
| **Remapping** | Fit to range, Fit to 0-1, Sin to 0-1, Smoothstep, Step threshold |
| **Smoothing** | Smooth follow, Lag (asymmetric), Trigger detect |
| **Noise & Random** | Noise 1D, Noise 2D, Random [0,1], Random range |
| **Node References** | Read CHOP channel, Read parameter, Self-reference par(), TOP resolution, TOP aspect, Named output (output/vol/sop/dat/img/mat), Copy reference workflow |
| **Math Patterns** | Sine + offset, Exponential decay, Power curve, Circular motion, Quantize |

Snippets are inserted at the cursor position, or replace the entire editor if empty.

---

## Expression Profiling

Expression evaluation timing is automatically tracked per parameter:

- **Tooltip** on expression fields shows last eval time and rolling average (µs)
- **Expression editor** info bar shows average eval time when opened
- **Per-component** timing is tracked independently

Timing is measured in microseconds (µs). Most expressions evaluate in < 5µs.
Complex expressions referencing many nodes may take 10-50µs.

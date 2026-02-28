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
6. **Renaming a node** automatically updates all expression strings across the
   network that reference the old name.
7. **Right-click to copy references.** Right-click a node → Copy Node Path, or
   right-click a param name → Copy Self/Cross Ref. Much faster than typing.

---

## Multi-line Expression Editor

For complex expressions, click the **↗** button next to any expression field to
open the **Expression Editor** popup. It provides:

- **CodeEdit** with syntax highlighting for GONODES keywords, GDScript functions,
  and context variables
- **Live validation** — errors shown immediately as you type
- **Autocomplete** — press Ctrl+Space for suggestions:
  - Inside `chop("`, `op("`, `top("` — suggests node IDs
  - Inside `chop("lfo1", "` — suggests channel names
  - Inside `op("node1", "` — suggests parameter names
  - Inside `fn("` — suggests registered custom functions
  - General context — variables, functions, constants
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
| **Node References** | Read CHOP channel, Read parameter, Self-reference par(), TOP resolution, TOP aspect, Copy reference workflow |
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

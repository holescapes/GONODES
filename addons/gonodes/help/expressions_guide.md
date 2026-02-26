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

Three functions let you read values from other nodes in the network.
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
3. **Per-component expressions return floats.** Don't return a Vector2 from a
   single component's expression — the engine expects a scalar per component.
4. **Node IDs are case-sensitive.** `chop("LFO1", "out")` won't find `lfo1`.
5. **Renaming a node** automatically updates all expression strings across the
   network that reference the old name.

# GONODES Operator API Reference

Quick reference for all public methods and properties available to operator
authors in `GNNode` and family base classes.

---

## Virtual Methods (Override These)

| Method | Return | Description |
|--------|--------|-------------|
| `_init_ports()` | `void` | Define input/output ports — called once after construction |
| `_init_parameters()` | `void` | Define parameters — called once after construction |
| `_cook(inputs: Array[GNData])` | `GNData` | Produce output from inputs; return `null` on failure |
| `_pre_cook(delta: float)` | `void` | Called each frame before cook; default calls `mark_dirty()` when `time_dependent = true` |
| `render_for_viewer(viewer, port_index: int = 0)` | `void` | Render into viewer panel (use `viewer.set_texture()`, `.set_control()`, `.set_info()`, `.get_3d_viewport()`, `.set_texture_overlay()`) |
| `render_for_preview(host)` | `void` | Render into on-node preview (use `host.set_texture()`, `.set_text()`, `.set_control()`) |
| `handle_viewer_input(event, local_pos)` | `bool` | Handle viewer input; return `true` to consume |
| `requires_compute()` | `bool` | Override to return `true` if node needs GPU compute |
| `has_cpu_fallback()` | `bool` | Override to return `true` if node provides `_cook_cpu()` |
| `_cook_cpu(inputs: Array[GNData])` | `GNData` | CPU fallback cook; called when compute unavailable |
| `supported_renderers()` | `PackedStringArray` | Override to restrict to specific renderers |
| `supported_platforms()` | `PackedStringArray` | Override to restrict to specific platforms |

---

## Port Definition

```gdscript
func _init_ports() -> void:
    add_input("in", GNFamily.Type.TOP, false, "Input texture")
    add_output("out", GNFamily.Type.TOP, "Texture output")
```

| Method | Description |
|--------|-------------|
| `add_input(name, family, multi, desc, label)` | Add input port |
| `add_output(name, family, desc, label)` | Add output port |
| `_enable_dynamic_inputs(family, prefix, desc, initial)` | Enable auto-grow inputs |
| `set_input_count(count, family, prefix, desc)` | Replace inputs with N sequential ports |
| `set_output_count(count, family, prefix, desc)` | Replace outputs with N sequential ports |

---

## Parameter Definition

```gdscript
func _init_parameters() -> void:
    add_parameter(GNParameter.create_float("scale", 1.0, 0.0, 10.0, 0.1, "Scale", ""))
    add_parameter(GNParameter.create_int("count", 4, 1, 16, "Count", ""))
    add_parameter(GNParameter.create_bool("active", true, "Active", ""))
    add_parameter(GNParameter.create_color("color", Color.WHITE, "Color", ""))
    add_parameter(GNParameter.create_string("label", "hello", "Label", ""))
    add_parameter(GNParameter.create_vector2("offset", Vector2.ZERO, "", "Offset", ""))
    add_parameter(GNParameter.create_vector2i("res", Vector2i(512, 512), "", "Resolution", ""))
    add_parameter(GNParameter.create_file("path", "", "File", ""))
```

### Reading / Writing

| Method | Description |
|--------|-------------|
| `get_param_value(name) → Variant` | Get resolved value (respects expression/bind mode) |
| `set_param_value(name, value)` | Set constant value programmatically |
| `get_parameter(name) → GNParameter` | Get raw parameter object |

---

## Cook Helpers

```gdscript
func _cook(inputs: Array[GNData]) -> GNData:
    var src := _get_input_top(inputs, 0)  # family helper
    if src == null:
        return null
    # Only process expensive port 1 if downstream needs it
    if is_output_demanded(1):
        _extract_secondary_data()
    return result
```

| Method | Description |
|--------|-------------|
| `mark_dirty()` | Request re-cook on next frame |
| `is_output_demanded(port_index) → bool` | Check if output port has active consumer |
| `get_output_data(port_index) → GNData` | Get cooked data for port (default: `cached_output`) |
| `_mutable_input(data) → GNData` | Get safe-to-mutate copy (clones shared data) |

---

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Node ID (e.g., `"noise1"`) |
| `node_type` | `String` | Operator type (e.g., `"noise"`) |
| `family` | `int` | Family enum (set by family base class) |
| `time_dependent` | `bool` | `true` → mark dirty every frame |
| `cached_output` | `GNData` | Last cook result |
| `dirty` | `bool` | Needs re-cook |
| `bypass` | `bool` | Pass-through mode |
| `locked` | `bool` | Parameters locked |
| `preview_enabled` | `bool` | On-node preview visible |
| `current_delta` | `float` | Frame delta (seconds) |
| `elapsed_time` | `float` | Time since engine started |
| `current_frame` | `int` | Frame number |
| `project_dir` | `String` | Absolute project folder path |

---

## Family Base Class Helpers

Each family base class provides typed input extraction and output preparation:

| Family | Input Helper | Output Helper |
|--------|-------------|--------------|
| `GNTopBase` | `_get_input_top(inputs, port) → GNTextureData` | `_init_shader_viewport(shader, transparent, use_texrect, size)` |
| `GNChopBase` | `_get_input_chop(inputs, port) → GNChannelData` | `_prepare_output(sample_rate) → GNChannelData` |
| `GNDatBase` | `_get_input_dat(inputs, port) → GNTableData` | `_prepare_table(clear) → GNTableData` |
| `GNSopBase` | `_get_input_sop(inputs, port) → GNGeoData` | `_prepare_geo() → GNGeoData` |
| `GNImgBase` | `_get_input_img(inputs, port) → GNImageData` | `_prepare_image() → GNImageData` |
| `GNPopBase` | `_get_input_pop(inputs, port) → GNParticleData` | — |
| `GNVolBase` | `_get_input_vol(inputs, port) → GNVolumeData` | — |
| `GNMatBase` | `_get_input_mat(inputs, port) → GNMaterialData` | — |
| `GNCompBase` | — | — |
| `GNSdfBase` | `_get_input_sdf(inputs, port) → GNSDFData` | — |

---

## Signals

| Signal | Description |
|--------|-------------|
| `node_dirty(node_id)` | Node marked dirty |
| `node_cooked(node_id)` | Cook finished |
| `parameter_changed(node_id, param_name)` | Parameter value changed |
| `ports_changed(node_id)` | Ports added/removed |
| `parameters_changed(node_id)` | Parameters added/removed or visibility changed |

---

## Expression Context

Expressions can call these functions (methods on `GNCookEngine`):

| Function | Description |
|----------|-------------|
| `chop("id", "chan", index)` | Read CHOP channel value |
| `top("id", "property")` | Read TOP property |
| `op("id", "param")` | Read any node's parameter |
| `sop("id")` | Get SOP geometry |
| `dat("id", row, col)` | Read DAT cell |
| `par("param")` | Read own parameter |
| `set_par(name, value)` | Write parameter |
| `fps()` | Effective FPS |
| `speed()` | Playback speed multiplier |
| `tstart()` | Timeline start (seconds) |
| `tend()` | Timeline end (seconds) |
| `frames()` | Total frames in timeline range |

Context variables: `me` (current node), `time` (seconds), `frame` (count), `dt` (delta).

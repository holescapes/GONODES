# Extensions

GONODES supports third-party operator extensions via the GNExtensionRegistry
architecture. Extensions can add new operators to any family without modifying
core code.

---

## Extension Structure

Extensions live under `res://addons/gn_ext_<name>/` and contain:

- **gn_extension.cfg** — Manifest file declaring operators and metadata
- **operators/** — GDScript files extending GNNode (or family base classes)
- **README.md** — Optional documentation

---

## Manifest Format

The `gn_extension.cfg` file is a Godot ConfigFile with the following structure:

```
[extension]
name = "My Extension"
version = "1.0.0"
author = "Your Name"
description = "What the extension does."
dependencies = ["SomeClassDBClass"]
section = "MySection"

[operator.MyCustomTOP]
family = "TOP"
script = "res://addons/gn_ext_myext/operators/my_custom_top.gd"
description = "One-line description for the palette tooltip."

[operator.MyCustomCHOP]
family = "CHOP"
script = "res://addons/gn_ext_myext/operators/my_custom_chop.gd"
description = "Another operator in the same extension."
```

### Extension-Level Fields

| Field          | Required | Description                                    |
|----------------|----------|------------------------------------------------|
| name           | Yes      | Display name of the extension                  |
| version        | No       | Semantic version string                        |
| author         | No       | Author name                                    |
| description    | No       | Brief description of the extension             |
| dependencies   | No       | Array of ClassDB class names that must exist   |
| section        | No       | Palette sub-heading (defaults to name)         |

### Operator-Level Fields

| Field       | Required | Description                                       |
|-------------|----------|---------------------------------------------------|
| family      | Yes      | TOP, CHOP, DAT, SOP, IMG, MAT, COMP, UI, or OUT  |
| script      | Yes      | Resource path to the operator GDScript             |
| description | No       | One-line tooltip text                              |
| section     | No       | Overrides extension-level section for this operator|

---

## Writing an Operator

### Step 1: Create the Script

Create a GDScript that extends the appropriate family base class:

```
extends GNNode

func _init() -> void:
    node_type = "mycustom"
    node_description = "My custom operator."
    family = "TOP"

func _init_ports() -> void:
    inputs = [{"name": "in1", "family": "TOP"}]
    outputs = [{"name": "out1", "family": "TOP"}]

func _init_params() -> void:
    params = [
        {"name": "amount", "type": "float", "default": 1.0,
         "min": 0.0, "max": 10.0, "description": "Effect amount"}
    ]

func cook(cook_context: Dictionary) -> void:
    var input_tex = get_input_value(0)
    # Process input_tex...
    set_output_value(0, result)
```

### Step 2: Register in the Manifest

Add an `[operator.MyCustomTOP]` section to your `gn_extension.cfg`.

### Step 3: Place Under addons/

Put your extension folder at `res://addons/gn_ext_myext/`.

### Step 4: Run GONODES

The extension is discovered automatically on startup when the editor calls
`GNExtensionRegistry.instance().scan_extensions()`.

---

## Dependency Guards

If your extension requires a GDExtension (C++ native library), list the
ClassDB class names in the `dependencies` array. The registry will skip
loading the extension if any dependency is missing, with a warning.

```
[extension]
dependencies = ["FFmpegFrameDecoder"]
```

This prevents crashes when the native library isn't available.

---

## Existing Extensions

### gn_ext_ffmpeg

FFmpeg-based video codec operators (H.264, VP9, HAP) via GDExtension.

- **FFmpegMovieTOP** — Play video files using FFmpeg decoding
- **HAPMovieTOP** — GPU-direct HAP codec playback

### gn_ext_shadertoy

Ports of popular Shadertoy shaders to GONODES TOP operators.

- Several Shadertoy-derived visual effects
- Auto-translated from GLSL to Godot shading language

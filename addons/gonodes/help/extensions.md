# Extensions

GONODES supports third-party operator extensions via the GNExtensionRegistry
architecture. Extensions can add new operators to any family without modifying
core code.

---

## Extension Structure

Shipped extensions live under `res://addons/gn_ext_<name>/`. Installed packs
also load from `user://extensions/gn_ext_<name>/`. Preferences → Extensions
lists them, loads a `.pck`, and can disable a folder (GDScript operators leave
the palette immediately; a native library still needs a Godot restart).

Each extension folder contains:

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
| platforms      | No       | Array of OS names (e.g. `["macos"]`, `["windows"]`). If set, the extension is skipped on other platforms. |
| section        | No       | Palette sub-heading (defaults to name)         |

### Operator-Level Fields

| Field       | Required | Description                                       |
|-------------|----------|---------------------------------------------------|
| family      | Yes      | TOP, CHOP, DAT, SOP, IMG, MAT, COMP, UI, OUT, POP, VOL, SDF, or SCRIPT |
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

## Platform-Specific Extensions

Some extensions only work on a single OS — Syphon is macOS-only, Spout is
Windows-only. Two layers handle this:

### Layer 1: `platforms` Manifest Key

The `platforms` field in `gn_extension.cfg` tells the GNExtensionRegistry to
skip the extension's GDScript operators on non-matching platforms:

```
[extension]
name = "Syphon Texture Sharing"
platforms = ["macos"]
```

Valid values match `OS.get_name().to_lower()`: `"windows"`, `"macos"`,
`"linux"`, `"android"`, `"ios"`, `"web"`.

### Layer 2: `.gdignore` for Native Libraries

The `platforms` key only governs GDScript operator registration. It does **not**
prevent Godot's engine-level file scanner from discovering `.gdextension` files
inside the extension. If a `.gdextension` lists libraries only for macOS, Godot
will log errors every launch on Windows (and vice versa) because it cannot find
a matching binary for the current OS — there is no built-in `.gdextension`
platform filter.

**Solution:** Place a `.gdignore` file inside the `native/` directory on
platforms where the library does not apply. This makes Godot's scanner skip
the entire directory, so the `.gdextension` file is never seen.

```
addons/gn_ext_syphon/
├── gn_extension.cfg          # platforms=["macos"] — GDScript guard
├── operators/
│   └── top/
│       ├── syphon_in_top.gd  # ClassDB.class_exists() runtime guard
│       └── syphon_out_top.gd
└── native/
    ├── .gdignore             # ← present on Windows, absent on macOS
    └── gn_syphon.gdextension
```

The `.gdignore` must be **excluded from version control** so it does not affect
other platforms. Add it to `.gitignore`:

```
# Platform-local .gdignore — prevents Godot from loading
# macOS-only .gdextension files on Windows (and vice versa).
addons/gn_ext_syphon/native/.gdignore
```

This gives you three independent safety layers:

| Layer | Scope | Mechanism |
|-------|-------|----------|
| `.gdignore` in `native/` | Engine file scanner | Godot skips the entire directory |
| `platforms` in manifest | GDScript operator registration | Extension registry skips on wrong OS |
| `ClassDB.class_exists()` in `_init()` | Runtime | Operator gracefully degrades if native class is absent |

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

### SDF (Core Family)

> **Note:** SDF operators are now a core family (12th family type), no longer an extension.
> See `addons/gonodes/operators/sdf/` for the 26 operators and `addons/gonodes/help/sdf/` for help patches.

- **10 Primitives**: SphereSDF, BoxSDF, TorusSDF, CylinderSDF, CapsuleSDF, PlaneSDF, ConeSDF, PyramidSDF, OctahedronSDF, GyroidSDF
- **5 Booleans**: UnionSDF, IntersectionSDF, SubtractSDF, SmoothUnionSDF, SmoothSubtractSDF
- **8 Domain Modifiers**: RepeatSDF, MirrorSDF, TwistSDF, BendSDF, ElongateSDF, RoundSDF, OnionSDF, DisplaceSDF
- **2 Material**: MaterialSDF (PBR albedo/roughness/metallic), GradientSDF (distance-based coloring)
- **1 Renderer**: RaymarchSDF — compiles SDF AST to GLSL, renders with orbit camera, AO, soft shadows (outputs TOP texture)
- SDF ports carry `GNSDFData` (AST tree); only RaymarchSDF bridges SDF→TOP

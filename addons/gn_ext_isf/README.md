# gn_ext_isf — ISF Shader Pack

> **Status: Complete** — Single-node ISF v2 support with inline code editor, multi-pass rendering, 10 factory presets, and 3 help patches.

ISF (Interactive Shader Format) support for GONODES.

---

## Overview

This extension adds a single `ISFTOP` node that lets you write, load and edit [ISF v2](https://docs.vidvox.net/freeboard/) shaders directly inside the GONODES editor. The node auto-generates inspector parameters and input ports from the JSON `INPUTS` header, so there is no separate class per shader — just one node and as many presets as you like.

---

## Node: ISFTOP

| Family | Inputs | Outputs |
|--------|--------|---------|
| TOP    | 0..n (image inputs from JSON INPUTS, auto-wired) | 1 texture |

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `time_dependent` | Bool | Re-cook every frame. Enable for shaders that use `TIME`. |
| `isf_file` | File (.fs / .isf / .frag) | Load an external ISF file into the inline editor. |
| `resolution` | Vector2i | Output resolution (generators only — auto-hidden for FX). |
| `isf_code` | String | The live ISF source. Edit inline or click **Edit ↗**. |
| *dynamic* | various | Auto-created from JSON `INPUTS` on compile. |

### Code Editor

Click **Edit ↗** next to `isf_code` to open the full-screen code editor with:

- **ISF syntax highlighting** — JSON header block, ISF built-ins, ISF image functions, GLSL keywords
- **Presets menu** — load factory presets or save your own to `user://gonodes_presets/isf/`
- **Quick reference** — `TIME`, `RENDERSIZE`, `isf_FragNormCoord`, `gl_FragColor`, `IMG_PIXEL`, `IMG_NORM_PIXEL`, `IMG_THIS_PIXEL` shown in the status bar

### File Loading

Setting `isf_file` copies the file content into `isf_code` (one-shot on path change). You can then edit the code freely — the file on disk is not modified.

---

## ISF Primer

An ISF shader is a standard GLSL fragment shader with a JSON metadata block in a `/* { ... } */` comment at the top:

```glsl
/*{
    "DESCRIPTION": "My shader",
    "ISFVSN": "2.0",
    "CATEGORIES": ["Generator"],
    "INPUTS": [
        { "NAME": "speed", "TYPE": "float", "DEFAULT": 1.0, "MIN": 0.0, "MAX": 5.0 }
    ]
}*/

void main() {
    vec2 uv = isf_FragNormCoord;         // normalised 0–1 UV
    gl_FragColor = vec4(uv, sin(TIME * speed) * 0.5 + 0.5, 1.0);
}
```

### ISF → Godot mapping

| ISF | Godot equivalent |
|-----|-----------------|
| `isf_FragNormCoord` | `UV` |
| `gl_FragColor` | `COLOR` |
| `gl_FragCoord` | `FRAGCOORD` |
| `TIME` | built-in `TIME` |
| `RENDERSIZE` | `uniform vec2 isf_rendersize` |
| `TIMEDELTA` | `uniform float isf_time_delta` |
| `FRAMEINDEX` | `uniform int isf_frame_index` |
| `DATE` | `uniform vec4 isf_date` (year, month, day, seconds) |
| `PASSINDEX` | `uniform int isf_pass_index` |
| `IMG_THIS_PIXEL(img)` | `texture(img, UV)` |
| `IMG_NORM_PIXEL(img, uv)` | `texture(img, uv)` |
| `IMG_PIXEL(img, px)` | `texture(img, px / isf_rendersize)` |
| `IMG_SIZE(img)` | `isf_<img>_size` |

### Input types

| ISF type | Inspector parameter |
|----------|---------------------|
| `float` | Float slider |
| `bool` | Checkbox |
| `long` + LABELS | Enum dropdown |
| `point2D` | Vector2 |
| `color` | Colour picker |
| `event` | Momentary bool (auto-resets each frame) |
| `image` | TOP input port |

### Multi-pass

Define `PASSES` in the JSON header to create intermediate render targets:

```json
"PASSES": [
    { "TARGET": "buf_a", "PERSISTENT": true },
    {}
]
```

Each pass gets its own `SubViewport`. `PERSISTENT` feedback-loops the previous frame.  
Per-pass `WIDTH` / `HEIGHT` expressions support `$WIDTH`, `$HEIGHT` and `$inputName` variables.

---

## Bundled Presets

Factory presets are stored inside the extension at `addons/gn_ext_isf/presets/isf/` and are automatically discovered by the preset system. User presets are saved to:

### Generators
| File | Description |
|------|-------------|
| `color_bars.fs` | SMPTE colour bars test pattern |
| `sine_warp.fs` | Animated sinusoidal UV warp |
| `kaleidoscope.fs` | Kaleidoscope pattern generator |
| `gradient_map.fs` | Directional gradient between two colours |
| `lissajous.fs` | Animated Lissajous figure |

### Effects (require one image input)
| File | Description |
|------|-------------|
| `kaleidoscope_fx.fs` | Kaleidoscope applied to an input image |
| `glitch.fs` | Digital block-shift glitch with channel separation |
| `mirror.fs` | Horizontal / vertical / diagonal mirror |
| `edge_glow.fs` | Sobel edge detection with coloured glow |
| `cross_hatch.fs` | Cross-hatch sketch stylisation |

---

## Translator: `ISFTranslator`

The `ISFTranslator` class (autoloaded as a GDScript resource) is available for external use:

```gdscript
var result := ISFTranslator.translate(isf_source_string)
if result.success:
    print(result.godot_code)      # single-pass Godot shader
    print(result.pass_codes)      # Array[String] for multi-pass
    for inp in result.inputs:     # Array[ISFTranslator.ISFInput]
        print(inp.input_name, inp.type)
```

---

## Directory Layout

```
addons/gn_ext_isf/
├── gn_extension.cfg              # Extension manifest
├── isf_translator.gd             # ISF → Godot GLSL translator
├── operators/top/
│   └── isf_top.gd                # ISFTOP node
├── presets/isf/                  # Factory presets (.fs files)
├── shaders/                      # (legacy — unused; all translation is runtime)
└── help/top/
    ├── isf_generator.gnpatch     # Help patch: generator example
    └── isf_fx.gnpatch            # Help patch: FX example
```

User presets are stored in:
```
addons/gn_ext_isf/presets/isf/    ← factory presets (read-only)
user://gonodes_presets/isf/        ← user presets (saved from editor)
```

# gn_ext_shadertoy  Shadertoy Shader Pack for GONODES

Single `ShadertoyURLTOP` node that runs all Shadertoy GLSL through the runtime
translation pipeline. No pre-baked operators  write, paste or fetch any shader
and it compiles immediately.

---

## Node: ShadertoyURLTOP

| Family | Inputs | Outputs |
|--------|--------|---------|
| TOP | 0..4 (auto-wired from iChannel usage) | 1 texture |

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `time_dependent` | Bool | Re-cook every frame. Enable for shaders using `iTime`. |
| `fetch` | Bool (pulse) | Download shader from `shadertoy_url` via the public API. Auto-resets. |
| `resolution` | Vector2i | Output resolution (generators only  auto-hidden for FX). |
| `shadertoy_url` | String | Shadertoy page URL or bare shader ID (e.g. `Ms2SD1`). |
| `shadertoy_code` | String | Raw Shadertoy GLSL. Edit inline or open the full code editor. |
| *dynamic* | various | Auto-created from `uniform` declarations on compile. |

### Code Editor

Click **Edit ** next to `shadertoy_code` to open the full-screen editor with:

- **Shadertoy syntax highlighting**  `iTime`, `iResolution`, `iMouse`, `iChannel0..3`, `iFrame`, `mainImage`, GLSL types/functions
- **Presets menu**  10 factory presets (5 generators + 5 effects), user presets in `user://gonodes_presets/shadertoy/`
- **Quick reference bar**  `void mainImage(out vec4, in vec2)` signature + all iXxx uniforms

### URL Fetch

Set `shadertoy_url` to a Shadertoy page URL or a bare shader ID, then pulse `fetch`. The Shadertoy public API returns the Image pass GLSL, which is placed into `shadertoy_code` and auto-compiled on the next cook.

---

## Translation Pipeline

```
void mainImage(out vec4 fragColor, in vec2 fragCoord) { ... }
         
   ShadertoyTranslator
         
shader_type canvas_item;
uniform vec2 gn_resolution;
...
void fragment() { ... }
```

**Auto-mapped built-ins:**

| Shadertoy | Godot |
|-----------|-------|
| `iTime` | `TIME` |
| `iResolution` | `uniform vec2 gn_resolution` |
| `iMouse` | `uniform vec4 gn_mouse` |
| `iFrame` | `uniform int gn_frame` |
| `iChannel0..3` | TOP input ports  `gn_tex0..3` |
| `fragCoord` | `FRAGCOORD.xy` |
| `fragColor` | `COLOR` |

**`uniform` declarations** in the shader body (e.g. `uniform float block_size; // = 8.0`) become auto-generated inspector parameters with default values parsed from the comment.

---

## Bundled Presets

Loaded from `addons/gn_ext_shadertoy/presets/shadertoy/` (.glsl files):

### Generators
| File | Description |
|------|-------------|
| `plasma.glsl` | Classic plasma globe  retro demoscene effect |
| `creation.glsl` | Compact colour field  demoscene-style 1KB visual |
| `star_nest.glsl` | Volumetric space fractal with depth-ray march |
| `lava_lamp.glsl` | Smooth metaball blobs with warm/cool palette |
| `voronoi.glsl` | Animated cellular Voronoi noise |

### Effects (require iChannel0 input)
| File | Description |
|------|-------------|
| `crt.glsl` | CRT monitor  barrel distortion, scanlines, vignette |
| `chromatic_ab.glsl` | Radial RGB channel offset |
| `pixelate.glsl` | Mosaic / blocky pixelation (`block_size` param) |
| `film_grain.glsl` | Luminance-weighted animated film grain |
| `halftone.glsl` | CMYK halftone dot-screen rendering |

---

## Directory Layout

```
addons/gn_ext_shadertoy/
 gn_extension.cfg              # Extension manifest (ShadertoyURLTOP only)
 shadertoy_translator.gd       # Shadertoy GLSL  Godot canvas_item translator
 operators/top/
    shadertoy_url_top.gd      # ShadertoyURLTOP node
 presets/shadertoy/            # Factory presets (.glsl  mainImage format)
```

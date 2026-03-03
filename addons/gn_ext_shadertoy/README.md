# gn_ext_shadertoy — Shadertoy Shader Pack for GONODES

GONODES extension that provides **10 pre-baked Shadertoy-to-Godot shader
conversions** (5 generators + 5 effects) and a **runtime translator**
(`ShadertoyURLTOP`) that converts any pasted Shadertoy GLSL into a Godot
shader on the fly.

## Requirements

**None.** This extension is pure GDScript and .gdshader files — no external
dependencies or GDExtensions required.

## Architecture

| Component | Purpose |
|---|---|
| `gn_extension.cfg` | Manifest registering 11 operators (10 pre-baked + 1 runtime) |
| `shadertoy_translator.gd` | Static utility: Shadertoy GLSL → Godot `canvas_item` shader |
| `operators/top/shadertoy_base_top.gd` | Abstract base class for all pre-baked shader TOPs |
| `operators/top/shadertoy_url_top.gd` | Runtime translator — paste code or fetch by URL |
| `shaders/*.gdshader` | Pre-converted Godot shaders |

## Generators (no input)

| Operator | Source | Author | Description |
|---|---|---|---|
| `st_seascape` | [Ms2SD1](https://www.shadertoy.com/view/Ms2SD1) | TDM (Alexander Alekseev) | Procedural ocean with waves and lighting |
| `st_voronoi_fire` | [4tlSzl](https://www.shadertoy.com/view/4tlSzl) | Shane | Volumetric fire palette over 3D Voronoi noise |
| `st_creation` | [XsXXDn](https://www.shadertoy.com/view/XsXXDn) | Danilo Guanabara (Silexars) | Compact demoscene colour field |
| `st_star_nest` | [XlfGRj](https://www.shadertoy.com/view/XlfGRj) | Pablo Roman Andrioli (Kali) | Volumetric space fractal — MIT License |
| `st_plasma` | — | Original GONODES | Classic retro plasma globe effect |

### Generator parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `resolution` | Vector2i | 512×512 | Output texture resolution |
| `shadertoy_url` | String (read-only) | — | Original Shadertoy URL |
| `credits` | String (read-only) | — | Author and licence |

## Effects (one texture input)

| Operator | Source | Description | Extra parameters |
|---|---|---|---|
| `st_crt` | Original | CRT barrel distortion + scanlines + vignette | `curvature`, `scanline_weight`, `vignette_strength` |
| `st_chromatic_ab` | Original | Radial RGB channel offset | `intensity`, `radial_weight` |
| `st_pixelate` | Original | Mosaic / pixelation | `pixel_size` |
| `st_film_grain` | Original | Animated noise grain overlay | `grain_intensity`, `grain_speed` |
| `st_halftone` | [Mdf3Dn](https://www.shadertoy.com/view/Mdf3Dn) | CMYK halftone dot rendering by tsone | `dot_size`, `dot_scale` |

### Effect parameters

Effects inherit `shadertoy_url` and `credits` read-only params from the base
class, plus their own shader-specific uniforms listed above.

## Runtime translator — ShadertoyURLTOP (`shadertoy`)

Paste any single-pass Shadertoy GLSL code and the node automatically:

1. Runs `ShadertoyTranslator.translate()` to convert built-ins
2. Compiles the resulting Godot shader
3. Scans the shader for uniforms and creates dynamic parameters
4. Rebuilds input ports from `iChannel0..3` usage

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `time_dependent` | Bool | `true` | Re-cook every frame |
| `fetch` | Bool (pulse) | `false` | Download shader from Shadertoy API |
| `resolution` | Vector2i | 512×512 | Output resolution (generators only) |
| `shadertoy_url` | String | `""` | Shadertoy URL or bare ID for fetch |
| `shadertoy_code` | String | template | Paste Shadertoy GLSL here |

### Translation map

| Shadertoy | Godot equivalent |
|---|---|
| `iResolution` | `gn_resolution` (uniform vec2) |
| `iTime` | `TIME` (built-in) |
| `iTimeDelta` | `gn_time_delta` (uniform float) |
| `iFrame` | `gn_frame` (uniform int) |
| `iMouse` | `gn_mouse` (uniform vec4) |
| `iChannel0..3` | `gn_tex0..3` (uniform sampler2D) |
| `mainImage(out vec4, in vec2)` | `void fragment()` / `COLOR` / `FRAGCOORD` |

## Multi-pass support (future)

Only the main "Image" pass is currently converted. Multi-pass Buffer A/B/C/D
support would require:

1. Parse the `renderpass` array from the Shadertoy API JSON
2. Create one SubViewport per buffer pass, each with its own shader
3. Wire buffer outputs as `sampler2D` inputs to subsequent passes
4. Run passes in order each cook: BufferA → BufferB → … → Image
5. Buffer passes can read their own previous frame via a feedback texture

This mirrors the `FeedbackTOP` pattern already in GONODES core.

# GONODES — Operator Reference

> **534 operators** across 13 families: TOP, IMG, CHOP, DAT, SOP, POP, VOL, COMP, MAT, OUT, UI, SDF, SCRIPT, plus native C++ acceleration variants and 18 extension addons.

---

## Table of Contents

- [TOP — Texture Operators](#top--texture-operators)
- [IMG — Image Operators](#img--image-operators)
- [CHOP — Channel Operators](#chop--channel-operators)
- [DAT — Data Operators](#dat--data-operators)
- [SOP — Surface Operators](#sop--surface-operators)
- [COMP — Component Operators](#comp--component-operators)
- [MAT — Material Operators](#mat--material-operators)
- [OUT — Output Operators](#out--output-operators)
- [UI — User Interface Operators](#ui--user-interface-operators)

> **Help example patches:** Every operator has 3+ `.gnpatch` example files accessible via the `?` help button on each node. See `addons/gonodes/help/<family>/` for the full set (1,413 total).
>
> ### Help Patch Hard Rule
> Every help example patch **MUST**:
> 1. **Be meaningful** — Simply placing a node with no connections is not a valid example. The patch should demonstrate a realistic, useful workflow that shows what the operator does in context.
> 2. **End with a visible sink via family-appropriate chain** — The demonstrated operator must feed into WindowOUT through a chain that respects port family compatibility:
>    - **TOP** → WindowOUT (direct)
>    - **IMG** → ImgToTOP → WindowOUT
>    - **CHOP** → CHOPtoTOP → WindowOUT (waveform visualization)
>    - **SOP** → GeometryCOMP + CameraCOMP → RenderTOP → WindowOUT
>    - **COMP (scene)** → RenderTOP + CameraCOMP → WindowOUT
>    - **COMP (pass-through: Null, Switch, Animation)** → Route data *through* the COMP to RenderTOP — never bypass it with a direct connection, or the cook engine won't cook it (dead-end branches are skipped)
>    - **DAT** → TextTOP → WindowOUT
>    - **MAT** → GeometryCOMP (MAT on port 1) + CameraCOMP → RenderTOP → WindowOUT
>    - **UI** → PanelTOP → WindowOUT (interactive widgets rendered to texture)
> 3. **WindowOUT settings** — Resolution `512×512`, `"open": true` so the window opens automatically.
> 4. **Pass-through COMPs** must be in the active cook chain, not dead-end branches. The cook engine only cooks nodes upstream of sinks — an orphaned COMP node never cooks and appears broken.

---

## TOP — Texture Operators

TOPs process 2D textures on the GPU. Each TOP inherits from `GNTopBase`, which provides the shared viewport infrastructure: `_viewport` (SubViewport), `_material` (ShaderMaterial), `_canvas` (ColorRect/TextureRect), and `_cached_tex_data` (GNTextureData). Textures are passed between nodes as zero-copy GPU references (ViewportTexture). All texture processing happens entirely on the GPU — no CPU readback. SubViewports render exactly once per cook cycle via `UPDATE_ONCE` (not every frame).

**Total: 56 operators** — 12 generators, 28 filters, 7 combiners, 3 temporal/buffer, 2 simulation/generative, 2 utility, 2 bridge.

### Generators

These TOPs create textures from scratch with no input required.

---

#### NoiseTOP

Procedural noise texture generator. GPU-rendered via shader.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| noise_type | Enum | Simplex | Simplex, Perlin, Voronoi, White | Noise algorithm |
| scale | Float | 4.0 | 0.1–100.0 | Noise frequency/zoom |
| offset | Vector2 | (0, 0) | — | Spatial offset |
| time_offset | Float | 0.0 | — | Z-axis offset for animation |
| seed | Int | 0 | 0–99999 | Random seed |
| monochrome | Bool | true | — | Grayscale or RGB noise |
| octaves | Int | 1 | 1–8 | FBM octave count (1 = single layer) |
| lacunarity | Float | 2.0 | 1.0–4.0 | Frequency multiplier per octave |
| gain | Float | 0.5 | 0.0–1.0 | Amplitude multiplier per octave |
| periodic | Bool | false | — | Enable seamless tiling via periodic Perlin |
| tile_size | Float | 4.0 | 1.0–64.0 | Repeat period in noise-space (periodic mode) |

**How it works:** Renders a fullscreen quad with a noise shader. The shader implements 4 noise algorithms selectable via uniform. When `octaves` > 1, fractal Brownian motion (FBM) layers multiple noise samples with increasing frequency and decreasing amplitude. When `periodic` is enabled, a tileable Perlin implementation replaces the base noise so the output tiles seamlessly — useful for seamless textures, looping animations, and tiled backgrounds. Time-dependent — animates automatically when `time_offset` is driven by expressions.

---

#### RampTOP

Gradient ramp generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| type | Enum | Horizontal | Horizontal, Vertical, Radial, Circular | Gradient direction |
| color_a | Color | Black | — | Start color |
| color_b | Color | White | — | End color |
| center | Vector2 | (0.5, 0.5) | — | Center point (for radial/circular) |
| phase | Float | 0.0 | — | Phase offset |
| repeat | Bool | false | — | Repeat gradient |

**How it works:** Shader computes gradient value based on UV coordinates and selected type, then interpolates between the two colors. Radial mode uses distance from center. Circular mode uses angle.

---

#### CircleTOP

Circle or ring shape via signed distance field.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| fill_color | Color | White | — | Shape fill color |
| bg_color | Color | Black | — | Background color |
| center | Vector2 | (0.5, 0.5) | — | Circle center in UV space |
| radius | Float | 0.4 | 0.0–1.0 | Circle radius |
| border_width | Float | 0.0 | 0.0–0.5 | Ring border width (0 = filled) |
| softness | Float | 0.005 | 0.0–0.1 | Edge antialiasing |

**How it works:** SDF shader computes distance from center, applies smoothstep for edge softness. Border width > 0 creates a ring by subtracting an inner circle.

---

#### RectangleTOP

Rectangle or rounded rectangle via signed distance field.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| fill_color | Color | White | — | Shape fill color |
| bg_color | Color | Black | — | Background color |
| center | Vector2 | (0.5, 0.5) | — | Rectangle center |
| size | Vector2 | (0.6, 0.4) | — | Width and height |
| corner_radius | Float | 0.0 | 0.0–0.5 | Rounded corners |
| border_width | Float | 0.0 | 0.0–0.5 | Border only mode |
| softness | Float | 0.005 | 0.0–0.1 | Edge antialiasing |

**How it works:** SDF shader computes distance to a rounded rectangle. Same fill/border/softness logic as CircleTOP.

---

#### ConstantTOP

Solid color texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| color | Color | Black | — | Fill color |
| alpha | Float | 1.0 | 0.0–1.0 | Alpha override |

**How it works:** No shader needed — uses a `ColorRect` directly in the SubViewport.

---

#### TextTOP

Renders text to a texture. Supports custom font loading from project resources.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| text | String | "Hello" | — | Text content |
| resolution | Vector2i | 512×256 | — | Output resolution |
| font_file | File | (none) | — | Font file path (TTF, OTF, WOFF, WOFF2, .tres/.res). Leave empty for default font. |
| font_size | Int | 48 | 8–256 | Font size in pixels |
| font_color | Color | White | — | Text color |
| bg_color | Color | Black | — | Background color |
| align_h | Enum | Center | Left, Center, Right | Horizontal alignment |
| align_v | Enum | Center | Top, Center, Bottom | Vertical alignment |
| word_wrap | Bool | true | — | Wrap text at edges |

**How it works:** Uses Godot's `Label` node inside a SubViewport. The Label handles text layout, wrapping, and alignment natively. Custom fonts are loaded via `ResourceLoader` and applied with `add_theme_font_override()`.

---

#### ImageFileInTOP

Loads an image or texture resource from the project and outputs it as a TOP texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | (none) | — | Image/texture path (PNG, JPG, WebP, BMP, TGA, SVG, HDR, EXR, .tres/.res) |
| resolution | Vector2i | 512×512 | — | Output resolution |
| fit_mode | Enum | Keep Aspect Centered | Stretch, Keep Aspect, Keep Aspect Centered, Keep Aspect Covered, Tile | How the image fits the output |
| bg_color | Color | Black | — | Background color behind transparent or non-covering images |
| filter | Bool | true | — | Bilinear filtering (on) or nearest-neighbor (off) |

**How it works:** Loads any Godot-importable image format via `ResourceLoader`. The loaded `Texture2D` is displayed in a `TextureRect` inside a SubViewport. Supports all Godot stretch modes. Non-texture `Image` resources are automatically converted to `ImageTexture`.

---

#### MovieFileInTOP

Plays a video file as a live texture stream. Similar to TouchDesigner's Movie File In TOP.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | (none) | — | Video file path (.ogv Theora format) |
| resolution | Vector2i | 512×512 | — | Output resolution |
| play | Bool | true | — | Play / pause |
| loop | Bool | true | — | Loop when finished |
| speed | Float | 1.0 | 0.0–4.0 | Playback speed multiplier |
| seek | Float | -1.0 | -1.0–→ | Seek to time in seconds (-1 = disabled) |
| bg_color | Color | Black | — | Background color when no video loaded |

**How it works:** Uses Godot's native `VideoStreamPlayer` inside a SubViewport. Supports Theora (.ogv) format out of the box. The video player renders frames directly as a Control filling the viewport. Additional codecs can be added via GDExtensions.

**Codec notes:**
- **Theora (.ogv):** Built-in. CPU-decoded. No alpha channel support in Godot's decoder.
- **H.264/VP8/VP9:** Available via community `godot-videodecoder` GDExtension (FFmpeg-based). No alpha.
- **HAP / HAP Alpha / HAP Q:** Not yet supported. HAP is a VJ-standard codec that stores S3TC/DXT-compressed frames, uploaded directly to the GPU with no CPU decode — ideal for real-time performance. Requires a custom GDExtension wrapping the [HAP library](https://github.com/Vidvox/hap). See roadmap.
- **Image sequences:** For alpha-channel video content, use numbered PNG/WebP frame sequences with the ImageSequenceTOP operator.

---

#### ImageSequenceTOP

Plays a numbered image sequence as animated texture frames. Supports PNG, WebP, JPG, and other Godot-importable formats.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | (none) | — | Path to ANY frame in the sequence (auto-discovers siblings) |
| resolution | Vector2i | 512×512 | — | Output resolution (auto-set from first frame) |
| play | Bool | true | — | Play / pause |
| speed | Float | 1.0 | 0.01–10.0 | Playback speed multiplier |
| index | Int | -1 | -1–→ | Manual frame index override (-1 = auto time-based) |
| loop_mode | Enum | Loop | — | Loop, Hold First, Hold Last, Ping-Pong |
| fit_mode | Enum | Keep Aspect Centered | — | Stretch, Keep Aspect, Centered, Covered |
| bg_color | Color | Black | — | Background behind transparent/non-covering frames |
| preload_all | Bool | false | — | Load all frames at startup (faster playback, more RAM) |

**How it works:** Given any frame file (e.g., `render_0042.png`), the operator parses the filename to find the prefix and numbering pattern, then scans the directory for all matching files. Frames are lazy-loaded and cached on demand (or preloaded if the toggle is on). Supports expression-driven `index` for precise sequencing. The ping-pong mode reverses direction at sequence boundaries.

**Naming convention:** Files must have a consistent prefix followed by digits: `myprefix0001.png`, `myprefix0002.png`, etc. Zero-padding width is flexible. Sorting is lexicographic (works correctly for zero-padded names).

---

#### CustomShaderTOP

User-editable GPU shader with live recompilation.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| shader_code | String | *(template)* | — | Full `shader_type canvas_item;` shader |
| float_a–float_d | Float | 0.0 | — | 4 user float uniforms (`gn_float0`–`gn_float3`) |
| color_a | Color | White | — | User color uniform (`gn_color0`) |
| color_b | Color | Black | — | User color uniform (`gn_color1`) |

**Inputs:** Up to 4 texture inputs available as `gn_tex0`–`gn_tex3` in the shader.

**Built-in uniforms:** `gn_resolution` (vec2), Godot's built-in `TIME`.

**How it works:** User provides a complete `shader_type canvas_item;` shader string. The operator compiles it into a `Shader` resource and applies it. On compilation failure, the last working shader is kept. Recompilation only happens when the code text changes. Time-dependent — `TIME` uniform updates automatically.

---

#### PatternTOP

Procedural pattern generator: stripes, checkerboard, concentric circles, grids, and dots.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| type | Enum | Stripes | Stripes, Checkerboard, Concentric, Grid, Dots | Pattern type |
| frequency | Float | 8.0 | 0.1–100.0 | Pattern repetition frequency |
| duty_cycle | Float | 0.5 | 0.0–1.0 | Width ratio of primary shape |
| color_a | Color | White | — | Primary colour |
| color_b | Color | Black | — | Secondary / background colour |
| rotation | Float | 0.0 | — | Rotation in radians |
| softness | Float | 0.02 | 0.0–0.2 | Edge anti-aliasing |

---

#### TriangleTOP

SDF 2D primitives: triangle, line, pentagon.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| shape | Enum | Triangle | Triangle, Line, Pentagon | Shape type |
| size | Float | 0.4 | 0.01–0.5 | Shape radius in UV space |
| fill_color | Color | White | — | Shape interior colour |
| bg_color | Color | Black | — | Background colour |
| border_width | Float | 0.02 | 0.0–0.1 | Border thickness (0 = none) |
| border_color | Color | White | — | Border colour |
| rotation | Float | 0.0 | — | Shape rotation in radians |
| softness | Float | 0.005 | 0.0–0.05 | Edge anti-aliasing |

---

#### SVGTOP

Render SVG vector graphics to a texture at arbitrary resolution.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| svg_path | String | *(empty)* | — | Path to .svg file (res:// or user://) |

**How it works:** Loads and rasterises the SVG via Godot's Image loader. Re-rasterises only when path or resolution changes. No shader — pure CPU rasterisation.

---

### Filters

These TOPs take one texture input and modify it.

---

#### LevelTOP

Brightness, contrast, gamma, and invert adjustments.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| brightness | Float | 1.0 | 0.0–4.0 | Brightness multiplier |
| contrast | Float | 1.0 | 0.0–4.0 | Contrast amount |
| gamma | Float | 1.0 | 0.01–4.0 | Gamma correction |
| invert | Bool | false | — | Invert colors |
| opacity | Float | 1.0 | 0.0–1.0 | Output opacity |

**How it works:** Shader applies `color = ((color * brightness) - 0.5) * contrast + 0.5`, then `pow(color, 1.0/gamma)`, then optional invert, then alpha multiply.

---

#### BlurTOP

Gaussian or box blur.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| size | Float | 5.0 | 0.0–100.0 | Blur radius |
| quality | Int | 4 | 1–8 | Sample count per direction |
| method | Enum | Gaussian | Gaussian, Box | Blur algorithm |

**How it works:** Two-pass separable blur — horizontal pass into an intermediate SubViewport, then vertical pass into the output SubViewport. Each pass samples multiple texels along one axis weighted by a Gaussian (or uniform for box). Two shader materials, two viewports.

---

#### TransformTOP

2D translate, rotate, and scale.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| translate | Vector2 | (0, 0) | — | UV translation |
| rotate | Float | 0.0 | — | Rotation in radians |
| scale | Vector2 | (1.0, 1.0) | — | UV scale |
| pivot | Vector2 | (0.5, 0.5) | — | Transform pivot point |
| extend | Enum | Clamp | Clamp, Repeat, Mirror, Zero | Edge extension mode |

**How it works:** Shader builds a 2D transform matrix, applies it to UV coordinates, and samples the input. Extend mode controls what happens at UV boundaries.

---

#### HSVAdjustTOP

Hue, saturation, and value (brightness) adjustments.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| hue_offset | Float | 0.0 | -1.0–1.0 | Hue rotation (wraps) |
| saturation | Float | 1.0 | 0.0–4.0 | Saturation multiplier (0 = grayscale) |
| value | Float | 1.0 | 0.0–4.0 | Value/brightness multiplier |

**How it works:** Shader converts RGB to HSV, applies offsets/multipliers, converts back to RGB.

---

#### EdgeTOP

Sobel edge detection.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0.0–10.0 | Edge strength multiplier |
| grayscale | Bool | true | — | Output grayscale or colored edges |

**How it works:** Convolution with Sobel kernels (horizontal and vertical), combined as `sqrt(gx² + gy²)`. Computes on luminance if grayscale, or per-channel if colored.

---

#### ThresholdTOP

Binary black/white based on luminance threshold.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | 0.0–1.0 | Luminance cutoff |
| softness | Float | 0.0 | 0.0–0.5 | Soft transition width |
| use_alpha | Bool | false | — | Threshold alpha channel instead of luminance |

**How it works:** Shader computes luminance, applies `smoothstep(threshold - softness, threshold + softness, lum)` for soft edges or hard step for binary output.

---

#### FlipTOP

Mirror texture horizontally and/or vertically.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| flip_x | Bool | false | — | Mirror horizontally |
| flip_y | Bool | false | — | Mirror vertically |

**How it works:** Shader inverts UV.x and/or UV.y before sampling.

---

#### TileTOP

Tile/repeat a texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| repeat | Vector2 | (2.0, 2.0) | — | Repeat count per axis |
| offset | Vector2 | (0, 0) | — | UV offset |
| mirror_x | Bool | false | — | Mirror on horizontal repeats |
| mirror_y | Bool | false | — | Mirror on vertical repeats |

**How it works:** Shader multiplies UV by repeat count and wraps via `fract()`. Mirror mode alternates direction on odd repeats.

---

#### CropTOP

Crop a sub-region from the input.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output resolution |
| left_top | Vector2 | (0.0, 0.0) | — | Top-left UV corner |
| right_bottom | Vector2 | (1.0, 1.0) | — | Bottom-right UV corner |

**How it works:** Shader remaps UV from the output range to the specified sub-region of the input.

---

#### FeedbackTOP

Blends current frame with previous frame's output for trails and echoes.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mix | Float | 0.9 | 0.0–1.0 | Feedback persistence (higher = longer trails) |
| translate | Vector2 | (0, 0) | — | Feedback UV translation per frame |
| rotate | Float | 0.0 | — | Feedback rotation in radians per frame |
| scale | Vector2 | (1.0, 1.0) | — | Feedback scale per frame |
| reset | Bool | false | — | Clear feedback buffer |

**How it works:** Each frame, the shader blends the new input with the previous frame's output texture. The previous frame can be spatially transformed (translate/rotate/scale), creating spiral, zoom, or drift effects. Uses deferred capture (`call_deferred`) to read the viewport output into an `ImageTexture` for next frame's feedback uniform.

---

#### ResolutionTOP

Resize a texture to a different resolution.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 1920×1080 | — | Target output resolution |
| filter | Enum | Linear | Linear, Nearest | Filtering mode |

**How it works:** Renders the input texture into a SubViewport at the target resolution using a `TextureRect`. Filter mode controls interpolation quality.

---

#### RenderTOP

Renders a 3D scene from COMPs into a 2D texture with integrated post-processing. This is the bridge between the COMP/SOP pipeline and the TOP pipeline.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| **Scene** | | | | |
| resolution | Vector2i | 1280×720 | — | Render resolution |
| bg_color | Color | (0.1, 0.1, 0.12) | — | Background color |
| transparent_bg | Bool | false | — | Transparent background |
| use_environment | Bool | true | — | Enable environment lighting |
| ambient_energy | Float | 0.3 | 0.0–4.0 | Ambient light intensity |
| ambient_color | Color | (0.3, 0.3, 0.4) | — | Ambient light color |
| anti_aliasing | Enum | 4x MSAA | Off, 2x, 4x, 8x | MSAA quality |
| **Shadows** | | | | |
| shadow_atlas_size | Enum | 4096 | 1024, 2048, 4096, 8192 | Positional shadow atlas resolution |
| dir_shadow_size | Enum | 4096 | 1024, 2048, 4096, 8192 | Directional shadow map resolution |
| shadow_filter | Enum | Soft Medium | Hard, Soft Low/Med/High/Ultra | Shadow filter quality (PCF) |
| **Tonemap** | | | | |
| tonemap_mode | Enum | ACES | Linear, Reinhard, Filmic, ACES | Tone mapping algorithm |
| tonemap_exposure | Float | 1.0 | 0.1–8.0 | Exposure multiplier |
| tonemap_white | Float | 1.0 | 0.1–16.0 | White reference point |
| **Glow (Bloom)** | | | | |
| glow_enabled | Bool | false | — | Enable glow/bloom |
| glow_intensity | Float | 0.8 | 0.0–4.0 | Overall glow strength |
| glow_strength | Float | 1.0 | 0.0–2.0 | Per-level glow contribution |
| glow_bloom | Float | 0.0 | 0.0–1.0 | Screen-wide bloom amount |
| glow_hdr_threshold | Float | 1.0 | 0.0–4.0 | Brightness threshold for glow |
| glow_blend_mode | Enum | Additive | Additive, Screen, Softlight, Replace, Mix | Glow compositing mode |
| **Depth of Field** | | | | |
| dof_far_enabled | Bool | false | — | Enable far DOF blur |
| dof_far_distance | Float | 10.0 | 0.1–200.0 | Far focus distance |
| dof_far_transition | Float | 5.0 | 0.1–50.0 | Far transition width |
| dof_near_enabled | Bool | false | — | Enable near DOF blur |
| dof_near_distance | Float | 2.0 | 0.1–50.0 | Near focus distance |
| dof_near_transition | Float | 1.0 | 0.1–20.0 | Near transition width |
| dof_bokeh_size | Float | 4.0 | 0.5–10.0 | Blur disc radius |
| dof_bokeh_shape | Enum | Circle | Box, Hexagon, Circle | Bokeh shape |
| **SSAO** | | | | |
| ssao_enabled | Bool | false | — | Enable ambient occlusion |
| ssao_radius | Float | 1.0 | 0.01–16.0 | Sampling radius |
| ssao_intensity | Float | 2.0 | 0.0–10.0 | Darkening strength |
| ssao_power | Float | 1.5 | 0.1–10.0 | Falloff exponent |
| **SSIL** | | | | |
| ssil_enabled | Bool | false | — | Enable indirect lighting |
| ssil_radius | Float | 5.0 | 0.01–16.0 | Sampling radius |
| ssil_intensity | Float | 1.0 | 0.0–10.0 | Contribution strength |
| ssil_sharpness | Float | 0.98 | 0.0–1.0 | Edge-aware blur sharpness |
| ssil_normal_rejection | Float | 1.0 | 0.0–1.0 | Normal rejection factor |
| **SSR** | | | | |
| ssr_enabled | Bool | false | — | Enable screen-space reflections |
| ssr_max_steps | Int | 64 | 1–512 | Ray march steps |
| ssr_fade_in | Float | 0.15 | 0.0–2.0 | Reflection fade-in distance |
| ssr_fade_out | Float | 2.0 | 0.0–8.0 | Reflection fade-out distance |
| ssr_depth_tolerance | Float | 0.2 | 0.01–4.0 | Depth comparison tolerance |
| **Adjustments** | | | | |
| adj_enabled | Bool | false | — | Enable color adjustments |
| adj_brightness | Float | 1.0 | 0.01–4.0 | Brightness multiplier |
| adj_contrast | Float | 1.0 | 0.01–4.0 | Contrast |
| adj_saturation | Float | 1.0 | 0.0–4.0 | Color saturation |
| **Volumetric Fog** | | | | |
| fog_enabled | Bool | false | — | Enable volumetric fog |
| fog_density | Float | 0.05 | 0.0–1.0 | Base fog density |
| fog_albedo | Color | (1, 1, 1) | — | Fog scatter color |
| fog_emission | Color | (0, 0, 0) | — | Fog self-emission color |
| fog_emission_energy | Float | 1.0 | 0.0–16.0 | Fog emission intensity |
| fog_length | Float | 64.0 | 1.0–1024.0 | Volumetric fog distance |

**Inputs:** `comp_in` — accepts multiple COMP connections (multi-input port).

**How it works:** Creates an isolated 3D SubViewport with `own_world_3d = true`. Walks network input connections to discover GeometryCOMP, CameraCOMP, LightCOMP, and MergeCOMP nodes and adopts their 3D nodes into the viewport's scene tree. Creates a `WorldEnvironment` with configurable ambient lighting and post-processing via Godot's `Environment` resource. If no CameraCOMP is connected, a default perspective camera is placed at (0, 1.5, 3). DOF is applied to the active camera (from CameraCOMP or default). Time-dependent — re-populates the scene each frame.

**Performance:** When all post-processing toggles are off and tonemap is at defaults, the post-processing path early-exits with a single boolean check — zero overhead for vanilla 3D renders.

---

#### MultiBufferRenderTOP

Renders a 3D scene into multiple output buffers: color, depth, and normal. Extends RenderTOP with 3 separate output ports for multi-pass compositing workflows.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| depth_enabled | Bool | true | — | Enable depth buffer output on port 1 |
| normal_enabled | Bool | true | — | Enable normal buffer output on port 2 |
| *(inherits all RenderTOP parameters)* | | | | |

**Inputs:** `comp_in` — accepts multiple COMP connections (multi-input port, same as RenderTOP).

**Output 0:** Color — standard rendered scene texture (identical to RenderTOP).
**Output 1:** Depth — depth buffer visualization (uses `DEBUG_DRAW_OVERDRAW`).
**Output 2:** Normal — world-space normal buffer (uses `DEBUG_DRAW_NORMAL_BUFFER`).

**How it works:** Creates secondary SubViewports that share the primary viewport's `World3D` (no scene duplication). Each secondary viewport uses a different Godot debug draw mode to extract depth and normal information. Disabled outputs skip viewport creation entirely. All three outputs are `GNTextureData` GPU references.

---

#### PointCloudRenderTOP

Renders POP particle data as a 2D point-cloud image using GPU compute splatting. Each particle is projected with perspective and drawn as a circular disc with soft-edge falloff and depth testing. Supports per-particle color from POP data or a uniform override color.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| width | Int | 512 | 64–4096 | Output image width |
| height | Int | 512 | 64–4096 | Output image height |
| point_size | Float | 4.0 | 0.5–64.0 | Base splat radius in pixels |
| size_attenuation | Float | 1.0 | 0.0–1.0 | 0 = constant, 1 = full perspective |
| alpha | Float | 1.0 | 0.0–1.0 | Global opacity multiplier |
| use_particle_color | Bool | true | — | Use per-particle color (false = uniform) |
| color | Color | white | — | Uniform color when not using particle color |
| bg_color | Color | transparent | — | Background color |
| cam_dist | Float | 3.0 | 0.1–50.0 | Camera distance from origin |
| cam_yaw | Float | 0.0 | -180–180 | Horizontal rotation (degrees) |
| cam_pitch | Float | 20.0 | -89–89 | Vertical rotation (degrees) |
| fov | Float | 60.0 | 10–120 | Field of view (degrees) |
| near_clip | Float | 0.01 | 0.001–1.0 | Near clipping distance |
| far_clip | Float | 100.0 | 1–1000 | Far clipping distance |

**Input:** `pop` (POP — particle data to render).
**Output:** TOP (rendered point cloud image).

**How it works:** GPU path dispatches `point_cloud_render.glsl` — each invocation reads one particle from the SSBO (64-byte stride), projects to screen space, and splats a circular disc with depth testing. CPU fallback uses the same algorithm with Image pixel writes.

---

#### AnalyzeTOP

Per-pixel statistics: min, max, average, or sum over a configurable kernel.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Average | Min, Max, Average, Sum | Statistic to compute |
| kernel_size | Int | 3 | 1–15 | Neighbourhood size (must be odd) |

**Inputs:** `in` (TOP). **How it works:** Samples NxN neighbourhood and outputs per-pixel statistic.

---

#### MonoTOP

Convert a colour texture to grayscale.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| method | Enum | Rec.709 | Rec.709, Rec.601, Average, Desaturate | Greyscale formula |
| mix | Float | 1.0 | 0.0–1.0 | Blend between original and mono |

**Inputs:** `in` (TOP).

---

#### SharpenTOP

Unsharp-mask sharpening.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0.0–10.0 | Sharpening strength |
| radius | Float | 1.0 | 0.1–10.0 | Blur kernel radius |

**Inputs:** `in` (TOP).

---

#### NormalMapTOP

Generate tangent-space normal map from a height/bump texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0.1–20.0 | Bump amplification |
| invert_y | Bool | false | — | Flip green channel for DirectX convention |

**Inputs:** `in` (TOP).

---

#### DepthTOP

Pseudo-depth extraction via luminance mapping.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| near | Float | 0.1 | 0.01–100.0 | Near-plane luminance mapping |
| far | Float | 100.0 | 0.1–10000.0 | Far-plane luminance mapping |
| invert | Bool | false | — | Flip near→far |

**Inputs:** `in` (TOP). **How it works:** Maps input luminance through near/far range to produce a grayscale depth proxy.

---

#### ChannelMixTOP

Swap and remap RGBA channels with per-channel gain.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| r_source | Enum | Red | R, G, B, A, Luma, Zero, One | Source for red channel |
| g_source | Enum | Green | R, G, B, A, Luma, Zero, One | Source for green channel |
| b_source | Enum | Blue | R, G, B, A, Luma, Zero, One | Source for blue channel |
| a_source | Enum | Alpha | R, G, B, A, Luma, Zero, One | Source for alpha channel |
| r_gain–a_gain | Float | 1.0 | 0.0–2.0 | Per-channel gain |

**Inputs:** `in` (TOP).

---

#### ConvolutionTOP

Custom NxN kernel convolution with presets.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| preset | Enum | Emboss | Custom, Emboss, Sharpen, Edge Detect, Ridge, Gaussian Blur, Box Blur | Kernel preset |
| kernel_size | Int | 3 | 3–7 | Kernel dimension (odd) |
| divisor | Float | 1.0 | 0.001–100.0 | Divide result |
| bias | Float | 0.0 | →1.0–1.0 | Add after division |

**Inputs:** `in` (TOP).

---

#### DilateErodeTOP

Morphological dilation (expand bright) and erosion (shrink bright).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Dilate | Dilate, Erode | Operation |
| radius | Int | 2 | 1–16 | Kernel radius in pixels |

**Inputs:** `in` (TOP).

---

#### LensDistortTOP

Barrel / pincushion lens distortion with chromatic aberration.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| k1 | Float | 0.2 | →2.0–2.0 | Radial distortion (+ barrel, → pincushion) |
| k2 | Float | 0.0 | →1.0–1.0 | Higher-order radial distortion |
| chromatic_aberration | Float | 0.0 | 0.0–5.0 | RGB channel separation |
| bg_color | Color | Transparent | — | Fill outside distortion |

**Inputs:** `in` (TOP).

---

#### LumaBlurTOP

Luminance-weighted selective blur.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| blur_size | Float | 4.0 | 0.0–50.0 | Max blur radius |
| quality | Int | 4 | 1–8 | Samples per direction |
| luma_threshold | Float | 0.5 | 0.0–1.0 | Luminance cutoff |
| blur_bright | Bool | true | — | true = blur brights, false = blur darks |

**Inputs:** `in` (TOP).

---

#### SlopeTOP

Image gradient / derivative.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| output | Enum | Magnitude | Magnitude, Horizontal (dx), Vertical (dy) | Gradient component |
| strength | Float | 1.0 | 0.1–20.0 | Amplification |

**Inputs:** `in` (TOP).

---

#### CornerPinTOP

4-point perspective warp for projection mapping and keystone correction.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| top_left | Vector2 | (0, 0) | — | Top-left corner UV |
| top_right | Vector2 | (1, 0) | — | Top-right corner UV |
| bottom_left | Vector2 | (0, 1) | — | Bottom-left corner UV |
| bottom_right | Vector2 | (1, 1) | — | Bottom-right corner UV |
| bg_color | Color | Transparent | — | Fill outside warp |

**Inputs:** `in` (TOP).

---

#### ProjectionTOP

UV projection mapping: planar, cylindrical, or spherical.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Planar | Planar, Cylindrical, Spherical | Projection type |
| uv_offset | Vector2 | (0, 0) | — | UV translation |
| uv_scale | Vector2 | (1, 1) | — | UV scale |
| rotation | Float | 0.0 | — | UV rotation in radians |

**Inputs:** `in` (TOP).

---

#### FitTOP

Aspect-aware resize with letterbox / fill / stretch.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| fit_mode | Enum | Fit | Fit, Fill, Stretch, Letterbox | Resize strategy |
| resolution | Vector2i | 512×512 | — | Target resolution |
| border_color | Color | Black | — | Letterbox / border fill colour |

**Inputs:** `in` (TOP).

---

### Combiners

These TOPs take two texture inputs and combine them.

---

#### CompositeTOP

Blend two textures with various blend modes.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| operation | Enum | Add | Add, Multiply, Over, Screen, Subtract, Difference | Blend mode |
| opacity | Float | 1.0 | 0.0–1.0 | Blend opacity |

**Inputs:** `A` (TOP), `B` (TOP).

**How it works:** Shader samples both textures and applies the selected blend operation per pixel. Resolution follows input A.

---

#### CrossTOP

Linear crossfade between two textures.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| cross | Float | 0.5 | 0.0–1.0 | Crossfade value (0 = A, 1 = B) |

**Inputs:** `A` (TOP), `B` (TOP).

**How it works:** Shader does `mix(A, B, cross)` per pixel.

---

#### DisplaceTOP

Distort one texture using another as a displacement map.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| weight | Float | 0.1 | 0.0–2.0 | Displacement strength |
| method | Enum | RG as XY | RG as XY, Luminance, RGB as XYZ | How to read displacement |
| scale | Vector2 | (1.0, 1.0) | — | Per-axis displacement scale |

**Inputs:** `source` (TOP — texture to distort), `displace` (TOP — displacement map).

**How it works:** Shader reads displacement values from the second texture, offsets the UV coordinates of the source texture by the displacement amount. Method controls which channels drive the displacement.

---

#### LookupTOP

Color remapping via lookup table texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index_by | Enum | Luminance | Luminance, Red, Green, Blue | Which channel indexes the ramp |

**Inputs:** `source` (TOP — image to remap), `ramp` (TOP — color lookup table).

**How it works:** Shader computes the index value from the source (luminance or single channel), then samples the ramp texture at that position. Output color comes from the ramp.

---

#### ColorMapTOP

Remap luminance to a gradient texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| luma_mode | Enum | Rec.709 | Rec.709, Average, Luminosity | How to compute luminance |
| intensity | Float | 1.0 | 0.0–2.0 | Blend between original and mapped |

**Inputs:** `in` (TOP — source), `gradient` (TOP — gradient/LUT). **How it works:** Computes luminance from source, samples gradient texture at that value.

---

#### RemapTOP

UV displacement remap or 1D LUT value remap.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | UV Remap | UV Remap, Value Remap (LUT) | Remap method |
| strength | Float | 1.0 | 0.0–2.0 | Remap intensity |

**Inputs:** `in` (TOP — source), `map` (TOP — UV displacement or LUT). **How it works:** UV Remap uses map's RG as new UV coordinates; Value Remap uses luminance as LUT index.

---

#### LayoutTOP

Tile up to 8 input textures into a grid mosaic.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| columns | Int | 2 | 1–8 | Grid columns |
| bg_color | Color | Black | — | Background fill |

**Inputs:** Up to 8 dynamic TOP inputs (auto-grow/shrink). **How it works:** Shader tiles N inputs into a grid. Rows auto-calculated from input count and columns.

---

#### ChromaKeyTOP

Chroma / luma key (green-screen) with spill suppression.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| key_mode | Enum | Chroma | Chroma, Luma | Keying method |
| key_color | Color | Green | — | Key target colour |
| threshold | Float | 0.3 | 0.0–1.0 | Tolerance |
| smoothness | Float | 0.1 | 0.0–0.5 | Edge softness |
| spill_reduction | Float | 0.5 | 0.0–1.0 | Green fringe suppression |

**Inputs:** `in` (TOP).

---

#### DeformTOP

Deform/displace a texture using a second texture as displacement map. Three modes: Displace (raw UV shift), Refract (luminance-weighted), Warp (polar displacement).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strength` | Float | 0.1 | Displacement strength |
| `mode` | Enum | Displace | Deformation algorithm (Displace / Refract / Warp) |
| `resolution` | Vector2i | 1024×1024 | Output resolution |

**Inputs:** `in` (TOP source), `deform` (TOP displacement map).

---

#### ReorderTOP

Reorder/swizzle RGBA channels of a texture. Maps each output channel from any input channel (Red, Green, Blue, Alpha, One, Zero, Luminance).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `output_r` | Enum | Red | Source for output red |
| `output_g` | Enum | Green | Source for output green |
| `output_b` | Enum | Blue | Source for output blue |
| `output_a` | Enum | Alpha | Source for output alpha |
| `resolution` | Vector2i | 1024×1024 | Output resolution |

**Inputs:** `in` (TOP).

---

### Temporal / Buffer

These TOPs store frames over time for delay, scrubbing, and playback control.

---

#### CacheTOP

Ring buffer — stores N frames with delay and freeze controls.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| length | Int | 30 | 1–300 | Buffer length in frames |
| delay | Int | 0 | 0–299 | Output frame offset into the past |
| freeze | Bool | false | — | Pause recording |
| reset | Bool (pulse) | false | — | Clear the buffer |

**Inputs:** `in` (TOP). **How it works:** Captures each input frame as an ImageTexture (GPU→CPU→GPU roundtrip). Ring buffer advances each cook. Delay outputs a past frame.

---

#### TimeMachineTOP

Playback controller over a frame buffer with speed, scrub, and wrap modes.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| speed | Float | 1.0 | →10.0–10.0 | Playback speed |
| position | Float | 0.0 | 0.0–1.0 | Normalised scrub position |
| use_position | Bool | false | — | Override speed with position scrub |
| wrap_mode | Enum | Clamp | Clamp, Loop, Ping-Pong | End-of-buffer behaviour |
| freeze | Bool | false | — | Pause playback |
| reset | Bool (pulse) | false | — | Reset playback head |

**Inputs:** `in` (TOP — typically from CacheTOP). **How it works:** Reads from input CacheTOP's buffer. Speed/position controls which stored frame to output.

---

### Simulation / Generative

These feedback-loop TOPs evolve a physical or mathematical simulation each frame, producing animated generative textures. Both use a dual-viewport architecture: a **sim viewport** (CLEAR_MODE_NEVER, SCREEN_TEXTURE feedback) that carries state between frames, and a **render viewport** that colorizes the raw simulation buffer for output.

---

#### Fluid2DTOP

2D Navier-Stokes fluid simulation rendered as a live texture. Semi-Lagrangian advection, vorticity confinement, pressure correction, and configurable emitter with optional dye injection.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Output / simulation resolution |
| emitter_pos | Vector2 | (0.5, 0.5) | 0–1 | Emitter position (normalized UV) |
| emitter_dir | Vector2 | (0, -1) | — | Force direction vector |
| emitter_radius | Float | 0.06 | 0.01–0.5 | Emitter radius (normalized) |
| emitter_force | Float | 1.0 | 0.0–10.0 | Force injection strength |
| emitter_dye | Float | 1.0 | 0.0–5.0 | Dye injection amount |
| enable_emitter | Bool | true | — | Toggle emitter on/off |
| velocity_dissipation | Float | 0.995 | 0.9–1.0 | Velocity decay per step |
| density_dissipation | Float | 0.98 | 0.9–1.0 | Density decay per step |
| vorticity | Float | 0.3 | 0.0–2.0 | Vorticity confinement strength |
| pressure | Float | 16.0 | 0.0–32.0 | Pressure correction strength |
| dye_color_a | Color | (1, 0.4, 0.1) | — | Primary dye color |
| dye_color_b | Color | (0.1, 0.4, 1) | — | Secondary dye color |
| brightness | Float | 1.5 | 0.1–5.0 | Output brightness multiplier |
| show_velocity | Bool | false | — | Visualize velocity field |
| reset | Bool | false | — | Clear and restart simulation |

**Input 0:** `dye` (TOP, optional) — external dye source texture.
**Output:** TOP (colorized fluid density + velocity).

**How it works:** The sim shader packs velocity (RG) and density (B) into an RGBA buffer using SCREEN_TEXTURE for frame-to-frame feedback. Each frame: (1) self-advect velocity via semi-Lagrangian backtrace, (2) compute and apply vorticity confinement, (3) simplified pressure projection, (4) inject emitter force + dye, (5) apply dissipation. The render shader reads the packed buffer and maps density to a two-color gradient, or shows velocity magnitude when `show_velocity` is enabled. Emitter parameters support expressions for animated position/direction.

---

#### ReactionDiffusionTOP

Gray-Scott reaction-diffusion simulation — evolves two chemicals (U, V) via diffusion and reaction to produce emergent patterns: spots, stripes, coral, mazes, worms, and more.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512×512 | — | Simulation / output resolution |
| feed_rate | Float | 0.055 | 0.0–0.1 | Replenishment rate of U (controls pattern type) |
| kill_rate | Float | 0.062 | 0.0–0.1 | Removal rate of V (controls pattern type) |
| diffusion_u | Float | 1.0 | 0.0–2.0 | Diffusion rate of chemical U |
| diffusion_v | Float | 0.5 | 0.0–2.0 | Diffusion rate of chemical V |
| speed | Float | 1.0 | 0.1–5.0 | Time step multiplier |
| steps_per_frame | Int | 4 | 1–32 | Sub-steps per render (higher = faster evolution) |
| seed_pos | Vector2 | (0.5, 0.5) | 0–1 | Circle seed injection position |
| seed_radius | Float | 0.05 | 0.01–0.3 | Seed circle radius |
| seed_amount | Float | 0.25 | 0.0–1.0 | V concentration injected |
| add_seed | Bool | false | — | Inject seed this frame (pulse) |
| color_mode | Enum | Mono | Mono, Heat Map, Custom | Output coloring style |
| color_a | Color | Black | — | Background color (Custom mode) |
| color_b | Color | White | — | Pattern color (Custom mode) |
| brightness | Float | 1.0 | 0.1–5.0 | Output brightness |
| invert | Bool | false | — | Swap foreground/background |
| reset | Bool | false | — | Re-initialize simulation |
| preset | Enum | Custom | Custom, Mitosis, Coral, Maze, Spots, Worms, Waves | Quick parameter presets |

**Input 0:** `seed` (TOP, optional) — seed mask texture (bright pixels inject V).
**Output:** TOP (colorized reaction-diffusion pattern).

**How it works:** U (red channel) and V (green channel) evolve via the Gray-Scott equations: `dU/dt = Du∇²U - UV² + f(1-U)`, `dV/dt = Dv∇²V + UV² - (f+k)V`. The Laplacian uses a 3×3 weighted stencil. Multiple sub-steps per frame accelerate evolution without frame-rate coupling. SCREEN_TEXTURE provides frame-to-frame feedback. The 7 presets set (f, k) pairs that produce distinct pattern families — selecting a preset auto-resets the simulation. The render shader offers three modes: Mono (V concentration as grayscale), Heat Map (4-stop palette from blue through white), and Custom (two-color ramp).

---

### Utility

---

#### NullTOP

Pass-through. No processing — forwards input to output unchanged.

Used as an organizational endpoint, a reference target for expressions, or to "name" a point in the network.

---

#### SwitchTOP

Select one of up to 4 inputs by index.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index | Int | 0 | 0–3 | Which input to output |
| blend | Bool | false | — | Blend between adjacent inputs (stubbed) |

**Inputs:** `in0`, `in1`, `in2`, `in3` (all TOP).

**How it works:** Returns the texture from the selected input index. Falls back to the first valid input if the selected index has no connection.

---

### Filters (New — Matte, Premultiply, Posterize, Radial Blur, Anti-Alias, Palette)

---

#### MatteTOP

Apply alpha from a second texture. Configurable source channel (Luma, R, G, B, A), invert, and premultiply options.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| source | Enum | Luma | Luma/R/G/B/A | Which channel of the matte input drives alpha |
| invert | Bool | false | — | Invert the matte |
| premultiply | Bool | true | — | Premultiply RGB by new alpha |

**Inputs:** `in` (TOP — source), `matte` (TOP — alpha source). **Shader:** `matte.gdshader`.

---

#### PremultiplyTOP

Premultiply or unpremultiply RGB by alpha. Essential for correct compositing workflows.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Premultiply | Premultiply/Unpremultiply | Operation mode |

**Input:** `in` (TOP). **Shader:** `premultiply.gdshader`.

---

#### PosterizeTOP

Reduce color depth to N discrete levels per channel.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| levels | Int | 8 | 2–256 | Number of color levels |

**Input:** `in` (TOP). **Shader:** `posterize.gdshader`.

---

#### RadialBlurTOP

Zoom / radial blur effect radiating from a configurable center point.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 0.1 | 0–1 | Blur intensity |
| center_x | Float | 0.5 | 0–1 | Blur center X |
| center_y | Float | 0.5 | 0–1 | Blur center Y |
| samples | Int | 16 | 4–64 | Number of samples (quality) |

**Input:** `in` (TOP). **Shader:** `radial_blur.gdshader`.

---

#### AntiAliasTOP

Simplified FXAA-style anti-aliasing with luma-based edge detection.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0–2 | AA blending strength |
| edge_threshold | Float | 0.125 | 0.01–0.5 | Minimum edge contrast to trigger AA |

**Input:** `in` (TOP). **Shader:** `anti_alias.gdshader`.

---

#### PaletteTOP

Quantize image colors to a palette texture with optional Bayer dithering.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| palette_size | Int | 16 | 2–256 | Number of palette colors to use |
| dithering | Bool | false | — | Enable 4×4 Bayer dithering |

**Inputs:** `in` (TOP — source), `palette` (TOP — palette texture). **Shader:** `palette.gdshader`.

---

### Bridge (New)

---

#### CHOPtoTOP

Render CHOP channels as a texture — waveform oscilloscope, heatmap, or graph.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Waveform | Waveform, Heatmap, Graph | Visualisation style |
| resolution | Vector2i | 512×256 | — | Output image size |
| background | Color | (0.05, 0.05, 0.05) | — | Background colour |
| line_color | Color | (0.2, 0.8, 0.2) | — | Waveform / graph line colour |
| line_width | Float | 2.0 | 1.0–8.0 | Stroke width in pixels |
| min_val | Float | -1.0 | -1000–1000 | Value mapped to bottom of image |
| max_val | Float | 1.0 | -1000–1000 | Value mapped to top of image |
| auto_range | Bool | true | — | Auto-fit min/max to channel data |

**Input:** `in` (CHOP — source channels).

**How it works:** CPU-based Image rendering (no SubViewport). Reads channel samples and draws into an `Image`, then converts to `ImageTexture`. Waveform mode draws lines between samples; Heatmap maps values to a red-blue gradient; Graph draws filled bars. Auto-range scans the data for min/max each cook.

---

#### SnapshotTOP

Renders any non-TOP data type as a TOP texture — the same visualization the viewer panel shows, but as a node output for downstream processing. Shares rendering code with `GNViewerPanel` via `GNViewerRenderer`, so viewer improvements automatically update this node too.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | SOP | SOP, CHOP, DAT, POP, VOL, MAT, IMG | Select the input data family. Changing mode rebuilds the input port type. |
| resolution | Vector2i | 512×512 | — | Output image size |
| orbit_yaw | Float | 45.0 | -360–360 | Horizontal camera rotation (SOP/POP modes) |
| orbit_pitch | Float | -30.0 | -89–89 | Vertical camera rotation (SOP/POP modes) |
| orbit_distance | Float | 3.0 | 0.5–50 | Camera distance from origin (SOP/POP modes) |
| wireframe | Bool | false | — | Render mesh as wireframe (SOP mode) |
| point_size | Float | 0.02 | 0.001–1.0 | Billboard size per particle (POP mode) |
| vol_view | Enum | Slices | Slices, MIP | Volume visualization style (VOL mode) |
| slice_pos | Float | 0.5 | 0.0–1.0 | Normalized slice position along each axis (VOL mode) |

**Input:** `in` — dynamic port, family changes with mode (SOP/CHOP/DAT/POP/VOL/MAT/IMG).

**How it works:** Delegates all rendering to `GNViewerRenderer` — the same static utility class that `GNViewerPanel` uses. SOP and POP modes create lazily-initialized SubViewports with orbit cameras. CHOP mode renders a waveform to a CPU Image. DAT mode renders a grid-cell table. VOL mode composites 3 orthogonal slices (or MIP) into a single image. MAT mode renders a lit sphere with the material applied. IMG mode is a direct pass-through upload. Parameters that don't apply to the current mode are automatically hidden.

---

### PanelTOP

Container that renders connected UI widgets into a SubViewport texture. Outputs a non-interactive GNTextureData for use in TOP chains (blur, composite, recording). For widget state data, use each UI widget's own CHOP `state` output port.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512x512 | — | SubViewport render resolution |
| layout | Enum | VBox | VBox, HBox, Grid, Flow | How child widgets are arranged |
| padding | Int | 8 | 0-100 | Internal padding (pixels) |
| bg_color | Color | (0.15, 0.15, 0.15) | — | Background color |
| bg_opacity | Float | 1.0 | 0.0-1.0 | Background opacity |
| columns | Int | 2 | 1-10 | Column count (Grid layout only) |

**Input:** Dynamic UI inputs (unlimited connected UI widgets).
**Output 0:** TOP (GNTextureData, pixels only, non-interactive).

**How it works:** Creates a SubViewport with `gui_disable_input = true` and a root container inside. During cook, reparents each connected UI widget's `_control_node` into the root container. The SubViewport renders the widget tree into a texture. No interactive input is forwarded — for interactive panels, wire widgets through ContainerUI to WindowOUT's panel port instead.

---

## IMG — Image Operators

IMGs process CPU-side `Image` data. Unlike TOPs (GPU textures via SubViewport), IMGs work on raw pixel buffers for operations that need CPU access: file I/O, pixel sorting, procedural generation, and format conversion. All IMG data flows as `GNImageData` — a lightweight RefCounted wrapper around Godot's `Image` class.

Use `ImgToTOP` to bridge IMG output into the GPU TOP pipeline.

**Total: 13 operators** — 2 generators, 5 filters, 2 I/O, 2 bridges, 1 capture, 1 script, 1 utility.

---

#### NullIMG

Pass-through. Forwards input image unchanged. Useful for wire organization, expression references, and inspecting multi-output ports.

---

## CHOP — Channel Operators

CHOPs process named float arrays (channels). Each channel is a `PackedFloat32Array` with a name (e.g., "tx", "ty", "tz", "out"). Single-sample CHOPs act as real-time control signals. Multi-sample CHOPs carry waveform data, audio, or patterns.

All CHOP data flows as `GNChannelData` — a lightweight RefCounted wrapper around a `Dictionary` of named float arrays.

**Total: 66 operators** — 7 generators, 19 filters, 7 combiners, 7 utility, 5 channel management, 3 input devices, 4 bridge, 4 animation/sequencing, 2 object/skeleton, 1 tablet, 7 signal analysis & audio.

### Generators

These CHOPs create channel data from scratch.

---

#### LFO CHOP

Low-frequency oscillator. The fundamental animation driver in GONODES.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| waveform | Enum | Sine | Sine, Triangle, Square, Sawtooth, Pulse | Wave shape |
| frequency | Float | 1.0 | 0.001–100.0 | Oscillation speed in Hz |
| amplitude | Float | 1.0 | 0.0+ | Output amplitude |
| offset | Float | 0.0 | — | DC offset |
| phase | Float | 0.0 | 0.0–1.0 | Phase offset |
| duty_cycle | Float | 0.5 | 0.0–1.0 | Pulse width (Pulse waveform only) |

**Output:** Single channel `"out"`.

**How it works:** Phase accumulator advances by `frequency * delta_time` each frame. The accumulator feeds into the selected waveform function. Time-dependent — always cooks (produces a new value every frame).

---

#### WaveCHOP

Multi-channel, multi-sample waveform generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| waveform | Enum | Sine | Sine, Triangle, Square, Sawtooth, Pulse, Ramp | Wave shape |
| channels | Int | 1 | 1–16 | Number of channels |
| length | Int | 1 | 1–4096 | Samples per channel |
| frequency | Float | 1.0 | 0.001–1000.0 | Wave frequency |
| amplitude | Float | 1.0 | 0.0+ | Output amplitude |
| offset | Float | 0.0 | — | DC offset |
| phase | Float | 0.0 | 0.0–1.0 | Phase offset |
| phase_step | Float | 0.0 | 0.0–1.0 | Phase offset per channel |

**How it works:** When `length = 1`, uses `elapsed_time` for animated output (time-dependent). When `length > 1`, fills a multi-sample array over a 0→1 phase sweep. `phase_step` offsets each channel's phase for spread effects. Channels are named `chan0`, `chan1`, etc.

---

#### NoiseCHOP

Smooth procedural noise channels.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| num_channels | Int | 1 | 1–16 | Number of channels |
| channel_names | String | "chan1" | — | Comma-separated names |
| roughness | Float | 0.5 | 0.0–1.0 | Fractal roughness (octave blending) |
| period | Float | 1.0 | 0.01–100.0 | Noise period/speed |
| seed | Int | 0 | 0–99999 | Random seed |

**How it works:** Time accumulator advances each frame. Samples custom 1D smooth noise (hash-based with cubic interpolation) per channel. Roughness controls octave layering. Each channel uses a different seed offset. Time-dependent.

---

#### ConstantCHOP

Static named values with a dynamic number of channel slots.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| count | Int | 1 | 1–32 | Number of channel slots |
| nameN | String | "chan1" (slot 0) / "" | — | Channel name (empty = skip) |
| valueN | Float | 0.0 | — | Constant value for channel |

**How it works:** The **count** parameter controls how many name/value pairs appear in the inspector (1–32). Changing count at runtime dynamically adds or removes parameter slots — existing values are preserved when growing. Skips channels with empty names. Useful for constants, UI controls, and reference values.

---

#### PatternCHOP

Multi-sample pattern generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| type | Enum | Ramp | Ramp, Sine, Cosine, Step, Random, Constant | Pattern type |
| length | Int | 100 | 1–16384 | Number of samples |
| channels | Int | 1 | 1–16 | Number of channels |
| from_value | Float | 0.0 | — | Range start |
| to_value | Float | 1.0 | — | Range end |
| cycles | Float | 1.0 | 0.001+ | Number of cycles |
| seed | Int | 0 | 0–99999 | Seed (for Random pattern) |

**How it works:** Fills a multi-sample array with the selected pattern. Ramp = linear interpolation from→to. Sine/Cosine = cyclic wave mapped to from/to range. Step = binary toggle. Random = seeded random values. Constant = flat value. Channels are named `chan0`, `chan1`, etc.

---

#### TimerCHOP

Countdown/count-up timer with start/reset triggers.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| length | Float | 10.0 | 0.0+ | Timer duration in seconds |
| loop | Bool | false | — | Loop when complete |
| auto_start | Bool | true | — | Start automatically |
| speed | Float | 1.0 | 0.0+ | Time multiplier |

**Inputs:** `start` (CHOP — rising edge starts timer), `reset` (CHOP — rising edge resets).

**Output channels:** `timer_seconds` (elapsed time), `timer_fraction` (0→1 progress), `running` (0 or 1), `done` (0 or 1).

**How it works:** Counts up using `delta_time * speed`. Start/reset inputs use rising-edge detection. Auto-starts on first cook if enabled and no start input is connected. Time-dependent.

---

### Filters

These CHOPs take one input and modify the channel values.

---

#### FilterCHOP

Low-pass or high-pass filter.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| type | Enum | Low Pass | Low Pass, High Pass | Filter type |
| cutoff | Float | 0.1 | 0.001–1.0 | Cutoff frequency (normalized) |
| reset | Bool | false | — | Reset filter state |

**How it works:** Single-pole IIR filter. Low pass: `y = y_prev + α * (x - y_prev)`. High pass: `y = x - low_pass_result`. Alpha = clamped cutoff value. Maintains per-channel state across frames. Time-dependent.

---

#### LagCHOP

Exponential smoothing with separate attack and release times.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| attack | Float | 0.2 | 0.0–10.0 | Rise time in seconds |
| release | Float | 0.2 | 0.0–10.0 | Fall time in seconds |
| reset | Bool | false | — | Reset to current input value |

**How it works:** Uses `1.0 - exp(-dt / tau)` for frame-rate independent smoothing. Attack time is used when the input is rising, release time when falling. Time-dependent.

---

#### LimitCHOP

Clamp, loop, or zig-zag values into a range.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| type | Enum | Clamp | Clamp, Loop, Zig-Zag | Limit mode |
| min | Float | 0.0 | — | Range minimum |
| max | Float | 1.0 | — | Range maximum |

**How it works:** Processes each sample. Clamp = `clamp(val, min, max)`. Loop = wraps using `fmod`. Zig-Zag = bounces back and forth within the range.

---

#### TriggerCHOP

Rising-edge triggered envelope generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | — | Trigger threshold |
| attack | Float | 0.0 | 0.0–10.0 | Attack time in seconds |
| peak | Float | 1.0 | 0.0+ | Peak value |
| decay | Float | 0.5 | 0.0–10.0 | Decay time in seconds |
| retrigger | Bool | true | — | Allow retriggering during decay |

**How it works:** Detects rising edges (input crosses threshold). On trigger, starts an attack→peak→decay envelope. After decay completes, output returns to 0. Per-channel state tracking. Time-dependent.

---

#### HoldCHOP

Sample-and-hold. Captures input values on trigger and holds them.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | — | Trigger threshold |
| hold_on_start | Bool | true | — | Capture value on first cook |
| reset | Bool | false | — | Clear held values |

**Inputs:** `in` (CHOP — values to sample), `trigger` (CHOP — rising edge triggers capture).

**How it works:** On rising edge of trigger input, captures current input values and holds them until the next trigger. Time-dependent.

---

#### SpeedCHOP

Velocity integrator. Accumulates input values over time.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| scale | Float | 1.0 | — | Speed multiplier |
| clamp | Bool | false | — | Clamp accumulated value |
| min | Float | -1000.0 | — | Clamp minimum |
| max | Float | 1000.0 | — | Clamp maximum |
| reset_all | Bool | false | — | Reset accumulator |

**Inputs:** `in` (CHOP — velocity), `reset` (CHOP — rising edge resets).

**How it works:** Each frame: `accumulator += input * scale * delta_time`. Optional clamping. Useful for converting speed/velocity signals to position. Time-dependent.

---

#### CountCHOP

Event counter with rising-edge detection.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | — | Trigger threshold |
| step | Float | 1.0 | — | Count increment |
| limit_min | Float | 0.0 | — | Minimum count value |
| limit_max | Float | 1000000.0 | — | Maximum count value |
| overflow | Enum | Clamp | Clamp, Loop | What to do at limits |
| reset_all | Bool | false | — | Reset all counters |

**Inputs:** `in` (CHOP — events to count), `reset` (CHOP — resets counter).

**How it works:** Detects rising edges crossing threshold. Increments count by `step` on each trigger. Applies min/max limits with clamp or loop overflow. Per-channel counting. Time-dependent.

---

#### SelectCHOP

Filter and rename channels by pattern.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| pattern | String | "*" | — | Channel name pattern (e.g., `*`, `tx,ty`, `chan*`) |
| rename | String | "" | — | Comma-separated rename list (empty = keep names) |

**How it works:** Matches channel names against wildcard patterns. Supports `*` (match all), `prefix*`, `*suffix`. Comma-separated patterns for multiple matches. Optionally renames matched channels in order.

---

### Combiners

These CHOPs take two or more inputs and combine them.

---

#### MathCHOP

Arithmetic operations between channels.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| operation | Enum | Add | Add, Subtract, Multiply, Divide, Abs, Sin, Cos, Pow | Math operation |
| operand | Float | 0.0 | — | Value for single-input operations |
| channel_name | String | "" | — | Pick a specific in2 channel (empty = auto-match) |

**Inputs:** `in1` (CHOP), `in2` (CHOP, optional).

**How it works:** With 2 inputs, applies binary operation per-sample on matching channels. With 1 input, uses `operand` parameter for binary ops or applies unary ops (Abs, Sin, Cos). Pow uses second input or operand as exponent. When `channel_name` is set, the named channel from `in2` is used as the second operand for every `in1` channel. When empty, channels are matched automatically: by name first, then single-channel broadcast, then index position.

---

#### MergeCHOP

Merge channels from up to 4 inputs.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| duplicate | Enum | Overwrite | Overwrite, Rename | Duplicate name handling |

**Inputs:** `in1`, `in2`, `in3`, `in4` (all CHOP).

**How it works:** Collects all channels from all inputs into one output. When channel names collide, either overwrites (last wins) or renames with `_N` suffix.

---

#### CrossCHOP

Crossfade between two channel sets.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| cross | Float | 0.5 | 0.0–1.0 | Crossfade value (0 = A, 1 = B) |

**Inputs:** `A` (CHOP), `B` (CHOP).

**How it works:** Linearly interpolates (`lerpf`) between matching channels from A and B. If only one input has a channel, blends toward 0.

---

#### LogicCHOP

Boolean logic operations between channels.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| operation | Enum | AND | AND, OR, XOR, NAND, NOR, NOT | Logic operation |
| threshold | Float | 0.5 | — | True/false threshold |

**Inputs:** `in1` (CHOP), `in2` (CHOP, optional — NOT uses only in1).

**How it works:** Converts values to boolean (≥ threshold = true). Applies logic operation per-sample. Outputs 1.0 (true) or 0.0 (false).

---

### Utility

---

#### NullCHOP

Pass-through. Forwards input unchanged.

---

#### SwitchCHOP

Select one of up to 4 inputs by index.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index | Int | 0 | 0–3 | Which input to output |

**Inputs:** `in0`, `in1`, `in2`, `in3` (all CHOP).

---

#### RenameCHOP

Rename input channels with explicit from→to mapping. Channels not matched by any rename row pass through with their original name. Empty from/to fields are skipped.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| renames | Int | 1 | 1–32 | Number of rename rows |
| fromN | String | "" | — | Source channel name for row N (0-based) |
| toN | String | "" | — | Target channel name for row N (0-based) |

**Input:** `in` (CHOP).

**How it works:** For each channel in the input, checks if its name matches any `fromN` value. If matched, the channel is output under the corresponding `toN` name. Unmatched channels are copied unchanged. The number of from/to pairs is controlled by the `renames` parameter and can be changed dynamically.

---

#### DATtoCHOP *(Bridge — DAT → CHOP)*

Converts a DAT table to CHOP channels. Lives in the `dat/` folder but produces CHOP output (family = CHOP).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| layout | Enum | Columns as Channels | Columns as Channels, Rows as Channels | Conversion layout |
| first_is_name | Bool | true | — | Use first row/column as channel names |

**Input:** `dat_in` (DAT).

**How it works:** Parses numeric cell values from the DAT table into float arrays. Non-numeric cells become 0.0. Column mode: each column becomes a channel. Row mode: each row becomes a channel.

---

#### PhysicsCHOP *(Bridge — COMP → CHOP)*

Reads transform, velocity, and state from an upstream physics body COMP and outputs them as CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| position | Bool | true | Output `tx`, `ty`, `tz` channels |
| rotation | Bool | true | Output `rx`, `ry`, `rz` channels (degrees) |
| scale | Bool | false | Output `sx`, `sy`, `sz` channels |
| linear_vel | Bool | true | Output `vel_x`, `vel_y`, `vel_z` channels |
| angular_vel | Bool | false | Output `ang_vel_x`, `ang_vel_y`, `ang_vel_z` channels |
| speed | Bool | false | Output `speed` channel (velocity magnitude) |
| sleeping | Bool | false | Output `sleeping` channel (1.0 = asleep) |

**Input:** `comp_in` (COMP — a physics body such as RigidBodyCOMP).

**How it works:** Walks the network to find the upstream COMP's scene node (`RigidBody3D`, `StaticBody3D`, etc.) and reads its current transform and physics state. Each enabled parameter group adds the corresponding channels to the output. Position and rotation use global coordinates when the node is inside a scene tree. Velocity and sleeping state are only meaningful for `RigidBody3D` nodes; other body types output zeros for those channels.

---

### Generators (New)

---

#### ClockCHOP

System time, frame count, elapsed time, and BPM beat channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| bpm | Float | 120.0 | Beats per minute for beat channels |
| time_channels | Bool | true | Output hours, minutes, seconds |
| beat_channels | Bool | true | Output beat, bar, beat_frac |

**How it works:** Uses `Engine.get_frames_drawn()`, `Time.get_time_dict_from_system()`, and `elapsed_time` from the cook engine. BPM channels derive beat position from elapsed time.

---

#### ExpressionCHOP

Per-channel GDScript expression evaluation with time variables.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| channels | Int | 1 | Number of output channels |
| exprN | String | "v" | Expression for channel N |

**Input:** `in` (CHOP, optional).

**How it works:** Uses Godot's `Expression` class. Variables: `v` (input value), `i` (sample index), `n` (sample count), `t` (elapsed time), `dt` (delta), `ch` (channel dictionary). Evaluated per-sample per-channel.

---

### Filters (New)

---

#### SmoothCHOP

Biquad Butterworth IIR filter (low-pass, high-pass, band-pass).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| type | Enum | Low Pass | Low Pass, High Pass, Band Pass |
| cutoff | Float | 0.5 | Normalized cutoff frequency (0–1) |
| q | Float | 0.707 | Resonance / quality factor |

**Input:** `in` (CHOP).

**How it works:** Implements a biquad filter with Butterworth coefficient calculation. Maintains 4 state variables per channel (_x1, _x2, _y1, _y2) for proper IIR feedback.

---

#### SpringCHOP

Damped harmonic oscillator — channels spring toward input values.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| stiffness | Float | 10.0 | Spring stiffness constant |
| damping | Float | 0.5 | Damping ratio (0 = no damping, 1 = critical) |

**Input:** `in` (CHOP).

**How it works:** Semi-implicit Euler integration of `F = -k(pos - target) - d*vel`. Maintains per-channel position and velocity dictionaries. Creates bouncy, springy motion following input.

---

#### DelayCHOP

Delay channels by N frames using a ring buffer.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| frames | Int | 10 | Number of frames to delay |

**Input:** `in` (CHOP).

**How it works:** Maintains a ring buffer of past frame values per channel. Reads from `(write_idx - frames) % buffer_size` for delayed output.

---

#### EnvelopeCHOP

Envelope follower — RMS, peak, or average-abs with window size.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | RMS | RMS, Peak, Average Absolute |
| window | Int | 30 | Sliding window size in frames |

**Input:** `in` (CHOP).

**How it works:** Maintains a sliding ring buffer per channel. Computes the selected statistic over the window for smooth envelope tracking.

---

#### AnalyzeCHOP

Per-channel statistics: single output value per channel.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| function | Enum | Average | Average, Min, Max, Sum, RMS, Range, Count |

**Input:** `in` (CHOP).

**How it works:** Reduces each channel's sample array to a single summary value.

---

#### LookupCHOP

Index into a sample array using another channel as lookup position.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| interpolate | Enum | Linear | Nearest, Linear |
| extend | Enum | Clamp | Clamp, Cycle, Mirror |

**Inputs:** `table` (CHOP — lookup data), `index` (CHOP — lookup positions 0–1).

**How it works:** Normalizes index values to the table's sample range. Reads interpolated values from the table at the indexed position.

---

#### StretchCHOP

Time-stretch samples with Catmull-Rom cubic interpolation.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | To Length | To Length, By Factor |
| target | Int | 100 | Target sample count (To Length mode) |
| factor | Float | 2.0 | Stretch factor (By Factor mode) |
| interpolate | Enum | Linear | Linear, Cubic (Catmull-Rom) |

**Input:** `in` (CHOP).

**How it works:** Resamples channels to a new length. Catmull-Rom mode uses 4-point cubic interpolation for smooth results.

---

#### ResampleCHOP

Resample channels to a new sample count or sample rate.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| method | Enum | To Samples | To Samples, To Rate |
| samples | Int | 100 | Target sample count |
| rate | Float | 60.0 | Target sample rate |

**Input:** `in` (CHOP).

**How it works:** Linear interpolation to resize sample arrays. Rate mode calculates target length from current length and rate ratio.

---

#### TrimCHOP

Extract a sub-range of samples from channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| unit | Enum | Samples | Samples, Fraction, From End |
| start | Int | 0 | Start position |
| end | Int | -1 | End position (-1 = last sample) |

**Input:** `in` (CHOP).

---

#### ExtendCHOP

Pad samples before/after with selectable extend modes.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| before_mode | Enum | Hold | Hold, Cycle, Mirror, Slope, Zero |
| after_mode | Enum | Hold | Hold, Cycle, Mirror, Slope, Zero |
| before_length | Int | 0 | Samples to add before |
| after_length | Int | 0 | Samples to add after |

**Input:** `in` (CHOP).

---

### Combiners (New)

---

#### InterpolateCHOP

Blend between two channel sets with easing curves.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| blend | Float | 0.5 | Blend factor (0 = input A, 1 = input B) |
| curve | Enum | Linear | Linear, Ease In, Ease Out, Ease In-Out, Smooth Step |

**Inputs:** `a` (CHOP), `b` (CHOP).

---

#### JoinCHOP

Concatenate samples from multiple inputs with optional crossfade.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| overlap | Int | 0 | Crossfade overlap in samples |

**Inputs:** Dynamic (auto-grow). Each input's samples are appended end-to-end.

---

#### CompositeCHOP

Weighted blend from multiple dynamic inputs.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| method | Enum | Average | Average, Add, Max, Min |

**Inputs:** Dynamic (auto-grow).

---

#### CopyCHOP

Copy channels from input B onto input A.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| operation | Enum | Overwrite | Overwrite, Add, Subtract, Multiply |

**Inputs:** `a` (CHOP), `b` (CHOP).

---

### Channel Management (New)

---

#### ShuffleCHOP

Reorder, reverse, sort, or randomize channel order.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Reverse | Reverse, Sort by Name, Sort by Value, Random |
| seed | Int | 0 | Random seed (Random mode) |

**Input:** `in` (CHOP).

---

#### SplitCHOP

Select one channel or group of N channels from input.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Single | Single, Group |
| index | Int | 0 | Channel index to select |
| group_size | Int | 1 | Group size (Group mode) |

**Input:** `in` (CHOP).

---

#### FanCHOP

Fan a single channel into multiple copies with offset spread.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| copies | Int | 3 | Number of output copies |
| spread | Float | 0.1 | Offset per copy |
| operation | Enum | Add | Add, Multiply, Phase Shift |

**Input:** `in` (CHOP).

---

#### DeleteCHOP

Delete channels by name pattern, index, or keep-only mode.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | By Pattern | By Pattern, By Index, Keep Only |
| pattern | String | "" | Space-separated patterns (wildcards: * ?) |
| index | Int | 0 | Channel index (By Index mode) |

**Input:** `in` (CHOP).

---

### Input Devices (New)

---

#### KeyboardInCHOP

Outputs keyboard key states as CHOP channels. Each tracked key becomes a channel with value 1.0 (pressed) or 0.0 (released).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| keys | String | "w a s d space" | Space-separated key names |
| mode | Enum | Momentary | Toggle (flip on press), Momentary (held = 1) |
| window | String | "" | WindowOUT node name to read from (empty = global Input) |

**Channels:** Per-key channels (1.0/0.0), plus `focused` (1.0 when target window has focus) when `window` is set.

**Time-dependent.** When `window` is empty, uses global `Input.is_key_pressed()`. When set, reads per-window key state tracked by WindowOUT's `_on_window_input()` handler.

---

#### MouseInCHOP

Outputs mouse position, delta, buttons, and scroll as CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| normalized | Bool | true | Normalize position to 0–1 by viewport/window size |
| buttons | Bool | true | Output lmb, rmb, mmb channels |
| scroll | Bool | true | Output scroll channel |
| window | String | "" | WindowOUT node name to read from (empty = global Input) |

**Channels:** `tx`, `ty`, `dx`, `dy`, `lmb`, `rmb`, `mmb`, `scroll`, plus `focused` when `window` is set. When bound to a WindowOUT, position/delta are in that window's local coordinates and normalization uses the window's size.

**Time-dependent.**

---

#### GamepadCHOP

Outputs gamepad/controller stick, trigger, and button states.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| device | Int | 0 | Gamepad device index (0–7) |
| deadzone | Float | 0.1 | Stick deadzone threshold |

**Channels:** `lx`, `ly`, `rx`, `ry` (sticks), `lt`, `rt` (triggers), `a`, `b`, `x`, `y`, `lb`, `rb`, `start`, `select`, d-pad. **Time-dependent.**

---

### Bridge (New)

---

#### ParameterCHOP

Reads another node's parameter values as CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| node_path | String | "" | Target node ID |
| parameters | String | "" | Space-separated param names (empty = all) |

**How it works:** Walks up to the GNNetwork, finds the target node by ID, reads parameter values. Each float parameter becomes a single-value channel.

---

#### TrailCHOP

Scrolling buffer that records input channel values over time (oscilloscope trace).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| length | Int | 120 | 2–3600 | Number of frames to record |
| active | Bool | true | — | Enable recording |

**Input:** `in` (CHOP). **Time-dependent.** Maintains ring buffers per channel.

---

#### SOPtoCHOP

Extracts SOP vertex data as CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| attribute | Enum | Position | Position, Normal, UV |
| max_points | Int | 1000 | Max vertices to read |

**Input:** `in` (SOP). **Channels:** `px`/`py`/`pz` (position), `nx`/`ny`/`nz` (normal), or `u`/`v` (UV).

---

#### TOPtoCHOP

Samples pixel values from a TOP texture as CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Average | Average, CenterPixel, RowAverage, ColumnAverage |
| channel_r/g/b/a | Bool | true/true/true/false | Which color channels to output |

**Input:** `in` (TOP). Uses `tex.get_image()` for GPU readback.

---

#### Feedback CHOP

Previous frame's CHOP data for feedback loops. Time-dependent.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| reset | Bool | false |  | Pulse to clear stored data |

**Input:** `in` (CHOP, optional).
**Output:** CHOP (previous frame's channel data).

**How it works:** Returns the channel data stored from the previous frame (`_prev_data`). After outputting, deep-copies the current input for next frame. If `reset` is pulsed, clears all stored data.

---

#### Blend CHOP

Sample-by-sample weighted blend of multiple CHOP inputs (28 inputs).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| weight | Float | 0.5 | 0.01.0 | 0 = first input, 1 = last input |
| method | Enum | Linear | Linear, Ease In, Ease Out, Smooth Step | Interpolation curve |

**Input:** Dynamic inputs (28 CHOPs).
**Output:** CHOP (blended channels).

**How it works:** Scales `weight` across the input array to select two bracketing inputs and a fractional `t`. Applies the selected easing to `t`, then lerps all channels sample-by-sample. Missing channels are zero-filled.

---

#### Perform CHOP

System performance metrics as CHOP channels. Time-dependent.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| fps | Bool | true |  | Frames per second |
| frame_time | Bool | true |  | Frame time in milliseconds |
| frame_count | Bool | true |  | Total frames drawn |
| memory | Bool | true |  | Static memory usage in MB |
| gpu_time | Bool | false |  | Last GPU frame time (if available) |

**Output:** CHOP (performance channels, one per enabled metric).

**How it works:** Reads `Engine.get_frames_per_second()`, `Engine.get_frames_drawn()`, `OS.get_static_memory_usage()`, and `Performance.TIME_PROCESS` (GPU fallback). Each metric outputs as a single-sample channel gated by its bool.

---

#### Transform CHOP

3D transform on xyz channel groups. Detects channel triplets and applies a matrix transform.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx | Float | 0.0 | unbounded | Translate X |
| ty | Float | 0.0 | unbounded | Translate Y |
| tz | Float | 0.0 | unbounded | Translate Z |
| rx | Float | 0.0 | -360360 | Rotate X (degrees) |
| ry | Float | 0.0 | -360360 | Rotate Y (degrees) |
| rz | Float | 0.0 | -360360 | Rotate Z (degrees) |
| sx | Float | 1.0 | 0.001100 | Scale X |
| sy | Float | 1.0 | 0.001100 | Scale Y |
| sz | Float | 1.0 | 0.001100 | Scale Z |
| order | Enum | SRT | SRT, STR, RST, RTS, TSR, TRS | Transform operation order |

**Input:** `in` (CHOP, optional).
**Output:** CHOP (transformed channels).

**How it works:** Builds a `Transform3D` from TRS parameters in the specified order. Detects xyz channel groups (e.g. `tx/ty/tz` or `x/y/z`) and applies the matrix to every sample as a `Vector3`. Non-grouped channels pass through unchanged.

---

### Animation / Sequencing

---

#### Keyframe CHOP

Keyframe curve animation. Each slot defines a named channel with a ramp curve sampled at the current elapsed time within a user-defined time range. Extend modes: Hold, Cycle, Mirror, Slope.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | Float | 0.0 | Start time (seconds) |
| `end` | Float | 4.0 | End time (seconds) |
| `extend` | Enum | Hold | Behaviour outside range |
| `count` | Int | 1 | Number of channel slots |
| `nameN` | String | animN | Channel name for slot N |
| `curveN` | Ramp | — | Keyframe curve for slot N |

**Output:** CHOP (animated channels).

---

#### Sequence CHOP

Sequence CHOP inputs end-to-end in time. Each input plays for its duration, with optional crossfade blending between segments.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `duration` | Float | 2.0 | Seconds per input segment |
| `crossfade` | Float | 0.0 | Blend time between segments |
| `loop` | Bool | true | Loop back to first input |

**Inputs:** Dynamic (multiple CHOPs).
**Output:** CHOP (sequenced channels).

---

#### Clip CHOP

Play back recorded CHOP data with transport controls. Records the first frame of input and replays with speed, loop, and trim control.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | Float | 0.0 | Start position (0–1) |
| `end` | Float | 1.0 | End position (0–1) |
| `speed` | Float | 1.0 | Playback speed |
| `loop` | Enum | Loop | None / Loop / PingPong |
| `play` | Bool | true | Enable playback |
| `trigger` | Pulse | — | Reset to start |

**Inputs:** `in` (CHOP).
**Output:** CHOP (playback channels).

---

#### Channel CHOP

Create named channels from parameter values. Expression-friendly — each value parameter supports full expression mode for procedural animation.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `count` | Int | 3 | Number of channel slots |
| `nameN` | String | chanN | Channel name |
| `valueN` | Float | 0.0 | Channel value (expression-friendly) |

**Output:** CHOP (named channels).

---

### Object / Skeleton

---

#### Object CHOP

Read transform channels (tx/ty/tz/rx/ry/rz/sx/sy/sz) from a COMP node referenced by path.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `comp_path` | String | — | Node ID of the COMP to read |

**Output:** CHOP (9 transform channels).

---

#### Skeleton CHOP

Read skeleton bone transforms as CHOP channels. For each matching bone: `bone:tx`, `bone:ty`, `bone:tz`, `bone:rx`, `bone:ry`, `bone:rz`.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `comp_path` | String | — | Node ID of the Skeleton3D COMP |
| `bone_filter` | String | * | Wildcard pattern for bone names |
| `local` | Bool | true | Use local (vs model) space |

**Output:** CHOP (6 channels per bone).

---

#### Tablet In CHOP

Pen tablet/stylus input. Outputs position, pressure, tilt, and button state.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `normalize` | Bool | true | Normalize to 0–1 range |
| `active` | Bool | true | Enable input capture |

**Output:** CHOP (x, y, pressure, tilt_x, tilt_y, button).

---

### Signal Analysis & Audio

---

#### AudioBandCHOP

Multi-band frequency analysis with per-band envelope followers. Takes an AudioSpectrumCHOP (or any CHOP with `band:N` channels) and groups frequencies into configurable ranges — essential for music-reactive VJ visuals.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| num_bands | Int | 5 | 1–16 | Number of output frequency bands |
| band_names | String | bass,low_mid,mid,high_mid,treble | — | Comma-separated band names |
| crossovers | String | 80,250,2000,6000 | Hz | Comma-separated crossover frequencies between bands |
| attack | Float | 0.02 | 0.001–1.0 | Envelope attack time (seconds) |
| release | Float | 0.15 | 0.01–2.0 | Envelope release time (seconds) |
| peak_decay | Float | 0.98 | 0.9–0.999 | Peak hold decay per frame (higher = slower) |
| gain | Float | 1.0 | 0.1–10.0 | Input gain multiplier |
| freq_min | Float | 20.0 | 1–1000 | Assumed lowest frequency of input spectrum |
| freq_max | Float | 20000.0 | 100–24000 | Assumed highest frequency of input spectrum |

**Input 0:** `spectrum` (CHOP) — AudioSpectrumCHOP with `band:N` channels.

**Output channels per band:**
- `{name}` — smoothed band level (0–1)
- `{name}_peak` — peak-hold level (decays slowly)
- `{name}_norm` — level normalized against recent peak (auto-gain)
- `total` — overall combined energy
- `dominant_band` — index of the loudest band

**How it works:** Input spectrum bands are mapped to output bands by logarithmic frequency distribution. Each input band's center frequency is computed via `exp(log_min + t * (log_max - log_min))` and assigned to the output band whose crossover range contains it. An exponential attack/release envelope follower smooths each band level. Peak hold with configurable decay provides a slowly-falling maximum for auto-gain normalization. Typical workflow: `AudioInCHOP → AudioSpectrumCHOP → AudioBandCHOP → drive parameters via expressions`.

---

## DAT — Data Operators

DATs process tables and text. The output type is `GNTableData`, which operates in either **table mode** (2D grid of strings with headers) or **text mode** (plain string). DATs are useful for configuration, data lookups, text processing, and cross-family data conversion.

**Total: 33 operators** — 3 generators, 5 filters, 1 combiner, 2 utility, 2 bridges, 3 I/O, 4 new filters, 4 new bridges, 4 protocol/event, 5 networking.

### Generators

---

#### ConstantDAT

Manually editable 4×4 table.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| col0 | String | "name" | — | Column 0 header |
| col1 | String | "value" | — | Column 1 header |
| col2 | String | "" | — | Column 2 header (empty = skip) |
| col3 | String | "" | — | Column 3 header (empty = skip) |
| r0c0–r3c3 | String | "" | — | 16 cells (4 rows × 4 columns) |

**How it works:** Builds a table from hand-entered headers and cells. Column count stops at the first empty header (after col1). Entirely empty rows are skipped.

---

#### TextDAT

Plain text storage.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| text | String | "" | — | Text content |

**How it works:** Stores plain text in text mode (`GNTableData.set_text()`). Not a table — just a string.

---

#### InfoDAT

System information table. Time-dependent — updates every frame.

**Parameters:** None.

**Output table columns:** `property`, `value`.

**Rows:** `fps`, `frame`, `elapsed_time`, `delta`, `engine_version`, `os`, `processor_name`, `processor_count`, `screen_size`, `static_memory`.

**How it works:** Reads values from Godot's `Engine`, `OS`, `Performance`, and `DisplayServer` APIs each frame.

---

#### OscInDAT *(Stub)*

OSC message receiver. **Currently a stub** — UDP/OSC networking is not yet implemented.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| port | Int | 9000 | 1–65535 | Listening port |
| max_rows | Int | 100 | 1–10000 | Maximum stored messages |
| active | Bool | true | — | Enable/disable |

**Output table columns:** `address`, `arg0`, `arg1`, `arg2`, `timestamp`.

**How it works:** Has a public `push_message()` API for future integration. Stores messages in a ring buffer. Time-dependent.

---

### Filters

---

#### SelectDAT

Extract row/column subsets by index range.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| row_start | Int | 0 | 0+ | First row (inclusive) |
| row_end | Int | -1 | -1+ | Last row (-1 = all) |
| col_start | Int | 0 | 0+ | First column (inclusive) |
| col_end | Int | -1 | -1+ | Last column (-1 = all) |
| include_header | Bool | true | — | Include header row in output |

---

#### SortDAT

Sort rows by a column.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| sort_col | Int | 0 | 0+ | Column index to sort by |
| order | Enum | Ascending | Ascending, Descending | Sort direction |
| sort_type | Enum | Alphabetic | Alphabetic, Numeric | Comparison type |

**How it works:** Sorts data rows while preserving the header row. Uses `sort_custom` with appropriate comparator.

---

#### TransposeDAT

Swap rows and columns. No parameters.

**How it works:** Row 0 becomes column 0, row 1 becomes column 1, etc. The old first column becomes the new header.

---

#### EvaluateDAT

Evaluate expression cells.

**Parameters:** None.

**How it works:** Cells starting with `=` are evaluated as GDScript expressions using Godot's `Expression` class. Non-expression cells pass through. Failed evaluations output `#ERR`.

---

### Combiners

---

#### MergeDAT

Combine two tables.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Rows | Rows, Columns | Merge direction |

**Inputs:** `in1` (DAT), `in2` (DAT).

**How it works:** Rows mode stacks input 2's rows below input 1 (skips in2's header if headers match). Columns mode appends columns side-by-side, padding shorter tables with empty strings.

---

### Utility

---

#### NullDAT

Pass-through.

---

#### SwitchDAT

Select one of 2 inputs by index.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index | Int | 0 | 0–1 | Which input to output |

---

### Bridges

---

#### CHOPtoDAT *(Bridge — CHOP → DAT)*

Converts CHOP channel data to a DAT table.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| layout | Enum | Channels as Columns | Channels as Columns, Channels as Rows | Output layout |

**Input:** `chop_in` (CHOP).

**How it works:** Columns mode: channel names become column headers, samples become rows. Rows mode: first column is channel name, subsequent columns are samples labeled `s0`, `s1`, etc.

---

#### DATtoCHOP *(Bridge — DAT → CHOP)*

See [DATtoCHOP in the CHOP section](#dattochop-bridge--dat--chop) — this operator has CHOP family despite living in the DAT directory.

---

### I/O (New)

---

#### FileInDAT

Read a file from disk (CSV, TSV, JSON, or text) into a table.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| filepath | String | "" | Path to file (res:// or user://) |
| mode | Enum | Auto | Auto, CSV, TSV, JSON, Text |
| has_header | Bool | true | First row is header |

**How it works:** Auto-detects format from extension. JSON arrays-of-objects become rows with dict keys as headers. CSV/TSV split by delimiter.

---

#### JSONDAT

Parse JSON to table or generate JSON from table.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Parse | Parse, Generate |
| json_string | String | "" | JSON string for parse mode |
| pretty | Bool | true | Pretty-print generated JSON |

**Input:** `in` (DAT, optional — for Generate mode).

---

#### WebDAT

Fetch data from a URL via HTTP GET/POST.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| url | String | "" | Target URL |
| method | Enum | GET | GET, POST |
| body | String | "" | POST request body |
| content_type | String | "application/json" | Content type header |
| auto_parse | Bool | true | Auto-parse JSON responses |

**How it works:** Uses Godot's HTTPRequest node. Returns cached last response (async fetch triggered per cook).

---

### Filters (New)

---

#### SubstituteDAT

Find and replace text in table cells or text mode.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| find | String | "" | Search string or regex |
| replace_with | String | "" | Replacement text |
| use_regex | Bool | false | Use regex matching |
| case_sensitive | Bool | true | Case-sensitive search |
| scope | Enum | All | All, Column, Row |
| scope_index | Int | 0 | Column/row index for scoped replace |

**Input:** `in` (DAT).

---

#### InsertDAT

Insert rows or columns into a table.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Row | Row, Column |
| index | Int | 0 | Where to insert |
| count | Int | 1 | Number of rows/columns to insert |
| fill_value | String | "" | Fill value for new cells |

**Input:** `in` (DAT).

---

#### DeleteDAT

Delete rows or columns from a table by index range.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Row | Row, Column |
| start_index | Int | 0 | First row/column to delete |
| end_index | Int | 0 | Last row/column to delete (inclusive) |

**Input:** `in` (DAT).

---

#### FIFODAT

Rolling row buffer — accumulates rows over time, dropping oldest when full.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| max_rows | Int | 100 | 1–10000 | Maximum rows in buffer |
| active | Bool | true | — | Enable accumulation |

**Input:** `in` (DAT). **Time-dependent.** Maintains internal buffer across cooks.

---

### Bridges (New)

---

#### SOPtoDAT

Convert SOP geometry to a DAT table.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| attribute | Enum | Points | Points, Summary |
| max_points | Int | 1000 | Max vertices (Points mode) |

**Input:** `in` (SOP). Points mode: headers `px, py, pz, nx, ny, nz, u, v`. Summary mode: vertex count, surface count, AABB.

---

#### TOPtoDAT

Convert TOP texture info or pixel data to a DAT table.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Info | Info, Pixels |
| max_pixels | Int | 100 | Max pixels to read (Pixels mode) |

**Input:** `in` (TOP). Info mode: width, height, format. Pixels mode: x, y, r, g, b, a per pixel.

---

#### OPFindDAT

Search the current network for operators matching criteria.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| family_filter | Enum | All | All, CHOP, TOP, DAT, SOP, COMP, MAT |
| name_pattern | String | "*" | Glob pattern for operator names |
| include_type | Bool | true | Include type column in output |

**Output:** Table with columns: `name, id, family, type, num_inputs, num_outputs`.

---

### Scripting (New)

---

#### CallbackDAT

Event-driven callback DAT. Holds named GDScript snippets that fire automatically when events occur on a **target node** connected to its input.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| time_dependent | Bool | true | Re-cook every frame to poll events |
| active | Bool | true | Enable/disable all callbacks |
| log_events | Bool | true | Output event execution log as DAT table |
| on_start | String | (template) | Script that runs once on first cook frame |
| on_cook | String | (template) | Script that runs after target node cooks |
| on_value_change | String | (template) | Script that runs when target parameter changes |
| on_create | String | (template) | Script that runs once when CallbackDAT is first cooked |

**Input:** `target` (any family) — the node to observe.
**Output:** `out` (DAT) — event log table with columns: `time, event, status, target`.

**Callback context variables:** Same as Script operators (`me`, `inputs`, `time`, `frame`, `dt`, `par()`, `chop()`, `top()`, `sop()`, `dat()`, `set_par()`, `network_*()`) plus:
- `target` — the GNNode connected to input 0
- `event` — String name of the callback (e.g. "onCook")
- `event_param` — for onValueChange, the parameter name that changed

**Supported events:**

| Event | Trigger | Use Case |
|-------|---------|----------|
| `onStart` | First cook frame | Initialize params, build graph |
| `onCreate` | First cook of this CallbackDAT | One-time setup |
| `onCook` | Target node finishes cooking | React to output changes |
| `onValueChange` | Target node param changes | Mirror params, trigger side effects |

**Example — mirror a parameter:**

```gdscript
# onValueChange callback
if event_param == "speed":
    set_par("other_lfo", "speed", par(target.id, "speed") * 2.0)
```

**Example — procedural graph building:**

```gdscript
# onCreate callback
var nid = network_add_node("NoiseTOP")
set_par(nid, "resolution", Vector2i(512, 512))
network_connect(nid, 0, "composite1", 1)
```

---

#### Web Server DAT

HTTP server that serves responses and logs incoming requests as a table. Time-dependent.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| port | Int | 8080 | 165535 | Listen port |
| active | Bool | true |  | Enable / disable server |
| content_type | String | "text/html" |  | Response Content-Type header |
| max_requests | Int | 50 | 1100 | Maximum request log rows |
| clear | Bool | false |  | Pulse to clear log |

**Input:** `response` (DAT, optional  response body).
**Output:** DAT table (columns: method, path, time).

**How it works:** Runs a `TCPServer` that accepts connections, parses HTTP request lines, serves a response from the upstream DAT input (or "OK"), and logs each request into a rolling table trimmed to `max_requests` rows.

---

#### WebSocket DAT

WebSocket client/server communication. Time-dependent.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Client | Client, Server | Client connects to URL, Server listens on port |
| url | String | "ws://127.0.0.1:9090" |  | WebSocket URL (client mode) |
| port | Int | 9090 | 165535 | Listen port (server mode) |
| active | Bool | true |  | Enable / disable |
| max_lines | Int | 100 | 11000 | Maximum received messages to buffer |
| clear | Bool | false |  | Pulse to clear buffer |

**Input:** `send` (DAT, optional  data to send).
**Output:** DAT table (column: message).

**How it works:** In Client mode, connects to a WebSocket URL via `WebSocketPeer`, polls for packets, and sends upstream DAT text. In Server mode, listens via `TCPServer`, upgrades connections to `WebSocketPeer`, and broadcasts to all connected peers. Received messages accumulate into a rolling table.

---

#### Error DAT

Captures system warnings and errors as a table by hooking GNLogger. Time-dependent.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| level_filter | Enum | Warnings & Errors | Errors Only, Warnings & Errors, All | Minimum severity to capture |
| max_rows | Int | 200 | 15000 | Maximum log entries |
| clear | Bool | false |  | Pulse to clear the log |

**Output:** DAT table (columns: level, category, message, timestamp).

**How it works:** Hooks `GNLogger.log_sink` at init so all `GNLogger.warn`/`GNLogger.error` calls are captured. The `_on_log` callback filters by severity and appends rows. Cook trims to `max_rows` and outputs the accumulated table. Unhooks on deletion.

---

#### Folder DAT

List directory contents as a table.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| path | String | "res://" |  | Directory path to list |
| recursive | Bool | false |  | Include sub-directories recursively |
| filter | String | "*" |  | Glob-style filter (e.g. *.png) |
| include_dirs | Bool | true |  | Include directories in listing |

**Output:** DAT table (columns: name, path, extension, size, is_dir).

**How it works:** Opens the given directory with `DirAccess`, iterates entries (optionally recursive), filters with `matchn()`, reads file sizes, and builds a table with name/path/extension/size/is_dir columns.

---

#### Multi Touch In DAT

Multi-touch screen input as table rows. Time-dependent.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| active | Bool | true |  | Enable / disable touch capture |
| normalize | Bool | false |  | Output 01 normalized coords instead of pixels |
| window | String | "" |  | WindowOUT node name to read from (empty = global) |

**Output:** DAT table (columns: id, x, y, pressure, rel_x, rel_y, phase, window). The `window` column shows the WindowOUT's title when bound to a specific window.

**How it works:** When `window` is empty, maintains a `_touches` dictionary updated by `InputEventScreenTouch` (began/ended) and `InputEventScreenDrag` (moved). When `window` is set, reads from the target WindowOUT's per-window `_input_touches` state. Each cook outputs active touches as table rows. Optionally normalizes coordinates to viewport/window 01. Ended touches are removed after output.

---

### Protocol / Event

---

#### Serial DAT

Serial port (COM) communication. Outputs received data as table rows with timestamps. Framework ready for native serial transport extensions.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `port` | String | COM3 | Serial port name |
| `baud_rate` | Int | 9600 | Communication speed |
| `delimiter` | Enum | Newline | Message delimiter |
| `max_rows` | Int | 100 | Max table rows |
| `active` | Bool | false | Enable communication |
| `clear` | Pulse | — | Clear buffer |

**Output:** DAT table (timestamp, message).

---

#### DMX DAT

DMX lighting protocol controller via Art-Net UDP. Takes CHOP channel values and outputs as DMX universe table. Sends Art-Net packets when active.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `universe` | Int | 0 | DMX universe number |
| `ip` | String | 255.255.255.255 | Art-Net destination IP |
| `port` | Int | 6454 | UDP port |
| `active` | Bool | false | Enable DMX output |
| `channels` | Int | 512 | Active channel count |

**Inputs:** `values` (CHOP, channel values 0–255).
**Output:** DAT table (channel, value).

---

#### Render Pick DAT

Pick 3D objects from a render by screen coordinates via physics ray casting. Returns hit position, normal, distance, and object identity.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `render_comp` | String | — | Camera/Render COMP node ID |
| `u` | Float | 0.5 | Horizontal pick (0–1) |
| `v` | Float | 0.5 | Vertical pick (0–1) |
| `max_distance` | Float | 1000.0 | Max ray distance |
| `use_input` | Bool | true | Use input CHOP u/v |

**Inputs:** `uv` (CHOP, optional).
**Output:** DAT table (hit, node_id, world_xyz, normal_xyz, distance, face_index, u, v).

---

#### Panel Execute DAT

Logs panel/UI interaction events as DAT table rows with timestamps.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `panel_path` | String | — | Panel node ID to monitor |
| `max_events` | Int | 100 | Max events to keep |
| `log_values` | Bool | true | Log value changes |
| `log_hover` | Bool | false | Log hover events |
| `clear` | Pulse | — | Clear log |

**Inputs:** `panel` (CHOP, UI state).
**Output:** DAT table (timestamp, event, channel, value).

---

## SOP — Surface Operators

SOPs produce and manipulate 3D geometry. The output type is `GNGeoData`, which wraps Godot's native `ArrayMesh`. SOPs leverage Godot's built-in mesh primitives (`BoxMesh`, `SphereMesh`, etc.) and `SurfaceTool` for procedural generation. Geometry flows through SOP chains and ultimately reaches a GeometryCOMP for 3D scene placement.

**Total: 64 operators** — 13 generators, 20 filters, 6 combiners, 2 utility, 5 deformers, 3 bridge, 1 decimation, 3 smoothing/remesh, 2 merge/texture, 4 poly construction, 5 new.

### Generators

---

#### GridSOP

Subdivided plane.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| size_x | Float | 2.0 | 0.01–100.0 | Width |
| size_z | Float | 2.0 | 0.01–100.0 | Depth |
| rows | Int | 10 | 1–500 | Row subdivisions |
| cols | Int | 10 | 1–500 | Column subdivisions |
| orientation | Enum | XZ | XZ (Horizontal), XY (Vertical), YZ (Side) | Plane orientation |

**How it works:** Builds a subdivided quad using `SurfaceTool`. Vertices are arranged in a grid, triangulated, with calculated UVs and normals. Generates tangents. The mesh is centered at origin.

---

#### BoxSOP

Box mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| size_x | Float | 1.0 | 0.01–100.0 | Width |
| size_y | Float | 1.0 | 0.01–100.0 | Height |
| size_z | Float | 1.0 | 0.01–100.0 | Depth |
| subdivide_w | Int | 0 | 0–100 | Width subdivisions |
| subdivide_h | Int | 0 | 0–100 | Height subdivisions |
| subdivide_d | Int | 0 | 0–100 | Depth subdivisions |

**How it works:** Creates a Godot `BoxMesh`, converts to `ArrayMesh` via `SurfaceTool`.

---

#### SphereSOP

Sphere or hemisphere mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| radius | Float | 0.5 | 0.01–100.0 | Radius |
| height | Float | 1.0 | 0.01–200.0 | Height (stretch on Y) |
| radial_segments | Int | 32 | 3–256 | Longitudinal segments |
| rings | Int | 16 | 2–128 | Latitudinal rings |
| is_hemisphere | Bool | false | — | Only upper half |

**How it works:** Creates a Godot `SphereMesh`, converts to `ArrayMesh` via `SurfaceTool`.

---

#### TorusSOP

Torus (donut) mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| inner_radius | Float | 0.2 | 0.01–50.0 | Tube radius |
| outer_radius | Float | 0.5 | 0.01–100.0 | Ring radius |
| rings | Int | 32 | 3–256 | Major segments |
| ring_segments | Int | 16 | 3–128 | Minor segments |

**How it works:** Creates a Godot `TorusMesh`, converts to `ArrayMesh` via `SurfaceTool`.

---

#### CylinderSOP

Cylinder or cone mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| top_radius | Float | 0.5 | 0.0–50.0 | Top radius (0 = cone) |
| bottom_radius | Float | 0.5 | 0.0–50.0 | Bottom radius |
| height | Float | 1.0 | 0.01–100.0 | Height |
| radial_segments | Int | 32 | 3–256 | Segments around circumference |
| rings | Int | 4 | 1–128 | Vertical rings |
| cap_top | Bool | true | — | Cap the top |
| cap_bottom | Bool | true | — | Cap the bottom |

**How it works:** Creates a Godot `CylinderMesh`, converts to `ArrayMesh` via `SurfaceTool`. Set `top_radius = 0` for a cone.

---

#### LineSOP

Line strip mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| points | Int | 10 | 2–10000 | Number of points |
| direction | Enum | X | X, Y, Z | Axis direction |
| length | Float | 2.0 | 0.01–1000.0 | Total line length |

**How it works:** Generates a `LINE_STRIP` mesh with points evenly distributed along the selected axis, centered at origin.

---

#### CircleSOP

Filled disc or wire circle.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| radius | Float | 0.5 | 0.01–100.0 | Circle radius |
| segments | Int | 32 | 3–512 | Edge segments |
| type | Enum | Filled Disc | Filled Disc, Wire Circle | Solid or outline |
| orientation | Enum | XZ | XZ (Horizontal), XY (Vertical), YZ (Side) | Plane |

**How it works:** Filled disc uses a triangle fan from center. Wire circle uses `LINE_STRIP`. Orientation rotates the circle to the chosen plane.

---

### Filters

---

#### TransformSOP

Translate, rotate, and scale geometry.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Translation |
| rx, ry, rz | Float | 0.0 | -360–360 | Rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Scale |
| order | Enum | SRT | SRT, STR, RST, RTS, TSR, TRS | Transform order |

**How it works:** Builds a `Transform3D` from the translation, rotation, and scale parameters in the specified order. Applies the transform to every vertex position. Normals are transformed using the inverse-transpose basis to maintain correctness under non-uniform scale.

---

#### NoiseSOP

Displace vertices with procedural noise. Time-dependent — animates automatically.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| amplitude | Float | 0.2 | 0.0–100.0 | Displacement strength |
| frequency | Float | 2.0 | 0.01–100.0 | Noise frequency |
| offset_x, offset_y, offset_z | Float | 0.0 | — | Noise offset |
| speed | Float | 1.0 | 0.0–10.0 | Animation speed |
| noise_type | Enum | Simplex | Simplex, Perlin, Cellular, Value | Noise algorithm |
| displace_axis | Enum | Normal | Normal, X, Y, Z | Displacement direction |
| seed | Int | 0 | 0–9999 | Random seed |

**How it works:** Uses Godot's `FastNoiseLite` to sample 3D noise at each vertex position. The noise value displaces the vertex along its normal (or a fixed axis). Time offset evolves via `elapsed_time * speed` for animation.

---

#### SubdivideSOP

Midpoint subdivision.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| iterations | Int | 1 | 1–4 | Number of subdivision passes |

**How it works:** Splits each triangle into 4 by inserting midpoints on each edge. Non-triangle primitives pass through unchanged. Regenerates normals and tangents after subdivision. Each iteration quadruples the triangle count — limit of 4 iterations prevents runaway geometry.

---

#### WireframeSOP

Convert triangles to lines. No parameters.

**How it works:** Extracts edges from triangle mesh and outputs a `PRIMITIVE_LINES` mesh. Deduplicates edges using a hash key `min(a,b)*100000 + max(a,b)` to avoid drawing shared edges twice.

---

### Combiners

---

#### MergeSOP

Merge multiple geometries into one. No parameters.

**Input:** `in` (SOP, **multi-input** — accepts multiple connections).

**How it works:** Appends all surfaces from all input `ArrayMesh` objects into a single output `ArrayMesh`. Each input's geometry becomes a separate surface in the combined mesh.

---

### Utility

---

#### NullSOP

Pass-through.

---

#### SwitchSOP

Select one of 2 inputs by index.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index | Int | 0 | 0–1 | Which input to output |

---

### Generators (New)

---

#### TubeSOP

Tube or pipe generator with inner/outer walls and caps.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| outer_radius | Float | 0.5 | Outer radius |
| inner_radius | Float | 0.0 | Inner radius (0 = solid tube) |
| height | Float | 1.0 | Tube height |
| rows | Int | 4 | Height subdivisions |
| columns | Int | 16 | Radial segments |
| caps | Bool | true | Generate end caps |
| orientation | Enum | Y | X, Y, Z axis |

**How it works:** Generates vertices in concentric rings using SurfaceTool. When `inner_radius > 0`, creates both outer and inner walls forming a hollow pipe. Caps are annular rings connecting inner and outer edges.

---

### Filters (New)

---

#### NormalSOP

Recompute smooth normals, flip normals, or generate flat (faceted) normals.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Recompute Smooth | Recompute Smooth, Flip, Flat Faceted |

**Input:** `in` (SOP).

**How it works:** Recompute mode uses `SurfaceTool.generate_normals()`. Flip negates all normals. Flat mode unshares vertices so each triangle gets its own face normal.

---

#### ReverseSOP

Reverse face winding order and flip normals.

**Input:** `in` (SOP).

**How it works:** Swaps the 2nd and 3rd vertex of each triangle to reverse winding. Negates all normals.

---

#### PeakSOP

Push vertices along their normals by a distance.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| distance | Float | 0.1 | Distance to push (negative = shrink) |
| recompute | Bool | true | Recompute normals after displacement |

**Input:** `in` (SOP).

---

#### SortSOP

Sort vertices by axis, distance from origin, or randomly.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | X Axis | X, Y, Z Axis, Distance, Random |
| seed | Int | 0 | Random seed (Random mode) |

**Input:** `in` (SOP).

**How it works:** Builds a sort-index array, sorts it, then remaps all vertex arrays (positions, normals, UVs, tangents) and triangle indices through an inverse map.

---

#### FacetSOP

Unique points (flat shading) or consolidate close vertices.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Unique Points | Unique Points, Consolidate |
| distance | Float | 0.001 | Merge distance (Consolidate mode) |

**Input:** `in` (SOP).

**How it works:** Unique mode unshares every vertex so triangles have independent normals. Consolidate merges vertices within the distance threshold using O(n²) proximity search.

---

#### DeleteSOP

Delete faces or points by range, bounding box, or random percentage.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| entity | Enum | Faces | Faces, Points |
| mode | Enum | Range | Range, Bounding Box, Random |
| start | Int | 0 | Start index (Range) |
| end | Int | 10 | End index (Range) |
| percent | Float | 50.0 | Percentage to delete (Random) |
| invert | Bool | false | Invert selection |
| seed | Int | 0 | Random seed |
| bbox_min | Vector3 | (-0.5,-0.5,-0.5) | Bounding box minimum |
| bbox_max | Vector3 | (0.5,0.5,0.5) | Bounding box maximum |

**Input:** `in` (SOP).

---

#### PointSOP

Per-vertex position modification via GDScript expressions.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| expr_x | String | "px" | X position expression |
| expr_y | String | "py" | Y position expression |
| expr_z | String | "pz" | Z position expression |

**Input:** `in` (SOP).

**How it works:** Uses Godot's `Expression` class. Variables: `px`, `py`, `pz` (position), `nx`, `ny`, `nz` (normal), `u`, `v` (UV), `i` (vertex index), `n` (count), `t` (time).

---

#### AttributeSOP

Create or modify per-vertex point attributes from expressions or presets.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| attrib_name | String | "Cd" | Attribute name |
| components | Int | 3 | Values per vertex (1–4) |
| source | Enum | Constant | Constant, Expression, Position, Normal, UV, Random |

**Input:** `in` (SOP).

**How it works:** Stores results in `GNGeoData.point_attribs` dictionary — a dictionary of name → `PackedFloat32Array` with `components` values per vertex.

---

#### ClipSOP

Clip geometry by an axis-aligned plane with triangle splitting.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| axis | Enum | Y | X, Y, Z |
| origin | Float | 0.0 | Plane position along axis |
| keep_above | Bool | true | Keep above or below the plane |

**Input:** `in` (SOP).

**How it works:** Classifies each triangle vertex as above/below the clip plane. Triangles fully on the kept side pass through. Crossing triangles are split: edges are interpolated at the intersection point, producing 1 or 2 output triangles. Vertex attributes (positions, normals, UVs) are properly interpolated at split points.

---

#### MirrorSOP

Reflect geometry across a plane with optional merge.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| axis | Enum | X | X, Y, Z |
| merge | Bool | true | Merge reflected with original |

**Input:** `in` (SOP).

**How it works:** Reflects positions across the plane (`p - 2 * dot(p, axis) * axis`). Reverses triangle winding on the reflected copy. Negates the mirror axis component of normals.

---

#### ExtrudeSOP

Per-triangle face extrusion with front, back, and side walls.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| distance | Float | 0.3 | Extrusion distance along face normal |
| front | Bool | true | Generate front (extruded) face |
| sides | Bool | true | Generate side walls |
| back | Bool | false | Generate back (original) face |

**Input:** `in` (SOP).

**How it works:** For each triangle, computes face normal and offsets vertices by `distance * normal`. Builds up to 3 quads for the side walls connecting original and extruded edges.

---

### Combiners (New)

---

#### CopySOP

Instance template geometry onto each point of the target mesh.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| align_normals | Bool | true | Orient instances to target surface normals |

**Inputs:** `template` (SOP — geometry to copy), `target` (SOP — points to copy onto).

**How it works:** Extracts target point positions and normals. For each point, builds a transform basis from the normal and copies all template vertices, applying the transform. Supports `pscale` point attribute for per-instance scaling.

---

#### ScatterSOP

Scatter random points on mesh surface (area-weighted sampling).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| count | Int | 100 | Number of points to scatter |
| seed | Int | 0 | Random seed |

**Input:** `in` (SOP).

**How it works:** Computes per-triangle area, builds a CDF (cumulative distribution function), then uses binary search to select triangles proportional to their area. Random barycentric coordinates place points within each selected triangle. Outputs a point cloud with interpolated normals and UVs.

---

#### BooleanSOP

Boolean operations (union, intersect, subtract) via Godot's CSG system.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| operation | Enum | Union | Union, Intersect, Subtract |

**Inputs:** `a` (SOP), `b` (SOP).

**How it works:** Creates temporary `CSGCombiner3D` and `CSGMesh3D` nodes in the scene tree. Assigns input meshes, performs the boolean operation, extracts the result via `get_meshes()`, then removes the temporary nodes.

---

#### SweepSOP

Sweep a cross-section along a backbone curve (parallel transport frames).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| scale | Float | 0.1 | Profile cross-section scale |
| profile_segs | Int | 12 | Circle segments (no profile input) |
| close_profile | Bool | true | Close the profile ring |
| close_backbone | Bool | false | Loop the backbone |
| end_caps | Bool | false | Generate end caps |

**Inputs:** `backbone` (SOP — line strip), `profile` (SOP, optional — cross-section; uses circle if absent).

**How it works:** Computes rotation-minimizing frames (RMF) along the backbone using the double-reflection method. Places the scaled profile at each frame position, then connects consecutive rings with quad strips. This prevents the twisting artifacts that occur with simpler Frenet frames.

---

#### SkinSOP

Skin (loft) multiple cross-sections into a surface mesh.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| close_u | Bool | true | Close each cross-section ring |
| close_v | Bool | false | Loop along V (connect last to first section) |
| end_caps | Bool | false | Cap ends with fan triangles |
| recompute_normals | Bool | true | Recompute smooth normals |

**Inputs:** Dynamic (auto-grow). Each input provides a cross-section polyline.

**How it works:** Collects vertex arrays from each input. Resamples shorter sections to match the longest. Connects corresponding vertices between consecutive sections with quad strips to form the skin surface.

---

### Deformers (New)

---

#### BendSOP

Bend geometry along an axis using circular arc deformation.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| angle | Float | 0.0 | -360–360 | Bend angle in degrees |
| axis | Enum | Y | X, Y, Z | Bend axis |
| origin | Float | 0.0 | -10–10 | Center of bend along axis |
| length_val | Float | 0.0 | — | Region length (0 = auto from bounds) |

**Input:** `in` (SOP). Works best on subdivided geometry.

---

#### TwistSOP

Rotates vertices around an axis proportional to their position along that axis.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| angle | Float | 0.0 | -720–720 | Total twist in degrees |
| axis | Enum | Y | X, Y, Z | Twist axis |

**Input:** `in` (SOP). More subdivisions = smoother twist.

---

#### TaperSOP

Scale perpendicular axes as a function of position along the taper axis.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| scale_start | Float | 1.0 | 0–10 | Scale at bottom |
| scale_end | Float | 0.5 | 0–10 | Scale at top |
| axis | Enum | Y | X, Y, Z | Taper axis |
| profile | Enum | Linear | Linear, Smooth | Interpolation profile |

**Input:** `in` (SOP). Smooth uses smoothstep interpolation.

---

### Generators (New 2)

---

#### FontSOP

Generate 3D text mesh using Godot's TextMesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| text | String | "Hello" | — | Text to render |
| font_size | Float | 1.0 | 0.1–100 | Font size multiplier |
| depth | Float | 0.1 | 0–10 | Extrusion depth |
| horizontal_align | Enum | Center | Left, Center, Right | Horizontal alignment |

No input needed. Uses Godot's built-in TextMesh for high-quality 3D text.

---

### Filters (New 2)

---

#### TrailSOP

Records the centroid of input geometry over time as a line strip trail.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| length | Int | 60 | 2–3600 | Number of frames to record |
| active | Bool | true | — | Enable recording |

**Input:** `in` (SOP). **Time-dependent.** Computes centroid of input and appends to ring buffer.

---

#### TrailRibbonSOP

Builds ribbon geometry from POP particle trails — records positions each frame into a ring buffer, then generates triangle mesh ribbons with normals, UVs, and alpha fade.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| trail_length | Int | 30 | 2–300 | Frames of trail history per particle |
| width | Float | 0.1 | 0.001–10.0 | Ribbon half-width |
| taper | Float | 0.8 | 0.0–1.0 | Width taper (0 = uniform, 1 = full taper to tip) |
| max_particles | Int | 1000 | 1–100000 | Max particles to generate ribbons for |
| fade_alpha | Bool | true | — | Fade alpha along trail (old = transparent) |
| active | Bool | true | — | Record new positions each frame |

**Input:** `pop_in` (POP). **Output:** SOP (triangle mesh). **Time-dependent.**

**How it works:** Reads particle positions via GPU readback (or CPU arrays), stores each particle’s trail in a ring buffer, then builds ribbon quads perpendicular to the trail tangent. Width tapers from newest to oldest, alpha fades for a natural trail fade-out. Cross-product with up vector computes the side axis; normals face the camera-agnostic ribbon normal.

---

#### UVProjectSOP

Assign UV coordinates via planar, cylindrical, or spherical projection.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Planar | Planar, Cylindrical, Spherical |
| axis | Enum | Y | X, Y, Z |
| scale_u | Float | 1.0 | UV scale in U |
| scale_v | Float | 1.0 | UV scale in V |

**Input:** `in` (SOP). Maps vertex positions to UV coordinates based on projection mode and AABB bounds.

---

#### DivideSOP

Triangulate mesh and remove degenerate triangles.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | Enum | Triangulate | Triangulate, ConvexDecompose |
| remove_degenerate | Bool | true | Remove zero-area triangles |

**Input:** `in` (SOP). Ensures clean triangulated topology for downstream operators.

---

### Generators (New)

---

#### LSystemSOP

L-System fractal/branching geometry from formal grammar rewriting rules.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| axiom | String | "F" | — | Starting string |
| rule_a | String | "F=F[+F]F[-F]F" | — | Production rule A (format: X=replacement) |
| rule_b | String | "" | — | Production rule B (optional) |
| rule_c | String | "" | — | Production rule C (optional) |
| iterations | Int | 3 | 0–8 | Grammar rewriting passes |
| step_size | Float | 1.0 | 0.01–100.0 | Distance per F move |
| angle | Float | 25.7 | 0.1–180.0 | Turn angle in degrees |
| step_scale | Float | 1.0 | 0.1–2.0 | Step size multiplier per depth |
| angle_rand | Float | 0.0 | 0.0–1.0 | Random turn angle variation |
| seed | Int | 42 | 0–99999 | Random seed |
| tube_radius | Float | 0.0 | 0.0–10.0 | Tube radius (0 = line primitives) |
| tube_sides | Int | 6 | 3–16 | Cross-section polygon sides |
| taper | Float | 0.7 | 0.01–1.0 | Radius reduction per depth (branch thinning) |
| gravity | Float | 0.0 | -5.0–5.0 | Downward tropism per segment |

**How it works:** Rewrites the axiom string using production rules for the given iterations, then a turtle interprets the result: `F` = draw forward, `+`/`-` = yaw, `&`/`^` = pitch, `\`/`/` = roll, `[`/`]` = push/pop state. When `tube_radius > 0`, generates extruded tube geometry with taper; otherwise produces line-strip primitives.

---

#### MetaballSOP

Metaball implicit surface via marching cubes. Soft-blending blob geometry.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Int | 30 | 4–128 | Voxel grid subdivisions per axis |
| bounds_size | Float | 6.0 | 0.5–100.0 | Cubic grid extent |
| threshold | Float | 1.0 | 0.01–10.0 | Iso-surface threshold |
| default_radius | Float | 1.0 | 0.01–50.0 | Ball radius (no pscale attribute) |
| ball_count | Int | 2 | 0–4 | Built-in balls (no input connected) |
| b0x, b0y, b0z, b0r | Float | — | — | Ball 0 position and radius |
| b1x, b1y, b1z, b1r | Float | — | — | Ball 1 position and radius |
| b2x, b2y, b2z, b2r | Float | — | — | Ball 2 position and radius |
| b3x, b3y, b3z, b3r | Float | — | — | Ball 3 position and radius |

**Input:** `points` (SOP, optional — point cloud for ball centres).

**How it works:** Evaluates sum-of-inverse-square fields from all ball centres on a voxel grid, then extracts the iso-surface via marching cubes lookup tables. Reuses the same static MC table data as IsoSurfaceSOP. With no input connected, uses the built-in ball parameters; with input, reads vertex positions as ball centres (and pscale attribute as radius).

---

#### IsoSurfaceSOP

Analytic implicit surface via marching cubes — generates mathematical surfaces (Gyroid, Schwarz-P, Schwarz-D, Sphere, Torus, Custom).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| surface_type | Enum | Gyroid | Gyroid, Schwarz-P, Schwarz-D, Sphere, Torus, Custom | Implicit function |
| resolution | Int | 40 | 4–128 | Grid subdivisions per axis |
| bounds_size | Float | 6.28 | 0.5–100.0 | Cubic grid extent |
| threshold | Float | 0.0 | -50.0–50.0 | Iso value for surface extraction |
| frequency | Float | 1.0 | 0.01–20.0 | Spatial frequency multiplier |
| major_radius | Float | 2.0 | 0.1–50.0 | Torus major radius |
| minor_radius | Float | 0.8 | 0.01–20.0 | Torus minor radius |
| expression | String | "sin(x)*cos(y)+sin(y)*cos(z)+sin(z)*cos(x)" | — | Custom field formula (x, y, z) |

**How it works:** Evaluates the selected implicit function at each voxel grid point, then extracts the iso-surface via marching cubes. Custom mode uses Godot's `Expression` class to evaluate user formulas. Normal estimation via central differencing.

---

#### ParticleSOP

CPU particle emitter from SOP surface. Outputs a live point cloud.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| rate | Float | 100.0 | 0–100000 | Particles emitted per second |
| max_particles | Int | 10000 | 1–500000 | Maximum alive particles |
| seed | Int | 42 | 0–99999 | Random seed |
| life | Float | 2.0 | 0.01–60.0 | Particle lifespan (seconds) |
| life_rand | Float | 0.0 | 0.0–1.0 | Random life variation |
| emit_speed | Float | 1.0 | 0.0–100.0 | Initial velocity along surface normal |
| speed_rand | Float | 0.0 | 0.0–1.0 | Random speed variation |
| spread | Float | 0.0 | 0.0–180.0 | Cone angle deviation (degrees) |
| gravity | Float | -9.8 | -100–100 | Gravity on Y axis |
| drag | Float | 0.0 | 0.0–10.0 | Velocity damping |
| turbulence | Float | 0.0 | 0.0–50.0 | Random force per frame |
| attract_force | Float | 0.0 | -50–50 | Pull toward attractor input |
| floor_enabled | Bool | false | — | Floor collision |
| floor_y | Float | 0.0 | -100–100 | Floor plane Y position |
| bounce | Float | 0.3 | 0.0–1.0 | Bounce restitution |
| reset | Bool | false | — | Pulse to clear all particles |

**Inputs:** `emitter` (SOP, optional — emission surface), `attractor` (SOP, optional).

**How it works:** Maintains an internal particle pool with position, velocity, age, and life per particle. Each cook emits new particles (from emitter surface or origin), integrates particle dynamics (gravity, drag, turbulence, floor collision), kills expired particles, and outputs the live set as a point cloud mesh. Time-dependent — re-cooks every frame.

---

### Deformers (New)

---

#### MagnetSOP

Deform geometry by attracting/repelling vertices toward attractor points.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | -10.0–10.0 | Deformation strength (negative = repel) |
| radius | Float | 2.0 | 0.01–100.0 | Falloff radius |
| falloff | Enum | Smooth | Linear, Smooth, Inverse Square, Gaussian | Distance falloff curve |
| exponent | Float | 2.0 | 0.1–10.0 | Falloff exponent |
| affect_normals | Bool | true | — | Recompute normals after deformation |
| att_x, att_y, att_z | Float | 0.0 | -100–100 | Default attractor position |

**Inputs:** `geo` (SOP — geometry to deform), `attractors` (SOP, optional — point cloud).

**How it works:** For each vertex, computes distance to each attractor and applies a weighted displacement toward the attractor. The falloff function shapes the deformation zone. If `attractors` input is disconnected, uses the built-in `att_x/y/z` position. Optionally recomputes normals from the deformed mesh.

---

#### CarveSOP

Trim mesh by parametric U range — useful for reveal/wipe animations.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| first_u | Float | 0.0 | 0.0–1.0 | Start of kept range |
| second_u | Float | 1.0 | 0.0–1.0 | End of kept range |
| extract | Bool | false | — | Invert selection (keep outside) |
| use_uvs | Bool | false | — | Use texture U instead of vertex index |
| axis | Enum | Y | X, Y, Z | Positional axis for slicing |
| use_position | Bool | false | — | Carve by normalised position along axis |

**Input:** `geo` (SOP).

**How it works:** Computes a normalised parametric value per triangle (by vertex index fraction, UV coordinate, or normalised position along the chosen axis), then keeps or discards triangles based on the `[first_u, second_u]` range. Animate `second_u` for a reveal/wipe effect.

---

#### PolyReduceSOP

Mesh decimation via quadric error metric edge collapse.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| target_percent | Float | 50.0 | 1.0–100.0 | Percentage of triangles to keep |
| preserve_boundary | Bool | true | — | Extra cost on boundary edges |
| boundary_weight | Float | 10.0 | 0.1–1000.0 | Boundary edge penalty multiplier |

**Input:** `geo` (SOP).

**How it works:** Builds a half-edge structure, computes quadric error matrices per vertex, then iteratively collapses the lowest-cost edge until the target triangle count is reached. Boundary edges receive an extra penalty to preserve silhouette. Final mesh is rebuilt with `SurfaceTool` and normals are regenerated.

---

### Bridge (New)

---

#### CHOPtoSOP

Convert CHOP channels to SOP point geometry — visualise waveforms as 3D lines.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Points | Points, Line, Trail | How to interpret channel data |
| x_scale | Float | 0.1 | 0.001–100.0 | Horizontal sample spacing |
| y_scale | Float | 1.0 | 0.001–100.0 | Vertical value multiplier |
| max_samples | Int | 1000 | 1–100000 | Maximum samples to convert |
| center_x | Bool | true | — | Center geometry at X origin |

**Input:** `in` (CHOP).

**How it works:** Reads channel samples and maps them to vertex positions: X = sample index × x_scale, Y = value × y_scale. Points mode creates individual points; Line mode creates a connected line strip; Trail mode creates one geometry per channel.

---

#### DATtoSOP

Convert DAT table rows to SOP point geometry.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Points | Points, Lines | Output primitive type |
| max_rows | Int | 10000 | 1–1000000 | Maximum rows to process |

**Input:** `in` (DAT).

**How it works:** Reads table rows looking for columns named x, y, z (or columns 0, 1, 2). Each row becomes a vertex position. Points mode creates individual vertices; Lines mode connects them as a line strip.

---

#### TOPtoSOP

Convert TOP texture to SOP heightfield or point cloud.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Heightfield | Heightfield, Point Cloud, Normal Map | Conversion method |
| resolution | Int | 64 | 4–512 | Grid subdivisions |
| height_scale | Float | 2.0 | 0.0–100.0 | Vertical displacement multiplier |
| grid_size | Float | 10.0 | 0.1–1000.0 | Horizontal extent |
| threshold | Float | 0.1 | 0.0–1.0 | Luminance threshold (Point Cloud mode) |
| channel | Enum | Luminance | Luminance, Red, Green, Blue, Alpha | Displacement channel |

**Input:** `in` (TOP).

**How it works:** Reads the input texture via `get_image()`, then generates geometry: Heightfield builds a subdivided grid with Y displacement from pixel luminance; Point Cloud creates a point per pixel above the threshold; Normal Map displaces grid vertices along the decoded normal direction.

---

#### File In SOP

Import geometry from an OBJ, glTF, or Godot resource file.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | "" |  | Path to geometry file (OBJ, glTF, .tres, .res) |
| reload | Bool | false |  | Pulse to force reload |

**Output:** SOP (imported geometry).

**How it works:** Dispatches by extension: `.obj` is parsed line-by-line with `SurfaceTool` (positions, normals, UVs, fan-triangulated faces); `.glb`/`.gltf` uses `GLTFDocument` to load and extracts the first `MeshInstance3D`; `.tres`/`.res` uses `ResourceLoader`. The resulting `ArrayMesh` is set on the output.

---

#### File Out SOP

Export geometry to a Wavefront OBJ file with pass-through.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | "" |  | Output file path (.obj) |
| write | Bool | false |  | Pulse to export current geometry |

**Input:** `in` (SOP).
**Output:** SOP (pass-through of input geometry).

**How it works:** On `write` pulse, iterates all surfaces of the input `ArrayMesh`, writes vertices, normals, UVs, and indexed/non-indexed face definitions in Wavefront OBJ format. Creates directories as needed. Always passes input geometry through.

---

#### Group SOP

Create point or primitive groups by spatial/index criteria.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| group_name | String | "group1" |  | Name of the group to create |
| entity | Enum | Points | Points, Primitives | Select points or primitives |
| method | Enum | Bounding Box | Bounding Box, Normal Direction, Range Pattern, All | Selection criterion |
| bb_min_x/y/z | Float | -0.5 | unbounded | Bounding box minimum |
| bb_max_x/y/z | Float | 0.5 | unbounded | Bounding box maximum |
| dir_x/y/z | Float | 0/1/0 | -11 | Normal direction vector |
| spread_angle | Float | 45.0 | 0180 | Cone half-angle in degrees |
| range_pattern | String | "0-9" |  | Index range (e.g. 0-9, 20, 30-40) |
| operation | Enum | Set | Set, Add, Remove | Group operation mode |

**Input:** `in` (SOP).
**Output:** SOP (geometry with updated group attribs).

**How it works:** Duplicates input geometry, builds a selection mask using the chosen method (AABB containment, normal-direction cone test, comma-separated index ranges, or all), then applies Set/Add/Remove operation to produce a membership `PackedFloat32Array` stored as a point attrib. Primitive groups use a `prim_` prefix.

---

#### Primitive SOP

Compute per-primitive attributes: face normals, area, centroid, and primitive index.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| face_normals | Bool | true |  | Store face normal (fn_x, fn_y, fn_z) |
| face_area | Bool | false |  | Store face area (face_area) |
| face_centroid | Bool | false |  | Store centroid (fc_x, fc_y, fc_z) |
| face_id | Bool | true |  | Store primitive index (prim_id) |

**Input:** `in` (SOP).
**Output:** SOP (geometry with per-primitive point attribs).

**How it works:** Iterates all triangles across all surfaces. For each face, computes cross-product normal, area (half cross-product length), and centroid. Writes toggled attributes per-vertex as point attribs.

---

#### Blend SOP

Vertex-level morph/blend between two geometries.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| blend | Float | 0.5 | 0.01.0 | Interpolation factor (0 = A, 1 = B) |
| blend_normals | Bool | true |  | Also interpolate normals |
| blend_uvs | Bool | false |  | Also interpolate UVs |

**Input 0:** `geo_a` (SOP  base geometry, blend=0).
**Input 1:** `geo_b` (SOP  target geometry, blend=1).
**Output:** SOP (blended geometry).

**How it works:** For each surface where both inputs have matching vertex counts, lerps positions (and optionally normals/UVs) per-vertex by `blend`. Normalizes blended normals. Mismatched vertex counts pass through from input A.

---

### Smoothing / Remeshing

---

#### Smooth SOP

Iterative Laplacian vertex smoothing (relaxation). Averages vertex position with neighbours with configurable strength and iteration count. Border vertices can be pinned.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `iterations` | Int | 3 | Smoothing passes |
| `strength` | Float | 0.5 | Blend factor (0=none, 1=full) |
| `pin_borders` | Bool | true | Pin boundary vertices |

**Inputs:** `in` (SOP).
**Output:** SOP (smoothed geometry).

---

#### PolyBevel SOP

Bevel polygon edges by pushing vertices inward along normals and creating chamfer geometry. Multi-division rounding with configurable roundness.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `offset` | Float | 0.05 | Bevel distance |
| `divisions` | Int | 1 | Rounding subdivisions |
| `roundness` | Float | 0.5 | Flat (0) to rounded (1) |

**Inputs:** `in` (SOP).
**Output:** SOP (beveled geometry).

---

#### Remesh SOP

Retopologize to uniform triangle density. Edge-length-based midpoint subdivision with optional Laplacian smoothing.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `target_edge` | Float | 0.1 | Desired edge length |
| `iterations` | Int | 3 | Subdivision passes |
| `smooth` | Bool | true | Post-smoothing |

**Inputs:** `in` (SOP).
**Output:** SOP (uniformly tessellated mesh).

---

### Reference / Texture

---

#### Object Merge SOP

Fetch geometry from another SOP by path reference, optionally applying the source's transform.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sop_path` | String | — | Node ID of source SOP |
| `apply_transform` | Bool | false | Apply source transform |

**Output:** SOP (referenced geometry).

---

#### Texture SOP

Apply a TOP texture to SOP geometry as vertex colors or normal-based displacement.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mode` | Enum | Vertex Color | Application mode |
| `displacement_scale` | Float | 0.1 | Displacement multiplier |
| `uv_set` | Int | 0 | UV channel (0 or 1) |

**Inputs:** `geo` (SOP), `tex` (TOP).
**Output:** SOP (textured/displaced geometry).

---

### Poly Construction

---

#### PolyBridge SOP

Bridge two polygon edge loops with connecting quad strips. Supports subdivision and twist.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `divisions` | Int | 1 | Bridge subdivisions |
| `twist` | Float | 0.0 | Twist angle (degrees) |

**Inputs:** `geo_a` (SOP), `geo_b` (SOP).
**Output:** SOP (bridge geometry).

---

#### PolyPatch SOP

Bilinear Coons patch surface from 4 boundary corners with configurable resolution.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `rows` | Int | 10 | U subdivisions |
| `cols` | Int | 10 | V subdivisions |

**Inputs:** `in` (SOP, first 4 vertices as corners).
**Output:** SOP (patch surface with UVs).

---

#### PolySpline SOP

Catmull-Rom spline curve, tube, or ribbon from input control points.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `subdivisions` | Int | 8 | Points per segment |
| `output` | Enum | Line | Line / Tube / Ribbon |
| `radius` | Float | 0.05 | Tube/ribbon radius |
| `sides` | Int | 8 | Tube cross-section sides |
| `closed` | Bool | false | Close the spline loop |

**Inputs:** `in` (SOP, control points).
**Output:** SOP (spline geometry).

---

#### PolyStitch SOP

Stitch two polygon boundaries by connecting nearest vertex pairs. Creates triangle strips between matched boundary vertices.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_distance` | Float | 1.0 | Max pairing distance (0=unlimited) |
| `include_inputs` | Bool | true | Include original geometry |

**Inputs:** `geo_a` (SOP), `geo_b` (SOP).
**Output:** SOP (stitched geometry).

---

#### HeightfieldSOP

Procedural terrain heightfield generator — creates a subdivided grid, displaces vertices vertically using FBM noise, and optionally applies thermal erosion for natural-looking landscapes.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| size_x | Float | 10.0 | 0.1–1000.0 | Terrain width |
| size_z | Float | 10.0 | 0.1–1000.0 | Terrain depth |
| subdivisions | Int | 64 | 4–512 | Grid subdivisions (vertex count = (n+1)²) |
| height | Float | 2.0 | 0.0–100.0 | Maximum displacement height |
| octaves | Int | 6 | 1–12 | FBM fractal octaves |
| frequency | Float | 0.8 | 0.01–10.0 | Base noise frequency |
| lacunarity | Float | 2.0 | 1.0–4.0 | Frequency multiplier per octave |
| persistence | Float | 0.5 | 0.0–1.0 | Amplitude decay per octave |
| seed | Int | 0 | 0–99999 | Noise seed |
| offset_x | Float | 0.0 | — | Noise offset X |
| offset_z | Float | 0.0 | — | Noise offset Z |
| noise_type | Enum | Simplex | Simplex, Perlin, Cellular, Value | Noise algorithm |
| erosion_iters | Int | 0 | 0–100 | Thermal erosion iterations |
| erosion_strength | Float | 0.1 | 0.0–1.0 | Material transfer per iteration |
| talus_angle | Float | 0.6 | 0.0–2.0 | Slope threshold for erosion |

**Output:** SOP (terrain mesh with normals, tangents, and UVs).

**How it works:** Generates a (subdivisions+1)² vertex grid, samples `FastNoiseLite` with FBM fractal at each position, and displaces Y by noise × height. Thermal erosion simulates material sliding downhill: for each iteration, each vertex checks its 4-connected neighbors — if the slope exceeds `talus_angle`, material transfers from higher to lower vertex, producing realistic ridges and valleys. Final mesh includes auto-generated normals and tangents for correct lighting.

---

#### VoronoiShatter SOP

Fractures input geometry via 3D Voronoi decomposition. Seeds are scattered inside the mesh bounding box; each seed defines a Voronoi cell. The input mesh is clipped against each cell's half-planes using Sutherland-Hodgman clipping, producing separate fragment surfaces. Outputs a `piece` point attribute for per-fragment identification.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| num_points | Int | 8 | 2–256 | Number of Voronoi seed points |
| seed | Int | 0 | 0–99999 | Random seed for point scatter |
| offset | Float | 0.0 | 0.0–0.1 | Gap between pieces (explode factor) |
| interior_faces | Bool | true | — | Generate faces on cut planes |

**Input:** `in` (SOP — geometry to fracture).
**Output:** SOP (one surface per piece, `piece` point attribute).

---

## COMP — Component Operators

COMPs are 3D scene components. Unlike other families, COMPs don't produce `GNData` output — instead, they create and manage Godot `Node3D` instances (MeshInstance3D, Camera3D, Light3D) that are adopted into a RenderTOP's isolated 3D SubViewport for rendering.

COMPs are the bridge between procedural data (SOP geometry, TOP textures) and Godot's 3D rendering engine.

**Total: 12 operators.**

> Note: SubNetworkNode, InTunnel, OutTunnel are internal system nodes.
> NullCOMP, SwitchCOMP, and EnvironmentCOMP are utility nodes.

---

#### GeometryCOMP

Wraps a `MeshInstance3D`. Takes SOP geometry and optionally a TOP texture, placing them into a 3D scene.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Translation |
| rx, ry, rz | Float | 0.0 | -360–360 | Rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Scale |
| albedo_color | Color | White | — | Base material color |
| metallic | Float | 0.0 | 0.0–1.0 | Metallic shading |
| roughness | Float | 0.5 | 0.0–1.0 | Surface roughness |
| emission_energy | Float | 0.0 | 0.0–16.0 | Emission brightness |
| emission_color | Color | Black | — | Emission color |
| visible | Bool | true | — | Show/hide |

**Inputs:** `geo_in` (SOP — geometry to display), `tex_in` (TOP — optional albedo texture).

**How it works:** Creates a `MeshInstance3D` with a `StandardMaterial3D`. Each cook, applies the SOP mesh, transform, material properties, and optional TOP texture as albedo map. The MeshInstance3D is **not** added as a child of the COMP node — instead, RenderTOP discovers it via `get_mesh_instance()` and adopts it into its SubViewport.

---

#### InstanceCOMP

MultiMesh instancing — place thousands of copies in one draw call. Takes a template SOP and a point cloud SOP, creates a `MultiMeshInstance3D`.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| count | Int | 100 | 1–100000 | Instance count (no point cloud) |
| scatter_mode | Enum | Grid | Grid, Random | Placement without point input |
| spacing | Float | 1.0 | 0.01–100.0 | Grid cell spacing / random radius |
| seed | Int | 42 | 0–99999 | Random seed |
| tx, ty, tz | Float | 0.0 | — | Group translation |
| rx, ry, rz | Float | 0.0 | -360–360 | Group rotation |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Group scale |
| align_to_normal | Bool | true | — | Align instances to point normals |
| scale_rand | Float | 0.0 | 0.0–1.0 | Random scale variation |
| rotation_rand | Float | 0.0 | 0.0–360.0 | Random Y-axis rotation per instance |
| albedo_color | Color | White | — | Base colour (no MAT) |
| metallic | Float | 0.0 | 0.0–1.0 | Metallic (fallback material) |
| roughness | Float | 0.5 | 0.0–1.0 | Roughness (fallback material) |
| visible | Bool | true | — | Show/hide |
| cast_shadow | Enum | On | Off, On, Double-Sided, Shadows Only | Shadow mode |
| chop_map | Enum | Off | Off, Position, Scale, Rotation Y, Color (r/g/b/a), Uniform Scale (s) | CHOP → per-instance transforms or color |

**Inputs:** `template` (SOP — mesh to instance), `points` (SOP, optional — placement point cloud), `mat_in` (MAT, optional), `chop_in` (CHOP, optional — per-instance animation).

**How it works:** Creates a `MultiMeshInstance3D` with Godot's `MultiMesh`. If a point cloud SOP is connected, each point becomes an instance transform; otherwise generates a grid or random placement. Supports `pscale` and `N` (normal) attributes from the point cloud. CHOP input can drive per-instance transforms via the `chop_map` parameter. Extremely efficient — single draw call for all instances.

**Per-Instance Color:** Set `chop_map` to **Color (r/g/b/a)** and connect a CHOP with channels named `r`, `g`, `b`, `a`. Each instance receives a unique color via `MultiMesh.use_colors`. Alternatively, if the SOP point cloud contains a `Cd` attribute (PackedColorArray), per-instance colors are applied automatically regardless of chop_map mode.

**Uniform Scale:** Set `chop_map` to **Uniform Scale (s)** and connect a CHOP with a channel named `s`. Each instance's XYZ scale is multiplied uniformly by the channel value.

---

#### CameraCOMP

Wraps a `Camera3D`. Defines the viewpoint for a RenderTOP.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0, 1, 3 | — | Camera position |
| rx, ry, rz | Float | -15, 0, 0 | — | Camera rotation in degrees |
| use_look_at | Bool | false | — | Override rotation to look at a target point |
| look_at_x, y, z | Float | 0.0 | — | Look-at target position |
| projection | Enum | Perspective | Perspective, Orthogonal | Projection mode |
| fov | Float | 75.0 | 1.0–179.0 | Field of view (perspective only) |
| ortho_size | Float | 10.0 | 0.1–1000.0 | Orthographic view size |
| near | Float | 0.05 | 0.001–100.0 | Near clip plane |
| far | Float | 100.0 | 1.0–10000.0 | Far clip plane |
| clear_color | Color | (0.1, 0.1, 0.1) | — | Background clear color |

**How it works:** Creates a `Camera3D` node. Applies position, rotation (or look-at targeting), projection mode, and clipping planes. Returns null from cook — accessed via `get_camera()` by RenderTOP, which adopts the Camera3D into its viewport.

---

#### LightCOMP

Wraps a `Light3D`. Provides scene illumination in a RenderTOP.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| type | Enum | Directional | Directional, Omni, Spot | Light type |
| tx, ty, tz | Float | 0, 3, 2 | — | Light position |
| rx, ry, rz | Float | -45, 0, 0 | — | Light rotation in degrees |
| color | Color | White | — | Light color |
| energy | Float | 1.0 | 0.0–16.0 | Light intensity |
| shadows | Bool | true | — | Cast shadows |
| omni_range | Float | 10.0 | 0.1–1000.0 | Omni light range |
| spot_range | Float | 10.0 | 0.1–1000.0 | Spot light range |
| spot_angle | Float | 45.0 | 0.1–90.0 | Spot light cone angle |

**How it works:** Creates a `DirectionalLight3D`, `OmniLight3D`, or `SpotLight3D` depending on the `type` parameter. If the type changes, the old light node is freed and a new one is created. Returns null from cook — accessed via `get_light()` by RenderTOP.

---

#### RigidBodyCOMP

Wraps a `RigidBody3D` with `CollisionShape3D` for dynamic physics simulation. Takes a COMP input (typically GeometryCOMP) for mesh, material, and collision shape — this node only owns physics properties.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Initial position |
| rx, ry, rz | Float | 0.0 | -360–360 | Initial rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Scale |
| mode | Enum | Dynamic | Dynamic, Kinematic, Static | Physics body mode |
| mass | Float | 1.0 | 0.001–1000.0 | Body mass in kg |
| gravity_scale | Float | 1.0 | -10.0–10.0 | Gravity multiplier |
| friction | Float | 1.0 | 0.0–2.0 | Surface friction |
| bounce | Float | 0.0 | 0.0–1.0 | Restitution / bounciness |
| linear_damp | Float | 0.0 | 0.0–100.0 | Linear velocity damping |
| angular_damp | Float | 0.0 | 0.0–100.0 | Angular velocity damping |
| init_vel_x/y/z | Float | 0.0 | — | Initial linear velocity |
| lock_rot_x/y/z | Bool | false | — | Lock rotation axes |
| collision_shape | Enum | Convex Hull | Convex, Box, Sphere, Capsule, Trimesh | Collision shape type |
| ccd | Bool | false | — | Continuous collision detection |

**Inputs:** `comp_in` (COMP — typically GeometryCOMP providing mesh + material), `force_in` (CHOP, optional — channels: `force_x/y/z`, `impulse_x/y/z`, `torque_x/y/z`).

**Architecture:** `SOP → GeometryCOMP → RigidBodyCOMP → MergeCOMP → RenderTOP` (with PbrMAT wired to GeometryCOMP).

**How it works:** Resolves the upstream COMP's `MeshInstance3D` and mirrors its mesh, material, visibility, and shadow settings onto an internal `MeshInstance3D`. Collision shape is auto-generated from the upstream mesh. In Dynamic mode, Godot's physics engine (Jolt) controls the transform. CHOP force input is applied every cook (Dynamic mode only).

---

#### StaticBodyCOMP

Wraps a `StaticBody3D` — an immovable collider for floors, walls, and obstacles. Takes a COMP input (typically GeometryCOMP) — this node only owns collision and physics-material properties.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Position |
| rx, ry, rz | Float | 0.0 | -360–360 | Rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Scale |
| friction | Float | 1.0 | 0.0–2.0 | Surface friction |
| bounce | Float | 0.0 | 0.0–1.0 | Restitution |
| collision_shape | Enum | Trimesh | Convex, Box, Sphere, Capsule, Trimesh | Collision shape type |

**Inputs:** `comp_in` (COMP — typically GeometryCOMP providing mesh + material).

**Architecture:** `SOP → GeometryCOMP → StaticBodyCOMP → MergeCOMP → RenderTOP` (with PbrMAT wired to GeometryCOMP).

**How it works:** Resolves the upstream COMP's `MeshInstance3D` and mirrors its mesh, material, visibility, and shadow settings onto an internal `MeshInstance3D`. Defaults to Trimesh collision (accurate for complex static geometry). Transform is applied every cook.

---

#### SoftBodyCOMP

Wraps a `SoftBody3D` for deformable mesh physics (cloth, jelly, rubber). Takes a COMP input (typically GeometryCOMP) — this node only owns soft-body physics properties.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Position |
| rx, ry, rz | Float | 0.0 | -360–360 | Rotation |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Scale |
| simulation_precision | Int | 5 | 1–40 | Solver iterations |
| total_mass | Float | 1.0 | 0.01–1000.0 | Total body mass |
| linear_stiffness | Float | 0.5 | 0.0–1.0 | Spring stiffness |
| pressure_coefficient | Float | 0.0 | -100.0–100.0 | Internal pressure |
| damping_coefficient | Float | 0.01 | 0.0–1.0 | Motion damping |
| drag_coefficient | Float | 0.0 | 0.0–1.0 | Air drag |
| ray_pickable | Bool | false | — | Ray picking support |

**Inputs:** `comp_in` (COMP — typically GeometryCOMP providing mesh + material).

**Architecture:** `SOP → GeometryCOMP → SoftBodyCOMP → MergeCOMP → RenderTOP` (with PbrMAT wired to GeometryCOMP).

**How it works:** Resolves the upstream COMP's `MeshInstance3D` and copies its mesh, material, visibility, and shadow settings. The mesh is assigned **once** (SoftBody3D doesn't support live mesh swapping). Physics parameters are updated every cook. High `linear_stiffness` = rigid cloth; high `pressure_coefficient` = inflated balloon.

---

#### AreaCOMP

Wraps an `Area3D` for force fields, gravity zones, and wind effects.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Position |
| rx, ry, rz | Float | 0.0 | -360–360 | Rotation |
| gravity_direction_x/y/z | Float | 0,-1,0 | -1.0–1.0 | Gravity direction |
| gravity_strength | Float | 9.8 | 0.0–100.0 | Gravity magnitude |
| gravity_point | Bool | false | — | Point gravity (toward center) |
| damping | Float | 0.0 | 0.0–100.0 | Linear damping override |
| priority | Int | 0 | 0–128 | Area priority |
| shape | Enum | Box | Box, Sphere | Built-in shape |
| shape_size_x/y/z | Float | 2.0 | 0.01–1000.0 | Box half-extents |
| shape_radius | Float | 2.0 | 0.01–1000.0 | Sphere radius |
| debug_vis | Bool | false | — | Show translucent debug shape |

**Inputs:** `geo_in` (SOP, optional — custom collision shape).

**How it works:** Creates an `Area3D` with `SPACE_OVERRIDE_REPLACE`. When a rigid body enters the area, the area's gravity and damping override the world defaults. SOP input replaces the built-in shape with a convex hull collision shape. Debug visualization adds a translucent mesh to see the area bounds in the render.

---

#### JointCOMP

Wraps a `Joint3D` constraint between two physics bodies.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| joint_type | Enum | Pin | Pin, Hinge, Slider, ConeTwist, 6DOF | Joint type |
| tx, ty, tz | Float | 0.0 | — | Joint anchor position |
| rx, ry, rz | Float | 0.0 | -360–360 | Joint rotation |
| hinge_use_limit | Bool | false | — | Enable hinge angle limits |
| hinge_limit_lower/upper | Float | -180/180 | -180–180 | Hinge angle limits |
| hinge_motor_enable | Bool | false | — | Enable hinge motor |
| hinge_motor_speed | Float | 1.0 | -100–100 | Motor target speed |
| hinge_motor_max_impulse | Float | 1.0 | 0–1000 | Motor max impulse |
| slider_limit_lower/upper | Float | -1/1 | -100–100 | Slider linear limits |
| cone_swing_span | Float | 45.0 | 0–180 | Cone twist swing span |
| cone_twist_span | Float | 45.0 | 0–180 | Cone twist twist span |

**Inputs:** `body_a` (COMP), `body_b` (COMP).

**How it works:** Creates the appropriate Joint3D subtype (PinJoint3D, HingeJoint3D, etc.). Walks the network to find Body A and Body B COMP nodes, then sets `node_a` / `node_b` NodePaths. If the joint type changes, the old joint is freed and a new one is created. Both bodies must be in the same scene tree (typically via MergeCOMP → RenderTOP).

---

### Utility (New)

---

#### NullCOMP

Pass-through component for wire organization. Forwards input component unchanged.

**Input:** `in` (COMP). No parameters.

---

#### SwitchCOMP

Select one of up to 8 component inputs by index.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index | Int | 0 | 0–7 | Which input to pass through |

**Inputs:** `in0`–`in7` (COMP).

---

#### EnvironmentCOMP

Defines the rendering environment for a 3D scene — background, ambient light, tone mapping, and all post-processing effects. Connect to a RenderTOP COMP input alongside Geometry/Camera/Light COMPs.

Separating environment from rendering allows one environment shared across multiple RenderTOPs, CHOP-animated post-processing, and cleaner networks.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| bg_mode | Enum | Color | Background mode (Color, Sky, Canvas, Keep) |
| bg_color | Color | (0.1,0.1,0.12) | Background clear color |
| bg_energy | Float | 1.0 | Background energy multiplier |
| ambient_enabled | Bool | true | Enable ambient light |
| ambient_color | Color | (0.3,0.3,0.4) | Ambient light color |
| ambient_energy | Float | 0.3 | Ambient light intensity |
| tonemap_mode | Enum | ACES | Tone mapping (Linear, Reinhard, Filmic, ACES) |
| tonemap_exposure | Float | 1.0 | Exposure multiplier |
| tonemap_white | Float | 1.0 | White point |
| glow_enabled | Bool | false | Enable glow/bloom |
| glow_intensity | Float | 0.8 | Glow strength |
| glow_strength | Float | 1.0 | Per-level contribution |
| glow_bloom | Float | 0.0 | Screen-wide bloom |
| glow_hdr_threshold | Float | 1.0 | HDR brightness threshold |
| glow_blend_mode | Enum | Additive | Glow composite mode |
| ssao_enabled | Bool | false | Screen-space ambient occlusion |
| ssao_radius | Float | 1.0 | Occlusion radius |
| ssao_intensity | Float | 2.0 | Occlusion strength |
| ssao_power | Float | 1.5 | Falloff exponent |
| ssil_enabled | Bool | false | Screen-space indirect lighting |
| ssil_radius | Float | 5.0 | Indirect light radius |
| ssil_intensity | Float | 1.0 | Indirect light strength |
| ssil_sharpness | Float | 0.98 | Edge-aware blur |
| ssil_normal_rejection | Float | 1.0 | Normal rejection |
| ssr_enabled | Bool | false | Screen-space reflections |
| ssr_max_steps | Int | 64 | Ray march steps |
| ssr_fade_in | Float | 0.15 | Fade in distance |
| ssr_fade_out | Float | 2.0 | Fade out distance |
| ssr_depth_tolerance | Float | 0.2 | Depth tolerance |
| adj_enabled | Bool | false | Color adjustments |
| adj_brightness | Float | 1.0 | Brightness multiplier |
| adj_contrast | Float | 1.0 | Contrast |
| adj_saturation | Float | 1.0 | Saturation |
| fog_enabled | Bool | false | Volumetric fog |
| fog_density | Float | 0.05 | Fog density |
| fog_albedo | Color | White | Fog scatter colour |
| fog_emission | Color | Black | Fog emission colour |
| fog_emission_energy | Float | 1.0 | Emission intensity |
| fog_length | Float | 64.0 | Fog distance |

**Output:** `out` (COMP). When connected to RenderTOP, overrides the fallback environment.

---

### Scripting (SCRIPT Family)

---

#### GDScriptSCRIPT

Consolidated GDScript scripting node. A Template dropdown selects the target context (Generic, CHOP, SOP, DAT, IMG). The Generic template supports multi-output via `# @output` annotations.

Extends `GNNode` directly. Uses SCRIPT family.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| template | Enum | Generic | Starting code template (Generic, CHOP, SOP, DAT, IMG) |
| time_dependent | Bool | false | Re-cook every frame |
| cook_once | Bool | false | Pulse: force single cook, auto-resets |
| force_active | Bool | false | Keep active without downstream sink |
| code | String | (default) | GDScript with cook(), @output, @input, @param annotations |

**Preview:** Shows cook time and status (`0.8ms | OK` or `ERR | message`). No viewer — wire a Null of the target family to inspect output.

**Annotations:**

```
# @input <family>  <description>   — dynamic input port
# @output <family> <description>   — dynamic output port (chop, top, sop, dat, img, mat)
# @param <type> <name> <default> <description>  — inspector parameter
```

**Context variables:** `me`, `inputs`, `outputs` (Array of pre-populated typed data objects, one per @output), `op` (alias for outputs[0]), `time`, `frame`, `dt`, `par()`, `chop()`, `top()`, `sop()`, `dat()`, `op_ref()`, `set_par()`, `network_add_node()`, `network_connect()`, `network_disconnect()`, `network_remove_node()`, `network_node_ids()`, `network_node_info()`.

**Example:**

```gdscript
# @input chop  Signal source
# @output chop Modified signal
# @output dat  Signal info
# @param float gain 1.0 Output gain

func cook():
    if inputs[0] != null:
        for ch in inputs[0].get_channel_names():
            var v = inputs[0].get_value(ch) * par("gain")
            outputs[0].set_single_value(ch, v)
    outputs[1].set_headers(PackedStringArray(["key", "value"]))
    outputs[1].append_row(PackedStringArray(["time", "%.3f" % time]))
```

---

## MAT — Material Operators

MATs produce materials for COMP use. Output type is `GNMaterialData`, wrapping Godot's `Material` base class. MATs connect to GeometryCOMP's material input to override the default PBR.

**Total: 8 operators** — 1 PBR, 1 shader, 1 constant, 1 wireframe, 1 point sprite, 1 depth, 1 null, 1 utility.

---

#### ConstantMAT

Flat unlit material — no lighting or shading applied.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| color | Color | White | Surface color |
| alpha | Float | 1.0 | Opacity |
| cull_mode | Enum | Back | Back, Front, Disabled |

**Input:** `color_tex` (TOP, optional). Uses `SHADING_MODE_UNSHADED`.

---

#### WireframeMAT

Wireframe rendering material using Godot's spatial `render_mode wireframe`.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| color | Color | Green | Wire color |
| alpha | Float | 1.0 | Wire opacity |

Uses ShaderMaterial with inline spatial shader.

---

#### PointSpriteMAT

Renders geometry vertices as sized point sprites.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| color | Color | White | — | Point color |
| point_size | Float | 4.0 | 1–64 | Point size in pixels |

**Input:** `tex_in` (TOP, optional — sprite texture). Uses `POINT_SIZE` vertex shader output and `POINT_COORD` in fragment.

---

#### DepthMAT

Visualize scene depth as grayscale.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| near_val | Float | 0.1 | 0.001–100 | Near depth (white) |
| far_val | Float | 100.0 | 1–10000 | Far depth (black) |
| invert | Bool | false | — | Swap near/far mapping |

Uses ShaderMaterial that linearizes FRAGCOORD.z.

---

#### Normal Map MAT

Normal-map visualization material with PBR base.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| normal_scale | Float | 1.0 | -4.04.0 | Normal map strength |
| albedo_color | Color | (0.7, 0.7, 0.7) |  | Base color (no albedo texture) |
| roughness | Float | 0.5 | 0.01.0 | Surface roughness |
| unlit | Bool | false |  | Render unlit to see raw normal colors |
| cull_mode | Enum | Back | Back, Front, Disabled | Face culling |

**Input 0:** `normal_tex` (TOP  normal map texture).
**Input 1:** `albedo_tex` (TOP  optional base color texture).
**Output:** MAT (StandardMaterial3D with normal mapping).

**How it works:** Creates/updates a `StandardMaterial3D`. Sets albedo color/texture, enables normal mapping with input TOP texture and `normal_scale`, applies roughness, toggles unlit shading, and sets cull mode.

---

#### Line MAT

Line/wireframe rendering material with stipple (dashed line) controls.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| color | Color | White |  | Line color |
| width | Float | 1.0 | 0.110.0 | Line width |
| alpha | Float | 1.0 | 0.01.0 | Overall opacity |
| stipple_scale | Float | 10.0 | 0.1100.0 | Dash pattern frequency |
| stipple_ratio | Float | 1.0 | 0.01.0 | Visible portion of each dash (1.0 = solid) |
| cull_mode | Enum | Disabled | Back, Front, Disabled | Face culling |

**Output:** MAT (ShaderMaterial with wireframe render mode).

**How it works:** Creates a `ShaderMaterial` with `render_mode unshaded, wireframe`. Fragment shader discards fragments based on a distance-based stipple pattern. Uniforms control color, width, alpha, stipple scale and ratio.

---

#### FluidSurfaceMAT

Physically-inspired water/fluid surface material with Fresnel reflections, refraction, animated caustics, and procedural wave normals.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| deep_color | Color | (0.02, 0.08, 0.15, 1) | — | Deep water color |
| shallow_color | Color | (0.1, 0.4, 0.5, 1) | — | Shallow/edge color |
| opacity | Float | 0.85 | 0.0–1.0 | Base opacity |
| fresnel_power | Float | 3.0 | 0.5–10.0 | Fresnel exponent |
| fresnel_bias | Float | 0.04 | 0.0–1.0 | Minimum reflectance |
| refraction_strength | Float | 0.05 | 0.0–0.5 | Refraction distortion |
| metallic | Float | 0.0 | 0.0–1.0 | Metallic factor |
| roughness | Float | 0.05 | 0.0–1.0 | Surface roughness |
| specular | Float | 0.8 | 0.0–1.0 | Specular intensity |
| caustic_scale | Float | 8.0 | 1.0–50.0 | Caustic pattern scale |
| caustic_speed | Float | 1.0 | 0.0–5.0 | Caustic animation speed |
| caustic_intensity | Float | 0.3 | 0.0–2.0 | Caustic brightness |
| wave_scale | Float | 10.0 | 1.0–50.0 | Normal wave frequency |
| wave_height | Float | 0.02 | 0.0–0.2 | Normal perturbation strength |
| wave_speed | Float | 1.0 | 0.0–5.0 | Wave animation speed |

**Input 0:** `normal_map` (TOP, optional — external normal map blended with procedural waves).

**How it works:** Spatial shader with Fresnel-based deep/shallow color blending. Dual-layer animated Voronoi caustics add underwater light patterns. Procedural sine-wave normals create surface ripples. Refraction via BACKLIGHT. Optional TOP input provides an external normal map blended with the procedural waves. Suitable for ocean, pool, lava (with adjusted colors), and any fluid surface.

---

#### NullMAT

Pass-through. Forwards input material unchanged. Useful for wire organization, expression references, and inspecting multi-output ports.

---

## OUT — Output Operators

Output operators are terminal/sink nodes that display or save results. They extend `GNOutBase`, belong to the OUT family, and have `is_sink = true`. They have inputs but no data outputs — they are the endpoints of the cook graph.

---

#### SinkOUT

Keep-alive sink — holds its upstream chain active without producing output. Accepts any data family via adaptive input port. Use this to keep headless processing chains alive when there is no WindowOUT, file-save, or network output downstream.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| active | Bool | true | When ON the node acts as a sink, keeping its chain cooking |

**Input 0:** `in` (any family — adapts to whatever is connected).

**How it works:** Extends `GNOutBase` with `is_sink` toggled by the `active` parameter. Overrides `can_accept_connection()` to accept any data family (like DotNode). The `_cook()` method is a no-op — data flows in and is consumed without processing. Toggle Active OFF to suspend the chain without deleting the node.

---

#### WindowOUT

Displays a TOP texture in a standalone OS window. Essential for VJ output — each WindowOUT creates a separate window that can be placed on any connected monitor.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| title | String | "GONODES Output" | — | Window title |
| monitor | Int | 0 | 0–8 | Target display index |
| window_mode | Enum | Windowed | Windowed, Fullscreen, Borderless | Window mode |
| resolution | Vector2i | 1920×1080 | — | Window resolution |
| position | Vector2i | (-1, -1) | — | Window position (-1,-1 = auto center) |
| always_on_top | Bool | false | — | Keep window above others |
| vsync | Bool | true | — | V-sync |

**Input 0:** `in` (TOP — background texture).
**Input 1:** `panel` (UI — interactive panel with native Godot input routing).

**How it works:** Creates a Godot `Window` node with a `TextureRect` (`mouse_filter = IGNORE`, z=0) for the background texture and a `VBoxContainer` "UIRoot" (`mouse_filter = PASS`, z=1) for the interactive panel layer. The TextureRect is assigned the input TOP's `ViewportTexture` — a live GPU reference with zero copy overhead. UI controls from ContainerUI are adopted directly into the UIRoot container — no SubViewport indirection — so Godot's native input dispatch (mouse, keyboard, focus) works automatically. An overlay system (CanvasLayer at layer 100) supports dropdowns, color pickers, and popup menus above the panel layer. Window configuration (mode, position, monitor, vsync) is only applied when the WindowOUT's own parameters change, NOT when upstream textures update (preventing per-frame window reconfiguration). Multiple WindowOUT instances create multiple independent windows.

> **Architecture note — process_mode:** GNNode sets `process_mode = PROCESS_MODE_DISABLED` during `initialize()` so operators don't run Godot's `_process()` (all cooking is driven by GNCookEngine). However, Godot propagates process_mode to child nodes, so the Window would also become DISABLED — blocking GUI event dispatch entirely (buttons, sliders, etc. stop responding). The fix: WindowOUT explicitly sets `_window.process_mode = Node.PROCESS_MODE_ALWAYS` in `_ensure_window()`. This has zero performance cost — it simply re-enables standard Godot GUI dispatch for the Window subtree.

**Known issue:** Cannot ESC out of fullscreen/borderless mode from the output window. Workaround: change Window Mode back to Windowed from the inspector.

---

## UI — User Interface Operators

Interactive 2D widget operators for building control panels. UI widgets are wired through a **ContainerUI** into WindowOUT's panel port (Input 1). Controls are adopted directly into the Window's VBoxContainer UIRoot—no SubViewport indirection—so Godot's native input dispatch handles mouse, keyboard, and focus automatically.

**Base class:** `GNUiBase` (extends GNNode) — manages `_control_node: Control`. Color: Sky Blue.

Every UI widget automatically exposes a **"state" CHOP output port** (always the last output). State channels (listed per widget below) contain float values updated each cook. Wire this CHOP output to any parameter expression or CHOP-driven node to connect UI interactions to your network. ContainerUI's state port aggregates all connected children's states into a single CHOP stream.

### ButtonUI
A clickable button. Outputs press state (0/1) and cumulative click count as CHOP channels.
- **Parameters:** `text` (STRING), `font_size` (INT, 16), `color` (COLOR)
- **State channels:** `press`, `click_count`

### SliderUI
A horizontal or vertical slider with configurable range.
- **Parameters:** `min` (FLOAT, 0.0), `max` (FLOAT, 1.0), `step` (FLOAT, 0.01), `value` (FLOAT, 0.5), `orientation` (MENU: Horizontal/Vertical)
- **State channels:** `value`

### ToggleUI
An on/off toggle switch (CheckButton).
- **Parameters:** `text` (STRING), `default_state` (TOGGLE, false)
- **State channels:** `state`

### LabelUI
A read-only text label for display purposes.
- **Parameters:** `text` (STRING), `font_size` (INT, 16), `color` (COLOR), `alignment` (MENU: Left/Center/Right)
- **State channels:** none (display only)

### KnobUI
A rotary knob control with custom `_draw()` rendering.
- **Parameters:** `min` (FLOAT, 0.0), `max` (FLOAT, 1.0), `value` (FLOAT, 0.5), `size` (INT, 64), `color` (COLOR)
- **State channels:** `value`, `angle`

### XYPadUI
A 2D XY pad control with custom `_draw()` rendering.
- **Parameters:** `x_min` (FLOAT, 0.0), `x_max` (FLOAT, 1.0), `y_min` (FLOAT, 0.0), `y_max` (FLOAT, 1.0), `size` (INT, 128)
- **State channels:** `x`, `y`

### DropdownUI
A dropdown menu (OptionButton) with configurable items.
- **Parameters:** `items` (STRING, comma-separated), `default_index` (INT, 0)
- **State channels:** `index`

### ContainerUI
A layout container for nesting other UI widgets. Supports multiple layout modes.
- **Parameters:** `layout` (MENU: HBox/VBox/Grid/Flow), `columns` (INT, for grid mode)
- **State channels:** aggregated from all connected child widgets (channels named `<widget_id>:<key>`)

### TextureRectUI
Displays a TOP texture inside PanelTOP. Optional MAT input for shader overlay.
- **Inputs:** `top` (TOP), `mat` (MAT)
- **Parameters:** `stretch_mode` (MENU: 7 modes), `min_size` (VECTOR2I), `expand_mode` (TOGGLE)
- **State channels:** `has_texture`

### ColorRectUI
Colored rectangle. Clickable with optional MAT shader overlay.
- **Inputs:** `mat` (MAT)
- **Parameters:** `color` (COLOR), `min_size` (VECTOR2I)
- **State channels:** `click` (impulse)

### LineEditUI
Single-line text input field.
- **Parameters:** `placeholder` (STRING), `default_text` (STRING), `max_length` (INT), `editable` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `length`, `submitted` (impulse)

### TextEditUI
Multi-line text editor. Optional DAT input for initial content.
- **Inputs:** `dat` (DAT)
- **Parameters:** `placeholder` (STRING), `editable` (TOGGLE), `wrap_mode` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `lines`, `length`

### ProgressBarUI
Progress bar driven by CHOP input. Outputs value and ratio.
- **Inputs:** `chop` (CHOP)
- **Parameters:** `min_val` (FLOAT), `max_val` (FLOAT), `default_val` (FLOAT), `chop_channel` (STRING), `show_percentage` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `value`, `ratio`

### SpinBoxUI
Numeric spin box with increment/decrement buttons.
- **Parameters:** `min_val` (FLOAT), `max_val` (FLOAT), `step` (FLOAT), `default_val` (FLOAT), `prefix` (STRING), `suffix` (STRING), `editable` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `value`

### ColorPickerUI
Color picker button. Opens full color picker dialog. Outputs RGBA as CHOP channels.
- **Parameters:** `default_color` (COLOR), `edit_alpha` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `r`, `g`, `b`, `a`

### RichTextLabelUI
BBCode rich text label. Optional DAT input for content.
- **Inputs:** `dat` (DAT)
- **Parameters:** `text` (STRING), `bbcode` (TOGGLE), `font_size` (INT), `fit_content` (TOGGLE), `scroll_active` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** none (display only)

### ScrollContainerUI
Scrollable container for child UI widgets. Dynamic UI inputs.
- **Parameters:** `h_scroll` (TOGGLE), `v_scroll` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `scroll_h`, `scroll_v`

### TabContainerUI
Tabbed container. Each UI input becomes a tab page. Optional DAT for tab names.
- **Inputs:** `dat` (DAT), dynamic UI inputs
- **Parameters:** `default_tab` (INT), `min_size` (VECTOR2I)
- **State channels:** `tab`

### SplitContainerUI
Splits two UI inputs with a draggable divider.
- **Inputs:** `ui_a` (UI), `ui_b` (UI)
- **Parameters:** `vertical` (TOGGLE), `offset` (INT), `collapsed` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `offset`

### MarginContainerUI
Wraps a single UI widget with configurable margins.
- **Inputs:** `ui` (UI)
- **Parameters:** `left` (INT), `top` (INT), `right` (INT), `bottom` (INT), `min_size` (VECTOR2I)
- **State channels:** none (layout only)

### PanelContainerUI
Styled panel container with background color and rounded corners.
- **Parameters:** `bg_color` (COLOR), `corner_radius` (INT), `padding` (INT), `min_size` (VECTOR2I)
- **State channels:** none (layout only)

### TreeUI
Tree view built from DAT table data with parent/child relationships.
- **Inputs:** `dat` (DAT)
- **Parameters:** `hide_root` (TOGGLE), `hide_folding` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `selected`

### ItemListUI
Selectable item list from DAT data. Optional TOP icon texture.
- **Inputs:** `dat` (DAT), `top` (TOP)
- **Parameters:** `allow_reselect` (TOGGLE), `max_columns` (INT), `icon_size` (INT), `min_size` (VECTOR2I)
- **State channels:** `selected`

### TabBarUI
Tab bar from DAT data (no child content). Outputs selected tab index.
- **Inputs:** `dat` (DAT)
- **Parameters:** `default_tab` (INT), `closable` (TOGGLE), `drag_reorder` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `tab`

### MenuButtonUI
Button with popup menu items from DAT data.
- **Inputs:** `dat` (DAT)
- **Parameters:** `label` (STRING), `min_size` (VECTOR2I)
- **State channels:** `selected`

### CheckBoxUI
Standard checkbox with text label. Unlike ToggleUI (switch style), this is classic checkbox.
- **Parameters:** `label` (STRING), `default_on` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `value`

### TextureButtonUI
Clickable texture button with normal/pressed/hover TOP inputs.
- **Inputs:** `normal` (TOP), `pressed` (TOP), `hover` (TOP)
- **Parameters:** `toggle_mode` (TOGGLE), `stretch` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `press` (impulse), `toggle`

### SeparatorUI
Horizontal or vertical separator line for layout.
- **Parameters:** `vertical` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** none (layout only)

### NinePatchRectUI
Stretchable nine-patch texture display from TOP input.
- **Inputs:** `top` (TOP)
- **Parameters:** `patch_left` (INT), `patch_top` (INT), `patch_right` (INT), `patch_bottom` (INT), `draw_center` (TOGGLE), `min_size` (VECTOR2I)
- **State channels:** `has_texture`

### LinkButtonUI
Clickable text link button with underline options.
- **Parameters:** `text` (STRING), `underline` (MENU: Always/On Hover/Never), `min_size` (VECTOR2I)
- **State channels:** `press` (impulse)

### TextureProgressBarUI
Textured progress bar with TOP layers and CHOP driver.
- **Inputs:** `chop` (CHOP), `under` (TOP), `progress` (TOP), `over` (TOP)
- **Parameters:** `min_val` (FLOAT), `max_val` (FLOAT), `default_val` (FLOAT), `chop_channel` (STRING), `fill_mode` (INT: 0-5), `min_size` (VECTOR2I)
- **State channels:** `value`, `ratio`

---

## Editor Features

### Viewer Panel UI Preview

The viewer panel and on-node inline previews use **output-type dispatch** — the `GNNode` base class detects the actual data type of `cached_output` and selects the appropriate visualization automatically:

| Output Type | Preview Control | Display |
|-------------|----------------|--------|
| `GNTextureData` | TextureRect | Live texture thumbnail |
| `GNChannelData` | Label | Channel name:value pairs |
| `GNGeoData` | Label | Vertex/surface counts |
| `GNTableData` | Label | Header + first 3 rows |
| `GNImageData` | Label | Resolution + format |
| `GNParticleData` | Label | Particle count |
| `GNVolumeData` | Label | Resolution + field name |
| `GNMaterialData` | Label | Material label |

This means **cross-family nodes** automatically get the correct preview. For example:
- RaymarchVOL (VOL family) outputs `GNTextureData` → shows texture thumbnail, not volume stats
- InstancePOP (POP family) outputs `GNGeoData` → shows vertex counts, not particle counts
- AnalyzeVOL (VOL family) outputs `GNChannelData` → shows channel values, not volume stats

COMP, UI, and OUT families override `update_preview_control()` because they display non-data state (`_scene_node`, `_control_node`, sink status).

**Multi-output nodes** (GDScriptSCRIPT Generic template, MultiBufferRenderTOP) preview output port 0 (`cached_output`). To inspect other outputs, wire them into a **Null node** of the matching family and select that Null in the viewer. Every family has a Null pass-through: NullTOP, NullCHOP, NullSOP, NullDAT, NullIMG, NullPOP, NullVOL, NullMAT, NullCOMP.

### Node Palette Keyboard Navigation

The node palette popup supports full keyboard navigation:
- **Up/Down arrows** — navigate between operator entries in the filtered tree
- **Enter** — creates the currently highlighted operator
- **Typing** — filters the tree in real-time by operator name

Navigation wraps around and skips category headers, moving only between leaf (operator) entries.

### Logging & Warning System

GONODES has a 2-layer logging and diagnostics system that is **editor-only** — exported player builds skip all status tracking overhead.

#### Layer 1 — Per-Node Warning / Error Badges

Every operator (`GNNode`) has two transient string properties:

| Property | Badge | Color | Meaning |
|----------|-------|-------|---------|
| `node_warning` | ⚠️  | Yellow | Recoverable issue (e.g. UI fan-out conflict) |
| `node_error` | ✖ | Red | Failure (e.g. expression error, null cook result) |

Both are **cleared automatically** at the start of each cook cycle and only re-set if the problem persists (self-healing). The `GNNodeView` overlay renders the badge in the top-right corner of the node with a tooltip showing the full message.

**Setting status in operators:**

```gdscript
# Inside your _cook() implementation:
node_warning = "Seed unchanged — output is static"
node_error   = "Input image is null"
```

The cook engine also sets `node_error` automatically for:

- Null cook results (`cook returned null`)
- Expression evaluation failures
- Per-component expression errors

#### Layer 2 — Textport (Log Panel)

The collapsible **Textport** at the bottom of the editor displays live log output from `GNLogger`. Toggle it with the **Log** button in the toolbar.

**GNLogger API:**

```gdscript
GNLogger.debug("MyOp", "Verbose detail: %s" % info)
GNLogger.info("MyOp",  "Lifecycle event happened")
GNLogger.warn("MyOp",  "Recoverable issue: %s" % detail)
GNLogger.error("MyOp", "Failure: %s" % err)
```

**Log panel features:**

- 500-entry ring buffer (oldest entries drop automatically)
- Filter buttons: DBG / INF / WRN / ERR (toggle individually)
- Color-coded output (gray, white, yellow, red)
- Clear button to reset all entries
- Each line shows `[LEVEL] category: message`

**`log()` — User Script & Expression Bridge:**

Script operators and expression parameters can send messages to the Textport
via built-in `log()` helpers. The node's ID is used as the log category
automatically.

```gdscript
# In ScriptCHOP / ScriptDAT / ScriptSOP / ScriptIMG:
log("Processing frame %d" % frame)       # INFO level
log_debug("Verbose detail")               # DEBUG level
log_warn("Something looks off")           # WARN level
log_error("Critical failure")             # ERROR level

# In expression parameters (INFO level only):
log("value is " + str(par("scale")))
```

**Configuration:**

```gdscript
GNLogger.enabled = true          # master switch (default: false)
GNLogger.level = GNLogger.Level.DEBUG  # minimum severity
GNLogger.show_frame = true       # include frame number
GNLogger.show_timestamp = false  # include ms timestamp
GNLogger.muted_categories["CookEngine"] = true  # mute a subsystem
```

#### Editor-Only Guard

The cook engine has an `editor_mode` flag (`false` by default). The editor sets it to `true`; the player leaves it `false`. When `editor_mode` is off:

- `node_warning` / `node_error` are never cleared or set
- WindowOUT fan-out detection is skipped
- `GNLogger.enabled` stays `false` (no log output)
- No `GNLogPanel` is instantiated
- No status badge updates occur

This ensures zero logging overhead in exported player builds.

#### WindowOUT Fan-Out Warning

When two `WindowOUT` nodes are connected to the same UI operator, Godot's single-parent rule means only one can display the widget. The editor detects this and:

1. Sets `node_warning` on **both** WindowOUT nodes
2. Logs the conflict via `GNLogger.warn()`
3. The warning self-clears next frame if the conflict is resolved

---
## Quick Reference

| Family | Count | Operators |
|--------|-------|-----------|
| **TOP** | 71 | Noise, Ramp, Circle, Rectangle, Constant, Text, MovieFileIn, CustomShader, Level, Blur, Transform, HSVAdjust, Edge, Threshold, Flip, Tile, Crop, Feedback, Resolution, Render, MultiBufferRender, Composite, Cross, Displace, Lookup, ColorMap, Remap, Layout, ChromaKey, Pattern, Triangle, SVG, Analyze, Mono, Sharpen, NormalMap, Depth, ChannelMix, Convolution, DilateErode, LensDistort, LumaBlur, Slope, CornerPin, Projection, Fit, Cache, TimeMachine, Null, Switch, Matte, Premultiply, Posterize, RadialBlur, AntiAlias, Palette, CHOPtoTOP, OpticalFlow, Glue, Emboss, CompositorEffect, GeometryBuffer, PostProcess, Panel, ComputeShader, Snapshot, Deform, Reorder, Fluid2D, ReactionDiffusion, PointCloudRender |
*(Note: 17 additional TOPs via extensions — see Extension Operators below)* |
| **CHOP** | 74 | LFO, Wave, Noise, Constant, Pattern, Timer, Ramp, Clock, Expression, Math, Filter, Lag, Limit, Trigger, Speed, Count, Hold, Select, Smooth, Spring, Delay, Envelope, Analyze, Lookup, Stretch, Resample, Trim, Extend, Logic, Merge, Cross, Interpolate, Join, Composite, Copy, Shuffle, Split, Fan, Delete, Null, Switch, Rename, DATtoCHOP, Physics, Script, OscIn, MidiIn, AudioIn, AudioSpectrum, AudioFileIn, AudioBand, KeyboardIn, MouseIn, Gamepad, Parameter, Trail, SOPtoCHOP, TOPtoCHOP, Beat, IK, Warp, Slope, AudioDynamics, Feedback, Blend, Perform, Transform, Keyframe, Sequence, Clip, Channel, Object, Skeleton, TabletIn |
| **DAT** | 37 | Constant, Text, Info, OscIn, MidiIn, Select, Sort, Transpose, Evaluate, Merge, Null, Switch, CHOPtoDAT, Script, Callback, FileIn, JSON, Web, WebServer, WebSocket, Substitute, Insert, Delete, FIFO, SOPtoDAT, TOPtoDAT, OPFind, Table, Network, XML, Error, Folder, MultiTouchIn, Serial, DMX, RenderPick, PanelExecute |
| **SOP** | 74 | Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Tube, Font, Transform, Noise, Subdivide, Wireframe, Normal, Reverse, Peak, Sort, Facet, Delete, Point, Attribute, Clip, Mirror, Extrude, Merge, Copy, Scatter, Boolean, Sweep, Skin, Null, Switch, Script, Bend, Twist, Taper, Trail, TrailRibbon, UVProject, Divide, LSystem, Metaball, IsoSurface, Particle, Magnet, Carve, PolyReduce, CHOPtoSOP, DATtoSOP, TOPtoSOP, Fuse, Ray, Cap, Lattice, PolyLoft, Mountain, Heightfield, Select, FileIn, FileOut, Group, Primitive, Blend, Spring, Smooth, PolyBevel, Remesh, ObjectMerge, Texture, PolyBridge, PolyPatch, PolySpline, PolyStitch, VoronoiShatter |
| **COMP** | 20 | Geometry, Camera, Light, Merge, RigidBody, StaticBody, SoftBody, Area, Joint, Null, Switch, Environment, GenericScript, Instance, Replicator, Animation, SubNetwork, InTunnel, OutTunnel, Engines |
| **MAT** | 10 | PBR, Shader, Constant, Wireframe, PointSprite, Depth, NormalMap, Line, FluidSurface, Null |
| **IMG** | 13 | Noise, Checkerboard, ImageFileIn, ImageSequence, Webcam, Blur, EdgeDetect, PixelSort, Script, ImgToTOP, TOPtoIMG, ScreenGrab, Null |
| **OUT** | 9 | Window, TextureSave, ImageSave, TableSave, Movie, FFmpeg, AudioDevice, Record, OscOut |
| **UI** | 31 | Button, Slider, Toggle, Label, Knob, XYPad, Dropdown, Container, TextureRect, ColorRect, LineEdit, TextEdit, ProgressBar, SpinBox, ColorPicker, RichTextLabel, ScrollContainer, TabContainer, SplitContainer, MarginContainer, PanelContainer, Tree, ItemList, TabBar, MenuButton, CheckBox, TextureButton, Separator, NinePatchRect, LinkButton, TextureProgressBar |
| **POP** | 11 | Source, Force, Turbulence, Collision, Attract, Limit, Advect, Boids, Instance, Render, Null — *SSBO-based compute pipeline* |
| **VOL** | 13 | Noise, Fluid, Advect, Analyze, Pyro, Merge, Math, Null, Switch, Raymarch, MarchingCubes, GPUMarchingCubes, SOPtoVOL — *FluidVOL includes vorticity + obstacles; GPUMarchingCubes 10–100× faster via compute shader* |
| **Generic** | 1 | Dot |
| **Total** | **362** | |

### Extension Operators (not included in count above)

| Extension | Operators | Description |
|-----------|-----------|-------------|
| **gn_ext_shadertoy** | ShadertoyTOP | Runtime Shadertoy GLSL translation, URL fetch, 10 presets |
| **gn_ext_isf** | ISFTOP | ISF v2 shader support, multi-pass, JSON-driven params, 10 presets |
| **gn_ext_native** | 69 operators | C++ GDExtension acceleration (see below) |
| **gn_ext_spout** | SpoutInTOP, SpoutOutTOP | Windows-only Spout2 texture sharing with other apps |
| **gn_ext_syphon** | SyphonInTOP, SyphonOutTOP | macOS-only Syphon texture sharing via IOSurface |
| **gn_ext_video_capture** | VideoDeviceInIMG | Cross-platform webcam/capture device input (MF/AVFoundation/V4L2) |
| **gn_ext_midi** | RtMidiInCHOP, RtMidiOutCHOP | Cross-platform MIDI I/O via RtMidi (notes, CC, pitch bend) |
| **gn_ext_gpu_encode** | MovieFileOutTOP | Hardware GPU video encoding to H.264 MP4 (MF/VideoToolbox) |
| **gn_ext_mapper** | QuadMapTOP, BezierMapTOP, GridWarpTOP, EdgeBlendTOP, ProjectionMaskTOP, StonerTOP, ProjectorBlendTOP | GPU projection mapping — bezier/quad/grid warp, edge blend, masking |
| **gn_ext_hap** | HapInTOP, HapOUT | GPU-direct HAP video codec — DXT-compressed frames upload to GPU with zero CPU decode. Supports HAP, HAP Alpha, HAP Q variants in QuickTime MOV containers |

> **Note:** SDF operators (26 total — 10 primitives, 5 booleans, 8 domain modifiers, 2 materials, 1 renderer) were promoted from `gn_ext_sdf` to **core** as the 12th family type. See the SDF section above.

---

## Native Acceleration Extension (Optional)

The `gn_ext_native` extension provides C++ GDExtension-accelerated variants of 69 CPU-heavy operators across 6 build phases and 6 families. These appear as separate operators in the palette under a "Native" section when the C++ binaries are compiled. Each native operator has an identical parameter interface to its GDScript counterpart and includes a pure-GDScript fallback for when the C++ library is unavailable.

### Summary by Family

| Family | Count | Key Algorithms |
|--------|-------|---------------|
| SOP | 37 | Marching cubes, L-system turtle, quadric error decimation, Möller-Trumbore raycasting, spatial-hash welding, FFD lattice, damped spring, mesh deformers (bend/twist/taper/extrude), parametric lofting/skinning |
| CHOP | 18 | Biquad Butterworth IIR (LP/HP/BP), FFT audio spectrum, time-warp remap, physics simulation, expression evaluation, signal interpolation |
| IMG | 5 | Gaussian/box blur, Sobel/Prewitt edge detection, pixel sorting, Perlin noise, checkerboard |
| TOP | 4 | Horn-Schunck optical flow, statistical analysis, CHOP→texture bridge, particle state readback |
| VOL | 3 | Marching cubes isosurface extraction, CHOP→volume bridge, volume statistics |
| POP | 2 | GPU particle instancing, particle state rendering |
| **Total** | **69** | |

**Build status:** Windows x86_64 binary compiled and active (`bin/win64/libgn_native.windows.template_release.x86_64.dll`). Linux/macOS builds require running `scons platform=linux|macos target=template_release` on those platforms. The extension registry auto-detects the C++ classes via `ClassDB.class_exists()` and falls back to pure GDScript if the library is missing.

---

## Shadertoy Extension (gn_ext_shadertoy)

The `gn_ext_shadertoy` extension provides a single **ShadertoyTOP** node that runs any Shadertoy GLSL shader inside GONODES. No pre-baked operators — write, paste, or fetch any `void mainImage(out vec4, in vec2)` shader and it compiles immediately through the runtime Shadertoy-to-Godot translation pipeline.

### ShadertoyTOP

| Family | Inputs | Outputs |
|--------|--------|---------|
| TOP | 0..4 (auto-wired from iChannel usage) | 1 texture |

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `time_dependent` | Bool | Re-cook every frame (enable for shaders using `iTime`) |
| `fetch` | Bool (pulse) | Download shader from `shadertoy_url` via the public API |
| `resolution` | Vector2i | Output resolution (generators only) |
| `shadertoy_url` | String | Shadertoy page URL or bare shader ID (e.g. `Ms2SD1`) |
| `shadertoy_api_key` | String | Personal Shadertoy API key (required for fetch — see below) |
| `shadertoy_code` | String | Raw Shadertoy GLSL (`void mainImage` format) |
| *dynamic* | various | Auto-created from `uniform` declarations on compile |

**Translation pipeline:** `ShadertoyTranslator` maps Shadertoy built-ins (`iTime` → `TIME`, `iResolution` → `gn_resolution`, `iMouse` → `gn_mouse`, `iChannel0..3` → TOP inputs, `fragCoord` → `UV * gn_resolution`, `fragColor` → `COLOR`). Custom `uniform` declarations become auto-generated inspector parameters.

**URL Fetch & API key:** The fetch button downloads a shader's Image pass GLSL from the Shadertoy public API. This requires a free personal API key from [shadertoy.com/myapps](https://www.shadertoy.com/myapps) (you must publish at least one shader first). Without a valid key, fetch returns a 403 error.

**Presets:** 10 factory presets (5 generators: plasma, creation, star nest, lava lamp, voronoi; 5 effects: CRT, chromatic aberration, pixelate, film grain, halftone).

**Help patches:** 3 examples — generator, FX chain, URL fetch workflow.

---

## ISF Extension (gn_ext_isf)

The `gn_ext_isf` extension provides a single **ISFTOP** node that runs [ISF v2](https://docs.vidvox.net/freeboard/) (Interactive Shader Format) shaders inside GONODES. Parameters, input ports, and multi-pass targets are auto-generated from the JSON metadata header.

### ISFTOP

| Family | Inputs | Outputs |
|--------|--------|---------|
| TOP | 0..n (image inputs from JSON INPUTS) | 1 texture |

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `time_dependent` | Bool | Re-cook every frame (enable for shaders using `TIME`) |
| `isf_file` | File | Load an external `.fs` / `.isf` / `.frag` file into the editor |
| `resolution` | Vector2i | Output resolution (generators only) |
| `isf_code` | String | Live ISF source — edit inline or open the full code editor |
| *dynamic* | various | Auto-created from JSON `INPUTS` on compile |

**Translation pipeline:** `ISFTranslator` maps ISF built-ins (`isf_FragNormCoord` → `UV`, `gl_FragColor` → `COLOR`, `TIME` → Godot `TIME`, `RENDERSIZE` → `isf_rendersize`, `IMG_PIXEL`/`IMG_NORM_PIXEL`/`IMG_THIS_PIXEL` → `texture()` calls). ISF input types (`float`, `bool`, `long`, `point2D`, `color`, `event`, `image`) become inspector parameters or TOP input ports.

**Multi-pass:** ISF's `PASSES` array is fully supported. Each pass gets its own SubViewport. `PERSISTENT` enables feedback-loop buffers. Per-pass `WIDTH`/`HEIGHT` expressions support `$WIDTH`, `$HEIGHT` variables.

**Presets:** 10 factory presets (5 generators: color bars, sine warp, kaleidoscope, gradient map, Lissajous; 5 effects: kaleidoscope FX, glitch, mirror, edge glow, cross-hatch).

**Help patches:** 2 examples — generator, FX chain.

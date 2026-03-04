# GONODES — Operator Reference

> **78 operators** across 6 categories: TOP, CHOP, DAT, SOP, COMP, and Output.

---

## Table of Contents

- [TOP — Texture Operators](#top--texture-operators)
- [CHOP — Channel Operators](#chop--channel-operators)
- [DAT — Data Operators](#dat--data-operators)
- [SOP — Surface Operators](#sop--surface-operators)
- [COMP — Component Operators](#comp--component-operators)
- [Output Operators](#output-operators)

---

## TOP — Texture Operators

TOPs process 2D textures on the GPU. Each TOP inherits from `GNTopBase`, which provides the shared viewport infrastructure: `_viewport` (SubViewport), `_material` (ShaderMaterial), `_canvas` (ColorRect/TextureRect), and `_cached_tex_data` (GNTextureData). Textures are passed between nodes as zero-copy GPU references (ViewportTexture). All texture processing happens entirely on the GPU — no CPU readback. SubViewports render exactly once per cook cycle via `UPDATE_ONCE` (not every frame).

**Total: 27 operators** — 9 generators, 13 filters, 3 combiners, 2 utility.

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

**How it works:** Renders a fullscreen quad with a noise shader. The shader implements 4 noise algorithms selectable via uniform. Time-dependent — animates automatically when `time_offset` is driven by expressions.

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
| seek | Float | -1.0 | -1.0–∞ | Seek to time in seconds (-1 = disabled) |
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
| index | Int | -1 | -1–∞ | Manual frame index override (-1 = auto time-based) |
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

## CHOP — Channel Operators

CHOPs process named float arrays (channels). Each channel is a `PackedFloat32Array` with a name (e.g., "tx", "ty", "tz", "out"). Single-sample CHOPs act as real-time control signals. Multi-sample CHOPs carry waveform data, audio, or patterns.

All CHOP data flows as `GNChannelData` — a lightweight RefCounted wrapper around a `Dictionary` of named float arrays.

**Total: 20 operators** — 5 generators, 9 filters, 3 combiners, 3 utility.

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

## DAT — Data Operators

DATs process tables and text. The output type is `GNTableData`, which operates in either **table mode** (2D grid of strings with headers) or **text mode** (plain string). DATs are useful for configuration, data lookups, text processing, and cross-family data conversion.

**Total: 13 operators** — 3 generators, 5 filters, 1 combiner, 2 utility, 2 bridges.

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

## SOP — Surface Operators

SOPs produce and manipulate 3D geometry. The output type is `GNGeoData`, which wraps Godot's native `ArrayMesh`. SOPs leverage Godot's built-in mesh primitives (`BoxMesh`, `SphereMesh`, etc.) and `SurfaceTool` for procedural generation. Geometry flows through SOP chains and ultimately reaches a GeometryCOMP for 3D scene placement.

**Total: 14 operators** — 7 generators, 5 filters, 1 combiner, 1 utility (+ Switch).

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

## COMP — Component Operators

COMPs are 3D scene components. Unlike other families, COMPs don't produce `GNData` output — instead, they create and manage Godot `Node3D` instances (MeshInstance3D, Camera3D, Light3D) that are adopted into a RenderTOP's isolated 3D SubViewport for rendering.

COMPs are the bridge between procedural data (SOP geometry, TOP textures) and Godot's 3D rendering engine.

**Total: 8 operators.**

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

Wraps a `RigidBody3D` with `CollisionShape3D` for dynamic physics simulation. Auto-generates collision shapes from SOP mesh input.

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
| visible | Bool | true | — | Show/hide mesh |
| albedo_color | Color | White | — | Fallback material color |
| metallic | Float | 0.0 | 0.0–1.0 | Fallback metallic |
| roughness | Float | 0.5 | 0.0–1.0 | Fallback roughness |
| cast_shadow | Enum | On | Off, On, DoubleSided, ShadowsOnly | Shadow casting mode |

**Inputs:** `geo_in` (SOP), `mat_in` (MAT, optional), `force_in` (CHOP, optional — channels: `force_x/y/z`, `impulse_x/y/z`, `torque_x/y/z`).

**How it works:** Creates a `RigidBody3D` → `CollisionShape3D` + `MeshInstance3D` hierarchy. In Dynamic mode, Godot's physics engine (Jolt) controls the transform. Transform params are only applied for Kinematic/Static modes. Collision shape is auto-generated from the mesh. CHOP force input is applied every cook (Dynamic mode only).

---

#### StaticBodyCOMP

Wraps a `StaticBody3D` — an immovable collider for floors, walls, and obstacles.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Position |
| rx, ry, rz | Float | 0.0 | -360–360 | Rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Scale |
| friction | Float | 1.0 | 0.0–2.0 | Surface friction |
| bounce | Float | 0.0 | 0.0–1.0 | Restitution |
| collision_shape | Enum | Trimesh | Convex, Box, Sphere, Capsule, Trimesh | Collision shape type |
| visible | Bool | true | — | Show/hide mesh |
| albedo_color | Color | White | — | Fallback material color |
| cast_shadow | Enum | On | Off, On, DoubleSided, ShadowsOnly | Shadow casting |

**Inputs:** `geo_in` (SOP), `mat_in` (MAT, optional).

**How it works:** Creates a `StaticBody3D` → `CollisionShape3D` + `MeshInstance3D` hierarchy. Defaults to Trimesh collision (accurate for complex static geometry). Transform is applied every cook.

---

#### SoftBodyCOMP

Wraps a `SoftBody3D` for deformable mesh physics (cloth, jelly, rubber).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | — | Position |
| rx, ry, rz | Float | 0.0 | -360–360 | Rotation |
| sx, sy, sz | Float | 1.0 | 0.001–100.0 | Scale |
| simulation_precision | Int | 5 | 1–20 | Solver iterations |
| total_mass | Float | 1.0 | 0.01–100.0 | Total body mass |
| linear_stiffness | Float | 0.5 | 0.0–1.0 | Spring stiffness |
| pressure_coefficient | Float | 0.0 | -100.0–100.0 | Internal pressure |
| damping_coefficient | Float | 0.01 | 0.0–1.0 | Motion damping |
| drag_coefficient | Float | 0.0 | 0.0–1.0 | Air drag |
| visible | Bool | true | — | Show/hide |
| albedo_color | Color | White | — | Fallback color |

**Inputs:** `geo_in` (SOP), `mat_in` (MAT, optional).

**How it works:** Creates a `SoftBody3D`. The mesh is assigned **once** (SoftBody3D doesn't support live mesh swapping). Physics parameters are updated every cook. High `linear_stiffness` = rigid cloth; high `pressure_coefficient` = inflated balloon.

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

## Output Operators

Output operators are terminal/sink nodes that display results. They have inputs but no data outputs.

---

#### WindowTOP

Displays a TOP texture in a standalone OS window. Essential for VJ output — each WindowTOP creates a separate window that can be placed on any connected monitor.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| title | String | "GONODES Output" | — | Window title |
| monitor | Int | 0 | 0–8 | Target display index |
| window_mode | Enum | Windowed | Windowed, Fullscreen, Borderless | Window mode |
| resolution | Vector2i | 1920×1080 | — | Window resolution |
| position | Vector2i | (-1, -1) | — | Window position (-1,-1 = auto center) |
| always_on_top | Bool | false | — | Keep window above others |
| vsync | Bool | true | — | V-sync |

**Input:** `in` (TOP — texture to display).

**How it works:** Creates a Godot `Window` node with a `TextureRect` inside. The TextureRect is assigned the input TOP's `ViewportTexture` — a live GPU reference with zero copy overhead. Window configuration (mode, position, monitor, vsync) is only applied when the WindowTOP's own parameters change, NOT when upstream textures update (preventing per-frame window reconfiguration). Multiple WindowTOP instances create multiple independent windows.

**Known issue:** Cannot ESC out of fullscreen/borderless mode from the output window. Workaround: change Window Mode back to Windowed from the inspector.

---

## Quick Reference

| Family | Count | Operators |
|--------|-------|-----------|
| **TOP** | 25 | Noise, Ramp, Circle, Rectangle, Constant, Text, CustomShader, Level, Blur, Transform, HSVAdjust, Edge, Threshold, Flip, Tile, Crop, Feedback, Resolution, Render, Composite, Cross, Displace, Lookup, Null, Switch |
| **CHOP** | 21 | LFO, Wave, Noise, Constant, Pattern, Timer, Filter, Lag, Limit, Trigger, Hold, Speed, Count, Select, Math, Merge, Cross, Logic, Null, Switch, Physics (+DATtoCHOP bridge) |
| **DAT** | 13 | Constant, Text, Info, OscIn, Select, Sort, Transpose, Evaluate, Merge, Null, Switch, CHOPtoDAT, DATtoCHOP |
| **SOP** | 14 | Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Transform, Noise, Subdivide, Wireframe, Merge, Null, Switch |
| **COMP** | 8 | Geometry, Camera, Light, RigidBody, StaticBody, SoftBody, Area, Joint |
| **Output** | 1 | Window |
| **Total** | **82** | |

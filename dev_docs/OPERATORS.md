# GONODES â€” Operator Reference (Static Snapshot)

> **âš ï¸ This is a static snapshot and may be outdated.** The live operator reference is auto-generated in the in-editor Help window (F1 â†’ Operators Reference) from actual operator metadata.  
> **Audience:** Contributors needing implementation details ("How it works" per operator).  
> **Current operator count:** 256 operators across 9 families (this snapshot documents 131).

> **131 operators** across 9 categories: TOP, IMG, CHOP, DAT, SOP, COMP, MAT, OUT, and native extensions.

---

## Table of Contents

- [TOP â€” Texture Operators](#top--texture-operators)
- [IMG â€” Image Operators](#img--image-operators)
- [CHOP â€” Channel Operators](#chop--channel-operators)
- [DAT â€” Data Operators](#dat--data-operators)
- [SOP â€” Surface Operators](#sop--surface-operators)
- [COMP â€” Component Operators](#comp--component-operators)
- [MAT â€” Material Operators](#mat--material-operators)
- [Output Operators](#output-operators)

> **Help example patches:** Every operator has 1â€“2 `.gnpatch` example files accessible via the `?` help button on each node. See `addons/gonodes/help/<family>/` for the full set (131 patches).

---

## TOP â€” Texture Operators

TOPs process 2D textures on the GPU. Each TOP inherits from `GNTopBase`, which provides the shared viewport infrastructure: `_viewport` (SubViewport), `_material` (ShaderMaterial), `_canvas` (ColorRect/TextureRect), and `_cached_tex_data` (GNTextureData). Textures are passed between nodes as zero-copy GPU references (ViewportTexture). All texture processing happens entirely on the GPU â€” no CPU readback. SubViewports render exactly once per cook cycle via `UPDATE_ONCE` (not every frame).

**Total: 50 operators** â€” 12 generators, 26 filters, 7 combiners, 3 temporal/buffer, 2 utility.

### Generators

These TOPs create textures from scratch with no input required.

---

#### NoiseTOP

Procedural noise texture generator. GPU-rendered via shader.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| noise_type | Enum | Simplex | Simplex, Perlin, Voronoi, White | Noise algorithm |
| scale | Float | 4.0 | 0.1â€“100.0 | Noise frequency/zoom |
| offset | Vector2 | (0, 0) | â€” | Spatial offset |
| time_offset | Float | 0.0 | â€” | Z-axis offset for animation |
| seed | Int | 0 | 0â€“99999 | Random seed |
| monochrome | Bool | true | â€” | Grayscale or RGB noise |

**How it works:** Renders a fullscreen quad with a noise shader. The shader implements 4 noise algorithms selectable via uniform. Time-dependent â€” animates automatically when `time_offset` is driven by expressions.

---

#### RampTOP

Gradient ramp generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| type | Enum | Horizontal | Horizontal, Vertical, Radial, Circular | Gradient direction |
| color_a | Color | Black | â€” | Start color |
| color_b | Color | White | â€” | End color |
| center | Vector2 | (0.5, 0.5) | â€” | Center point (for radial/circular) |
| phase | Float | 0.0 | â€” | Phase offset |
| repeat | Bool | false | â€” | Repeat gradient |

**How it works:** Shader computes gradient value based on UV coordinates and selected type, then interpolates between the two colors. Radial mode uses distance from center. Circular mode uses angle.

---

#### CircleTOP

Circle or ring shape via signed distance field.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| fill_color | Color | White | â€” | Shape fill color |
| bg_color | Color | Black | â€” | Background color |
| center | Vector2 | (0.5, 0.5) | â€” | Circle center in UV space |
| radius | Float | 0.4 | 0.0â€“1.0 | Circle radius |
| border_width | Float | 0.0 | 0.0â€“0.5 | Ring border width (0 = filled) |
| softness | Float | 0.005 | 0.0â€“0.1 | Edge antialiasing |

**How it works:** SDF shader computes distance from center, applies smoothstep for edge softness. Border width > 0 creates a ring by subtracting an inner circle.

---

#### RectangleTOP

Rectangle or rounded rectangle via signed distance field.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| fill_color | Color | White | â€” | Shape fill color |
| bg_color | Color | Black | â€” | Background color |
| center | Vector2 | (0.5, 0.5) | â€” | Rectangle center |
| size | Vector2 | (0.6, 0.4) | â€” | Width and height |
| corner_radius | Float | 0.0 | 0.0â€“0.5 | Rounded corners |
| border_width | Float | 0.0 | 0.0â€“0.5 | Border only mode |
| softness | Float | 0.005 | 0.0â€“0.1 | Edge antialiasing |

**How it works:** SDF shader computes distance to a rounded rectangle. Same fill/border/softness logic as CircleTOP.

---

#### ConstantTOP

Solid color texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| color | Color | Black | â€” | Fill color |
| alpha | Float | 1.0 | 0.0â€“1.0 | Alpha override |

**How it works:** No shader needed â€” uses a `ColorRect` directly in the SubViewport.

---

#### TextTOP

Renders text to a texture. Supports custom font loading from project resources.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| text | String | "Hello" | â€” | Text content |
| resolution | Vector2i | 512Ã—256 | â€” | Output resolution |
| font_file | File | (none) | â€” | Font file path (TTF, OTF, WOFF, WOFF2, .tres/.res). Leave empty for default font. |
| font_size | Int | 48 | 8â€“256 | Font size in pixels |
| font_color | Color | White | â€” | Text color |
| bg_color | Color | Black | â€” | Background color |
| align_h | Enum | Center | Left, Center, Right | Horizontal alignment |
| align_v | Enum | Center | Top, Center, Bottom | Vertical alignment |
| word_wrap | Bool | true | â€” | Wrap text at edges |

**How it works:** Uses Godot's `Label` node inside a SubViewport. The Label handles text layout, wrapping, and alignment natively. Custom fonts are loaded via `ResourceLoader` and applied with `add_theme_font_override()`.

---

#### ImageFileInTOP

Loads an image or texture resource from the project and outputs it as a TOP texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | (none) | â€” | Image/texture path (PNG, JPG, WebP, BMP, TGA, SVG, HDR, EXR, .tres/.res) |
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| fit_mode | Enum | Keep Aspect Centered | Stretch, Keep Aspect, Keep Aspect Centered, Keep Aspect Covered, Tile | How the image fits the output |
| bg_color | Color | Black | â€” | Background color behind transparent or non-covering images |
| filter | Bool | true | â€” | Bilinear filtering (on) or nearest-neighbor (off) |

**How it works:** Loads any Godot-importable image format via `ResourceLoader`. The loaded `Texture2D` is displayed in a `TextureRect` inside a SubViewport. Supports all Godot stretch modes. Non-texture `Image` resources are automatically converted to `ImageTexture`.

---

#### MovieFileInTOP

Plays a video file as a live texture stream. Similar to TouchDesigner's Movie File In TOP.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | (none) | â€” | Video file path (.ogv Theora format) |
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| play | Bool | true | â€” | Play / pause |
| loop | Bool | true | â€” | Loop when finished |
| speed | Float | 1.0 | 0.0â€“4.0 | Playback speed multiplier |
| seek | Float | -1.0 | -1.0â€“âˆž | Seek to time in seconds (-1 = disabled) |
| bg_color | Color | Black | â€” | Background color when no video loaded |

**How it works:** Uses Godot's native `VideoStreamPlayer` inside a SubViewport. Supports Theora (.ogv) format out of the box. The video player renders frames directly as a Control filling the viewport. Additional codecs can be added via GDExtensions.

**Codec notes:**
- **Theora (.ogv):** Built-in. CPU-decoded. No alpha channel support in Godot's decoder.
- **H.264/VP8/VP9:** Available via community `godot-videodecoder` GDExtension (FFmpeg-based). No alpha.
- **HAP / HAP Alpha / HAP Q:** Not yet supported. HAP is a VJ-standard codec that stores S3TC/DXT-compressed frames, uploaded directly to the GPU with no CPU decode â€” ideal for real-time performance. Requires a custom GDExtension wrapping the [HAP library](https://github.com/Vidvox/hap). See roadmap.
- **Image sequences:** For alpha-channel video content, use numbered PNG/WebP frame sequences with the ImageSequenceTOP operator.

---

#### ImageSequenceTOP

Plays a numbered image sequence as animated texture frames. Supports PNG, WebP, JPG, and other Godot-importable formats.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| file | File | (none) | â€” | Path to ANY frame in the sequence (auto-discovers siblings) |
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution (auto-set from first frame) |
| play | Bool | true | â€” | Play / pause |
| speed | Float | 1.0 | 0.01â€“10.0 | Playback speed multiplier |
| index | Int | -1 | -1â€“âˆž | Manual frame index override (-1 = auto time-based) |
| loop_mode | Enum | Loop | â€” | Loop, Hold First, Hold Last, Ping-Pong |
| fit_mode | Enum | Keep Aspect Centered | â€” | Stretch, Keep Aspect, Centered, Covered |
| bg_color | Color | Black | â€” | Background behind transparent/non-covering frames |
| preload_all | Bool | false | â€” | Load all frames at startup (faster playback, more RAM) |

**How it works:** Given any frame file (e.g., `render_0042.png`), the operator parses the filename to find the prefix and numbering pattern, then scans the directory for all matching files. Frames are lazy-loaded and cached on demand (or preloaded if the toggle is on). Supports expression-driven `index` for precise sequencing. The ping-pong mode reverses direction at sequence boundaries.

**Naming convention:** Files must have a consistent prefix followed by digits: `myprefix0001.png`, `myprefix0002.png`, etc. Zero-padding width is flexible. Sorting is lexicographic (works correctly for zero-padded names).

---

#### CustomShaderTOP

User-editable GPU shader with live recompilation.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| shader_code | String | *(template)* | â€” | Full `shader_type canvas_item;` shader |
| float_aâ€“float_d | Float | 0.0 | â€” | 4 user float uniforms (`gn_float0`â€“`gn_float3`) |
| color_a | Color | White | â€” | User color uniform (`gn_color0`) |
| color_b | Color | Black | â€” | User color uniform (`gn_color1`) |

**Inputs:** Up to 4 texture inputs available as `gn_tex0`â€“`gn_tex3` in the shader.

---

#### ComputeShaderTOP

GPU compute shader (GLSL 450) with storage image output via Godot's RenderingDevice API.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution (generator mode; inherited from input in filter mode) |
| shader_code | String | *(template)* | â€” | GLSL 450 compute shader source |
| time_dependent | Bool | true | â€” | Re-cook every frame |
| cook_once | Bool | false | â€” | Pulse: force a single cook |
| *(dynamic)* | Float/Int | *(from shader)* | â€” | Push constant fields become inspector params |

**Binding layout:**
- `set 0, binding 0` â€” `image2D gn_output` (rgba8 storage, write)
- `set 1, binding N` â€” `sampler2D gn_tex<N>` (input textures, read)
- `push_constant` â€” `PushConstants` struct with auto-bound `gn_time`, `gn_frame`, `gn_res_x`, `gn_res_y`; additional `float`/`int` fields become inspector parameters

**Inputs:** Up to 8 texture inputs via `sampler2D gn_tex<N>` declarations (auto-detected).

**Built-in uniforms:** `gn_resolution` (vec2), Godot's built-in `TIME`.

**How it works:** User provides a complete `shader_type canvas_item;` shader string. The operator compiles it into a `Shader` resource and applies it. On compilation failure, the last working shader is kept. Recompilation only happens when the code text changes. Time-dependent â€” `TIME` uniform updates automatically.

---

#### PatternTOP

Procedural pattern generator: stripes, checkerboard, concentric circles, grids, and dots.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| type | Enum | Stripes | Stripes, Checkerboard, Concentric, Grid, Dots | Pattern type |
| frequency | Float | 8.0 | 0.1â€“100.0 | Pattern repetition frequency |
| duty_cycle | Float | 0.5 | 0.0â€“1.0 | Width ratio of primary shape |
| color_a | Color | White | â€” | Primary colour |
| color_b | Color | Black | â€” | Secondary / background colour |
| rotation | Float | 0.0 | â€” | Rotation in radians |
| softness | Float | 0.02 | 0.0â€“0.2 | Edge anti-aliasing |

---

#### TriangleTOP

SDF 2D primitives: triangle, line, pentagon.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| shape | Enum | Triangle | Triangle, Line, Pentagon | Shape type |
| size | Float | 0.4 | 0.01â€“0.5 | Shape radius in UV space |
| fill_color | Color | White | â€” | Shape interior colour |
| bg_color | Color | Black | â€” | Background colour |
| border_width | Float | 0.02 | 0.0â€“0.1 | Border thickness (0 = none) |
| border_color | Color | White | â€” | Border colour |
| rotation | Float | 0.0 | â€” | Shape rotation in radians |
| softness | Float | 0.005 | 0.0â€“0.05 | Edge anti-aliasing |

---

#### SVGTOP

Render SVG vector graphics to a texture at arbitrary resolution.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| svg_path | String | *(empty)* | â€” | Path to .svg file (res:// or user://) |

**How it works:** Loads and rasterises the SVG via Godot's Image loader. Re-rasterises only when path or resolution changes. No shader â€” pure CPU rasterisation.

---

### Filters

These TOPs take one texture input and modify it.

---

#### LevelTOP

Brightness, contrast, gamma, and invert adjustments.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| brightness | Float | 1.0 | 0.0â€“4.0 | Brightness multiplier |
| contrast | Float | 1.0 | 0.0â€“4.0 | Contrast amount |
| gamma | Float | 1.0 | 0.01â€“4.0 | Gamma correction |
| invert | Bool | false | â€” | Invert colors |
| opacity | Float | 1.0 | 0.0â€“1.0 | Output opacity |

**How it works:** Shader applies `color = ((color * brightness) - 0.5) * contrast + 0.5`, then `pow(color, 1.0/gamma)`, then optional invert, then alpha multiply.

---

#### BlurTOP

Gaussian or box blur.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| size | Float | 5.0 | 0.0â€“100.0 | Blur radius |
| quality | Int | 4 | 1â€“8 | Sample count per direction |
| method | Enum | Gaussian | Gaussian, Box | Blur algorithm |

**How it works:** Two-pass separable blur â€” horizontal pass into an intermediate SubViewport, then vertical pass into the output SubViewport. Each pass samples multiple texels along one axis weighted by a Gaussian (or uniform for box). Two shader materials, two viewports.

---

#### TransformTOP

2D translate, rotate, and scale.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| translate | Vector2 | (0, 0) | â€” | UV translation |
| rotate | Float | 0.0 | â€” | Rotation in radians |
| scale | Vector2 | (1.0, 1.0) | â€” | UV scale |
| pivot | Vector2 | (0.5, 0.5) | â€” | Transform pivot point |
| extend | Enum | Clamp | Clamp, Repeat, Mirror, Zero | Edge extension mode |

**How it works:** Shader builds a 2D transform matrix, applies it to UV coordinates, and samples the input. Extend mode controls what happens at UV boundaries.

---

#### HSVAdjustTOP

Hue, saturation, and value (brightness) adjustments.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| hue_offset | Float | 0.0 | -1.0â€“1.0 | Hue rotation (wraps) |
| saturation | Float | 1.0 | 0.0â€“4.0 | Saturation multiplier (0 = grayscale) |
| value | Float | 1.0 | 0.0â€“4.0 | Value/brightness multiplier |

**How it works:** Shader converts RGB to HSV, applies offsets/multipliers, converts back to RGB.

---

#### EdgeTOP

Sobel edge detection.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0.0â€“10.0 | Edge strength multiplier |
| grayscale | Bool | true | â€” | Output grayscale or colored edges |

**How it works:** Convolution with Sobel kernels (horizontal and vertical), combined as `sqrt(gxÂ² + gyÂ²)`. Computes on luminance if grayscale, or per-channel if colored.

---

#### ThresholdTOP

Binary black/white based on luminance threshold.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | 0.0â€“1.0 | Luminance cutoff |
| softness | Float | 0.0 | 0.0â€“0.5 | Soft transition width |
| use_alpha | Bool | false | â€” | Threshold alpha channel instead of luminance |

**How it works:** Shader computes luminance, applies `smoothstep(threshold - softness, threshold + softness, lum)` for soft edges or hard step for binary output.

---

#### FlipTOP

Mirror texture horizontally and/or vertically.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| flip_x | Bool | false | â€” | Mirror horizontally |
| flip_y | Bool | false | â€” | Mirror vertically |

**How it works:** Shader inverts UV.x and/or UV.y before sampling.

---

#### TileTOP

Tile/repeat a texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| repeat | Vector2 | (2.0, 2.0) | â€” | Repeat count per axis |
| offset | Vector2 | (0, 0) | â€” | UV offset |
| mirror_x | Bool | false | â€” | Mirror on horizontal repeats |
| mirror_y | Bool | false | â€” | Mirror on vertical repeats |

**How it works:** Shader multiplies UV by repeat count and wraps via `fract()`. Mirror mode alternates direction on odd repeats.

---

#### CropTOP

Crop a sub-region from the input.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 512Ã—512 | â€” | Output resolution |
| left_top | Vector2 | (0.0, 0.0) | â€” | Top-left UV corner |
| right_bottom | Vector2 | (1.0, 1.0) | â€” | Bottom-right UV corner |

**How it works:** Shader remaps UV from the output range to the specified sub-region of the input.

---

#### FeedbackTOP

Blends current frame with previous frame's output for trails and echoes.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mix | Float | 0.9 | 0.0â€“1.0 | Feedback persistence (higher = longer trails) |
| translate | Vector2 | (0, 0) | â€” | Feedback UV translation per frame |
| rotate | Float | 0.0 | â€” | Feedback rotation in radians per frame |
| scale | Vector2 | (1.0, 1.0) | â€” | Feedback scale per frame |
| reset | Bool | false | â€” | Clear feedback buffer |

**How it works:** Each frame, the shader blends the new input with the previous frame's output texture. The previous frame can be spatially transformed (translate/rotate/scale), creating spiral, zoom, or drift effects. Uses deferred capture (`call_deferred`) to read the viewport output into an `ImageTexture` for next frame's feedback uniform.

---

#### ResolutionTOP

Resize a texture to a different resolution.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| resolution | Vector2i | 1920Ã—1080 | â€” | Target output resolution |
| filter | Enum | Linear | Linear, Nearest | Filtering mode |

**How it works:** Renders the input texture into a SubViewport at the target resolution using a `TextureRect`. Filter mode controls interpolation quality.

---

#### RenderTOP

Renders a 3D scene from COMPs into a 2D texture with integrated post-processing. This is the bridge between the COMP/SOP pipeline and the TOP pipeline.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| **Scene** | | | | |
| resolution | Vector2i | 1280Ã—720 | â€” | Render resolution |
| bg_color | Color | (0.1, 0.1, 0.12) | â€” | Background color |
| transparent_bg | Bool | false | â€” | Transparent background |
| use_environment | Bool | true | â€” | Enable environment lighting |
| ambient_energy | Float | 0.3 | 0.0â€“4.0 | Ambient light intensity |
| ambient_color | Color | (0.3, 0.3, 0.4) | â€” | Ambient light color |
| anti_aliasing | Enum | 4x MSAA | Off, 2x, 4x, 8x | MSAA quality |
| **Shadows** | | | | |
| shadow_atlas_size | Enum | 4096 | 1024, 2048, 4096, 8192 | Positional shadow atlas resolution |
| dir_shadow_size | Enum | 4096 | 1024, 2048, 4096, 8192 | Directional shadow map resolution |
| shadow_filter | Enum | Soft Medium | Hard, Soft Low/Med/High/Ultra | Shadow filter quality (PCF) |
| **Tonemap** | | | | |
| tonemap_mode | Enum | ACES | Linear, Reinhard, Filmic, ACES | Tone mapping algorithm |
| tonemap_exposure | Float | 1.0 | 0.1â€“8.0 | Exposure multiplier |
| tonemap_white | Float | 1.0 | 0.1â€“16.0 | White reference point |
| **Glow (Bloom)** | | | | |
| glow_enabled | Bool | false | â€” | Enable glow/bloom |
| glow_intensity | Float | 0.8 | 0.0â€“4.0 | Overall glow strength |
| glow_strength | Float | 1.0 | 0.0â€“2.0 | Per-level glow contribution |
| glow_bloom | Float | 0.0 | 0.0â€“1.0 | Screen-wide bloom amount |
| glow_hdr_threshold | Float | 1.0 | 0.0â€“4.0 | Brightness threshold for glow |
| glow_blend_mode | Enum | Additive | Additive, Screen, Softlight, Replace, Mix | Glow compositing mode |
| **Depth of Field** | | | | |
| dof_far_enabled | Bool | false | â€” | Enable far DOF blur |
| dof_far_distance | Float | 10.0 | 0.1â€“200.0 | Far focus distance |
| dof_far_transition | Float | 5.0 | 0.1â€“50.0 | Far transition width |
| dof_near_enabled | Bool | false | â€” | Enable near DOF blur |
| dof_near_distance | Float | 2.0 | 0.1â€“50.0 | Near focus distance |
| dof_near_transition | Float | 1.0 | 0.1â€“20.0 | Near transition width |
| dof_bokeh_size | Float | 4.0 | 0.5â€“10.0 | Blur disc radius |
| dof_bokeh_shape | Enum | Circle | Box, Hexagon, Circle | Bokeh shape |
| **SSAO** | | | | |
| ssao_enabled | Bool | false | â€” | Enable ambient occlusion |
| ssao_radius | Float | 1.0 | 0.01â€“16.0 | Sampling radius |
| ssao_intensity | Float | 2.0 | 0.0â€“10.0 | Darkening strength |
| ssao_power | Float | 1.5 | 0.1â€“10.0 | Falloff exponent |
| **SSIL** | | | | |
| ssil_enabled | Bool | false | â€” | Enable indirect lighting |
| ssil_radius | Float | 5.0 | 0.01â€“16.0 | Sampling radius |
| ssil_intensity | Float | 1.0 | 0.0â€“10.0 | Contribution strength |
| ssil_sharpness | Float | 0.98 | 0.0â€“1.0 | Edge-aware blur sharpness |
| ssil_normal_rejection | Float | 1.0 | 0.0â€“1.0 | Normal rejection factor |
| **SSR** | | | | |
| ssr_enabled | Bool | false | â€” | Enable screen-space reflections |
| ssr_max_steps | Int | 64 | 1â€“512 | Ray march steps |
| ssr_fade_in | Float | 0.15 | 0.0â€“2.0 | Reflection fade-in distance |
| ssr_fade_out | Float | 2.0 | 0.0â€“8.0 | Reflection fade-out distance |
| ssr_depth_tolerance | Float | 0.2 | 0.01â€“4.0 | Depth comparison tolerance |
| **Adjustments** | | | | |
| adj_enabled | Bool | false | â€” | Enable color adjustments |
| adj_brightness | Float | 1.0 | 0.01â€“4.0 | Brightness multiplier |
| adj_contrast | Float | 1.0 | 0.01â€“4.0 | Contrast |
| adj_saturation | Float | 1.0 | 0.0â€“4.0 | Color saturation |
| **Volumetric Fog** | | | | |
| fog_enabled | Bool | false | â€” | Enable volumetric fog |
| fog_density | Float | 0.05 | 0.0â€“1.0 | Base fog density |
| fog_albedo | Color | (1, 1, 1) | â€” | Fog scatter color |
| fog_emission | Color | (0, 0, 0) | â€” | Fog self-emission color |
| fog_emission_energy | Float | 1.0 | 0.0â€“16.0 | Fog emission intensity |
| fog_length | Float | 64.0 | 1.0â€“1024.0 | Volumetric fog distance |

**Inputs:** `comp_in` â€” accepts multiple COMP connections (multi-input port).

**How it works:** Creates an isolated 3D SubViewport with `own_world_3d = true`. Walks network input connections to discover GeometryCOMP, CameraCOMP, LightCOMP, and MergeCOMP nodes and adopts their 3D nodes into the viewport's scene tree. Creates a `WorldEnvironment` with configurable ambient lighting and post-processing via Godot's `Environment` resource. If no CameraCOMP is connected, a default perspective camera is placed at (0, 1.5, 3). DOF is applied to the active camera (from CameraCOMP or default). Time-dependent â€” re-populates the scene each frame.

**Performance:** When all post-processing toggles are off and tonemap is at defaults, the post-processing path early-exits with a single boolean check â€” zero overhead for vanilla 3D renders.

---

#### AnalyzeTOP

Per-pixel statistics: min, max, average, or sum over a configurable kernel.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Average | Min, Max, Average, Sum | Statistic to compute |
| kernel_size | Int | 3 | 1â€“15 | Neighbourhood size (must be odd) |

**Inputs:** `in` (TOP). **How it works:** Samples NxN neighbourhood and outputs per-pixel statistic.

---

#### MonoTOP

Convert a colour texture to grayscale.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| method | Enum | Rec.709 | Rec.709, Rec.601, Average, Desaturate | Greyscale formula |
| mix | Float | 1.0 | 0.0â€“1.0 | Blend between original and mono |

**Inputs:** `in` (TOP).

---

#### SharpenTOP

Unsharp-mask sharpening.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0.0â€“10.0 | Sharpening strength |
| radius | Float | 1.0 | 0.1â€“10.0 | Blur kernel radius |

**Inputs:** `in` (TOP).

---

#### NormalMapTOP

Generate tangent-space normal map from a height/bump texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0.1â€“20.0 | Bump amplification |
| invert_y | Bool | false | â€” | Flip green channel for DirectX convention |

**Inputs:** `in` (TOP).

---

#### DepthTOP

Pseudo-depth extraction via luminance mapping.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| near | Float | 0.1 | 0.01â€“100.0 | Near-plane luminance mapping |
| far | Float | 100.0 | 0.1â€“10000.0 | Far-plane luminance mapping |
| invert | Bool | false | â€” | Flip nearâ†”far |

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
| r_gainâ€“a_gain | Float | 1.0 | 0.0â€“2.0 | Per-channel gain |

**Inputs:** `in` (TOP).

---

#### ConvolutionTOP

Custom NxN kernel convolution with presets.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| preset | Enum | Emboss | Custom, Emboss, Sharpen, Edge Detect, Ridge, Gaussian Blur, Box Blur | Kernel preset |
| kernel_size | Int | 3 | 3â€“7 | Kernel dimension (odd) |
| divisor | Float | 1.0 | 0.001â€“100.0 | Divide result |
| bias | Float | 0.0 | âˆ’1.0â€“1.0 | Add after division |

**Inputs:** `in` (TOP).

---

#### DilateErodeTOP

Morphological dilation (expand bright) and erosion (shrink bright).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Dilate | Dilate, Erode | Operation |
| radius | Int | 2 | 1â€“16 | Kernel radius in pixels |

**Inputs:** `in` (TOP).

---

#### LensDistortTOP

Barrel / pincushion lens distortion with chromatic aberration.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| k1 | Float | 0.2 | âˆ’2.0â€“2.0 | Radial distortion (+ barrel, âˆ’ pincushion) |
| k2 | Float | 0.0 | âˆ’1.0â€“1.0 | Higher-order radial distortion |
| chromatic_aberration | Float | 0.0 | 0.0â€“5.0 | RGB channel separation |
| bg_color | Color | Transparent | â€” | Fill outside distortion |

**Inputs:** `in` (TOP).

---

#### LumaBlurTOP

Luminance-weighted selective blur.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| blur_size | Float | 4.0 | 0.0â€“50.0 | Max blur radius |
| quality | Int | 4 | 1â€“8 | Samples per direction |
| luma_threshold | Float | 0.5 | 0.0â€“1.0 | Luminance cutoff |
| blur_bright | Bool | true | â€” | true = blur brights, false = blur darks |

**Inputs:** `in` (TOP).

---

#### SlopeTOP

Image gradient / derivative.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| output | Enum | Magnitude | Magnitude, Horizontal (dx), Vertical (dy) | Gradient component |
| strength | Float | 1.0 | 0.1â€“20.0 | Amplification |

**Inputs:** `in` (TOP).

---

#### CornerPinTOP

4-point perspective warp for projection mapping and keystone correction.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| top_left | Vector2 | (0, 0) | â€” | Top-left corner UV |
| top_right | Vector2 | (1, 0) | â€” | Top-right corner UV |
| bottom_left | Vector2 | (0, 1) | â€” | Bottom-left corner UV |
| bottom_right | Vector2 | (1, 1) | â€” | Bottom-right corner UV |
| bg_color | Color | Transparent | â€” | Fill outside warp |

**Inputs:** `in` (TOP).

---

#### ProjectionTOP

UV projection mapping: planar, cylindrical, or spherical.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | Planar | Planar, Cylindrical, Spherical | Projection type |
| uv_offset | Vector2 | (0, 0) | â€” | UV translation |
| uv_scale | Vector2 | (1, 1) | â€” | UV scale |
| rotation | Float | 0.0 | â€” | UV rotation in radians |

**Inputs:** `in` (TOP).

---

#### FitTOP

Aspect-aware resize with letterbox / fill / stretch.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| fit_mode | Enum | Fit | Fit, Fill, Stretch, Letterbox | Resize strategy |
| resolution | Vector2i | 512Ã—512 | â€” | Target resolution |
| border_color | Color | Black | â€” | Letterbox / border fill colour |

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
| opacity | Float | 1.0 | 0.0â€“1.0 | Blend opacity |

**Inputs:** `A` (TOP), `B` (TOP).

**How it works:** Shader samples both textures and applies the selected blend operation per pixel. Resolution follows input A.

---

#### CrossTOP

Linear crossfade between two textures.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| cross | Float | 0.5 | 0.0â€“1.0 | Crossfade value (0 = A, 1 = B) |

**Inputs:** `A` (TOP), `B` (TOP).

**How it works:** Shader does `mix(A, B, cross)` per pixel.

---

#### DisplaceTOP

Distort one texture using another as a displacement map.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| weight | Float | 0.1 | 0.0â€“2.0 | Displacement strength |
| method | Enum | RG as XY | RG as XY, Luminance, RGB as XYZ | How to read displacement |
| scale | Vector2 | (1.0, 1.0) | â€” | Per-axis displacement scale |

**Inputs:** `source` (TOP â€” texture to distort), `displace` (TOP â€” displacement map).

**How it works:** Shader reads displacement values from the second texture, offsets the UV coordinates of the source texture by the displacement amount. Method controls which channels drive the displacement.

---

#### LookupTOP

Color remapping via lookup table texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index_by | Enum | Luminance | Luminance, Red, Green, Blue | Which channel indexes the ramp |

**Inputs:** `source` (TOP â€” image to remap), `ramp` (TOP â€” color lookup table).

**How it works:** Shader computes the index value from the source (luminance or single channel), then samples the ramp texture at that position. Output color comes from the ramp.

---

#### ColorMapTOP

Remap luminance to a gradient texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| luma_mode | Enum | Rec.709 | Rec.709, Average, Luminosity | How to compute luminance |
| intensity | Float | 1.0 | 0.0â€“2.0 | Blend between original and mapped |

**Inputs:** `in` (TOP â€” source), `gradient` (TOP â€” gradient/LUT). **How it works:** Computes luminance from source, samples gradient texture at that value.

---

#### RemapTOP

UV displacement remap or 1D LUT value remap.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| mode | Enum | UV Remap | UV Remap, Value Remap (LUT) | Remap method |
| strength | Float | 1.0 | 0.0â€“2.0 | Remap intensity |

**Inputs:** `in` (TOP â€” source), `map` (TOP â€” UV displacement or LUT). **How it works:** UV Remap uses map's RG as new UV coordinates; Value Remap uses luminance as LUT index.

---

#### LayoutTOP

Tile up to 8 input textures into a grid mosaic.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| columns | Int | 2 | 1â€“8 | Grid columns |
| bg_color | Color | Black | â€” | Background fill |

**Inputs:** Up to 8 dynamic TOP inputs (auto-grow/shrink). **How it works:** Shader tiles N inputs into a grid. Rows auto-calculated from input count and columns.

---

#### ChromaKeyTOP

Chroma / luma key (green-screen) with spill suppression.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| key_mode | Enum | Chroma | Chroma, Luma | Keying method |
| key_color | Color | Green | â€” | Key target colour |
| threshold | Float | 0.3 | 0.0â€“1.0 | Tolerance |
| smoothness | Float | 0.1 | 0.0â€“0.5 | Edge softness |
| spill_reduction | Float | 0.5 | 0.0â€“1.0 | Green fringe suppression |

**Inputs:** `in` (TOP).

---

### Temporal / Buffer

These TOPs store frames over time for delay, scrubbing, and playback control.

---

#### CacheTOP

Ring buffer â€” stores N frames with delay and freeze controls.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| length | Int | 30 | 1â€“300 | Buffer length in frames |
| delay | Int | 0 | 0â€“299 | Output frame offset into the past |
| freeze | Bool | false | â€” | Pause recording |
| reset | Bool (pulse) | false | â€” | Clear the buffer |

**Inputs:** `in` (TOP). **How it works:** Captures each input frame as an ImageTexture (GPUâ†’CPUâ†’GPU roundtrip). Ring buffer advances each cook. Delay outputs a past frame.

---

#### TimeMachineTOP

Playback controller over a frame buffer with speed, scrub, and wrap modes.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| speed | Float | 1.0 | âˆ’10.0â€“10.0 | Playback speed |
| position | Float | 0.0 | 0.0â€“1.0 | Normalised scrub position |
| use_position | Bool | false | â€” | Override speed with position scrub |
| wrap_mode | Enum | Clamp | Clamp, Loop, Ping-Pong | End-of-buffer behaviour |
| freeze | Bool | false | â€” | Pause playback |
| reset | Bool (pulse) | false | â€” | Reset playback head |

**Inputs:** `in` (TOP â€” typically from CacheTOP). **How it works:** Reads from input CacheTOP's buffer. Speed/position controls which stored frame to output.

---

### Utility

---

#### NullTOP

Pass-through. No processing â€” forwards input to output unchanged.

Used as an organizational endpoint, a reference target for expressions, or to "name" a point in the network.

---

#### SwitchTOP

Select one of up to 4 inputs by index.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| index | Int | 0 | 0â€“3 | Which input to output |
| blend | Bool | false | â€” | Blend between adjacent inputs (stubbed) |

**Inputs:** `in0`, `in1`, `in2`, `in3` (all TOP).

**How it works:** Returns the texture from the selected input index. Falls back to the first valid input if the selected index has no connection.

---

### Filters (New â€” Matte, Premultiply, Posterize, Radial Blur, Anti-Alias, Palette)

---

#### MatteTOP

Apply alpha from a second texture. Configurable source channel (Luma, R, G, B, A), invert, and premultiply options.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| source | Enum | Luma | Luma/R/G/B/A | Which channel of the matte input drives alpha |
| invert | Bool | false | â€” | Invert the matte |
| premultiply | Bool | true | â€” | Premultiply RGB by new alpha |

**Inputs:** `in` (TOP â€” source), `matte` (TOP â€” alpha source). **Shader:** `matte.gdshader`.

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
| levels | Int | 8 | 2â€“256 | Number of color levels |

**Input:** `in` (TOP). **Shader:** `posterize.gdshader`.

---

#### RadialBlurTOP

Zoom / radial blur effect radiating from a configurable center point.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 0.1 | 0â€“1 | Blur intensity |
| center_x | Float | 0.5 | 0â€“1 | Blur center X |
| center_y | Float | 0.5 | 0â€“1 | Blur center Y |
| samples | Int | 16 | 4â€“64 | Number of samples (quality) |

**Input:** `in` (TOP). **Shader:** `radial_blur.gdshader`.

---

#### AntiAliasTOP

Simplified FXAA-style anti-aliasing with luma-based edge detection.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| strength | Float | 1.0 | 0â€“2 | AA blending strength |
| edge_threshold | Float | 0.125 | 0.01â€“0.5 | Minimum edge contrast to trigger AA |

**Input:** `in` (TOP). **Shader:** `anti_alias.gdshader`.

---

#### PaletteTOP

Quantize image colors to a palette texture with optional Bayer dithering.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| palette_size | Int | 16 | 2â€“256 | Number of palette colors to use |
| dithering | Bool | false | â€” | Enable 4Ã—4 Bayer dithering |

**Inputs:** `in` (TOP â€” source), `palette` (TOP â€” palette texture). **Shader:** `palette.gdshader`.

---

#### ScreenGrabIMG

Captures the main viewport (or editor viewport) as a CPU-side Image. Viewport-only â€” no OS-level desktop capture. Chain â†’ ImgToTOP for GPU texture.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| source | Menu | Main Viewport | Main/Editor | Which viewport to capture |
| res_x | Int | 512 | 1â€“4096 | Output width |
| res_y | Int | 512 | 1â€“4096 | Output height |
| active | Bool | true | â€” | Enable/disable capture |

**No inputs.** Grabs viewport via `Viewport.get_texture().get_image()`, resizes on CPU. `time_dependent = true` â€” recooks every frame.

**File:** `operators/img/screen_grab_img.gd`

---

## CHOP â€” Channel Operators

CHOPs process named float arrays (channels). Each channel is a `PackedFloat32Array` with a name (e.g., "tx", "ty", "tz", "out"). Single-sample CHOPs act as real-time control signals. Multi-sample CHOPs carry waveform data, audio, or patterns.

All CHOP data flows as `GNChannelData` â€” a lightweight RefCounted wrapper around a `Dictionary` of named float arrays.

**Total: 53 operators** â€” 7 generators, 19 filters, 7 combiners, 7 utility, 5 channel management, 3 input devices, 4 bridge, 1 audio output.

### Generators

These CHOPs create channel data from scratch.

---

#### LFO CHOP

Low-frequency oscillator. The fundamental animation driver in GONODES.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| waveform | Enum | Sine | Sine, Triangle, Square, Sawtooth, Pulse | Wave shape |
| frequency | Float | 1.0 | 0.001â€“100.0 | Oscillation speed in Hz |
| amplitude | Float | 1.0 | 0.0+ | Output amplitude |
| offset | Float | 0.0 | â€” | DC offset |
| phase | Float | 0.0 | 0.0â€“1.0 | Phase offset |
| duty_cycle | Float | 0.5 | 0.0â€“1.0 | Pulse width (Pulse waveform only) |

**Output:** Single channel `"out"`.

**How it works:** Phase accumulator advances by `frequency * delta_time` each frame. The accumulator feeds into the selected waveform function. Time-dependent â€” always cooks (produces a new value every frame).

---

#### WaveCHOP

Multi-channel, multi-sample waveform generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| waveform | Enum | Sine | Sine, Triangle, Square, Sawtooth, Pulse, Ramp | Wave shape |
| channels | Int | 1 | 1â€“16 | Number of channels |
| length | Int | 1 | 1â€“4096 | Samples per channel |
| frequency | Float | 1.0 | 0.001â€“1000.0 | Wave frequency |
| amplitude | Float | 1.0 | 0.0+ | Output amplitude |
| offset | Float | 0.0 | â€” | DC offset |
| phase | Float | 0.0 | 0.0â€“1.0 | Phase offset |
| phase_step | Float | 0.0 | 0.0â€“1.0 | Phase offset per channel |

**How it works:** When `length = 1`, uses `elapsed_time` for animated output (time-dependent). When `length > 1`, fills a multi-sample array over a 0â†’1 phase sweep. `phase_step` offsets each channel's phase for spread effects. Channels are named `chan0`, `chan1`, etc.

---

#### NoiseCHOP

Smooth procedural noise channels.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| num_channels | Int | 1 | 1â€“16 | Number of channels |
| channel_names | String | "chan1" | â€” | Comma-separated names |
| roughness | Float | 0.5 | 0.0â€“1.0 | Fractal roughness (octave blending) |
| period | Float | 1.0 | 0.01â€“100.0 | Noise period/speed |
| seed | Int | 0 | 0â€“99999 | Random seed |

**How it works:** Time accumulator advances each frame. Samples custom 1D smooth noise (hash-based with cubic interpolation) per channel. Roughness controls octave layering. Each channel uses a different seed offset. Time-dependent.

---

#### ConstantCHOP

Static named values with a dynamic number of channel slots.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| count | Int | 1 | 1â€“32 | Number of channel slots |
| nameN | String | "chan1" (slot 0) / "" | â€” | Channel name (empty = skip) |
| valueN | Float | 0.0 | â€” | Constant value for channel |

**How it works:** The **count** parameter controls how many name/value pairs appear in the inspector (1â€“32). Changing count at runtime dynamically adds or removes parameter slots â€” existing values are preserved when growing. Skips channels with empty names. Useful for constants, UI controls, and reference values.

---

#### PatternCHOP

Multi-sample pattern generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| type | Enum | Ramp | Ramp, Sine, Cosine, Step, Random, Constant | Pattern type |
| length | Int | 100 | 1â€“16384 | Number of samples |
| channels | Int | 1 | 1â€“16 | Number of channels |
| from_value | Float | 0.0 | â€” | Range start |
| to_value | Float | 1.0 | â€” | Range end |
| cycles | Float | 1.0 | 0.001+ | Number of cycles |
| seed | Int | 0 | 0â€“99999 | Seed (for Random pattern) |

**How it works:** Fills a multi-sample array with the selected pattern. Ramp = linear interpolation fromâ†’to. Sine/Cosine = cyclic wave mapped to from/to range. Step = binary toggle. Random = seeded random values. Constant = flat value. Channels are named `chan0`, `chan1`, etc.

---

#### TimerCHOP

Countdown/count-up timer with start/reset triggers.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| length | Float | 10.0 | 0.0+ | Timer duration in seconds |
| loop | Bool | false | â€” | Loop when complete |
| auto_start | Bool | true | â€” | Start automatically |
| speed | Float | 1.0 | 0.0+ | Time multiplier |

**Inputs:** `start` (CHOP â€” rising edge starts timer), `reset` (CHOP â€” rising edge resets).

**Output channels:** `timer_seconds` (elapsed time), `timer_fraction` (0â†’1 progress), `running` (0 or 1), `done` (0 or 1).

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
| cutoff | Float | 0.1 | 0.001â€“1.0 | Cutoff frequency (normalized) |
| reset | Bool | false | â€” | Reset filter state |

**How it works:** Single-pole IIR filter. Low pass: `y = y_prev + Î± * (x - y_prev)`. High pass: `y = x - low_pass_result`. Alpha = clamped cutoff value. Maintains per-channel state across frames. Time-dependent.

---

#### LagCHOP

Exponential smoothing with separate attack and release times.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| attack | Float | 0.2 | 0.0â€“10.0 | Rise time in seconds |
| release | Float | 0.2 | 0.0â€“10.0 | Fall time in seconds |
| reset | Bool | false | â€” | Reset to current input value |

**How it works:** Uses `1.0 - exp(-dt / tau)` for frame-rate independent smoothing. Attack time is used when the input is rising, release time when falling. Time-dependent.

---

#### LimitCHOP

Clamp, loop, or zig-zag values into a range.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| type | Enum | Clamp | Clamp, Loop, Zig-Zag | Limit mode |
| min | Float | 0.0 | â€” | Range minimum |
| max | Float | 1.0 | â€” | Range maximum |

**How it works:** Processes each sample. Clamp = `clamp(val, min, max)`. Loop = wraps using `fmod`. Zig-Zag = bounces back and forth within the range.

---

#### TriggerCHOP

Rising-edge triggered envelope generator.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | â€” | Trigger threshold |
| attack | Float | 0.0 | 0.0â€“10.0 | Attack time in seconds |
| peak | Float | 1.0 | 0.0+ | Peak value |
| decay | Float | 0.5 | 0.0â€“10.0 | Decay time in seconds |
| retrigger | Bool | true | â€” | Allow retriggering during decay |

**How it works:** Detects rising edges (input crosses threshold). On trigger, starts an attackâ†’peakâ†’decay envelope. After decay completes, output returns to 0. Per-channel state tracking. Time-dependent.

---

#### HoldCHOP

Sample-and-hold. Captures input values on trigger and holds them.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | â€” | Trigger threshold |
| hold_on_start | Bool | true | â€” | Capture value on first cook |
| reset | Bool | false | â€” | Clear held values |

**Inputs:** `in` (CHOP â€” values to sample), `trigger` (CHOP â€” rising edge triggers capture).

**How it works:** On rising edge of trigger input, captures current input values and holds them until the next trigger. Time-dependent.

---

#### SpeedCHOP

Velocity integrator. Accumulates input values over time.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| scale | Float | 1.0 | â€” | Speed multiplier |
| clamp | Bool | false | â€” | Clamp accumulated value |
| min | Float | -1000.0 | â€” | Clamp minimum |
| max | Float | 1000.0 | â€” | Clamp maximum |
| reset_all | Bool | false | â€” | Reset accumulator |

**Inputs:** `in` (CHOP â€” velocity), `reset` (CHOP â€” rising edge resets).

**How it works:** Each frame: `accumulator += input * scale * delta_time`. Optional clamping. Useful for converting speed/velocity signals to position. Time-dependent.

---

#### CountCHOP

Event counter with rising-edge detection.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| threshold | Float | 0.5 | â€” | Trigger threshold |
| step | Float | 1.0 | â€” | Count increment |
| limit_min | Float | 0.0 | â€” | Minimum count value |
| limit_max | Float | 1000000.0 | â€” | Maximum count value |
| overflow | Enum | Clamp | Clamp, Loop | What to do at limits |
| reset_all | Bool | false | â€” | Reset all counters |

**Inputs:** `in` (CHOP â€” events to count), `reset` (CHOP â€” resets counter).

**How it works:** Detects rising edges crossing threshold. Increments count by `step` on each trigger. Applies min/max limits with clamp or loop overflow. Per-channel counting. Time-dependent.

---

#### SelectCHOP

Filter and rename channels by pattern.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| pattern | String | "*" | â€” | Channel name pattern (e.g., `*`, `tx,ty`, `chan*`) |
| rename | String | "" | â€” | Comma-separated rename list (empty = keep names) |

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
| operand | Float | 0.0 | â€” | Value for single-input operations |
| channel_name | String | "" | â€” | Pick a specific in2 channel (empty = auto-match) |

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
| cross | Float | 0.5 | 0.0â€“1.0 | Crossfade value (0 = A, 1 = B) |

**Inputs:** `A` (CHOP), `B` (CHOP).

**How it works:** Linearly interpolates (`lerpf`) between matching channels from A and B. If only one input has a channel, blends toward 0.

---

#### LogicCHOP

Boolean logic operations between channels.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| operation | Enum | AND | AND, OR, XOR, NAND, NOR, NOT | Logic operation |
| threshold | Float | 0.5 | â€” | True/false threshold |

**Inputs:** `in1` (CHOP), `in2` (CHOP, optional â€” NOT uses only in1).

**How it works:** Converts values to boolean (â‰¥ threshold = true). Applies logic operation per-sample. Outputs 1.0 (true) or 0.0 (false).

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
| index | Int | 0 | 0â€“3 | Which input to output |

**Inputs:** `in0`, `in1`, `in2`, `in3` (all CHOP).

---

#### RenameCHOP

Rename input channels with explicit fromâ†’to mapping. Channels not matched by any rename row pass through with their original name. Empty from/to fields are skipped.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| renames | Int | 1 | 1â€“32 | Number of rename rows |
| fromN | String | "" | â€” | Source channel name for row N (0-based) |
| toN | String | "" | â€” | Target channel name for row N (0-based) |

**Input:** `in` (CHOP).

**How it works:** For each channel in the input, checks if its name matches any `fromN` value. If matched, the channel is output under the corresponding `toN` name. Unmatched channels are copied unchanged. The number of from/to pairs is controlled by the `renames` parameter and can be changed dynamically.

---

#### DATtoCHOP *(Bridge â€” DAT â†’ CHOP)*

Converts a DAT table to CHOP channels. Lives in the `dat/` folder but produces CHOP output (family = CHOP).

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| layout | Enum | Columns as Channels | Columns as Channels, Rows as Channels | Conversion layout |
| first_is_name | Bool | true | â€” | Use first row/column as channel names |

**Input:** `dat_in` (DAT).

**How it works:** Parses numeric cell values from the DAT table into float arrays. Non-numeric cells become 0.0. Column mode: each column becomes a channel. Row mode: each row becomes a channel.

---

#### PhysicsCHOP *(Bridge â€” COMP â†’ CHOP)*

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

**Input:** `comp_in` (COMP â€” a physics body such as RigidBodyCOMP).

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
| cutoff | Float | 0.5 | Normalized cutoff frequency (0â€“1) |
| q | Float | 0.707 | Resonance / quality factor |

**Input:** `in` (CHOP).

**How it works:** Implements a biquad filter with Butterworth coefficient calculation. Maintains 4 state variables per channel (_x1, _x2, _y1, _y2) for proper IIR feedback.

---

#### SpringCHOP

Damped harmonic oscillator â€” channels spring toward input values.

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

Envelope follower â€” RMS, peak, or average-abs with window size.

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

**Inputs:** `table` (CHOP â€” lookup data), `index` (CHOP â€” lookup positions 0â€“1).

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

**Time-dependent.** Uses `Input.is_key_pressed()`.

---

#### MouseInCHOP

Outputs mouse position, delta, buttons, and scroll as CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| normalized | Bool | true | Normalize position to 0â€“1 by viewport size |
| buttons | Bool | true | Output lmb, rmb, mmb channels |
| scroll | Bool | true | Output scroll channel |

**Channels:** `tx`, `ty`, `dx`, `dy`, `lmb`, `rmb`, `mmb`, `scroll`. **Time-dependent.**

---

#### GamepadCHOP

Outputs gamepad/controller stick, trigger, and button states.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| device | Int | 0 | Gamepad device index (0â€“7) |
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
| length | Int | 120 | 2â€“3600 | Number of frames to record |
| active | Bool | true | â€” | Enable recording |

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

#### AudioDeviceOUT

Outputs CHOP channel data to the audio system as PCM audio. Uses `AudioStreamGenerator` + `AudioStreamGeneratorPlayback` to push sample frames to speakers.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| active | Bool | false | â€” | Enable/disable audio output |
| gain | Float | 1.0 | 0â€“10 | Output gain multiplier |
| mix_rate | Float | 44100 | 8000â€“96000 | Audio sample rate (Hz) |
| buffer_length | Float | 0.1 | 0.01â€“1 | Generator buffer length (seconds) |

**Input:** `in` (CHOP â€” audio samples). Channels named `left`/`right` map to stereo; otherwise first 1â€“2 channels are used. Creates a dedicated AudioServer bus routed to Master. `time_dependent = true`.

**File:** `operators/output/audio_device_out.gd`

---

## DAT â€” Data Operators

DATs process tables and text. The output type is `GNTableData`, which operates in either **table mode** (2D grid of strings with headers) or **text mode** (plain string). DATs are useful for configuration, data lookups, text processing, and cross-family data conversion.

**Total: 24 operators** â€” 3 generators, 5 filters, 1 combiner, 2 utility, 2 bridges, 3 I/O, 4 new filters, 4 new bridges.

### Generators

---

#### ConstantDAT

Manually editable 4Ã—4 table.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| col0 | String | "name" | â€” | Column 0 header |
| col1 | String | "value" | â€” | Column 1 header |
| col2 | String | "" | â€” | Column 2 header (empty = skip) |
| col3 | String | "" | â€” | Column 3 header (empty = skip) |
| r0c0â€“r3c3 | String | "" | â€” | 16 cells (4 rows Ã— 4 columns) |

**How it works:** Builds a table from hand-entered headers and cells. Column count stops at the first empty header (after col1). Entirely empty rows are skipped.

---

#### TextDAT

Plain text storage.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| text | String | "" | â€” | Text content |

**How it works:** Stores plain text in text mode (`GNTableData.set_text()`). Not a table â€” just a string.

---

#### InfoDAT

System information table. Time-dependent â€” updates every frame.

**Parameters:** None.

**Output table columns:** `property`, `value`.

**Rows:** `fps`, `frame`, `elapsed_time`, `delta`, `engine_version`, `os`, `processor_name`, `processor_count`, `screen_size`, `static_memory`.

**How it works:** Reads values from Godot's `Engine`, `OS`, `Performance`, and `DisplayServer` APIs each frame.

---

#### OscInDAT *(Stub)*

OSC message receiver. **Currently a stub** â€” UDP/OSC networking is not yet implemented.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| port | Int | 9000 | 1â€“65535 | Listening port |
| max_rows | Int | 100 | 1â€“10000 | Maximum stored messages |
| active | Bool | true | â€” | Enable/disable |

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
| include_header | Bool | true | â€” | Include header row in output |

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
| index | Int | 0 | 0â€“1 | Which input to output |

---

### Bridges

---

#### CHOPtoDAT *(Bridge â€” CHOP â†’ DAT)*

Converts CHOP channel data to a DAT table.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| layout | Enum | Channels as Columns | Channels as Columns, Channels as Rows | Output layout |

**Input:** `chop_in` (CHOP).

**How it works:** Columns mode: channel names become column headers, samples become rows. Rows mode: first column is channel name, subsequent columns are samples labeled `s0`, `s1`, etc.

---

#### DATtoCHOP *(Bridge â€” DAT â†’ CHOP)*

See [DATtoCHOP in the CHOP section](#dattochop-bridge--dat--chop) â€” this operator has CHOP family despite living in the DAT directory.

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

**Input:** `in` (DAT, optional â€” for Generate mode).

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

Rolling row buffer â€” accumulates rows over time, dropping oldest when full.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| max_rows | Int | 100 | 1â€“10000 | Maximum rows in buffer |
| active | Bool | true | â€” | Enable accumulation |

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

**Input:** `target` (any family) â€” the node to observe.
**Output:** `out` (DAT) â€” event log table with columns: `time, event, status, target`.

**Callback context variables:** Same as Script operators (`me`, `inputs`, `time`, `frame`, `dt`, `par()`, `chop()`, `top()`, `sop()`, `dat()`, `set_par()`, `network_*()`) plus:
- `target` â€” the GNNode connected to input 0
- `event` â€” String name of the callback (e.g. "onCook")
- `event_param` â€” for onValueChange, the parameter name that changed

**Supported events:**

| Event | Trigger | Use Case |
|-------|---------|----------|
| `onStart` | First cook frame | Initialize params, build graph |
| `onCreate` | First cook of this CallbackDAT | One-time setup |
| `onCook` | Target node finishes cooking | React to output changes |
| `onValueChange` | Target node param changes | Mirror params, trigger side effects |

**Example â€” mirror a parameter:**

```gdscript
# onValueChange callback
if event_param == "speed":
    set_par("other_lfo", "speed", par(target.id, "speed") * 2.0)
```

**Example â€” procedural graph building:**

```gdscript
# onCreate callback
var nid = network_add_node("NoiseTOP")
set_par(nid, "resolution", Vector2i(512, 512))
network_connect(nid, 0, "composite1", 1)
```

---

## SOP â€” Surface Operators

SOPs produce and manipulate 3D geometry. The output type is `GNGeoData`, which wraps Godot's native `ArrayMesh`. SOPs leverage Godot's built-in mesh primitives (`BoxMesh`, `SphereMesh`, etc.) and `SurfaceTool` for procedural generation. Geometry flows through SOP chains and ultimately reaches a GeometryCOMP for 3D scene placement.

**Total: 40 operators** â€” 9 generators, 20 filters, 6 combiners, 2 utility, 3 deformers.

### Generators

---

#### GridSOP

Subdivided plane.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| size_x | Float | 2.0 | 0.01â€“100.0 | Width |
| size_z | Float | 2.0 | 0.01â€“100.0 | Depth |
| rows | Int | 10 | 1â€“500 | Row subdivisions |
| cols | Int | 10 | 1â€“500 | Column subdivisions |
| orientation | Enum | XZ | XZ (Horizontal), XY (Vertical), YZ (Side) | Plane orientation |

**How it works:** Builds a subdivided quad using `SurfaceTool`. Vertices are arranged in a grid, triangulated, with calculated UVs and normals. Generates tangents. The mesh is centered at origin.

---

#### BoxSOP

Box mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| size_x | Float | 1.0 | 0.01â€“100.0 | Width |
| size_y | Float | 1.0 | 0.01â€“100.0 | Height |
| size_z | Float | 1.0 | 0.01â€“100.0 | Depth |
| subdivide_w | Int | 0 | 0â€“100 | Width subdivisions |
| subdivide_h | Int | 0 | 0â€“100 | Height subdivisions |
| subdivide_d | Int | 0 | 0â€“100 | Depth subdivisions |

**How it works:** Creates a Godot `BoxMesh`, converts to `ArrayMesh` via `SurfaceTool`.

---

#### SphereSOP

Sphere or hemisphere mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| radius | Float | 0.5 | 0.01â€“100.0 | Radius |
| height | Float | 1.0 | 0.01â€“200.0 | Height (stretch on Y) |
| radial_segments | Int | 32 | 3â€“256 | Longitudinal segments |
| rings | Int | 16 | 2â€“128 | Latitudinal rings |
| is_hemisphere | Bool | false | â€” | Only upper half |

**How it works:** Creates a Godot `SphereMesh`, converts to `ArrayMesh` via `SurfaceTool`.

---

#### TorusSOP

Torus (donut) mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| inner_radius | Float | 0.2 | 0.01â€“50.0 | Tube radius |
| outer_radius | Float | 0.5 | 0.01â€“100.0 | Ring radius |
| rings | Int | 32 | 3â€“256 | Major segments |
| ring_segments | Int | 16 | 3â€“128 | Minor segments |

**How it works:** Creates a Godot `TorusMesh`, converts to `ArrayMesh` via `SurfaceTool`.

---

#### CylinderSOP

Cylinder or cone mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| top_radius | Float | 0.5 | 0.0â€“50.0 | Top radius (0 = cone) |
| bottom_radius | Float | 0.5 | 0.0â€“50.0 | Bottom radius |
| height | Float | 1.0 | 0.01â€“100.0 | Height |
| radial_segments | Int | 32 | 3â€“256 | Segments around circumference |
| rings | Int | 4 | 1â€“128 | Vertical rings |
| cap_top | Bool | true | â€” | Cap the top |
| cap_bottom | Bool | true | â€” | Cap the bottom |

**How it works:** Creates a Godot `CylinderMesh`, converts to `ArrayMesh` via `SurfaceTool`. Set `top_radius = 0` for a cone.

---

#### LineSOP

Line strip mesh.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| points | Int | 10 | 2â€“10000 | Number of points |
| direction | Enum | X | X, Y, Z | Axis direction |
| length | Float | 2.0 | 0.01â€“1000.0 | Total line length |

**How it works:** Generates a `LINE_STRIP` mesh with points evenly distributed along the selected axis, centered at origin.

---

#### CircleSOP

Filled disc or wire circle.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| radius | Float | 0.5 | 0.01â€“100.0 | Circle radius |
| segments | Int | 32 | 3â€“512 | Edge segments |
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
| tx, ty, tz | Float | 0.0 | â€” | Translation |
| rx, ry, rz | Float | 0.0 | -360â€“360 | Rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001â€“100.0 | Scale |
| order | Enum | SRT | SRT, STR, RST, RTS, TSR, TRS | Transform order |

**How it works:** Builds a `Transform3D` from the translation, rotation, and scale parameters in the specified order. Applies the transform to every vertex position. Normals are transformed using the inverse-transpose basis to maintain correctness under non-uniform scale.

---

#### NoiseSOP

Displace vertices with procedural noise. Time-dependent â€” animates automatically.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| amplitude | Float | 0.2 | 0.0â€“100.0 | Displacement strength |
| frequency | Float | 2.0 | 0.01â€“100.0 | Noise frequency |
| offset_x, offset_y, offset_z | Float | 0.0 | â€” | Noise offset |
| speed | Float | 1.0 | 0.0â€“10.0 | Animation speed |
| noise_type | Enum | Simplex | Simplex, Perlin, Cellular, Value | Noise algorithm |
| displace_axis | Enum | Normal | Normal, X, Y, Z | Displacement direction |
| seed | Int | 0 | 0â€“9999 | Random seed |

**How it works:** Uses Godot's `FastNoiseLite` to sample 3D noise at each vertex position. The noise value displaces the vertex along its normal (or a fixed axis). Time offset evolves via `elapsed_time * speed` for animation.

---

#### SubdivideSOP

Midpoint subdivision.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| iterations | Int | 1 | 1â€“4 | Number of subdivision passes |

**How it works:** Splits each triangle into 4 by inserting midpoints on each edge. Non-triangle primitives pass through unchanged. Regenerates normals and tangents after subdivision. Each iteration quadruples the triangle count â€” limit of 4 iterations prevents runaway geometry.

---

#### WireframeSOP

Convert triangles to lines. No parameters.

**How it works:** Extracts edges from triangle mesh and outputs a `PRIMITIVE_LINES` mesh. Deduplicates edges using a hash key `min(a,b)*100000 + max(a,b)` to avoid drawing shared edges twice.

---

### Combiners

---

#### MergeSOP

Merge multiple geometries into one. No parameters.

**Input:** `in` (SOP, **multi-input** â€” accepts multiple connections).

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
| index | Int | 0 | 0â€“1 | Which input to output |

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

**How it works:** Unique mode unshares every vertex so triangles have independent normals. Consolidate merges vertices within the distance threshold using O(nÂ²) proximity search.

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
| components | Int | 3 | Values per vertex (1â€“4) |
| source | Enum | Constant | Constant, Expression, Position, Normal, UV, Random |

**Input:** `in` (SOP).

**How it works:** Stores results in `GNGeoData.point_attribs` dictionary â€” a dictionary of name â†’ `PackedFloat32Array` with `components` values per vertex.

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

**Inputs:** `template` (SOP â€” geometry to copy), `target` (SOP â€” points to copy onto).

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

**Inputs:** `backbone` (SOP â€” line strip), `profile` (SOP, optional â€” cross-section; uses circle if absent).

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

#### SpringSOP

Damped spring vertex deformer. Each vertex maintains spring state (position + velocity) and oscillates toward the input rest positions. Creates "jelly" or lag-based vertex animation.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| stiffness | Float | 20.0 | 0.1â€“500 | Spring constant (higher = snappier) |
| damping | Float | 4.0 | 0â€“50 | Damping coefficient (higher = less overshoot) |
| mass | Float | 1.0 | 0.01â€“10 | Vertex mass (higher = slower) |
| reset | Bool | false | â€” | Reset spring state |
| max_displacement | Float | 10.0 | 0.01â€“100 | Clamp max displacement from target |

**Input:** `in` (SOP). Uses semi-implicit Euler integration per vertex. Recalculates normals from deformed positions. `time_dependent = true`. Physics reference: `SpringCHOP`.

**File:** `operators/sop/spring_sop.gd`

---

#### BendSOP

Bend geometry along an axis using circular arc deformation.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| angle | Float | 0.0 | -360â€“360 | Bend angle in degrees |
| axis | Enum | Y | X, Y, Z | Bend axis |
| origin | Float | 0.0 | -10â€“10 | Center of bend along axis |
| length_val | Float | 0.0 | â€” | Region length (0 = auto from bounds) |

**Input:** `in` (SOP). Works best on subdivided geometry.

---

#### TwistSOP

Rotates vertices around an axis proportional to their position along that axis.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| angle | Float | 0.0 | -720â€“720 | Total twist in degrees |
| axis | Enum | Y | X, Y, Z | Twist axis |

**Input:** `in` (SOP). More subdivisions = smoother twist.

---

#### TaperSOP

Scale perpendicular axes as a function of position along the taper axis.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| scale_start | Float | 1.0 | 0â€“10 | Scale at bottom |
| scale_end | Float | 0.5 | 0â€“10 | Scale at top |
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
| text | String | "Hello" | â€” | Text to render |
| font_size | Float | 1.0 | 0.1â€“100 | Font size multiplier |
| depth | Float | 0.1 | 0â€“10 | Extrusion depth |
| horizontal_align | Enum | Center | Left, Center, Right | Horizontal alignment |

No input needed. Uses Godot's built-in TextMesh for high-quality 3D text.

---

### Filters (New 2)

---

#### TrailSOP

Records the centroid of input geometry over time as a line strip trail.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| length | Int | 60 | 2â€“3600 | Number of frames to record |
| active | Bool | true | â€” | Enable recording |

**Input:** `in` (SOP). **Time-dependent.** Computes centroid of input and appends to ring buffer.

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

## COMP â€” Component Operators

COMPs are 3D scene components. Unlike other families, COMPs don't produce `GNData` output â€” instead, they create and manage Godot `Node3D` instances (MeshInstance3D, Camera3D, Light3D) that are adopted into a RenderTOP's isolated 3D SubViewport for rendering.

COMPs are the bridge between procedural data (SOP geometry, TOP textures) and Godot's 3D rendering engine.

**Total: 11 operators.**

> Note: SubNetworkNode, InTunnel, OutTunnel are internal system nodes.
> NullCOMP, SwitchCOMP, EnvironmentCOMP, and GenericScriptNode are utility nodes.

---

#### GeometryCOMP

Wraps a `MeshInstance3D`. Takes SOP geometry and optionally a TOP texture, placing them into a 3D scene.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | â€” | Translation |
| rx, ry, rz | Float | 0.0 | -360â€“360 | Rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001â€“100.0 | Scale |
| albedo_color | Color | White | â€” | Base material color |
| metallic | Float | 0.0 | 0.0â€“1.0 | Metallic shading |
| roughness | Float | 0.5 | 0.0â€“1.0 | Surface roughness |
| emission_energy | Float | 0.0 | 0.0â€“16.0 | Emission brightness |
| emission_color | Color | Black | â€” | Emission color |
| visible | Bool | true | â€” | Show/hide |

**Inputs:** `geo_in` (SOP â€” geometry to display), `tex_in` (TOP â€” optional albedo texture).

**How it works:** Creates a `MeshInstance3D` with a `StandardMaterial3D`. Each cook, applies the SOP mesh, transform, material properties, and optional TOP texture as albedo map. The MeshInstance3D is **not** added as a child of the COMP node â€” instead, RenderTOP discovers it via `get_mesh_instance()` and adopts it into its SubViewport.

---

#### CameraCOMP

Wraps a `Camera3D`. Defines the viewpoint for a RenderTOP.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0, 1, 3 | â€” | Camera position |
| rx, ry, rz | Float | -15, 0, 0 | â€” | Camera rotation in degrees |
| use_look_at | Bool | false | â€” | Override rotation to look at a target point |
| look_at_x, y, z | Float | 0.0 | â€” | Look-at target position |
| projection | Enum | Perspective | Perspective, Orthogonal | Projection mode |
| fov | Float | 75.0 | 1.0â€“179.0 | Field of view (perspective only) |
| ortho_size | Float | 10.0 | 0.1â€“1000.0 | Orthographic view size |
| near | Float | 0.05 | 0.001â€“100.0 | Near clip plane |
| far | Float | 100.0 | 1.0â€“10000.0 | Far clip plane |
| clear_color | Color | (0.1, 0.1, 0.1) | â€” | Background clear color |

**How it works:** Creates a `Camera3D` node. Applies position, rotation (or look-at targeting), projection mode, and clipping planes. Returns null from cook â€” accessed via `get_camera()` by RenderTOP, which adopts the Camera3D into its viewport.

---

#### LightCOMP

Wraps a `Light3D`. Provides scene illumination in a RenderTOP.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| type | Enum | Directional | Directional, Omni, Spot | Light type |
| tx, ty, tz | Float | 0, 3, 2 | â€” | Light position |
| rx, ry, rz | Float | -45, 0, 0 | â€” | Light rotation in degrees |
| color | Color | White | â€” | Light color |
| energy | Float | 1.0 | 0.0â€“16.0 | Light intensity |
| shadows | Bool | true | â€” | Cast shadows |
| omni_range | Float | 10.0 | 0.1â€“1000.0 | Omni light range |
| spot_range | Float | 10.0 | 0.1â€“1000.0 | Spot light range |
| spot_angle | Float | 45.0 | 0.1â€“90.0 | Spot light cone angle |

**How it works:** Creates a `DirectionalLight3D`, `OmniLight3D`, or `SpotLight3D` depending on the `type` parameter. If the type changes, the old light node is freed and a new one is created. Returns null from cook â€” accessed via `get_light()` by RenderTOP.

---

#### RigidBodyCOMP

Wraps a `RigidBody3D` with `CollisionShape3D` for dynamic physics simulation. Takes a COMP input (typically GeometryCOMP) for mesh, material, and collision shape â€” this node only owns physics properties.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | â€” | Initial position |
| rx, ry, rz | Float | 0.0 | -360â€“360 | Initial rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001â€“100.0 | Scale |
| mode | Enum | Dynamic | Dynamic, Kinematic, Static | Physics body mode |
| mass | Float | 1.0 | 0.001â€“1000.0 | Body mass in kg |
| gravity_scale | Float | 1.0 | -10.0â€“10.0 | Gravity multiplier |
| friction | Float | 1.0 | 0.0â€“2.0 | Surface friction |
| bounce | Float | 0.0 | 0.0â€“1.0 | Restitution / bounciness |
| linear_damp | Float | 0.0 | 0.0â€“100.0 | Linear velocity damping |
| angular_damp | Float | 0.0 | 0.0â€“100.0 | Angular velocity damping |
| init_vel_x/y/z | Float | 0.0 | â€” | Initial linear velocity |
| lock_rot_x/y/z | Bool | false | â€” | Lock rotation axes |
| collision_shape | Enum | Convex Hull | Convex, Box, Sphere, Capsule, Trimesh | Collision shape type |
| ccd | Bool | false | â€” | Continuous collision detection |

**Inputs:** `comp_in` (COMP â€” typically GeometryCOMP providing mesh + material), `force_in` (CHOP, optional â€” channels: `force_x/y/z`, `impulse_x/y/z`, `torque_x/y/z`).

**Architecture:** `SOP â†’ GeometryCOMP â†’ RigidBodyCOMP â†’ MergeCOMP â†’ RenderTOP` (with PBR_MAT wired to GeometryCOMP).

**How it works:** Resolves the upstream COMP's `MeshInstance3D` and mirrors its mesh, material, visibility, and shadow settings onto an internal `MeshInstance3D`. Collision shape is auto-generated from the upstream mesh. In Dynamic mode, Godot's physics engine (Jolt) controls the transform. CHOP force input is applied every cook (Dynamic mode only).

---

#### StaticBodyCOMP

Wraps a `StaticBody3D` â€” an immovable collider for floors, walls, and obstacles. Takes a COMP input (typically GeometryCOMP) â€” this node only owns collision and physics-material properties.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | â€” | Position |
| rx, ry, rz | Float | 0.0 | -360â€“360 | Rotation in degrees |
| sx, sy, sz | Float | 1.0 | 0.001â€“100.0 | Scale |
| friction | Float | 1.0 | 0.0â€“2.0 | Surface friction |
| bounce | Float | 0.0 | 0.0â€“1.0 | Restitution |
| collision_shape | Enum | Trimesh | Convex, Box, Sphere, Capsule, Trimesh | Collision shape type |

**Inputs:** `comp_in` (COMP â€” typically GeometryCOMP providing mesh + material).

**Architecture:** `SOP â†’ GeometryCOMP â†’ StaticBodyCOMP â†’ MergeCOMP â†’ RenderTOP` (with PBR_MAT wired to GeometryCOMP).

**How it works:** Resolves the upstream COMP's `MeshInstance3D` and mirrors its mesh, material, visibility, and shadow settings onto an internal `MeshInstance3D`. Defaults to Trimesh collision (accurate for complex static geometry). Transform is applied every cook.

---

#### SoftBodyCOMP

Wraps a `SoftBody3D` for deformable mesh physics (cloth, jelly, rubber). Takes a COMP input (typically GeometryCOMP) â€” this node only owns soft-body physics properties.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | â€” | Position |
| rx, ry, rz | Float | 0.0 | -360â€“360 | Rotation |
| sx, sy, sz | Float | 1.0 | 0.001â€“100.0 | Scale |
| simulation_precision | Int | 5 | 1â€“40 | Solver iterations |
| total_mass | Float | 1.0 | 0.01â€“1000.0 | Total body mass |
| linear_stiffness | Float | 0.5 | 0.0â€“1.0 | Spring stiffness |
| pressure_coefficient | Float | 0.0 | -100.0â€“100.0 | Internal pressure |
| damping_coefficient | Float | 0.01 | 0.0â€“1.0 | Motion damping |
| drag_coefficient | Float | 0.0 | 0.0â€“1.0 | Air drag |
| ray_pickable | Bool | false | â€” | Ray picking support |

**Inputs:** `comp_in` (COMP â€” typically GeometryCOMP providing mesh + material).

**Architecture:** `SOP â†’ GeometryCOMP â†’ SoftBodyCOMP â†’ MergeCOMP â†’ RenderTOP` (with PBR_MAT wired to GeometryCOMP).

**How it works:** Resolves the upstream COMP's `MeshInstance3D` and copies its mesh, material, visibility, and shadow settings. The mesh is assigned **once** (SoftBody3D doesn't support live mesh swapping). Physics parameters are updated every cook. High `linear_stiffness` = rigid cloth; high `pressure_coefficient` = inflated balloon.

---

#### AreaCOMP

Wraps an `Area3D` for force fields, gravity zones, and wind effects.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| tx, ty, tz | Float | 0.0 | â€” | Position |
| rx, ry, rz | Float | 0.0 | -360â€“360 | Rotation |
| gravity_direction_x/y/z | Float | 0,-1,0 | -1.0â€“1.0 | Gravity direction |
| gravity_strength | Float | 9.8 | 0.0â€“100.0 | Gravity magnitude |
| gravity_point | Bool | false | â€” | Point gravity (toward center) |
| damping | Float | 0.0 | 0.0â€“100.0 | Linear damping override |
| priority | Int | 0 | 0â€“128 | Area priority |
| shape | Enum | Box | Box, Sphere | Built-in shape |
| shape_size_x/y/z | Float | 2.0 | 0.01â€“1000.0 | Box half-extents |
| shape_radius | Float | 2.0 | 0.01â€“1000.0 | Sphere radius |
| debug_vis | Bool | false | â€” | Show translucent debug shape |

**Inputs:** `geo_in` (SOP, optional â€” custom collision shape).

**How it works:** Creates an `Area3D` with `SPACE_OVERRIDE_REPLACE`. When a rigid body enters the area, the area's gravity and damping override the world defaults. SOP input replaces the built-in shape with a convex hull collision shape. Debug visualization adds a translucent mesh to see the area bounds in the render.

---

#### JointCOMP

Wraps a `Joint3D` constraint between two physics bodies.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| joint_type | Enum | Pin | Pin, Hinge, Slider, ConeTwist, 6DOF | Joint type |
| tx, ty, tz | Float | 0.0 | â€” | Joint anchor position |
| rx, ry, rz | Float | 0.0 | -360â€“360 | Joint rotation |
| hinge_use_limit | Bool | false | â€” | Enable hinge angle limits |
| hinge_limit_lower/upper | Float | -180/180 | -180â€“180 | Hinge angle limits |
| hinge_motor_enable | Bool | false | â€” | Enable hinge motor |
| hinge_motor_speed | Float | 1.0 | -100â€“100 | Motor target speed |
| hinge_motor_max_impulse | Float | 1.0 | 0â€“1000 | Motor max impulse |
| slider_limit_lower/upper | Float | -1/1 | -100â€“100 | Slider linear limits |
| cone_swing_span | Float | 45.0 | 0â€“180 | Cone twist swing span |
| cone_twist_span | Float | 45.0 | 0â€“180 | Cone twist twist span |

**Inputs:** `body_a` (COMP), `body_b` (COMP).

**How it works:** Creates the appropriate Joint3D subtype (PinJoint3D, HingeJoint3D, etc.). Walks the network to find Body A and Body B COMP nodes, then sets `node_a` / `node_b` NodePaths. If the joint type changes, the old joint is freed and a new one is created. Both bodies must be in the same scene tree (typically via MergeCOMP â†’ RenderTOP).

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
| index | Int | 0 | 0â€“7 | Which input to pass through |

**Inputs:** `in0`â€“`in7` (COMP).

---

#### EnvironmentCOMP

Defines the rendering environment for a 3D scene â€” background, ambient light, tone mapping, and all post-processing effects. Connect to a RenderTOP COMP input alongside Geometry/Camera/Light COMPs.

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

### Scripting (New)

---

#### GenericScriptNode

Multi-output scripting node. Unlike per-family Script operators which produce a single output of their family type, GenericScriptNode can output **any combination** of data types simultaneously via `# @output` annotations.

Extends `GNNode` directly (not a family base class). Uses COMP family for neutral gray color in the graph.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| time_dependent | Bool | false | Re-cook every frame |
| cook_once | Bool | false | Pulse: force single cook, auto-resets |
| force_active | Bool | false | Keep active without downstream sink |
| code | String | (default) | GDScript with cook(), @output, @input, @param annotations |

**Annotations:**

```
# @input <family>  <description>   â€” dynamic input port
# @output <family> <description>   â€” dynamic output port (chop, top, sop, dat, img, mat)
# @param <type> <name> <default> <description>  â€” inspector parameter
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

#### AnimationCOMP

AnimationPlayer wrapper for keyframe animation on COMP transform properties. Takes a COMP input, attaches an AnimationPlayer to its scene node, and drives startâ†’end keyframe animation on position, rotation, and scale.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| active | Bool | true | â€” | Enable/disable animation |
| speed | Float | 1.0 | -10â€“10 | Playback speed multiplier |
| duration | Float | 2.0 | 0.01â€“600 | Animation length (seconds) |
| loop_mode | Menu | Linear | None, Linear, Ping-Pong | Loop mode |
| tx/ty/tz_start/end | Float | 0 | -100â€“100 | Translation keyframes |
| rx/ry/rz_start/end | Float | 0/360 | -360â€“360 | Rotation keyframes (degrees) |
| sx/sy/sz_start/end | Float | 1 | 0.001â€“100 | Scale keyframes |

**Input:** `comp` (COMP). Creates Animation with position, rotation (quaternion), and scale tracks. Seeks to `current_time * speed` each cook. Rebuilds animation on parameter change (hash-based change detection). `time_dependent = true`.

**File:** `operators/comp/animation_comp.gd`

---

## MAT â€” Material Operators

MATs produce materials for COMP use. Output type is `GNMaterialData`, wrapping Godot's `Material` base class. MATs connect to GeometryCOMP's material input to override the default PBR.

**Total: 6 operators** â€” 1 PBR, 1 shader, 1 constant, 1 wireframe, 1 point sprite, 1 depth.

---

#### ConstantMAT

Flat unlit material â€” no lighting or shading applied.

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
| color | Color | White | â€” | Point color |
| point_size | Float | 4.0 | 1â€“64 | Point size in pixels |

**Input:** `tex_in` (TOP, optional â€” sprite texture). Uses `POINT_SIZE` vertex shader output and `POINT_COORD` in fragment.

---

#### DepthMAT

Visualize scene depth as grayscale.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| near_val | Float | 0.1 | 0.001â€“100 | Near depth (white) |
| far_val | Float | 100.0 | 1â€“10000 | Far depth (black) |
| invert | Bool | false | â€” | Swap near/far mapping |

Uses ShaderMaterial that linearizes FRAGCOORD.z.

---

## Output Operators

Output operators are terminal/sink nodes that display results. They have inputs but no data outputs.

---

#### WindowOUT

Displays a TOP texture in a standalone OS window. Essential for VJ output â€” each WindowOUT creates a separate window that can be placed on any connected monitor.

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| title | String | "GONODES Output" | â€” | Window title |
| monitor | Int | 0 | 0â€“8 | Target display index |
| window_mode | Enum | Windowed | Windowed, Fullscreen, Borderless | Window mode |
| resolution | Vector2i | 1920Ã—1080 | â€” | Window resolution |
| position | Vector2i | (-1, -1) | â€” | Window position (-1,-1 = auto center) |
| always_on_top | Bool | false | â€” | Keep window above others |
| vsync | Bool | true | â€” | V-sync |

**Input:** `in` (TOP â€” texture to display).

**How it works:** Creates a Godot `Window` node with a `TextureRect` inside. The TextureRect is assigned the input TOP's `ViewportTexture` â€” a live GPU reference with zero copy overhead. Window configuration (mode, position, monitor, vsync) is only applied when the WindowOUT's own parameters change, NOT when upstream textures update (preventing per-frame window reconfiguration). Multiple WindowOUT instances create multiple independent windows.

**Known issue:** Cannot ESC out of fullscreen/borderless mode from the output window. Workaround: change Window Mode back to Windowed from the inspector.

---

## Quick Reference

| Family | Count | Operators |
|--------|-------|-----------|
| **TOP** | 59 | Noise, Ramp, Circle, Rectangle, Constant, Text, MovieFileIn, CustomShader, ComputeShader, Level, Blur, Transform, HSVAdjust, Edge, Threshold, Flip, Tile, Crop, Feedback, Resolution, Render, Composite, Cross, Displace, Lookup, ColorMap, Remap, Layout, ChromaKey, Pattern, Triangle, SVG, Analyze, Mono, Sharpen, NormalMap, Depth, ChannelMix, Convolution, DilateErode, LensDistort, LumaBlur, Slope, CornerPin, Projection, Fit, Cache, TimeMachine, CHOPtoTOP, FileSave, Null, Switch, Window, Matte, Premultiply, Posterize, RadialBlur, AntiAlias, Palette |
| **CHOP** | 53 | LFO, Wave, Noise, Constant, Pattern, Timer, Ramp, Clock, Expression, Math, Filter, Lag, Limit, Trigger, Speed, Count, Hold, Select, Smooth, Spring, Delay, Envelope, Analyze, Lookup, Stretch, Resample, Trim, Extend, Logic, Merge, Cross, Interpolate, Join, Composite, Copy, Shuffle, Split, Fan, Delete, Null, Switch, Rename, DATtoCHOP, Physics, Script, OscIn, OscOut, MidiIn, AudioIn, AudioSpectrum, AudioFileIn, AudioDeviceOut, Record, KeyboardIn, MouseIn, Gamepad, Parameter, Trail, SOPtoCHOP, TOPtoCHOP |
| **DAT** | 25 | Constant, Text, Info, OscIn, MidiIn, Select, Sort, Transpose, Evaluate, Merge, Null, Switch, CHOPtoDAT, Script, Callback, FileSave, FileIn, JSON, Web, Substitute, Insert, Delete, FIFO, SOPtoDAT, TOPtoDAT, OPFind |
| **SOP** | 51 | Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Tube, Font, Transform, Noise, Subdivide, Wireframe, Normal, Reverse, Peak, Sort, Facet, Delete, Point, Attribute, Clip, Mirror, Extrude, Merge, Copy, Scatter, Boolean, Sweep, Skin, Null, Switch, Script, Spring, Bend, Twist, Taper, Trail, UVProject, Divide, LSystem, Metaball, IsoSurface, Particle, Magnet, Carve, PolyReduce, CHOPtoSOP, DATtoSOP, TOPtoSOP |
| **COMP** | 15 | Geometry, Camera, Light, Merge, RigidBody, StaticBody, SoftBody, Area, Joint, Null, Switch, Environment, GenericScript, Instance, Animation |
| **MAT** | 6 | PBR, Shader, Constant, Wireframe, PointSprite, Depth |
| **IMG** | 15 | Noise, Checkerboard, ImageFileIn, ImageSequence, Webcam, ScreenGrab, Blur, EdgeDetect, PixelSort, Script, ImgToTOP, TOPtoIMG, FileSave, MovieOut, FFmpegOut |
| **Output** | 1 | Window |
| **Total** | **225** | |

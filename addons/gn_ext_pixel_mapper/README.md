# gn_ext_pixel_mapper -- LED Pixel Mapping Extension

MadMapper-style LED pixel mapping for GONODES. Define fixture shapes (strips, grids, matrices), place them visually on a source image using interactive handles in the viewer panel, and output sampled LED colour values as CHOP channels for DMX routing.

**Pure GDScript + one GLSL shader -- no native binaries or external dependencies required.**

---

## Overview

The PixelMapper extension introduces its own **FIX family** -- a data type that describes an LED fixture's shape, LED count, and DMX addressing. FIX nodes define fixtures in local space (a unit square); the **FixtureSamplerTOP** owns each fixture's placement on the source image and provides interactive drag handles in its viewer panel.

FixtureSamplerTOP has three outputs:
- **Port 0 (TOP):** Source texture passthrough -- connect to WindowOUT for preview
- **Port 1 (CHOP):** Sampled LED colour values as named channels (0-1) with dmx_routing metadata -- connect to PixelDmxOUT
- **Port 2 (UI panel):** Interactive fixture handles -- connect to WindowOUT panel for pop-out editing (`GNTopInteractiveBase`)

```
StripFIX --+
GridFIX   -+---> FixtureSamplerTOP --port 0--> WindowOUT (texture)
MatrixFIX -+          |                |--port 1--> PixelDmxOUT (Art-Net)
                  NoiseTOP / any TOP    \--port 2--> WindowOUT (panel)
```
### Viewer Interaction

When you view FixtureSamplerTOP, you see the source image with fixture handles overlaid:
- **Strips:** Two draggable endpoints + connecting line + LED dots along the line
- **Grids/Matrices:** Four draggable corner handles + bounding rect + LED dot grid
- **Custom:** Draggable offset handle + LED dots
- Fixtures are colour-coded for visual distinction (cyan, magenta, yellow, green, blue, orange)
- Labels show fixture names; tooltips on hover

When you view a FIX node, you see a visual LED layout with colour-coded dots. Hover over any LED to see its DMX address (Universe, Channel range).

---

## Architecture

### FIX Wire Data -- GNFixtureData

| Field | Type | Description |
|-------|------|-------------|
| led_positions | PackedVector2Array | Local-space LED positions (0-1 unit square) |
| fixture_name | String | Label for CHOP channel names and viewer overlay |
| led_count | int | Total LEDs (always = led_positions.size()) |
| channel_layout | String | "rgb", "rgbw", "r", "g", "b", "w" |
| channels_per_led | int | 3 for rgb, 4 for rgbw, 1 for single |
| universe | int | DMX universe (1-based) |
| start_channel | int | First DMX channel within the universe (1-512) |
| shape | StringName | "strip", "grid", "matrix", "custom" (handle type hint) |

### Placement Transforms (owned by FixtureSamplerTOP)

Each fixture connected to the sampler has a placement transform stored on the sampler node:

| Shape | Placement Data | Interaction |
|-------|---------------|-------------|
| strip | Two endpoints (a, b) | Drag endpoints to position the line |
| grid/matrix | Four corners (tl, tr, bl, br) | Drag corners to define a quad |
| custom | Offset + scale | Drag to position the group |

Local LED positions are mapped to source-image UV via:
- **Strip:** `lerp(a, b, local_x)` -- each LED's x coordinate (0-1) interpolates along the line
- **Grid/Matrix:** Bilinear interpolation across 4 corners using `(local_x, local_y)`
- **Custom:** `offset + local_pos * scale`

Placements are serialized in .gnpatch files under "fixture_placements".

### GPU Sampling

The sampler builds a LED-position texture (RGBAf, one pixel per LED: r=uv_x, g=uv_y, b=extent_x, a=extent_y) and dispatches a single GPU shader pass that samples the source image at all LED positions simultaneously. No source image readback occurs (Rule 25.1). The tiny result texture is read back to CPU only when the CHOP output (port 1) is demanded (Rule 25.24).

### DMX Addressing

Each fixture has a DMX universe (1-based) and start channel (1-512). The absolute address is computed as: `(universe - 1) * 512 + (start_channel - 1)`. A 60-LED RGB strip at Universe 1, Channel 1 occupies channels 1-180.

---

## Operators (10)

### FIX Primitives

| node_type | Class | Description |
|-----------|-------|-------------|
| strip_fix | StripFIX | N LEDs in a horizontal line (local space) |
| grid_fix | GridFIX | Cols x rows LEDs filling a unit square (local space) |
| matrix_fix | MatrixFIX | LED matrix with configurable pitch, rotation, and skew |
| custom_fix | CustomFIX | LED positions from a DAT -- columns "x", "y" required |
| file_in_fix | FileInFIX | Loads a .fixture JSON file |

### FIX Utilities

| node_type | Class | Description |
|-----------|-------|-------------|
| null_fix | NullFIX | Pass-through relay |
| select_fix | SelectFIX | Wireless FIX reference (Rule 25.35) |
| switch_fix | SwitchFIX | Selects one of N FIX inputs by index |

### Sampling & Output

| node_type | Family | Class | Description |
|-----------|--------|-------|-------------|
| fixture_sampler | TOP | FixtureSamplerTOP | MadMapper-style placement + GPU sampling. Port 0 = passthrough TOP, Port 1 = CHOP |
| pixel_dmx_out | OUT | PixelDmxOUT | Multi-universe Art-Net output. Reads dmx_routing metadata, scales 0-1 to 0-255 |

---

## .fixture JSON Format

```json
{
  "name": "my_strip",
  "shape": "strip",
  "channel_layout": "rgb",
  "universe": 1,
  "start_channel": 1,
  "leds": [
    {"x": 0.0, "y": 0.5},
    {"x": 0.1, "y": 0.5}
  ]
}
```

FileInFIX also supports legacy "uv_x"/"uv_y" keys for backward compatibility.

---

## Help Patches

| Patch | Demonstrates |
|-------|-------------|
| help/fix/strip_fix_basic.gnpatch | StripFIX -> FixtureSamplerTOP -> WindowOUT |
| help/fix/grid_fix_basic.gnpatch | GridFIX -> FixtureSamplerTOP -> WindowOUT |
| help/top/fixture_sampler_top_multi.gnpatch | Two strips + grid, sampler CHOP output |

---

## Roadmap

- [ ] **Fixture library panel** -- a palette of common fixture profiles (WS2812B strips, APA102 rings, common LED panel sizes) that can be dragged into the network
- [ ] **Zig-zag / serpentine scan order** -- a parameter on GridFIX to alternate row direction for LED panels wired in serpentine order

---

## Directory Layout

```
addons/gn_ext_pixel_mapper/
  gn_extension.cfg          # Extension manifest -- FIX family + 10 operators
  boot.gd                   # Boot script (empty)
  README.md
  core/
    gn_fixture_data.gd      # GNFixtureData -- FIX wire data type
    gn_fixture_base.gd      # GNFixtureBase -- shared base class + LED viewer
  operators/
    fix/                     # 8 FIX operators (5 primitives + 3 utilities)
    output/
      pixel_dmx_out.gd       # Multi-universe Art-Net output (OUT family)
    top/
      fixture_sampler_top.gd # MadMapper-style placement + sampling
  ui/
    fixture_overlay.gd       # Interactive handles overlay for sampler viewer
    fixture_viewer_overlay.gd # LED hover tooltip overlay for FIX viewer
  shaders/
    fixture_sampler.gdshader # Point + box-filter GPU sampling shader
  help/
    fix/                     # 2 FIX help patches
    top/                     # 1 TOP help patch
  tests/
    test_pixel_mapper_operators.gd
```

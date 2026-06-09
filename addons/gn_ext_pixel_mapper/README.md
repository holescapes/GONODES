# gn_ext_pixel_mapper — LED Pixel Mapping Extension

LED pixel-mapping operators for GONODES. Define fixture layouts, sample a source image at every LED's UV position in a single GPU pass, and route the resulting colour values to DMX or downstream CHOP processing.

**Pure GDScript + one GLSL shader — no native binaries or external dependencies required.**

---

## Overview

The PixelMapper extension introduces its own **FIX family** — a data type that describes a set of LED positions in UV space. Fixture nodes produce `GNFixtureData` on a FIX wire. `FixtureSamplerTOP` accepts multiple FIX wires and one source image, and samples all LED positions in a single GPU shader dispatch. `FixtureUnpackCHOP` reads the compact result texture back to CPU (tiny — `channels_per_led × total_leds` pixels) and emits named CHOP channels for DMX routing.

```
StripFIX ──┐
GridFIX   ─┼──► FixtureSamplerTOP ──► FixtureUnpackCHOP ──► DmxOutCHOP
MatrixFIX ─┘          ↑
                  NoiseTOP / any TOP
```

---

## Architecture

### FIX Wire Data — `GNFixtureData`

`GNFixtureData` is the data type carried on FIX wires. Key fields:

| Field | Type | Description |
|-------|------|-------------|
| `fixture_name` | String | Label — used in CHOP channel names and the viewer overlay |
| `led_positions` | PackedVector2Array | One UV coordinate per LED (0–1 on both axes) |
| `led_count` | int | Total LEDs — always equals `led_positions.size()` |
| `channel_layout` | String | `"rgb"`, `"rgbw"`, `"r"`, `"g"`, `"b"`, `"w"` |
| `channels_per_led` | int | Derived from `channel_layout` (3 for rgb, 4 for rgbw, 1 for single) |
| `dmx_start` | int | First DMX channel: `universe × 512 + channel_index` (0 = unassigned) |
| `sample_extent` | Vector2 | UV half-size of box-filter area per LED — `Vector2.ZERO` = point sample |

### Base Class — `GNFixtureBase`

All FIX operators extend `GNFixtureBase`, which:
- Resolves the `FIX_FAMILY` id once from the extension registry (`GNFamily.string_to_type("FIX")`)
- Provides `_prepare_output() -> GNFixtureData` (reuses cached data, clears LED arrays)
- Provides `_get_input_fix(inputs, port) -> GNFixtureData` (type-safe input extraction)
- Implements `render_for_viewer()` to show LED count and dmx_start in the viewer panel

### GPU Sampling — `FixtureSamplerTOP`

- Port 0: source image (any TOP, any resolution — no readback)
- Ports 1+: dynamic auto-grow FIX inputs (same pattern as MergeCHOP, RenderTOP)
- On cook:
  1. Collects all connected `GNFixtureData` objects
  2. If fixtures changed (hash mismatch), rebuilds the **LED-position texture**: an `RGBAf` image of size `(total_leds × 1)` where each pixel is `(uv_x, uv_y, extent_x, extent_y)` — CPU only, happens once per fixture change
  3. Sets shader uniforms and dispatches a single render pass
- Output texture size: `(max_channels_per_led × total_leds)` — compact, GPU-only, no readback of the source image (Rule 25.1 compliant)

### Shader — `shaders/fixture_sampler.gdshader`

A canvas-item shader. For each output pixel `(channel_col, led_row)`:
1. Reads the LED's UV and sample extent from the LED-position texture
2. Point-samples (or 3×3 box-filters) the source image at that UV
3. Outputs the requested channel's value in the red component

### CPU Unpack — `FixtureUnpackCHOP`

- Reads the tiny packed result texture back to CPU (`tex.get_image()`)
- Walks `FixtureSamplerTOP._fixture_manifest` for fixture metadata
- Emits one CHOP channel per fixture × channel × LED: `"strip.r.0"`, `"strip.g.0"`, ...
- `value_range` param: 0–1 float (for normalised math) or 0–255 int (for raw DMX)
- Wire output to `DmxOutCHOP` to send to hardware

---

## Operators (10)

### FIX Primitives

| Operator | Class | Description |
|----------|-------|-------------|
| `strip_fix` | `StripFIX` | N LEDs evenly spaced along a UV line (uv_start → uv_end) |
| `grid_fix` | `GridFIX` | Cols × rows of LEDs within a UV bounding box |
| `matrix_fix` | `MatrixFIX` | LED matrix with configurable pixel pitch, rotation (deg), and skew |
| `custom_fix` | `CustomFIX` | LED positions loaded from a DAT input — columns `uv_x`, `uv_y` required |
| `file_in_fix` | `FileInFIX` | Loads a `.fixture` JSON file (`{"name":..., "leds":[{"uv_x":f,"uv_y":f},...]}`) |

### FIX Utilities

| Operator | Class | Description |
|----------|-------|-------------|
| `null_fix` | `NullFIX` | Pass-through relay — useful as a labelled junction point |
| `select_fix` | `SelectFIX` | Wireless FIX reference — re-emits a named node's output (Rule 25.35) |
| `switch_fix` | `SwitchFIX` | Selects one of N FIX inputs by index; dynamic auto-grow inputs |

### Sampling & Output

| Operator | Family | Class | Description |
|----------|--------|-------|-------------|
| `fixture_sampler` | TOP | `FixtureSamplerTOP` | Single-pass GPU sampler — all fixtures, all LEDs |
| `fixture_unpack` | CHOP | `FixtureUnpackCHOP` | Packed texture → named CHOP channels → DMX |

---

## `.fixture` JSON Format

```json
{
  "name": "my_strip",
  "channel_layout": "rgb",
  "dmx_start": 1,
  "leds": [
    {"uv_x": 0.1, "uv_y": 0.5},
    {"uv_x": 0.2, "uv_y": 0.5},
    ...
  ]
}
```

Fields `channel_layout` and `dmx_start` can be overridden by the `FileInFIX` parameters at node level.

---

## Help Patches

| Patch | Demonstrates |
|-------|-------------|
| `help/fix/strip_fix_basic.gnpatch` | NoiseTOP → StripFIX → FixtureSamplerTOP → WindowOUT |
| `help/fix/grid_fix_basic.gnpatch` | NoiseTOP → GridFIX → FixtureSamplerTOP → WindowOUT |
| `help/top/fixture_sampler_top_multi.gnpatch` | Two strips + grid all sampled in one pass |
| `help/chop/fixture_unpack_chop_basic.gnpatch` | Full chain with FixtureUnpackCHOP → CHOPtoTOP → WindowOUT |

---

## Directory Layout

```
addons/gn_ext_pixel_mapper/
├── gn_extension.cfg                          # Extension manifest — registers FIX family + 10 operators
├── boot.gd                                   # Boot script (empty — no extra registration needed)
├── README.md                                 # This file
├── core/
│   ├── gn_fixture_data.gd                    # GNFixtureData — FIX wire data type
│   └── gn_fixture_base.gd                    # GNFixtureBase — shared base class
├── operators/
│   ├── fix/
│   │   ├── strip_fix.gd                      # Linear LED strip
│   │   ├── grid_fix.gd                       # 2D LED grid
│   │   ├── matrix_fix.gd                     # LED matrix (pitch/rotation/skew)
│   │   ├── custom_fix.gd                     # Custom positions from DAT
│   │   ├── file_in_fix.gd                    # Load .fixture JSON
│   │   ├── null_fix.gd                       # Pass-through
│   │   ├── select_fix.gd                     # Wireless reference
│   │   └── switch_fix.gd                     # Index selector
│   ├── top/
│   │   └── fixture_sampler_top.gd            # GPU sampler (TOP output)
│   └── chop/
│       └── fixture_unpack_chop.gd            # Packed texture → CHOP channels
├── shaders/
│   └── fixture_sampler.gdshader              # Point + box-filter sampling shader
├── help/
│   ├── fix/
│   │   ├── strip_fix_basic.gnpatch
│   │   └── grid_fix_basic.gnpatch
│   ├── top/
│   │   └── fixture_sampler_top_multi.gnpatch
│   └── chop/
│       └── fixture_unpack_chop_basic.gnpatch
└── tests/
    └── test_pixel_mapper_operators.gd        # 20 tests
```

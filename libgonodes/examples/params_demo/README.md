# Parameters Demo

Comprehensive demonstration of the GONODES C API for **parameter control
and data I/O** — no GPU or windowing library needed (headless mode).

## What It Demonstrates

### Host I/O Manifest
- **`gonodes_get_host_io(gn)`** — query the patch's declared interface
- Auto-discover inputs (texture/CHOP/DAT), outputs, and exposed parameters
- Use the manifest JSON to build UI bindings, validate requirements

### Parameter Types
- **Float**: `gonodes_set_parameter(gn, "noise1", "scale", "8.0")`
- **Integer**: `gonodes_set_parameter(gn, "noise1", "seed", "42")`
- **Boolean**: `gonodes_set_parameter(gn, "noise1", "monochrome", "false")`
- **String**: `gonodes_set_parameter(gn, "text1", "text", "\"Hello\"")`
- **Color (RGBA)**: `"[1.0, 0.3, 0.0, 1.0]"`
- **Vector2i**: `"{\"_type\": \"Vector2i\", \"x\": 1920, \"y\": 1080}"`

### CHOP I/O
- Single-sample injection (tx, ty, tz constants)
- Multi-sample injection (128-sample sine waveform)
- Reading output channels with `gonodes_get_output_chop()`

### DAT I/O
- Table injection as JSON 2D array
- Reading output table with `gonodes_get_output_table()`

### Introspection
- `gonodes_list_nodes()` — JSON array of all nodes
- `gonodes_list_connections()` — JSON array of all wires
- `gonodes_list_parameters()` — per-node parameter listing
- `gonodes_get_node_info()` — detailed node info

### Callbacks
- Parameter change callback via `gonodes_set_on_param_changed()`
- Log routing via `gonodes_set_log_callback()`

### Lifecycle
- Version query, patch load, cook, reload, destroy
- Performance stats via `gonodes_get_stats()`

## Build

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target params_demo
```

## Run

A sample patch is included at `examples/patches/params_test.gnpatch`:

```bash
./params_demo /path/to/gonodes_project ../patches/params_test.gnpatch
```

## Patch Layout

The included `params_test.gnpatch` contains all the nodes the demo expects:

| Node ID | Type | Role |
|---------|------|------|
| `noise1` | NoiseTOP | Parameter control (scale, seed, monochrome, resolution) |
| `text1` | TextTOP | String parameter demo |
| `constant1` | ConstantTOP | Color parameter demo |
| `host_lfo` | HostInCHOP | Receives animated LFO |
| `host_chop` | HostInCHOP | Receives tx/ty/tz channels |
| `host_wave` | HostInCHOP | Receives 128-sample waveform |
| `host_dat` | HostInDAT | Receives sensor table |
| `host_out_tex` | HostOutTOP | Exports texture (wired from noise1) |
| `host_out_chop` | HostOutCHOP | Exports channels (passthrough from host_chop) |
| `host_out_dat` | HostOutDAT | Exports table (passthrough from host_dat) |

## Dependencies

- libgonodes + libgodot (no windowing or GPU libraries needed)
